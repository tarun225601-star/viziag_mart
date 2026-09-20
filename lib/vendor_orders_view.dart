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

  // 1. ऐप खुलते ही लोकल मेमोरी से तुरंत दिखाओ (बिना नेट खर्च किए)
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

  // पूरी लिस्ट केवल जरूरत पर लाने के लिए
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

  // 2. शून्य नेट खर्च स्मार्ट गिनती (Shallow Poling) - राइडर वाले स्टाइल में
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

  // केवल नया वाला आर्डर खींचने के लिए (जीरो वेस्टेज)
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

  // आर्डर स्टेटस अपडेट करने के लिए (वेंडर द्वारा)
  Future<void> _updateOrderStatus(String firebaseKey, String newStatus, Map<String, dynamic> orderData) async {
    if (firebaseKey.isEmpty) return;
    try {
      // 1. वेंडर के मेन आर्डर का स्टेटस अपडेट करो
      await http.patch(
        Uri.parse('${CakeDatabase.firebaseRestUrl}/orders/$firebaseKey.json'),
        body: json.encode({'status': newStatus, 'orderStatus': newStatus}),
      );

      // 2. जब वेंडर 'Accepted' करेगा, तभी आर्डर डिलीवरी राइडर के पास जाएगा
      if (newStatus == 'Accepted') {
        final deliveryUri = Uri.parse('${CakeDatabase.firebaseRestUrl}/delivery_orders.json');
        await http.post(deliveryUri, body: json.encode(orderData));
      }

      for (var ord in allOrders) {
        if (ord['firebaseKey'] == firebaseKey) {
          ord['status'] = newStatus;
          ord['orderStatus'] = newStatus;
          break;
        }
      }
      await CakeDatabase.saveOrdersLocally();
      setState(() {});

      String msg = newStatus == 'Accepted' ? '✅ आर्डर स्वीकार कर लिया गया और डिलीवरी राइडर को भेज दिया गया!' : '❌ आर्डर रद्द कर दिया गया';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: newStatus == 'Accepted' ? Colors.green : Colors.red),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('अपडेट विफल: $e'), backgroundColor: Colors.red),
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
                        String currentStatus = order['status'] ?? order['orderStatus'] ?? 'Pending';
                        var itemsList = order['items'] is List ? order['items'] as List : [];
                        var grandTotal = order['grandTotal'] ?? order['totalAmount'] ?? order['price'] ?? 0;

                        return Card(
                          elevation: 3,
                          margin: const EdgeInsets.only(bottom: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // ऊपर का हिस्सा: आर्डर आईडी और कुल रकम
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'आर्डर #${order['firebaseKey'] != null && order['firebaseKey'].toString().length > 6 ? order['firebaseKey'].toString().substring(0, 6) : (index + 1)}',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black54),
                                    ),
                                    Text(
                                      '₹${grandTotal.toString()}',
                                      style: const TextStyle(color: Colors.green, fontWeight: FontWeight.w900, fontSize: 17),
                                    ),
                                  ],
                                ),
                                const Divider(height: 14),

                                // आर्डर के अंदर के सभी आइटम्स की पूरी लिस्ट
                                const Text('📦 आर्डर किए गए आइटम्स:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
                                const SizedBox(height: 6),
                                ...itemsList.map((it) {
                                  var itemMap = it is Map ? it : {};
                                  String itemName = itemMap['name'] ?? itemMap['title'] ?? 'Item';
                                  var itemQty = itemMap['qty'] ?? itemMap['quantity'] ?? 1;
                                  var itemPrice = itemMap['price'] ?? 0;
                                  var itemUnit = itemMap['unit'] ?? '';

                                  return Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 3.0),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            '• $itemName ($itemQty $itemUnit)',
                                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                          ),
                                        ),
                                        Text(
                                          '₹${(double.tryParse(itemPrice.toString()) ?? 0) * (double.tryParse(itemQty.toString()) ?? 1)}',
                                          style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 13),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),

                                const Divider(height: 16),

                                // ग्राहक की जानकारी
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
                                        'पता: ${order['customerAddress'] ?? CakeDatabase.currentDeliveryAddress}',
                                        style: const TextStyle(fontSize: 12, color: Colors.black54),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),

                                // करंट स्टेटस बैज
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: currentStatus == 'Accepted' ? Colors.blue.shade50 : (currentStatus == 'Delivered' ? Colors.green.shade50 : Colors.orange.shade50),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        'स्थिति: $currentStatus',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: currentStatus == 'Accepted' ? Colors.blue.shade700 : (currentStatus == 'Delivered' ? Colors.green.shade700 : Colors.orange.shade800),
                                        ),
                                      ),
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
                                        _updateOrderStatus(key, 'Rejected', order);
                                      },
                                      icon: const Icon(Icons.close, size: 16, color: Colors.red),
                                      label: const Text('रद्द करें', style: TextStyle(color: Colors.red, fontSize: 12)),
                                      style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.red)),
                                    ),
                                    const SizedBox(width: 8),
                                    ElevatedButton.icon(
                                      onPressed: () {
                                        String key = order['firebaseKey'] ?? '';
                                        _updateOrderStatus(key, 'Accepted', order);
                                      },
                                      icon: const Icon(Icons.check, size: 16, color: Colors.white),
                                      label: const Text('स्वीकार करें (राइडर को भेजें)', style: TextStyle(fontSize: 12)),
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
