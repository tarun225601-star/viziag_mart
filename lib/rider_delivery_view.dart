import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

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
  Set<String> _localSeenOrderIds = {};

  // 5 मिनट वाला ऑटो-रिफ्रेश टाइमर
  Timer? _orderRefreshTimer;

  // Firebase REST URL for direct HTTP operations (100% safe from core-no-app crash)
  final String _firebaseRestUrl = "https://viziagmart-default-rtdb.firebaseio.com";

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
    _orderRefreshTimer?.cancel();
    _phoneController.dispose();
    _passwordController.dispose();
    _regNameController.dispose();
    _regPhoneController.dispose();
    _regVehicleController.dispose();
    _regPasswordController.dispose();
    super.dispose();
  }

  // 📳 नया आर्डर आने पर भौकाली हैप्टिक फीडबैक और अलर्ट
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

  // 🟢 REST API के जरिए ऑर्डर्स फेच करने वाला सॉलिड फंक्शन
  Future<void> _fetchOrdersRest() async {
    try {
      final uri = Uri.parse('$_firebaseRestUrl/orders.json');
      final res = await http.get(uri);

      if (res.statusCode == 200 && res.body != 'null' && res.body.isNotEmpty) {
        Map<String, dynamic> data = json.decode(res.body);
        List<Map<String, dynamic>> loadedOrders = [];
        bool hasNewOrder = false;

        data.forEach((key, value) {
          if (value is Map) {
            var order = Map<String, dynamic>.from(value);
            order['orderId'] = key;

            String status = order['orderStatus'] ?? order['status'] ?? 'Pending';
            if (!status.toLowerCase().contains('delivered')) {
              loadedOrders.add(order);

              if (!_localSeenOrderIds.contains(key)) {
                _localSeenOrderIds.add(key);
                hasNewOrder = true;
              }
            }
          }
        });

        _saveSeenOrderIds();
        loadedOrders = loadedOrders.reversed.toList();

        if (mounted) {
          setState(() {
            _activeOrders = loadedOrders;
          });

          if (hasNewOrder) {
            _triggerNewOrderAlert();
          }
        }
      } else {
        if (mounted) {
          setState(() {
            _activeOrders = [];
          });
        }
      }
    } catch (e) {
      debugPrint("Fetch orders REST error: $e");
    }
  }

  // ⏱️ 5 मिनट वाला ऑटो-रिफ्रेश टाइमर
  void _startOrderRefreshTimer() {
    _orderRefreshTimer?.cancel();
    _orderRefreshTimer = Timer.periodic(const Duration(minutes: 5), (timer) {
      if (mounted && _isLoggedIn && !_isAdminLoggedIn) {
        _fetchOrdersRest();
        debugPrint("🔄 5 मिनट पूरा होने पर बैकग्राउंड में ऑर्डर्स ऑटो-रिफ्रेश हो गए!");
      }
    });
  }

  // 🟢 राइडर लॉगिन (एडमिन या राइडर)
  Future<void> _loginRider() async {
    String phone = _phoneController.text.trim();
    String password = _passwordController.text.trim();

    if (phone.isEmpty || password.isEmpty) {
      _showMsg('कृपया मोबाइल नंबर और पासवर्ड दर्ज करें!', Colors.red);
      return;
    }

    // एडमिन लॉगिन चेक
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
          _fetchOrdersRest();
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

  // 📝 नया राइडर रजिस्ट्रेशन
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

  // 👑 एडमिन के लिए पेंडिंग राइडर्स फेच करना
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

  // ✅ एडमिन द्वारा राइडर अप्रूव करना
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

  // 🚚 ऑर्डर स्टेटस अपडेट करना (डिलिवर्ड करना)
  Future<void> _updateOrderStatus(String orderId, String newStatus) async {
    try {
      await http.patch(
        Uri.parse('$_firebaseRestUrl/orders/$orderId.json'),
        body: json.encode({
          'orderStatus': newStatus,
          'status': newStatus,
        }),
      );
      HapticFeedback.mediumImpact();
      _showMsg('✅ आर्डर स्टेटस बदलकर "$newStatus" कर दिया गया!', Colors.green);
      
      setState(() {
        _activeOrders.removeWhere((order) => order['orderId'] == orderId);
      });
    } catch (e) {
      debugPrint("Status update error: $e");
    }
  }

  void _makePhoneCall(String phone) {
    if (phone.isEmpty) {
      _showMsg('ग्राहक का फोन नंबर उपलब्ध नहीं है!', Colors.orange);
      return;
    }
    _showMsg('कॉलिंग फीचर: $phone', Colors.blue);
  }

  // 📦 आर्डर का पूरा विवरण देखने वाला डायलॉग (शॉप एड्रेस + कस्टमर एड्रेस के साथ)
  void _showOrderDetailsDialog(Map<String, dynamic> order) {
    String customerName = order['customerName'] ?? order['name'] ?? 'Customer';
    String phone = order['customerPhone'] ?? order['phone'] ?? '';
    String address = order['customerAddress'] ?? order['deliveryAddress'] ?? order['address'] ?? 'पता उपलब्ध नहीं';
    String shopAddress = order['shopAddress'] ?? order['pickupAddress'] ?? 'केक शॉप (मुख्य शाखा, फरीदाबाद)';
    String itemsText = order['itemsSummary'] ?? order['items'] ?? 'आइटम विवरण नहीं';
    String amount = order['totalAmount'] ?? order['amount'] ?? 'लागू नहीं';
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

    // 👑 एडमिन अप्रूवल पैनल स्क्रीन
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
                _orderRefreshTimer?.cancel();
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

    // 🚴‍♂️ राइडर लाइव ऑर्डर्स स्क्रीन (शॉप एड्रेस, कस्टमर एड्रेस, हैप्टिक और 5-मिनट टाइमर के साथ)
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        title: const Text('🚴‍♂️ राइडर लाइव ऑर्डर्स (Auto 5-Min)', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 13)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.green),
            onPressed: _fetchOrdersRest,
            tooltip: 'मैनुअल रिफ्रेश करें',
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.red),
            onPressed: () {
              _orderRefreshTimer?.cancel();
              setState(() => _isLoggedIn = false);
            },
            tooltip: 'लॉग आउट',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _fetchOrdersRest,
        child: _activeOrders.isEmpty
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  SizedBox(
                    height: MediaQuery.of(context).size.height * 0.7,
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.delivery_dining, size: 70, color: Colors.grey.shade400),
                          const SizedBox(height: 12),
                          const Text('कोई नया डिलीवरी ऑर्डर नहीं है!', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey)),
                          const SizedBox(height: 6),
                          const Text('📡 (REST API + 5 मिनट ऑटो-रिफ्रेश चालू है)', style: TextStyle(fontSize: 11, color: Colors.green), textAlign: TextAlign.center),
                        ],
                      ),
                    ),
                  ),
                ],
              )
            : ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(12),
                itemCount: _activeOrders.length,
                itemBuilder: (context, index) {
                  var order = _activeOrders[index];
                  String orderId = order['orderId'] ?? '';
                  String customerName = order['customerName'] ?? order['name'] ?? 'Customer';
                  String phone = order['customerPhone'] ?? order['phone'] ?? '';
                  String customerAddress = order['customerAddress'] ?? order['deliveryAddress'] ?? order['address'] ?? 'ग्राहक का पता उपलब्ध नहीं';
                  String shopAddress = order['shopAddress'] ?? order['pickupAddress'] ?? 'केक शॉप (मुख्य शाखा)';
                  String amount = order['totalAmount'] ?? order['amount'] ?? 'लागू नहीं';
                  String orderStatus = order['orderStatus'] ?? order['status'] ?? 'Pending';

                  return Card(
                    elevation: 2,
                    margin: const EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(customerName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              Chip(
                                label: Text(orderStatus, style: const TextStyle(color: Colors.white, fontSize: 11)),
                                backgroundColor: Colors.orange,
                                padding: EdgeInsets.zero,
                              ),
                            ],
                          ),
                          const Divider(height: 12),
                          // 🏬 शॉप एड्रेस (पिकअप)
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.store, size: 16, color: Colors.blue),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text('पिकअप: $shopAddress', style: const TextStyle(fontSize: 12, color: Colors.blueGrey, fontWeight: FontWeight.w600)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          // 📍 कस्टमर एड्रेस (डिलीवरी)
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.location_on, size: 16, color: Colors.red),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text('डिलिवरी: $customerAddress', style: const TextStyle(fontSize: 12, color: Colors.black87)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text('💰 कुल राशि: ₹$amount', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green, fontSize: 13)),
                          const Divider(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              OutlinedButton.icon(
                                icon: const Icon(Icons.visibility, size: 16),
                                label: const Text('विवरण'),
                                onPressed: () => _showOrderDetailsDialog(order),
                              ),
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
                                icon: const Icon(Icons.phone, size: 16),
                                label: const Text('कॉल'),
                                onPressed: () => _makePhoneCall(phone),
                              ),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                                onPressed: () => _updateOrderStatus(orderId, 'Delivered'),
                                child: const Text('डिलिवर्ड'),
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
    );
  }
}
