import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

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

  // अब हम पूरी लिस्ट की जगह सिर्फ एक आखिरी आर्डर स्टोर करेंगे
  Map<String, dynamic>? _latestOrder;
  List<Map<String, dynamic>> _pendingRiders = [];
  Set<String> _localSeenOrderIds = {};

  Timer? _orderRefreshTimer;

  // 🟢 URL दोनों फाइलों में बिल्कुल एक जैसा
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

  // 🔥 यहाँ है असली जादू: सिर्फ आखिरी 1 सिंगल ऑर्डर खींचने का रेस्ट एपीआई कॉल (नेट खर्च शून्य)
  Future<void> _fetchOnlyLatestOrderRest() async {
    try {
      // orderBy और limitToLast=1 की मदद से सर्वर सिर्फ आखिरी 1 रिकॉर्ड फेच करेगा
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
            // अगर आर्डर डिलीवर्ड नहीं हुआ है तभी दिखाएंगे
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
        if (mounted) {
          setState(() {
            _latestOrder = null;
          });
        }
      }
    } catch (e) {
      debugPrint("Fetch single order REST error: $e");
    }
  }

  // 🔄 6 सेकंड वाला लूप जो सिर्फ 1 सिंगल आर्डर चेक करेगा
  void _startOrderRefreshTimer() {
    _orderRefreshTimer?.cancel();
    _orderRefreshTimer = Timer.periodic(const Duration(seconds: 6), (timer) {
      if (mounted && _isLoggedIn && !_isAdminLoggedIn) {
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
          _startOrderRefreshTimer(); // 6 सेकंड का लाइटवेट लूप चालू
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
        _latestOrder = null; // आर्डर पूरा होने पर स्क्रीन साफ़
      });
    } catch (e) {
      debugPrint("Status update error: $e");
    }
  }

  void _showOrderDetailsDialog(Map<String, dynamic> order) {
    String customerName = order['customerName'] ?? order['name'] ?? 'Customer';
    String phone = order['customerPhone'] ?? order['phone'] ?? '';
    String address = order['customerAddress'] ?? order['deliveryAddress'] ?? order['address'] ?? 'पता उपलब्ध नहीं';
    String shopAddress = order['shopAddress'] ?? order['pickupAddress'] ?? 'केक शॉप (मुख्य शाखा, फरीदाबाद)';
    
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

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        title: const Text('🚴‍♂️ स्मार्ट लाइव ऑर्डर (Zero Data)', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 13)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.green),
            onPressed: _fetchOnlyLatestOrderRest,
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
        onRefresh: _fetchOnlyLatestOrderRest,
        child: _latestOrder == null
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
                          const Text('फिलहाल कोई नया आर्डर नहीं है!\n(नेट खर्च बिल्कुल शून्य)', textAlign: TextAlign.center, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey)),
                        ],
                      ),
                    ),
                  ),
                ],
              )
            : ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(12),
                children: [
                  Card(
                    elevation: 3,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('🔥 एकदम नया ऑर्डर', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.deepOrange)),
                              Text('₹${_latestOrder!['grandTotal'] ?? _latestOrder!['totalAmount'] ?? '0'}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.green)),
                            ],
                          ),
                          const Divider(height: 20),
                          Text('ग्राहक: ${_latestOrder!['customerName'] ?? _latestOrder!['name'] ?? 'N/A'}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 6),
                          Text('पता: ${_latestOrder!['customerAddress'] ?? _latestOrder!['deliveryAddress'] ?? 'पता उपलब्ध नहीं'}', style: const TextStyle(fontSize: 13, color: Colors.black54)),
                          const SizedBox(height: 14),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              OutlinedButton.icon(
                                onPressed: () => _showOrderDetailsDialog(_latestOrder!),
                                icon: const Icon(Icons.info_outline),
                                label: const Text('पूरी डिटेल्स'),
                              ),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                                onPressed: () => _updateOrderStatus(_latestOrder!['orderId'], 'Delivered'),
                                child: const Text('डिलिवर्ड करें'),
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
