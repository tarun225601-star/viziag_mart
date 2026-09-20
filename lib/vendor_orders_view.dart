import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';

class VendorOrdersScreen extends StatefulWidget {
  const VendorOrdersScreen({super.key});

  @override
  State<VendorOrdersScreen> createState() => _VendorOrdersScreenState();
}

class _VendorOrdersScreenState extends State<VendorOrdersScreen> {
  bool _isLoading = false;
  int _todayAcceptedCount = 0;
  double _todayTotalRevenue = 0.0;
  
  // 📦 लोकल सेव किए गए पुराने ऑर्डर्स की हिस्ट्री
  List<Map<String, dynamic>> _vendorHistoryList = [];

  Map<String, dynamic>? _latestIncomingOrder;
  Set<String> _localSeenOrderIds = {};

  Timer? _orderRefreshTimer;
  final String _firebaseRestUrl = "https://viziagmart-default-rtdb.firebaseio.com";

  @override
  void initState() {
    super.initState();
    _loadLocalData();
    _startOrderRefreshTimer();
  }

  // 📂 लोकल मेमोरी से डेटा लोड करना
  Future<void> _loadLocalData() async {
    final prefs = await SharedPreferences.getInstance();
    List<String> savedIds = prefs.getStringList('vendor_seen_order_ids') ?? [];
    String? historyString = prefs.getString('vendor_orders_history');
    List<Map<String, dynamic>> loadedHistory = [];
    
    if (historyString != null && historyString.isNotEmpty) {
      try {
        List decoded = json.decode(historyString);
        loadedHistory = decoded.map((e) => Map<String, dynamic>.from(e)).toList();
      } catch (e) {
        debugPrint("History load error: $e");
      }
    }

    setState(() {
      _localSeenOrderIds = savedIds.toSet();
      _vendorHistoryList = loadedHistory;
      _todayAcceptedCount = loadedHistory.length;
      
      double totalRev = 0.0;
      for (var ord in loadedHistory) {
        double amt = double.tryParse((ord['grandTotal'] ?? ord['totalAmount'] ?? '0').toString()) ?? 0.0;
        totalRev += amt;
      }
      _todayTotalRevenue = totalRev;
    });
  }

