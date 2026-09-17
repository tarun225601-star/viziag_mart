import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'database_models.dart';

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
  
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();

  final _regNameController = TextEditingController();
  final _regPhoneController = TextEditingController();
  final _regVehicleController = TextEditingController();
  final _regPasswordController = TextEditingController();

  List<Map<String, dynamic>> _activeOrders = [];
  List<Map<String, dynamic>> _pendingRiders = [];

  Timer? _smartPollingTimer;
  Set<String> _localSeenOrderIds = {};
  bool _isFirstLoad = true;

  @override
  void initState() {
    super.initState();
    _loadLocalSeenOrders();
  }

  Future<void> _loadLocalSeenOrders() async {
    final prefs = await SharedPreferences.getInstance();
    List<String> savedIds = prefs.getStringList('seen_order_ids') ?? [];
    setState(() {
      _localSeenOrderIds = savedIds.toSet();
    });
  }

  Future<void> _saveSeenOrderIds() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('seen_order_ids', _localSeenOrderIds.toList());
  }

  @override
  void dispose() {
    _smartPollingTimer?.cancel();
    _phoneController.dispose();
    _passwordController.dispose();
    _regNameController.dispose();
    _regPhoneController.dispose();
    _regVehicleController.dispose();
    _regPasswordController.dispose();
    super.dispose();
  }

  void _startSmartOrderChecker() {
    _fetchAllActiveOrdersRest(isInitial: true);
    
    _smartPollingTimer = Timer.periodic(const Duration(seconds: 6), (timer) async {
      if (!_isLoggedIn || _isAdminLoggedIn) return;
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
                  content: Text('⚡ 🚴‍♂️ नया डिलीवरी ऑर्डर प्राप्त हुआ है!'),
                  backgroundColor: Colors.green,
                  duration: Duration(seconds: 4),
                ),
              );
            }
            _fetchAllActiveOrdersRest(isInitial: false);
          }
        }
      } catch (e) {
        debugPrint("Smart local-cache check error: $e");
      }
    });
  }

  Future<void> _fetchAllActiveOrdersRest({bool isInitial = false}) async {
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

            String status = order['orderStatus'] ?? order['status'] ?? 'Pending';
            if (!status.toLowerCase().contains('delivered')) {
              loadedOrders.add(order);
            }
          }
        });

        _saveSeenOrderIds();
        loadedOrders = loadedOrders.reversed.toList();

        if (mounted) {
          setState(() {
            _activeOrders = loadedOrders;
            _isFirstLoad = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _activeOrders = [];
            _isFirstLoad = false;
          });
        }
      }
    } catch (e) {
      debugPrint("Rest order fetch error: $e");
    }
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
      final response = await http.get(Uri.parse('${CakeDatabase.firebaseRestUrl}/riders.json'));
      if (response.statusCode == 200 && response.body != 'null') {
        Map<String, dynamic> data = json.decode(response.body);
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
            _isLoading = false;
          });
          _showMsg('🎉 राइडर लॉगिन सफल!', Colors.green);
          _startSmartOrderChecker();
        } else if (found && !approved) {
          setState(() => _isLoading = false);
          _showMsg('⏳ आपका अकाउंट अभी एडमिन द्वारा अप्रूव नहीं किया गया है!', Colors.orange);
        } else {
          setState(() => _isLoading = false);
          _showMsg('गलत मोबाइल नंबर या पासवर्ड!', Colors.red);
        }
      } else {
        setState(() => _isLoading = false);
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
      final response = await http.post(
        Uri.parse('${CakeDatabase.firebaseRestUrl}/riders.json'),
        body: json.encode({
          'name': name,
          'phone': phone,
          'vehicle': vehicle,
          'password': password,
          'isApproved': false,
          'createdAt': DateTime.now().toIso8601String(),
        }),
      );

      if (response.statusCode == 200) {
        setState(() {
          _isLoading = false;
          _isRegistering = false;
        });
        _showMsg('✅ रजिस्ट्रेशन सफल! एडमिन अप्रूवल के बाद ही लॉगिन कर सकेंगे।', Colors.green);
      } else {
        setState(() => _isLoading = false);
        _showMsg('रजिस्ट्रेशन फेल हुआ!', Colors.red);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showMsg('रजिस्ट्रेशन एरर: $e', Colors.red);
    }
  }

  Future<void> _fetchPendingRidersRest() async {
    setState(() => _isLoading = true);
    try {
      final response = await http.get(Uri.parse('${CakeDatabase.firebaseRestUrl}/riders.json'));
      if (response.statusCode == 200 && response.body != 'null') {
        Map<String, dynamic> data = json.decode(response.body);
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
        Uri.parse('${CakeDatabase.firebaseRestUrl}/riders/$riderId.json'),
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
        _fetchAllActiveOrdersRest();
      } catch (e) {
        debugPrint("Delete order error: $e");
      }
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
      _fetchAllActiveOrdersRest();
    } catch (e) {
      debugPrint("Status update error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isLoggedIn) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8F9FA),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 1,
          title: Text(_isRegistering ? '📝 नया राइडर रजिस्ट्रेशन' : '🚴‍♂️ राइडर पोर्टल लॉगिन', 
            style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 16)),
        ),
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Card(
              elevation: 3,
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
        backgroundColor: const Color(0xFFF8F9FA),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 1,
          title: const Text('👑 एडमिन: राइडर अप्रूवल पैनल', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 16)),
          actions: [
            IconButton(
              icon: const Icon(Icons.logout, color: Colors.red),
              onPressed: () {
                _smartPollingTimer?.cancel();
                setState(() { _isLoggedIn = false; _isAdminLoggedIn = false; });
              },
              tooltip: 'लॉग आउट',
            ),
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Colors.green))
            : _pendingRiders.isEmpty
                ? const Center(child: Text('कोई नया राइडर अप्रूवल के लिए पेंडिंग नहीं है!', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)))
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _pendingRiders.length,
                    itemBuilder: (context, index) {
                      var rider = _pendingRiders[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        child: ListTile(
                          title: Text(rider['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text('फोन: ${rider['phone']}\nवाहन: ${rider['vehicle']}'),
                          isThreeLine: true,
                          trailing: ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                            onPressed: () => _approveRider(rider['riderId']),
                            child: const Text('Approve'),
                          ),
                        ),
                      );
                    },
                  ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        title: const Text('🚴‍♂️ राइडर डिलीवरी (Pickup & Bill Info)', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 12)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.green),
            onPressed: () => _fetchAllActiveOrdersRest(),
            tooltip: 'मैनुअल रिफ्रेश',
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.red),
            onPressed: () {
              _smartPollingTimer?.cancel();
              setState(() => _isLoggedIn = false);
            },
            tooltip: 'लॉग आउट',
          ),
        ],
      ),
      body: _activeOrders.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.delivery_dining, size: 70, color: Colors.grey.shade400),
                  const SizedBox(height: 12),
                  const Text('कोई नया डिलीवरी ऑर्डर उपलब्ध नहीं है!', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey)),
                  const SizedBox(height: 8),
                  const Text('(नया आर्डर आते ही स्क्रीन अपने आप अपडेट हो जाएगी)', style: TextStyle(fontSize: 11, color: Colors.green)),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _activeOrders.length,
              itemBuilder: (context, index) {
                var order = _activeOrders[index];
                String orderId = order['orderId'] ?? '';
                String customerName = order['customerName'] ?? order['name'] ?? 'Customer';
                String phone = order['customerPhone'] ?? order['phone'] ?? '';
                
                // 📍 पिकअप और डिलीवरी एड्रेस
                String shopAddress = order['shopAddress'] ?? 'Sector 89A Ajronda Sabji Mandi Faridabad';
                String deliveryAddress = order['customerAddress'] ?? order['deliveryAddress'] ?? order['address'] ?? 'पता उपलब्ध नहीं';
                
                String status = order['orderStatus'] ?? order['status'] ?? 'Pending ⏳';
                var items = order['items'] as List<dynamic>? ?? [];
                double totalAmount = (order['totalAmount'] ?? order['grandTotal'] ?? 0.0).toDouble();
                String timeAgo = _getTimeAgo(order['orderTime']);

                bool isAccepted = status.toLowerCase().contains('accepted') || status.toLowerCase().contains('accepted ✅');

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
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.green.shade800)),
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
                                color: isAccepted ? Colors.blue.shade100 : Colors.orange.shade100,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(status, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isAccepted ? Colors.blue.shade800 : Colors.orange.shade800)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
      भाई राइडर वाले कोड में तो डिलीवर होते ही अपने आप ही हट जाते हैं आइटम लेकिन वेंडर वाले में नहीं हटते लेकिन इसमें मेरा नेट बहुत खर्च हो रहा है ध्यान कर लेना पूरा 50% चुटकियों में उड़ गया नेट
