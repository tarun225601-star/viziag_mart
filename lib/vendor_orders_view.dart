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
  int _lastKnownCount = -1;

  @override
  void initState() {
    super.initState();
    _loadInitialOrders();
  }

  // 1. ऐप खुलते ही लोकल मेमोरी से दिखाओ
  Future<void> _loadInitialOrders() async {
    setState(() => isLoading = true);
    await CakeDatabase.loadOrdersLocally();
    if (mounted) {
      setState(() {
        allOrders = List<Map<String, dynamic>>.from(CakeDatabase.localOrdersCache);
        _lastKnownCount = allOrders.length;
        isLoading = false;
      });
    }
    _fetchFullOrdersFromFirebase();
    _startSmartCountPolling();
  }

  // पूरी लिस्ट लाने के लिए
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
            _lastKnownCount = allOrders.length;
          });
        }
      }
    } catch (_) {}
  }

  // 2. 5-सेकंड स्मार्ट गिनती (Shallow) पोलिंग - नेट बिल्कुल खर्च नहीं होगा
  void _startSmartCountPolling() {
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 5));
      if (!mounted) return false;

      try {
        final res = await http.get(Uri.parse('${CakeDatabase.firebaseRestUrl}/orders.json?shallow=true'));
        if (res.statusCode == 200 && res.body != 'null' && res.body.isNotEmpty) {
          Map<String, dynamic> data = json.decode(res.body);
          int currentServerCount = data.keys.length;

          if (_lastKnownCount != -1 && currentServerCount > _lastKnownCount) {
            await _fetchLatestSingleOrder();
          }
          _lastKnownCount = currentServerCount;
        }
      } catch (_) {}

      return mounted;
    });
  }

  // केवल नया आर्डर खींचने के लिए
  Future<void> _fetchLatestSingleOrder() async {
    try {
      final res = await http.get(Uri.parse('${CakeDatabase.firebaseRestUrl}/orders.json?orderBy="\$key"&limitToLast=1'));
      if (res.statusCode == 200 && res.body != 'null' && res.body.isNotEmpty) {
        Map<String, dynamic> data = json.decode(res.body);
        if (data.isNotEmpty) {
          String latestKey = data.keys.first;
          bool exists = allOrders.any((o) => o['firebaseKey'] == latestKey);
          if (!exists) {
            var latestVal = Map<String, dynamic>.from(data[latestKey]);
            latestVal['firebaseKey'] = latestKey;

            setState(() {
              allOrders.insert(0, latestVal);
            });

            CakeDatabase.localOrdersCache = List<Map<String, dynamic>>.from(allOrders);
            await CakeDatabase.saveOrdersLocally();

            if (mounted) {
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
    } catch (_) {}
  }

  // आर्डर स्टेटस अपडेट करने के लिए
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
        const SnackBar(content: Text('अपडेट विफल!'), backgroundColor: Colors.red),
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
      body: RefreshIndicator(
        onRefresh: _fetchFullOrdersFromFirebase,
        color: Colors.green,
        child: Column(
          children: [
            if (isLoading) const LinearProgressIndicator(color: Colors.green),
            Expanded(
              child: allOrders.isEmpty
                  ? ListView(
                      children: [
                        const SizedBox(height: 150),
                        Center(
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
                        ),
                      ],
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: allOrders.length,
                      itemBuilder: (context, index) {
                        final order = allOrders[index];
                        String currentStatus = order['status'] ?? 'Pending';
                        
                        // --- यहाँ है असली स्मार्ट एक्सट्रैक्शन लॉजिक (हर जगह से ढूंढ लेगा) ---
                        var itemsList = order['items'];
                        String itemTitle = '';
                        String? imageUrl;
                        var quantity = 1;

                        if (itemsList is List && itemsList.isNotEmpty) {
                          var firstItem = itemsList[0];
                          if (firstItem is Map) {
                            itemTitle = firstItem['title'] ?? firstItem['name'] ?? firstItem['productName'] ?? '';
                            imageUrl = firstItem['image'] ?? firstItem['imageUrl'] ?? firstItem['photo'] ?? firstItem['img'];
                            quantity = firstItem['qty'] ?? firstItem['quantity'] ?? 1;
                          }
                        } else if (itemsList is Map && itemsList.isNotEmpty) {
                          // अगर items लिस्ट न होकर Map के रूप में हो
                          var firstItem = itemsList.values.first;
                          if (firstItem is Map) {
                            itemTitle = firstItem['title'] ?? firstItem['name'] ?? firstItem['productName'] ?? '';
                            imageUrl = firstItem['image'] ?? firstItem['imageUrl'] ?? firstItem['photo'] ?? firstItem['img'];
                            quantity = firstItem['qty'] ?? firstItem['quantity'] ?? 1;
                          }
                        }

                        // अगर ऊपर न मिले, तो सीधे रूट लेवल पर चेक करो
                        if (itemTitle.isEmpty) {
                          itemTitle = order['title'] ?? order['name'] ?? order['productName'] ?? 'ऑर्डर #${order['orderId'] ?? index + 1}';
                        }
                        if (imageUrl == null || imageUrl.isEmpty) {
                          imageUrl = order['image'] ?? order['imageUrl'] ?? order['photo'] ?? order['img'];
                        }
                        if (quantity == 1) {
                          quantity = order['qty'] ?? order['quantity'] ?? order['count'] ?? 1;
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
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: imageUrl != null && imageUrl.toString().isNotEmpty
                                          ? Image.network(
                                              imageUrl.toString(),
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
                                            itemTitle.toString(),
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
                                      '₹${order['totalAmount'] ?? order['price'] ?? order['total'] ?? 0}',
                                      style: const TextStyle(color: Colors.green, fontWeight: FontWeight.w900, fontSize: 16),
                                    ),
                                  ],
                                ),
                                const Divider(height: 20),
                                Row(
                                  children: [
                                    const Icon(Icons.person, size: 14, color: Colors.grey),
                                    const SizedBox(width: 6),
                                    Text('ग्राहक: ${order['customerName'] ?? order['name'] ?? CakeDatabase.currentCustomerName}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(Icons.phone, size: 14, color: Colors.grey),
                                    const SizedBox(width: 6),
                                    Text('फोन: ${order['customerPhone'] ?? order['phone'] ?? CakeDatabase.currentUserPhone}', style: const TextStyle(fontSize: 12)),
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
      ),
    );
  }
}