  Future<void> _saveSeenOrderIds() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('vendor_seen_order_ids', _localSeenOrderIds.toList());
  }

  // 💾 आर्डर को लोकल हिस्ट्री में सेव करना
  Future<void> _saveOrderToVendorHistory(Map<String, dynamic> order) async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _vendorHistoryList.insert(0, order);
      _todayAcceptedCount = _vendorHistoryList.length;
      
      double totalRev = 0.0;
      for (var ord in _vendorHistoryList) {
        double amt = double.tryParse((ord['grandTotal'] ?? ord['totalAmount'] ?? '0').toString()) ?? 0.0;
        totalRev += amt;
      }
      _todayTotalRevenue = totalRev;
    });

    await prefs.setString('vendor_orders_history', json.encode(_vendorHistoryList));
  }

  @override
  void dispose() {
    _orderRefreshTimer?.cancel();
    super.dispose();
  }

  void _triggerNewOrderAlert() {
    HapticFeedback.heavyImpact();
    Future.delayed(const Duration(milliseconds: 300), () {
      HapticFeedback.vibrate();
    });
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🚨 नया वेंडर आर्डर आ गया है भाई!', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          backgroundColor: Colors.redAccent,
          duration: Duration(seconds: 4),
        ),
      );
    }
  }

  String _formatOrderTime(dynamic timestampRaw) {
    if (timestampRaw == null) return 'समय उपलब्ध नहीं';
    try {
      DateTime orderTime;
      if (timestampRaw is int) {
        orderTime = DateTime.fromMillisecondsSinceEpoch(timestampRaw);
      } else if (timestampRaw is String) {
        orderTime = DateTime.parse(timestampRaw);
      } else {
        return 'समय उपलब्ध नहीं';
      }
      return DateFormat('hh:mm a (dd MMM)').format(orderTime);
    } catch (e) {
      return timestampRaw.toString();
    }
  }

  // सिर्फ लेटेस्ट आर्डर चेक करने के लिए (जीरो नेट वेस्टेज)
  Future<void> _fetchOnlyLatestIncomingOrder() async {
    try {
      final uri = Uri.parse('$_firebaseRestUrl/orders.json?orderBy="\$key"&limitToLast=1');
      final res = await http.get(uri);

      if (res.statusCode == 200 && res.body != 'null' && res.body.isNotEmpty) {
        Map<String, dynamic> decodedData = json.decode(res.body);
        bool hasNewOrder = false;
        Map<String, dynamic>? fetchedOrder;

        decodedData.forEach((key, value) {
          if (value is Map) {
            var order = Map<String, dynamic>.from(value);
            order['orderId'] = key;

            String status = order['orderStatus'] ?? order['status'] ?? 'Pending';
            // केवल पेंडिंग आर्डर्स दिखाओ जो वेंडर ने अभी एक्सेप्ट न किए हों
            if (status.toLowerCase() == 'pending') {
              fetchedOrder = order;

              if (!_localSeenOrderIds.contains(key)) {
                _localSeenOrderIds.add(key);
                hasNewOrder = true;
              }
            }
          }
        });

        _saveSeenOrderIds();

        if (mounted) {
          setState(() {
            _latestIncomingOrder = fetchedOrder;
          });

          if (hasNewOrder) {
            _triggerNewOrderAlert();
          }
        }
      } else {
        if (mounted) {
          setState(() {
            _latestIncomingOrder = null;
          });
        }
      }
    } catch (e) {
      debugPrint("Fetch vendor single order error: $e");
    }
  }

  void _startOrderRefreshTimer() {
    _orderRefreshTimer?.cancel();
    _orderRefreshTimer = Timer.periodic(const Duration(seconds: 6), (timer) {
      if (mounted) {
        _fetchOnlyLatestIncomingOrder();
      }
    });
  }

  void _showMsg(String msg, Color color) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));
    }
  }

  // 1️⃣ वेंडर आर्डर स्वीकार करेगा और उसे डिलीवरी राइडर के पास भेजेगा
  Future<void> _acceptAndForwardOrder(Map<String, dynamic> order) async {
    String orderId = order['orderId'];
    try {
      // स्टेटस 'Accepted' करो
      await http.patch(
        Uri.parse('$_firebaseRestUrl/orders/$orderId.json'),
        body: json.encode({
          'orderStatus': 'Accepted',
          'status': 'Accepted',
        }),
      );

      // डिलीवरी वाले नोड में भेज दो ताकि राइडर को मिल जाए
      await http.post(
        Uri.parse('$_firebaseRestUrl/delivery_orders.json'),
        body: json.encode(order),
      );

      HapticFeedback.mediumImpact();
      _showMsg('✅ आर्डर स्वीकार कर लिया गया और डिलीवरी राइडर को भेज दिया गया!', Colors.green);
      
      order['orderStatus'] = 'Accepted';
      await _saveOrderToVendorHistory(order);

      setState(() {
        _latestIncomingOrder = null; 
      });
    } catch (e) {
      debugPrint("Vendor accept error: $e");
      _showMsg('एरर: $e', Colors.red);
    }
  }

  // 2️⃣ वेंडर आर्डर रद्द करेगा
  Future<void> _rejectOrder(Map<String, dynamic> order) async {
    String orderId = order['orderId'];
    try {
      await http.patch(
        Uri.parse('$_firebaseRestUrl/orders/$orderId.json'),
        body: json.encode({
          'orderStatus': 'Rejected',
          'status': 'Rejected',
        }),
      );
      HapticFeedback.mediumImpact();
      _showMsg('❌ आर्डर रद्द कर दिया गया!', Colors.red);

      setState(() {
        _latestIncomingOrder = null;
      });
    } catch (e) {
      debugPrint("Vendor reject error: $e");
    }
  }

  // 📜 पुरानी वेंडर हिस्ट्री देखने का डायलॉग
  void _showVendorHistoryDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('📜 स्वीकार किए गए आर्डर्स (${_vendorHistoryList.length})'),
        content: SizedBox(
          width: double.maxFinite,
          child: _vendorHistoryList.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(20),
                  child: Text('अभी तक कोई आर्डर प्रोसेस नहीं हुआ है!', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: _vendorHistoryList.length,
                  itemBuilder: (context, index) {
                    var ord = _vendorHistoryList[index];
                    String name = ord['customerName'] ?? ord['name'] ?? 'Customer';
                    String amount = ord['grandTotal']?.toString() ?? ord['totalAmount']?.toString() ?? '0';
                    String timeStr = _formatOrderTime(ord['timestamp'] ?? ord['createdAt'] ?? ord['time']);
                    
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        subtitle: Text('समय: $timeStr\nअमाउंट: ₹$amount', style: const TextStyle(fontSize: 12)),
                        trailing: const Icon(Icons.check_circle, color: Colors.green),
                        isThreeLine: true,
                      ),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('बंद करें'),
          ),
        ],
      ),
    );
  }

  // 🔍 पूरा विवरण देखने वाला डायलॉग (बिना शॉप एड्रेस के)
  void _showOrderDetailsDialog(Map<String, dynamic> order) {
    String customerName = order['customerName'] ?? order['name'] ?? 'Customer';
    String phone = order['customerPhone'] ?? order['phone'] ?? '';
    String address = order['customerAddress'] ?? order['deliveryAddress'] ?? order['address'] ?? 'पता उपलब्ध नहीं';
    String orderTimeStr = _formatOrderTime(order['timestamp'] ?? order['createdAt'] ?? order['time']);
    
    var itemsRaw = order['items'];
    String itemsText = '';
    if (itemsRaw is List) {
      itemsText = itemsRaw.map((it) => "${it['name'] ?? 'Item'} (x${it['qty'] ?? 1})").join(', ');
    } else {
      itemsText = itemsRaw?.toString() ?? 'आइटम विवरण नहीं';
    }

    String amount = order['grandTotal']?.toString() ?? order['totalAmount']?.toString() ?? order['amount']?.toString() ?? '0';
    String paymentMode = order['paymentMode'] ?? order['paymentType'] ?? 'COD';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('📦 ऑर्डर विवरण: $customerName'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('🕒 ऑर्डर का समय: $orderTimeStr', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.deepPurple)),
              const Divider(),
              const Text('📍 डिलीवरी (ग्राहक का पता):', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
              Text(address, style: const TextStyle(fontSize: 13)),
              const Divider(),
              Text('📞 मोबाइल नंबर: $phone'),
              const SizedBox(height: 6),
              Text('🛒 आइटम्स: $itemsText'),
              const SizedBox(height: 6),
              Text('💰 कुल राशि: ₹$amount'),
              const SizedBox(height: 6),
              Text('💳 पेमेंट मोड: $paymentMode'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('बंद करें'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),
      appBar: AppBar(
        title: const Text('🛒 वेंडर डैशबोर्ड', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.history, color: Colors.white),
            tooltip: 'प्रोसेस्ड हिस्ट्री',
            onPressed: _showVendorHistoryDialog,
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            tooltip: 'रिफ्रेश करें',
            onPressed: _fetchOnlyLatestIncomingOrder,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // डैशबोर्ड कार्ड (कुल स्वीकार आर्डर और कुल कमाई)
            Row(
              children: [
                Expanded(
                  child: Card(
                    color: Colors.teal.shade50,
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          const Text('स्वीकार आर्डर', style: TextStyle(color: Colors.teal, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 6),
                          Text('$_todayAcceptedCount', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.teal)),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Card(
                    color: Colors.green.shade50,
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          const Text('कुल बिजनेस', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 6),
                          Text('₹$_todayTotalRevenue', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.green)),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // नया आने वाला आर्डर सेक्शन
            const Text('🔔 नया इनकमिंग आर्डर', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
            const SizedBox(height: 10),

            _latestIncomingOrder == null
                ? Container(
                    height: 220,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.store_mall_directory_outlined, size: 50, color: Colors.grey),
                          SizedBox(height: 10),
                          Text('नये ग्राहक आर्डर का इंतज़ार है...\nऑटोमैटिक रिफ्रेश चालू है', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w500)),
                        ],
                      ),
                    ),
                  )
                : Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('आर्डर #${_latestIncomingOrder!['orderId']?.toString().substring(0, 6) ?? ''}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                              const Chip(
                                label: Text('नया आर्डर 🔔', style: TextStyle(color: Colors.white, fontSize: 11)),
                                backgroundColor: Colors.red,
                              ),
                            ],
                          ),
                          const Divider(height: 20),
                          Text('👤 ग्राहक: ${_latestIncomingOrder!['customerName'] ?? _latestIncomingOrder!['name'] ?? 'Customer'}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 6),
                          // 📍 केवल ग्राहक का पता
                          Text('📍 पता: ${_latestIncomingOrder!['customerAddress'] ?? _latestIncomingOrder!['deliveryAddress'] ?? _latestIncomingOrder!['address'] ?? 'पता उपलब्ध नहीं'}', style: const TextStyle(fontSize: 13, color: Colors.black54)),
                          const SizedBox(height: 6),
                          Text('📞 फोन: ${_latestIncomingOrder!['customerPhone'] ?? _latestIncomingOrder!['phone'] ?? ''}', style: const TextStyle(fontSize: 13)),
                          const SizedBox(height: 6),
                          Text('💰 अमाउंट: ₹${_latestIncomingOrder!['grandTotal'] ?? _latestIncomingOrder!['totalAmount'] ?? _latestIncomingOrder!['amount'] ?? '0'}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.green)),
                          const SizedBox(height: 16),
                          
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () => _showOrderDetailsDialog(_latestIncomingOrder!),
                                  icon: const Icon(Icons.info_outline, size: 16),
                                  label: const Text('विवरण'),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(foregroundColor: Colors.red, side: const BorderSide(color: Colors.red)),
                                  onPressed: () => _rejectOrder(_latestIncomingOrder!),
                                  icon: const Icon(Icons.close, size: 16),
                                  label: const Text('रद्द करें'),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
                                  onPressed: () => _acceptAndForwardOrder(_latestIncomingOrder!),
                                  icon: const Icon(Icons.check, size: 16),
                                  label: const Text('स्वीकार करें'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}
