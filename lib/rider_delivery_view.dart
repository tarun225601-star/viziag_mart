import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_database/firebase_database.dart';
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

  DatabaseReference? _ordersRef;
  var _ordersSubscription;

  // Firebase REST URL for direct HTTP operations if required
  final String _firebaseRestUrl = "https://viziag-mart-default-rtdb.firebaseio.com";

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
    _ordersSubscription?.cancel();
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

  void _listenToNewOrdersOnly() {
    _ordersRef = FirebaseDatabase.instance.ref().child('orders');

    _ordersRef!.get().then((snapshot) {
      if (snapshot.exists && snapshot.value != null) {
        Map<String, dynamic> data = Map<String, dynamic>.from(snapshot.value as Map);
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
          });
        }
      }
    });

    _ordersSubscription = _ordersRef!.onChildAdded.listen((event) {
      final snapshot = event.snapshot;
      if (snapshot.exists && snapshot.value != null) {
        String newOrderId = snapshot.key ?? '';
        
        if (newOrderId.isNotEmpty && !_localSeenOrderIds.contains(newOrderId)) {
          var value = snapshot.value;
          if (value is Map) {
            var order = Map<String, dynamic>.from(value);
            order['orderId'] = newOrderId;

            String status = order['orderStatus'] ?? order['status'] ?? 'Pending';

            if (!status.toLowerCase().contains('delivered')) {
              _localSeenOrderIds.add(newOrderId);
              _saveSeenOrderIds();

              if (mounted) {
                setState(() {
                  _activeOrders.insert(0, order);
                });
                _triggerNewOrderAlert();
              }
            }
          }
        }
      }
    }, onError: (error) {
      debugPrint("Firebase Child Added Error: $error");
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
      final DatabaseReference ridersRef = FirebaseDatabase.instance.ref().child('riders');
      final snapshot = await ridersRef.get();

      if (snapshot.exists && snapshot.value != null) {
        Map<String, dynamic> data = Map<String, dynamic>.from(snapshot.value as Map);
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
          _listenToNewOrdersOnly();
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
      // Using REST API for robust cross-platform insertion
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

  void _showOrderDetailsDialog(Map<String, dynamic> order) {
    String customerName = order['customerName'] ?? order['name'] ?? 'Customer';
    String phone = order['customerPhone'] ?? order['phone'] ?? '';
    String address = order['customerAddress'] ?? order['deliveryAddress'] ?? order['address'] ?? 'पता उपलब्ध नहीं';
    String shopAddress = order['shopAddress'] ?? order['pickupAddress'] ?? 'केक शॉप (मुख्य शाखा)';
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
              Text(shopAddress),
              const Divider(),
              const Text('📍 डिलीवरी (ग्राहक का पता):', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
              Text(address),
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
                _ordersSubscription?.cancel();
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
        title: const Text('🚴‍♂️ राइडर लाइव ऑर्डर्स', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 14)),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.red),
            onPressed: () {
              _ordersSubscription?.cancel();
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
                  const Text('कोई नया डिलीवरी ऑर्डर नहीं है!', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey)),
                  const SizedBox(height: 6),
                  const Text('📡 (सुपर फास्ट REST API + डेटा-सेविंग मोड ऑन है)', style: TextStyle(fontSize: 11, color: Colors.green), textAlign: TextAlign.center),
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
                String address = order['customerAddress'] ?? order['deliveryAddress'] ?? order['address'] ?? 'पता उपलब्ध नहीं';
                String amount = order['totalAmount'] ?? order['amount'] ?? '0';

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text('📦 ऑर्डर #${orderId.substring(0, 6)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey)),
                            const Spacer(),
                            Text('₹$amount', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.green)),
                          ],
                        ),
                        const Divider(),
                        Text('👤 ग्राहक: $customerName', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        const SizedBox(height: 4),
                        Text('📍 पता: $address', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(foregroundColor: Colors.blue, padding: const EdgeInsets.symmetric(horizontal: 8)),
                              onPressed: () => _makePhoneCall(phone),
                              icon: const Icon(Icons.phone, size: 14),
                              label: const Text('कॉल', style: TextStyle(fontSize: 11)),
                            ),
                            const SizedBox(width: 6),
                            OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(foregroundColor: Colors.purple, padding: const EdgeInsets.symmetric(horizontal: 8)),
                              onPressed: () => _showOrderDetailsDialog(order),
                              icon: const Icon(Icons.info_outline, size: 14),
                              label: const Text('डिटेल', style: TextStyle(fontSize: 11)),
                            ),
                            const Spacer(),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 10)),
                              onPressed: () => _updateOrderStatus(orderId, 'Delivered'),
                              child: const Text('डिलिवर्ड ✅', style: TextStyle(fontSize: 11)),
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
