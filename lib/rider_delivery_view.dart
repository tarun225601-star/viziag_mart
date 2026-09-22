import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';

class RiderDeliveryScreen extends StatefulWidget {
  const RiderDeliveryScreen({super.key});

  @override
  State<RiderDeliveryScreen> createState() => _RiderDeliveryScreenState();
}

class _RiderDeliveryScreenState extends State<RiderDeliveryScreen> {
  bool _isLoggedIn = false;
  bool _isAdminLoggedIn = false;
  bool _isRegistering = false;
  bool _isLoading = false;
  
  bool _isAcceptedByRider = false;

  int _todayCompletedCount = 0;
  double _todayTotalEarnings = 0.0;
  
  // 📦 लोकल सेव किए गए पुराने डिलीवर ऑर्डर्स की लिस्ट
  List<Map<String, dynamic>> _deliveredHistoryList = [];

  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();

  final _regNameController = TextEditingController();
  final _regPhoneController = TextEditingController();
  final _regVehicleController = TextEditingController();
  final _regPasswordController = TextEditingController();

  Map<String, dynamic>? _latestOrder;
  List<Map<String, dynamic>> _pendingRiders = [];
  Set<String> _localSeenOrderIds = {};

  Timer? _orderRefreshTimer;
  final String _firebaseRestUrl = "https://viziagmart-default-rtdb.firebaseio.com";

  @override
  void initState() {
    super.initState();
    _loadLocalData();
  }

