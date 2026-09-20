import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'database_models.dart';

class VendorOrdersView extends StatefulWidget {
  const VendorOrdersView({super.key});

  @override
  State<VendorOrdersView> createState() => _VendorOrdersViewState();
}

class _VendorOrdersViewState extends State<VendorOrdersView> {
  List<Map<String, dynamic>> allOrders = [];
  bool isLoading = false;
  String? _lastKnownFirebaseKey; // सबसे आखिरी नए आर्डर की आईडी ट्रैक करने के लिए

  @override
  void initState() {
    super.initState();
    _loadInitialOrders();
  }

  // 1. ऐप खुलते ही तुरंत लोकल मेमोरी से दिखाओ ताकि स्क्रीन खाली न रहे
  Future<void> _loadInitialOrders() async {
    setState(() => isLoading = true);
    await CakeDatabase.loadOrdersLocally();
    if (mounted) {
      setState(() {
        allOrders = List<Map<String, dynamic>>.from(CakeDatabase.localOrdersCache);
        if (allOrders.isNotEmpty) {
          _lastKnownFirebaseKey = allOrders.first['firebaseKey'];
        }
        isLoading = false;
      });
    }
    // साथ ही फायरबेस से ताज़ा पूरी लिस्ट एक बार खींच लो
    _fetchFullOrdersFromFirebase();
    // 2. 5 सेकंड वाला स्मार्ट बैकग्राउंड लूप शुरू करो (सिर्फ नया सिंगल आर्डर पकड़ने के लिए)
    _startRealtimeOrderPolling();
  }

  // फायरबेस से पूरी लिस्ट लाने के लिए
  Future<void> _fetchFullOrdersFromFirebase() async {
    try {
      final res = await http.get(Uri.parse('${CakeDatabase.firebaseRestUrl}/orders.json'));
      if (res.statusCode == 200 && res.body != 'null' && res.body.isNotEmpty) {
        Map<String, dynamic> data = json.decode(res.body);
        List<Map<String, dynamic>> list = [];
        data.forEach((key, val) {
          if (val != null) {
            var item = Map<String, dynamic>.from(val);
            item['firebaseKey'] = key;
            list.add(item);
          }
        });
        
        CakeDatabase.localOrdersCache = list.reversed.toList();
        await CakeDatabase.saveOrdersLocally();

        if (mounted) {
          setState(() {
            allOrders = List<Map<String, dynamic>>.from(CakeDatabase.localOrdersCache);
            if (allOrders.isNotEmpty) {
              _lastKnownFirebaseKey = allOrders.first['firebaseKey'];
            }
          });
        }
      }
    } catch (_) {}
  }

