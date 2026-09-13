import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'database_models.dart';

class VendorPortalScreen extends StatefulWidget {
  const VendorPortalScreen({super.key});

  @override
  State<VendorPortalScreen> createState() => _VendorPortalScreenState();
}

class _VendorPortalScreenState extends State<VendorPortalScreen> {
  bool _isLoading = false;
  List<Map<String, dynamic>> _vendorOrders = [];

  Timer? _smartPollingTimer;
  Set<String> _localSeenOrderIds = {};
  bool _isFirstLoad = true;

  @override
  void initState() {
    super.initState();
    _loadLocalSeenOrders();
    _startSmartOrderChecker();
  }

  @override
  void dispose() {
    _smartPollingTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadLocalSeenOrders() async {
    final prefs = await SharedPreferences.getInstance();
    List<String> savedIds = prefs.getStringList('vendor_seen_order_ids') ?? [];
    setState(() {
      _localSeenOrderIds = savedIds.toSet();
    });
  }

  Future<void> _saveSeenOrderIds() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('vendor_seen_order_ids', _localSeenOrderIds.toList());
  }

  void _startSmartOrderChecker() {
    _fetchAllVendorOrdersRest(isInitial: true);
    
    _smartPollingTimer = Timer.periodic(const Duration(seconds: 6), (timer) async {
      try {
        final response = await http.get(Uri.parse('${CakeDatabase.firebaseRestUrl}/orders.json?shallow=true'));
        if (response.statusCode == 200 && response.body != 'null') {
          Map<String, dynamic> data = json.decode(response.body);
          
          bool hasNewOrder = false;
          for (String serverId in data.keys) {
            if (!_localSeenOrderIds.contains(serverId)) {
              hasNewOrder = true;
              break;
            }
          }

          if (!_isFirstLoad && hasNewOrder) {
            HapticFeedback.heavyImpact();
            if (mounted) {
              ScaffoldMessenger.of(context).removeCurrentSnackBar();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('🔔 🛒 नया आर्डर प्राप्त हुआ है!'),
                  backgroundColor: Colors.orange,
                  duration: Duration(seconds: 4),
                ),
              );
            }
            _fetchAllVendorOrdersRest(isInitial: false);
          }
        }
      } catch (e) {
        debugPrint("Vendor smart local-cache check error: $e");
      }
    });
  }

  Future<void> _fetchAllVendorOrdersRest({bool isInitial = false}) async {
    try {
      final response = await http.get(Uri.parse('${CakeDatabase.firebaseRestUrl}/orders.json'));
      if (response.statusCode == 200 && response.body != 'null') {
        Map<String, dynamic> data = json.decode(response.body);
        List<Map<String, dynamic>> loadedOrders = [];

        data.forEach((key, value) {
          if (value is Map) {
            var order = Map<String, dynamic>.from(value);
            order['orderId'] = key;
            _localSeenOrderIds.add(key);
            loadedOrders.add(order);
          }
        });

        _saveSeenOrderIds();
        loadedOrders = loadedOrders.reversed.toList();

        if (mounted) {
          setState(() {
            _vendorOrders = loadedOrders;
            _isFirstLoad = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _vendorOrders = [];
            _isFirstLoad = false;
          });
        }
      }
    } catch (e) {
      debugPrint("Vendor Rest order fetch error: $e");
    }
  }

  Future<void> _updateOrderStatus(String orderId, String newStatus) async {
    try {
      await http.patch(
        Uri.parse('${CakeDatabase.firebaseRestUrl}/orders/$orderId.json'),
        body: json.encode({
          'orderStatus': newStatus,
          'status': newStatus,
        }),
      );
      HapticFeedback.mediumImpact();
      _showMsg('✅ आर्डर स्टेटस बदलकर "$newStatus" कर दिया गया!', Colors.green);
      _fetchAllVendorOrdersRest();
    } catch (e) {
      debugPrint("Vendor Status update error: $e");
    }
  }

  Future<void> _deleteOrder(String orderId) async {
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('⚠️ आर्डर डिलीट करें?'),
        content: const Text('क्या आप इस आर्डर को हमेशा के लिए हटाना चाहते हैं?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('नहीं')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('हाँ, डिलीट करें', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await http.delete(Uri.parse('${CakeDatabase.firebaseRestUrl}/orders/$orderId.json'));
        _localSeenOrderIds.remove(orderId);
        _saveSeenOrderIds();
        HapticFeedback.mediumImpact();
        _showMsg('🗑️ आर्डर हमेशा के लिए डिलीट कर दिया गया!', Colors.red);
        _fetchAllVendorOrdersRest();
      } catch (e) {
        debugPrint("Vendor Delete order error: $e");
      }
    }
  }

  void _showMsg(String msg, Color color) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));
    }
  }

  String _getTimeAgo(String? timeStr) {
    if (timeStr == null || timeStr.isEmpty) return 'अभी-अभी';
    try {
      DateTime orderTime = DateTime.parse(timeStr);
      Duration diff = DateTime.now().difference(orderTime);
      
      if (diff.inSeconds < 60) {
        return 'अभी-अभी (${diff.inSeconds} सेकेंड पहले)';
      } else if (diff.inMinutes < 60) {
        return '${diff.inMinutes} मिनट पहले';
      } else if (diff.inHours < 24) {
        return '${diff.inHours} घंटे पहले';
      } else {
        return '${orderTime.day}/${orderTime.month}/${orderTime.year}';
      }
    } catch (e) {
      return timeStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        title: const Text('🏪 वेंडर पोर्टल (Orders Management)', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 13)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.orange),
            onPressed: () => _fetchAllVendorOrdersRest(),
            tooltip: 'मैनुअल रिफ्रेश',
          ),
        ],
      ),
      body: _vendorOrders.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.storefront, size: 70, color: Colors.grey.shade400),
                  const SizedBox(height: 12),
                  const Text('कोई नया आर्डर नहीं आया है!', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey)),
                  const SizedBox(height: 8),
                  const Text('(नया आर्डर आते ही डैशबोर्ड खुद अपडेट हो जाएगा)', style: TextStyle(fontSize: 11, color: Colors.orange)),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _vendorOrders.length,
              itemBuilder: (context, index) {
                var order = _vendorOrders[index];
                String orderId = order['orderId'] ?? '';
                String customerName = order['customerName'] ?? order['name'] ?? 'Customer';
                String phone = order['customerPhone'] ?? order['phone'] ?? '';
                
                String deliveryAddress = order['customerAddress'] ?? order['deliveryAddress'] ?? order['address'] ?? 'पता उपलब्ध नहीं';
                String status = order['orderStatus'] ?? order['status'] ?? 'Pending ⏳';
                var items = order['items'] as List<dynamic>? ?? [];
                double totalAmount = (order['totalAmount'] ?? order['grandTotal'] ?? 0.0).toDouble();
                String timeAgo = _getTimeAgo(order['orderTime']);

                bool isAccepted = status.toLowerCase().contains('accepted') || status.toLowerCase().contains('accepted ✅');
                bool isDelivered = status.toLowerCase().contains('delivered');

                return Card(
                  margin: const EdgeInsets.only(bottom: 14),
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text('📦 #${orderId.length > 8 ? orderId.substring(0, 8) : orderId}',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.orange.shade800)),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(4)),
                              child: Text(timeAgo, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black54)),
                            ),
                            const SizedBox(width: 6),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                              onPressed: () => _deleteOrder(orderId),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              tooltip: 'ऑर्डर डिलीट करें',
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('ग्राहक: $customerName ($phone)', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: isDelivered ? Colors.green.shade100 : (isAccepted ? Colors.blue.shade100 : Colors.orange.shade100),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(status, style: TextStyle(
                                fontSize: 11, 
                                fontWeight: FontWeight.bold, 
                                color: isDelivered ? Colors.green.shade800 : (isAccepted ? Colors.blue.shade800 : Colors.orange.shade800)
                              )),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        // केवल डिलीवरी एड्रेस (पिकअप दुकान का एड्रेस यहां से हटा दिया गया है)
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade50,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.orange.shade200),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.location_on, size: 14, color: Colors.red),
                              const SizedBox(width: 4),
                              Expanded(child: Text('डिलीवरी एड्रेस: $deliveryAddress', style: const TextStyle(fontSize: 11, color: Colors.black87, fontWeight: FontWeight.w500))),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),

                        const Text('🛒 आर्डर का पूरा ब्यौरा (Item List):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.grey)),
                        const SizedBox(height: 4),

                        ...items.map((it) {
                          var m = it is Map ? it : {};
                          String itemName = m['name'] ?? m['title'] ?? 'आइटम';
                          var itemQty = m['qty'] ?? 1;
                          var itemPrice = double.tryParse(m['price'].toString()) ?? 0;

                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('• $itemName (Qty: $itemQty)', style: const TextStyle(fontSize: 12)),
                                Text('₹${itemPrice * (double.tryParse(itemQty.toString()) ?? 1)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          );
                        }),

                        const Divider(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('कुल राशि: ₹$totalAmount', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.orange.shade800)),
                            Row(
                              children: [
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white, minimumSize: const Size(60, 30)),
                                  onPressed: () => _updateOrderStatus(orderId, 'Accepted ✅'),
                                  icon: const Icon(Icons.check, size: 14),
                                  label: const Text('स्वीकार', style: TextStyle(fontSize: 10)),
                                ),
                                const SizedBox(width: 6),
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white, minimumSize: const Size(60, 30)),
                                  onPressed: () => _updateOrderStatus(orderId, 'Ready / Packed 📦'),
                                  icon: const Icon(Icons.inventory, size: 14),
                                  label: const Text('पैक', style: TextStyle(fontSize: 10)),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