  // 📂 लोकल मेमोरी से सीन ऑर्डर्स और पुरानी हिस्ट्री लोड करना
  Future<void> _loadLocalData() async {
    final prefs = await SharedPreferences.getInstance();
    
    // सीन आर्डर आईडी
    List<String> savedIds = prefs.getStringList('seen_order_ids') ?? [];
    
    // पुरानी डिलीवर हिस्ट्री
    String? historyString = prefs.getString('delivered_orders_history');
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
      _deliveredHistoryList = loadedHistory;
      _todayCompletedCount = loadedHistory.length; 
      
      // कुल कमाई कैलकुलेट करना
      double totalEarn = 0.0;
      for (var ord in loadedHistory) {
        double amt = double.tryParse((ord['grandTotal'] ?? ord['totalAmount'] ?? '0').toString()) ?? 0.0;
        totalEarn += amt;
      }
      _todayTotalEarnings = totalEarn;
    });
  }

  Future<void> _saveSeenOrderIds() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('seen_order_ids', _localSeenOrderIds.toList());
  }

  // 💾 डिलीवर आर्डर को लोकल मेमोरी में हमेशा के लिए SharedPreferences में सेव करना
  Future<void> _saveOrderToLocalHistory(Map<String, dynamic> order) async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _deliveredHistoryList.insert(0, order); // सबसे ऊपर नया जोड़ें
      _todayCompletedCount = _deliveredHistoryList.length;
      
      double totalEarn = 0.0;
      for (var ord in _deliveredHistoryList) {
        double amt = double.tryParse((ord['grandTotal'] ?? ord['totalAmount'] ?? '0').toString()) ?? 0.0;
        totalEarn += amt;
      }
      _todayTotalEarnings = totalEarn;
    });

    // SharedPreferences में JSON स्ट्रिंग बनाकर सेव करें
    await prefs.setString('delivered_orders_history', json.encode(_deliveredHistoryList));
  }

  @override
  void dispose() {
    _orderRefreshTimer?.cancel();
    _phoneController.dispose();
    _passwordController.dispose();
    _regNameController.dispose();
    _regPhoneController.dispose();
    _regVehicleController.dispose();
    _regPasswordController.dispose();
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
          content: Text('🚨 नया डिलीवरी आर्डर आ गया है भाई!', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
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

  Future<void> _fetchOnlyLatestOrderRest() async {
    if (_isAcceptedByRider) return; 

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
            if (!status.toLowerCase().contains('delivered')) {
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
            _latestOrder = fetchedOrder;
          });

          if (hasNewOrder) {
            _triggerNewOrderAlert();
          }
        }
      } else {
        if (mounted && !_isAcceptedByRider) {
          setState(() {
            _latestOrder = null;
          });
        }
      }
    } catch (e) {
      debugPrint("Fetch single order REST error: $e");
    }
  }

  void _startOrderRefreshTimer() {
    _orderRefreshTimer?.cancel();
    _orderRefreshTimer = Timer.periodic(const Duration(seconds: 120), (timer) {
      if (mounted && _isLoggedIn && !_isAdminLoggedIn && !_isAcceptedByRider) {
        _fetchOnlyLatestOrderRest();
      }
    });
  }

  Future<void> _loginRider() async {
    String phone = _phoneController.text.trim();
    String password = _passwordController.text.trim();

    if (phone.isEmpty || password.isEmpty) {
      _showMsg('कृपया मोबाइल नंबर और पासवर्ड दर्ज करें!', Colors.red);
      return;
    }

    if (password == 'tarun#1') {
      setState(() {
        _isAdminLoggedIn = true;
        _isLoggedIn = true;
      });
      _showMsg('👑 एडमिन पैनल लॉगिन सफल!', Colors.green);
      _fetchPendingRidersRest();
      return;
    }

    setState(() => _isLoading = true);
    try {
      final res = await http.get(Uri.parse('$_firebaseRestUrl/riders.json'));
      setState(() => _isLoading = false);

      if (res.statusCode == 200 && res.body != 'null' && res.body.isNotEmpty) {
        Map<String, dynamic> data = json.decode(res.body);
        bool found = false;
        bool approved = false;

        data.forEach((key, value) {
          if (value is Map && value['phone'] == phone && value['password'] == password) {
            found = true;
            if (value['isApproved'] == true) {
              approved = true;
            }
          }
        });

        if (found && approved) {
          setState(() {
            _isLoggedIn = true;
            _isAdminLoggedIn = false;
          });
          _showMsg('🎉 राइडर लॉगिन सफल!', Colors.green);
          _fetchOnlyLatestOrderRest();
          _startOrderRefreshTimer();
        } else if (found && !approved) {
          _showMsg('⏳ आपका अकाउंट अभी एडमिन द्वारा अप्रूव नहीं किया गया है!', Colors.orange);
        } else {
          _showMsg('गलत मोबाइल नंबर या पासवर्ड!', Colors.red);
        }
      } else {
        _showMsg('कोई राइडर रजिस्टर्ड नहीं है!', Colors.red);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showMsg('एरर: $e', Colors.red);
    }
  }

  Future<void> _registerRider() async {
    String name = _regNameController.text.trim();
    String phone = _regPhoneController.text.trim();
    String vehicle = _regVehicleController.text.trim();
    String password = _regPasswordController.text.trim();

    if (name.isEmpty || phone.isEmpty || vehicle.isEmpty || password.isEmpty) {
      _showMsg('सभी फील्ड भरना अनिवार्य है!', Colors.red);
      return;
    }

    setState(() => _isLoading = true);
    try {
      final uri = Uri.parse('$_firebaseRestUrl/riders.json');
      await http.post(
        uri,
        body: json.encode({
          'name': name,
          'phone': phone,
          'vehicle': vehicle,
          'password': password,
          'isApproved': false,
          'createdAt': DateTime.now().toIso8601String(),
        }),
      );

      setState(() {
        _isLoading = false;
        _isRegistering = false;
      });
      _showMsg('✅ रजिस्ट्रेशन सफल! एडमिन अप्रूवल के बाद ही लॉगिन कर सकेंगे।', Colors.green);
    } catch (e) {
      setState(() => _isLoading = false);
      _showMsg('रजिस्ट्रेशन एरर: $e', Colors.red);
    }
  }

  Future<void> _fetchPendingRidersRest() async {
    setState(() => _isLoading = true);
    try {
      final res = await http.get(Uri.parse('$_firebaseRestUrl/riders.json'));
      if (res.statusCode == 200 && res.body != 'null' && res.body.isNotEmpty) {
        Map<String, dynamic> data = json.decode(res.body);
        List<Map<String, dynamic>> list = [];
        data.forEach((key, value) {
          if (value is Map) {
            var r = Map<String, dynamic>.from(value);
            r['riderId'] = key;
            if (r['isApproved'] != true) {
              list.add(r);
            }
          }
        });
        setState(() => _pendingRiders = list);
      } else {
        setState(() => _pendingRiders = []);
      }
    } catch (e) {
      debugPrint("Fetch pending error: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _approveRider(String riderId) async {
    try {
      await http.patch(
        Uri.parse('$_firebaseRestUrl/riders/$riderId.json'),
        body: json.encode({'isApproved': true}),
      );
      _showMsg('✅ राइडर सक्सेसफुली अप्रूव हो गया!', Colors.green);
      _fetchPendingRidersRest();
    } catch (e) {
      _showMsg('अप्रूवल एरर: $e', Colors.red);
    }
  }

  void _showMsg(String msg, Color color) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));
    }
  }

  void _acceptOrder() {
    setState(() {
      _isAcceptedByRider = true;
    });
    HapticFeedback.mediumImpact();
    _showMsg('✅ आपने आर्डर स्वीकार कर लिया है! अब डिलीवरी पूरी करें।', Colors.green);
  }

  Future<void> _updateOrderStatus(Map<String, dynamic> order, String newStatus) async {
    String orderId = order['orderId'];
    try {
      await http.patch(
        Uri.parse('$_firebaseRestUrl/orders/$orderId.json'),
        body: json.encode({
          'orderStatus': newStatus,
          'status': newStatus,
        }),
      );
      HapticFeedback.mediumImpact();
      _showMsg('🎉 डिलीवरी सफलतापूर्वक पूरी हो गई! कमाई जुड़ गई है।', Colors.green);
      
      // 📦 आर्डर को लोकल हिस्ट्री और SharedPreferences में सेव करें
      order['orderStatus'] = newStatus;
      await _saveOrderToLocalHistory(order);

      setState(() {
        _latestOrder = null; 
        _isAcceptedByRider = false; 
      });
    } catch (e) {
      debugPrint("Status update error: $e");
    }
  }

  // 📜 पुराने डिलीवर ऑर्डर्स की हिस्ट्री देखने वाला डायलॉग
  void _showHistoryDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('📜 पुरानी आर्डर हिस्ट्री (${_deliveredHistoryList.length})'),
        content: SizedBox(
          width: double.maxFinite,
          child: _deliveredHistoryList.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(20),
                  child: Text('अभी तक कोई पुराना डिलीवर आर्डर सेव नहीं है!', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: _deliveredHistoryList.length,
                  itemBuilder: (context, index) {
                    var ord = _deliveredHistoryList[index];
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

  void _showOrderDetailsDialog(Map<String, dynamic> order) {
    String customerName = order['customerName'] ?? order['name'] ?? 'Customer';
    String phone = order['customerPhone'] ?? order['phone'] ?? '';
    String address = order['customerAddress'] ?? order['deliveryAddress'] ?? order['address'] ?? 'पता उपलब्ध नहीं';
    String shopAddress = order['shopAddress'] ?? order['pickupAddress'] ?? 'केक शॉप (मुख्य शाखा, फरीदाबाद)';
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
              const Text('🏬 पिकअप (शॉप एड्रेस):', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
              Text(shopAddress, style: const TextStyle(fontSize: 13)),
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
    if (!_isLoggedIn) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8F9FA),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 1,
          title: Text(_isRegistering ? '📝 नया राइडर रजिस्ट्रेशन' : '🚴‍♂️ राइडर पोर्टल लॉगिन', style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
        ),
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: _isRegistering ? _buildRegisterForm() : _buildLoginForm(),
              ),
            ),
          ),
        ),
      );
    }

    if (_isAdminLoggedIn) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.deepPurple,
          title: const Text('👑 एडमिन पैनल - राइडर अप्रूवल', style: TextStyle(color: Colors.white)),
          actions: [
            IconButton(
              icon: const Icon(Icons.logout, color: Colors.white),
              onPressed: () => setState(() => _isAdminLoggedIn = false),
            )
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _pendingRiders.isEmpty
                ? const Center(child: Text('कोई नया राइडर अप्रूवल के लिए पेंडिंग नहीं है!', style: TextStyle(fontSize: 15, color: Colors.grey)))
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _pendingRiders.length,
                    itemBuilder: (context, index) {
                      var r = _pendingRiders[index];
                      return Card(
                        elevation: 2,
                        margin: const EdgeInsets.only(bottom: 10),
                        child: ListTile(
                          title: Text(r['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text('मोबाइल: ${r['phone']}\nवाहन: ${r['vehicle']}'),
                          trailing: ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                            onPressed: () => _approveRider(r['riderId']),
                            child: const Text('अप्रूव करें'),
                          ),
                          isThreeLine: true,
                        ),
                      );
                    },
                  ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.green.shade700,
        title: const Text('🚴‍♂️ राइडर डिलीवरी डैशबोर्ड', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.history, color: Colors.white),
            tooltip: 'पुरानी हिस्ट्री',
            onPressed: _showHistoryDialog,
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            tooltip: 'लॉगआउट',
            onPressed: () => setState(() => _isLoggedIn = false),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 📊 स्टेटस कार्ड
            Row(
              children: [
                Expanded(
                  child: Card(
                    color: Colors.blue.shade50,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          const Text('डिलीवर ऑर्डर्स', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.blue)),
                          const SizedBox(height: 6),
                          Text('$_todayCompletedCount', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.blue)),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Card(
                    color: Colors.green.shade50,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          const Text('कुल कमाई', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.green)),
                          const SizedBox(height: 6),
                          Text('₹${_todayTotalEarnings.toStringAsFixed(1)}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.green)),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // 📦 लेटेस्ट ऑर्डर सेक्शन
            const Text('📦 नया उपलब्ध ऑर्डर', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),

            _latestOrder == null
                ? Container(
                    padding: const EdgeInsets.all(30),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade300)),
                    child: const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.hourglass_empty, size: 48, color: Colors.grey),
                          SizedBox(height: 10),
                          Text('फिलहाल कोई नया ऑर्डर नहीं है। नया ऑर्डर आने पर घंटी बजेगी!', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
                        ],
                      ),
                    ),
                  )
                : Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('ऑर्डर ID: ${_latestOrder!['orderId']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(6)),
                                child: const Text('नया ऑर्डर', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                          const Divider(),
                          Text('ग्राहक: ${_latestOrder!['customerName'] ?? _latestOrder!['name'] ?? 'Customer'}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                          const SizedBox(height: 4),
                          Text('पता: ${_latestOrder!['customerAddress'] ?? _latestOrder!['deliveryAddress'] ?? _latestOrder!['address'] ?? 'पता उपलब्ध नहीं'}', style: const TextStyle(color: Colors.grey, fontSize: 13)),
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('अमाउंट: ₹${_latestOrder!['grandTotal'] ?? _latestOrder!['totalAmount'] ?? '0'}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.green)),
                              TextButton.icon(
                                onPressed: () => _showOrderDetailsDialog(_latestOrder!),
                                icon: const Icon(Icons.info_outline, size: 16),
                                label: const Text('पूरा विवरण देखें'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          if (!_isAcceptedByRider)
                            SizedBox(
                              width: double.infinity,
                              height: 45,
                              child: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                              onPressed: _acceptOrder,
                              child: const Text('ऑर्डर स्वीकार करें (Accept)', style: TextStyle(fontWeight: FontWeight.bold)),
                            )
                          else
                            SizedBox(
                              width: double.infinity,
                              height: 45,
                              child: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                              onPressed: () => _updateOrderStatus(_latestOrder!, 'Delivered'),
                              child: const Text('डिलीवरी पूरी हुई (Mark as Delivered)', style: TextStyle(fontWeight: FontWeight.bold)),
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

  Widget _buildLoginForm() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('राइडर लॉगिन', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        TextField(
          controller: _phoneController,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(labelText: 'मोबाइल नंबर', border: OutlineInputBorder()),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _passwordController,
          obscureText: true,
          decoration: const InputDecoration(labelText: 'पासवर्ड (या एडमिन tarun#1)', border: OutlineInputBorder()),
        ),
        const SizedBox(height: 16),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white, padding: const EdgeInsets.all(12)),
          onPressed: _isLoading ? null : _loginRider,
          child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text('लॉगिन करें'),
        ),
        const SizedBox(height: 10),
        TextButton(
          onPressed: () => setState(() => _isRegistering = true),
          child: const Text('नया राइडर रजिस्ट्रेशन करें'),
        ),
      ],
    );
  }

  Widget _buildRegisterForm() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('नया राइडर रजिस्ट्रेशन', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        TextField(
          controller: _regNameController,
          decoration: const InputDecoration(labelText: 'पूरा नाम', border: OutlineInputBorder()),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _regPhoneController,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(labelText: 'मोबाइल नंबर', border: OutlineInputBorder()),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _regVehicleController,
          decoration: const InputDecoration(labelText: 'वाहन का नाम/नंबर (जैसे: Bike - DL 1234)', border: OutlineInputBorder()),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _regPasswordController,
          obscureText: true,
          decoration: const InputDecoration(labelText: 'पासवर्ड बनाएं', border: OutlineInputBorder()),
        ),
        const SizedBox(height: 16),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white, padding: const EdgeInsets.all(12)),
          onPressed: _isLoading ? null : _registerRider,
          child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text('रजिस्टर करें'),
        ),
        const SizedBox(height: 10),
        TextButton(
          onPressed: () => setState(() => _isRegistering = false),
          child: const Text('पहले से अकाउंट है? लॉगिन करें'),
        ),
      ],
    );
  }
}
