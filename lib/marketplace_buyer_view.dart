import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';

class MarketplaceBuyerView extends StatefulWidget {
  const MarketplaceBuyerView({super.key});

  @override
  State<MarketplaceBuyerView> createState() => _MarketplaceBuyerViewState();
}

class _MarketplaceBuyerViewState extends State<MarketplaceBuyerView> {
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

  List<Map<String, dynamic>> _pendingRiders = [];
  final String _firebaseRestUrl = "https://viziagmart-default-rtdb.firebaseio.com";

  @override
  void dispose() {
    _phoneController.dispose();
    _passwordController.dispose();
    _regNameController.dispose();
    _regPhoneController.dispose();
    _regVehicleController.dispose();
    _regPasswordController.dispose();
    super.dispose();
  }

  void _showMsg(String msg, Color color) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));
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
          _showMsg('🎉 लॉगिन सफल!', Colors.green);
        } else if (found && !approved) {
          _showMsg('⏳ आपका अकाउंट अभी एडमिन द्वारा अप्रूव नहीं किया गया है!', Colors.orange);
        } else {
          _showMsg('गलत मोबाइल नंबर या पासवर्ड!', Colors.red);
        }
      } else {
        _showMsg('कोई यूजर रजिस्टर्ड नहीं है!', Colors.red);
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
      _showMsg('✅ सक्सेसफुली अप्रूव हो गया!', Colors.green);
      _fetchPendingRidersRest();
    } catch (e) {
      _showMsg('अप्रूवल एरर: $e', Colors.red);
    }
  }

  Widget _buildLoginForm() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('मार्केटप्लेस लॉगिन', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
          child: const Text('नया रजिस्ट्रेशन करें'),
        ),
      ],
    );
  }

  Widget _buildRegisterForm() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('नया रजिस्ट्रेशन', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
          decoration: const InputDecoration(labelText: 'विवरण / वाहन नंबर', border: OutlineInputBorder()),
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

  Widget _buildBuyerDashboard() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.storefront, size: 64, color: Colors.green),
          SizedBox(height: 12),
          Text('मार्केटप्लेस में आपका स्वागत है!', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          SizedBox(height: 6),
          Text('यहाँ आपके प्रोडक्ट्स दिखेंगे।', style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildAdminDashboard() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('👑 पेंडिंग अप्रूवल लिस्ट', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Expanded(
            child: _pendingRiders.isEmpty
                ? const Center(child: Text('कोई पेंडिंग रिक्वेस्ट नहीं है।', style: TextStyle(color: Colors.grey)))
                : ListView.builder(
                    itemCount: _pendingRiders.length,
                    itemBuilder: (context, index) {
                      var r = _pendingRiders[index];
                      return Card(
                        child: ListTile(
                          title: Text(r['name'] ?? 'User', style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text('📞 ${r['phone']} | 🛵 ${r['vehicle']}'),
                          trailing: ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                            onPressed: () => _approveRider(r['riderId']),
                            child: const Text('अप्रूव करें'),
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

  @override
  Widget build(BuildContext context) {
    if (!_isLoggedIn) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8F9FA),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 1,
          title: Text(
            _isRegistering ? '📝 नया रजिस्ट्रेशन' : '🛍️ मार्केटप्लेस',
            style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
          ),
        ),
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Card(
              elevation: 3,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: _isRegistering ? _buildRegisterForm() : _buildLoginForm(),
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: _isAdminLoggedIn ? Colors.black87 : Colors.green,
        foregroundColor: Colors.white,
        title: Text(_isAdminLoggedIn ? '👑 मार्केटप्लेस एडमिन पैनल' : '🛍️ मार्केटप्लेस पोर्टल'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              setState(() {
                _isLoggedIn = false;
                _isAdminLoggedIn = false;
              });
            },
          )
        ],
      ),
      body: _isAdminLoggedIn ? _buildAdminDashboard() : _buildBuyerDashboard(),
    );
  }
}
