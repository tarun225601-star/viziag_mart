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
  String? _lastKnownLatestKey;

  @override
  void initState() {
    super.initState();
    _loadInitialOrders();
  }

  // 1. राइडर स्टाइल: पहले लोकल मेमोरी से तुरंत दिखाओ (नेट ज़ीरो खर्च)
  Future<void> _loadInitialOrders() async {
    setState(() => isLoading = true);
    await CakeDatabase.loadOrdersLocally();
    if (mounted) {
      setState(() {
        allOrders = List<Map<String, dynamic>>.from(CakeDatabase.localOrdersCache);
        if (allOrders.isNotEmpty) {
          _lastKnownLatestKey = allOrders.first['firebaseKey'] ?? allOrders.first['orderId'];
        }
        isLoading = false;
      });
    }
    _startRiderStylePolling();
  }

  // 2. 5 सेकंड वाला स्मार्ट पोलिंग (नया ऑर्डर पकड़ने के लिए)
  void _startRiderStylePolling() {
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 5));
      if (!mounted) return false;

      try {
        var newOrder = await CakeDatabase.fetchSingleLatestOrderOnly();
        
        if (newOrder != null) {
          String newKey = newOrder['firebaseKey'] ?? newOrder['orderId'] ?? '';
          
          if (newKey.isNotEmpty && newKey != _lastKnownLatestKey) {
            _lastKnownLatestKey = newKey;
            
            CakeDatabase.localOrdersCache.insert(0, newOrder);
            await CakeDatabase.saveOrdersLocally();

            if (mounted) {
              setState(() {
                allOrders = List<Map<String, dynamic>>.from(CakeDatabase.localOrdersCache);
              });
              
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('🔔 नया आर्डर आ गया और लोकल मेमोरी में सुरक्षित हो गया!'), 
                  backgroundColor: Colors.green,
                  duration: Duration(seconds: 2),
                ),
              );
            }
          }
        }
      } catch (_) {}

      return mounted;
    });
  }

  // मैनुअल रिफ्रेश बटन
  Future<void> _manualRefresh() async {
    setState(() => isLoading = true);
    try {
      final res = await http.get(Uri.parse('${CakeDatabase.firebaseRestUrl}/orders.json'));
      if (res.statusCode == 200 && res.body != 'null' && res.body.isNotEmpty) {
        Map<String, dynamic> data = json.decode(res.body);
        List<Map<String, dynamic>> list = [];
        data.forEach((key, val) {
          var item = Map<String, dynamic>.from(val);
          item['firebaseKey'] = key;
          list.add(item);
        });
        CakeDatabase.localOrdersCache = list.reversed.toList();
        await CakeDatabase.saveOrdersLocally();
        if (mounted) {
          setState(() {
            allOrders = CakeDatabase.localOrdersCache;
            if (allOrders.isNotEmpty) {
              _lastKnownLatestKey = allOrders.first['firebaseKey'];
            }
          });
        }
      }
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  // ऑर्डर का स्टेटस बदलने के लिए (जैसे स्वीकार करना या पूरा करना)
  Future<void> _updateOrderStatus(String firebaseKey, String newStatus) async {
    if (firebaseKey.isEmpty) return;
    try {
      await http.patch(
        Uri.parse('${CakeDatabase.firebaseRestUrl}/orders/$firebaseKey.json'),
        body: json.encode({'status': newStatus}),
      );
      // लोकल लिस्ट में भी स्टेटस अपडेट करके सेव करें
      for (var ord in allOrders) {
        if (ord['firebaseKey'] == firebaseKey) {
          ord['status'] = newStatus;
          break;
        }
      }
      await CakeDatabase.saveOrdersLocally();
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('ऑर्डर स्टेटस अपडेट हुआ: $newStatus'), backgroundColor: Colors.blue),
      );
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('स्टेटस अपडेट करने में विफल!'), backgroundColor: Colors.red),
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
            onPressed: _manualRefresh,
            tooltip: 'रिफ्रेश (Refresh)',
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
                      String? imageUrl = order['image'] ?? order['imageUrl'] ?? order['photo'];

                      return Card(
                        elevation: 3,
                        margin: const EdgeInsets.only(bottom: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // ऊपर का हिस्सा: फोटो, टाइटल और कीमत
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // आर्डर की फोटो
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: imageUrl != null && imageUrl.isNotEmpty
                                        ? Image.network(
                                            imageUrl,
                                            width: 55,
                                            height: 55,
                                            fit: BoxFit.cover,
                                            errorBuilder: (context, error, stackTrace) => Container(
                                              width: 55,
                                              height: 55,
                                              color: Colors.grey.shade200,
                                              child: const Icon(Icons.cake, color: Colors.grey),
                                            ),
                                          )
                                        : Container(
                                            width: 55,
                                            height: 55,
                                            color: Colors.green.shade50,
                                            child: const Icon(Icons.shopping_bag, color: Colors.green, size: 28),
                                          ),
                                  ),
                                  const SizedBox(width: 12),
                                  // टाइटल और स्टेटस
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          order['title'] ?? 'ऑर्डर #${index + 1}',
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'स्थिति: $currentStatus',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: currentStatus == 'Accepted' ? Colors.blue : (currentStatus == 'Completed' ? Colors.green : Colors.orange),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  // मूल्य
                                  Text(
                                    '₹${order['totalAmount'] ?? order['price'] ?? 0}',
                                    style: const TextStyle(color: Colors.green, fontWeight: FontWeight.w900, fontSize: 16),
                                  ),
                                ],
                              ),
                              const Divider(height: 20),
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
                              // मात्रा (Qty) बैज
                              Row(
                                children: [
                                  Chip(
                                    label: Text('मात्रा (Qty): ${order['qty'] ?? order['quantity'] ?? 1}', style: const TextStyle(fontSize: 11)),
                                    backgroundColor: Colors.green.shade50,
                                    labelStyle: TextStyle(color: Colors.green.shade800, fontWeight: FontWeight.bold),
                                    padding: EdgeInsets.zero,
                                  ),
                                ],
                              ),
                              const Divider(height: 16),
                              // एक्शन बटन (Accept / Complete)
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