  // 3. सबसे तेज राइडर स्टाइल पोलिंग: हर 5 सेकंड में सिर्फ सबसे नया ऑर्डर चेक करेगा
  void _startRealtimeOrderPolling() {
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 5));
      if (!mounted) return false;

      try {
        // फायरबेस से सिर्फ सबसे आखिरी (Latest) ऑर्डर की मांग करो (जीरो नेट खर्च और सुपर फास्ट)
        final res = await http.get(Uri.parse('${CakeDatabase.firebaseRestUrl}/orders.json?orderBy="\$key"&limitToLast=1'));
        if (res.statusCode == 200 && res.body != 'null' && res.body.isNotEmpty) {
          Map<String, dynamic> data = json.decode(res.body);
          if (data.isNotEmpty) {
            String latestKey = data.keys.first;
            var latestVal = Map<String, dynamic>.from(data[latestKey]);
            latestVal['firebaseKey'] = latestKey;

            // अगर यह नया ऑर्डर है जो पहले से स्क्रीन पर नहीं है
            if (_lastKnownFirebaseKey != latestKey) {
              _lastKnownFirebaseKey = latestKey;

              // चेक करो कि क्या यह आर्डर पहले से लिस्ट में है या नहीं
              bool exists = allOrders.any((o) => o['firebaseKey'] == latestKey);
              if (!exists) {
                allOrders.insert(0, latestVal);
                CakeDatabase.localOrdersCache = List<Map<String, dynamic>>.from(allOrders);
                await CakeDatabase.saveOrdersLocally();

                if (mounted) {
                  setState(() {});
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('🔔 नया आर्डर आ गया है!'),
                      backgroundColor: Colors.green,
                      duration: Duration(seconds: 3),
                    ),
                  );
                }
              }
            }
          }
        }
      } catch (_) {}

      return mounted;
    });
  }

  // आर्डर का स्टेटस बदलने के लिए (स्वीकार करें / रद्द करें)
  Future<void> _updateOrderStatus(String firebaseKey, String newStatus) async {
    if (firebaseKey.isEmpty) return;
    try {
      await http.patch(
        Uri.parse('${CakeDatabase.firebaseRestUrl}/orders/$firebaseKey.json'),
        body: json.encode({'status': newStatus}),
      );
      for (var ord in allOrders) {
        if (ord['firebaseKey'] == firebaseKey) {
          ord['status'] = newStatus;
          break;
        }
      }
      await CakeDatabase.saveOrdersLocally();
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('ऑर्डर स्टेटस: $newStatus'), backgroundColor: Colors.green),
      );
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('अपडेट करने में विफल!'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🛒 वेंडर लाइव ऑर्डर्स', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 1,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.green),
            onPressed: _fetchFullOrdersFromFirebase,
            tooltip: 'रिफ्रेश',
          ),
        ],
      ),
      body: Column(
        children: [
          if (isLoading) const LinearProgressIndicator(color: Colors.green),
          Expanded(
            child: allOrders.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.inbox_outlined, size: 65, color: Colors.grey),
                        SizedBox(height: 12),
                        Text(
                          'अभी कोई नया आर्डर नहीं है!',
                          style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: allOrders.length,
                    itemBuilder: (context, index) {
                      final order = allOrders[index];
                      String currentStatus = order['status'] ?? 'Pending';
                      
                      // आइटम की डिटेल्स, फोटो और क्वांटिटी निकालने का पक्का लॉजिक
                      var itemsList = order['items'];
                      String itemTitle = 'ऑर्डर #${order['orderId'] ?? index + 1}';
                      String? imageUrl;
                      var quantity = order['qty'] ?? order['quantity'] ?? 1;

                      if (itemsList is List && itemsList.isNotEmpty) {
                        var firstItem = itemsList[0];
                        itemTitle = firstItem['title'] ?? firstItem['name'] ?? itemTitle;
                        imageUrl = firstItem['image'] ?? firstItem['imageUrl'] ?? firstItem['photo'];
                        quantity = firstItem['qty'] ?? firstItem['quantity'] ?? 1;
                      } else {
                        itemTitle = order['title'] ?? order['name'] ?? itemTitle;
                        imageUrl = order['image'] ?? order['imageUrl'] ?? order['photo'];
                      }

                      return Card(
                        elevation: 3,
                        margin: const EdgeInsets.only(bottom: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // फोटो, नाम और कीमत
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: imageUrl != null && imageUrl.isNotEmpty
                                        ? Image.network(
                                            imageUrl,
                                            width: 60,
                                            height: 60,
                                            fit: BoxFit.cover,
                                            errorBuilder: (context, error, stackTrace) => Container(
                                              width: 60,
                                              height: 60,
                                              color: Colors.grey.shade200,
                                              child: const Icon(Icons.fastfood, color: Colors.grey),
                                            ),
                                          )
                                        : Container(
                                            width: 60,
                                            height: 60,
                                            color: Colors.green.shade50,
                                            child: const Icon(Icons.shopping_bag, color: Colors.green, size: 30),
                                          ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          itemTitle,
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'स्थिति: $currentStatus',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: currentStatus == 'Accepted' ? Colors.blue : (currentStatus == 'Delivered' ? Colors.green : Colors.orange),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    '₹${order['totalAmount'] ?? order['price'] ?? 0}',
                                    style: const TextStyle(color: Colors.green, fontWeight: FontWeight.w900, fontSize: 16),
                                  ),
                                ],
                              ),
                              const Divider(height: 20),
                              // ग्राहक की जानकारी और पूरा एड्रेस
                              Row(
                                children: [
                                  const Icon(Icons.person, size: 14, color: Colors.grey),
                                  const SizedBox(width: 6),
                                  Text('ग्राहक: ${order['customerName'] ?? CakeDatabase.currentCustomerName}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  const Icon(Icons.phone, size: 14, color: Colors.grey),
                                  const SizedBox(width: 6),
                                  Text('फोन: ${order['customerPhone'] ?? CakeDatabase.currentUserPhone}', style: const TextStyle(fontSize: 12)),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  const Icon(Icons.location_on, size: 14, color: Colors.grey),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      'पता: ${order['customerAddress'] ?? order['address'] ?? CakeDatabase.currentDeliveryAddress}',
                                      style: const TextStyle(fontSize: 12, color: Colors.black54),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              // मात्रा (Qty)
                              Row(
                                children: [
                                  Chip(
                                    label: Text('पैकिंग मात्रा (Qty): $quantity', style: const TextStyle(fontSize: 11)),
                                    backgroundColor: Colors.green.shade50,
                                    labelStyle: TextStyle(color: Colors.green.shade800, fontWeight: FontWeight.bold),
                                    padding: EdgeInsets.zero,
                                  ),
                                ],
                              ),
                              const Divider(height: 16),
                              // एक्शन बटन्स
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  OutlinedButton.icon(
                                    onPressed: () {
                                      String key = order['firebaseKey'] ?? '';
                                      _updateOrderStatus(key, 'Rejected');
                                    },
                                    icon: const Icon(Icons.close, size: 16, color: Colors.red),
                                    label: const Text('रद्द करें', style: TextStyle(color: Colors.red, fontSize: 12)),
                                    style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.red)),
                                  ),
                                  const SizedBox(width: 8),
                                  ElevatedButton.icon(
                                    onPressed: () {
                                      String key = order['firebaseKey'] ?? '';
                                      _updateOrderStatus(key, 'Accepted');
                                    },
                                    icon: const Icon(Icons.check, size: 16, color: Colors.white),
                                    label: const Text('स्वीकार करें', style: TextStyle(fontSize: 12)),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green,
                                      foregroundColor: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
