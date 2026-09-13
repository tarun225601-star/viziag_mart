// =========================================================================
// VIZIAG MART ENTERPRISE PLATFORM (FULL 1050+ LINES ULTIMATE CODE)
// =========================================================================

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'database_models.dart';
import 'marketplace_buyer_view.dart';
import 'cart_and_orders_view.dart';
import 'image_picker_helper.dart';
import 'rider_delivery_view.dart'; 
import 'package:http/http.dart' as http;
import 'dart:convert';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint("Firebase initialization warning: $e");
  }

  runApp(const CakeAppEnterpriseApp());
}

class CakeAppEnterpriseApp extends StatelessWidget {
  const CakeAppEnterpriseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Viziag Mart Enterprise',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        scaffoldBackgroundColor: const Color(0xFFF8F9FA),
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
      ),
      home: const CakeMainHubScreen(),
    );
  }
}

class CakeMainHubScreen extends StatefulWidget {
  const CakeMainHubScreen({super.key});

  @override
  State<CakeMainHubScreen> createState() => _CakeMainHubScreenState();
}

class _CakeMainHubScreenState extends State<CakeMainHubScreen> {
  int _selectedTabIndex = 0;

  final List<Widget> _tabScreens = [
    const MarketplaceBuyerView(),
    const VendorAuthAndPortalView(),
    const RiderDeliveryScreen(),
    const CartAndOrdersView(),
  ];

  @override
  Widget build(BuildContext context) {
    int totalCartCount = CakeDatabase.cartItems.fold(
      0, 
      (sum, item) => sum + ((item['qty'] as num?)?.toInt() ?? 1)
    );

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(75),
        child: AppBar(
          backgroundColor: Colors.white,
          elevation: 1,
          title: Row(
            children: [
              const Text(
                'VIZIAG MART',
                style: TextStyle(
                  color: Colors.black87, 
                  fontWeight: FontWeight.w900, 
                  fontSize: 18, 
                  letterSpacing: 1.5
                ),
              ),
              const Spacer(),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade700, 
                  foregroundColor: Colors.white, 
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), 
                  minimumSize: Size.zero
                ),
                onPressed: () => setState(() => _selectedTabIndex = 0),
                icon: const Icon(Icons.store, size: 14),
                label: const Text('Shop', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 6),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey.shade200, 
                  foregroundColor: Colors.black87, 
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), 
                  minimumSize: Size.zero
                ),
                onPressed: () => setState(() => _selectedTabIndex = 1),
                icon: const Icon(Icons.lock_outline, size: 14),
                label: const Text('Vendor', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(30),
            child: Container(
              color: Colors.green.shade50,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => _showProfileEditDialog(context),
                    child: Row(
                      children: [
                        Icon(Icons.person_pin_circle, color: Colors.green.shade700, size: 15),
                        const SizedBox(width: 6),
                        Text(
                          CakeDatabase.currentCustomerName, 
                          style: const TextStyle(color: Colors.black87, fontSize: 11, fontWeight: FontWeight.bold)
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => _showProfileEditDialog(context),
                    child: Text(
                      '(Edit Profile & Address)', 
                      style: TextStyle(color: Colors.green.shade700, fontSize: 10, fontWeight: FontWeight.w600)
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: IndexedStack(
        index: _selectedTabIndex > 3 ? 3 : _selectedTabIndex, 
        children: _tabScreens
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedTabIndex > 3 ? 3 : _selectedTabIndex,
        selectedItemColor: Colors.green.shade700,
        unselectedItemColor: Colors.grey,
        backgroundColor: Colors.white,
        type: BottomNavigationBarType.fixed,
        onTap: (i) => setState(() => _selectedTabIndex = i),
        items: [
          const BottomNavigationBarItem(icon: Icon(Icons.storefront_outlined), label: 'Shop'),
          const BottomNavigationBarItem(icon: Icon(Icons.admin_panel_settings_outlined), label: 'Vendor'),
          const BottomNavigationBarItem(icon: Icon(Icons.delivery_dining), label: 'Delivery'),
          BottomNavigationBarItem(
            icon: Stack(
              children: [
                const Icon(Icons.shopping_cart_outlined),
                if (totalCartCount > 0)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                      constraints: const BoxConstraints(minWidth: 14, minHeight: 14),
                      child: Text(
                        '$totalCartCount', 
                        style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold), 
                        textAlign: TextAlign.center
                      ),
                    ),
                  ),
              ],
            ),
            label: 'Cart & Orders',
          ),
        ],
      ),
    );
  }

  void _showProfileEditDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        final nameCtrl = TextEditingController(text: CakeDatabase.currentCustomerName);
        final phoneCtrl = TextEditingController(text: CakeDatabase.currentUserPhone);
        final addressCtrl = TextEditingController(text: CakeDatabase.currentDeliveryAddress);
        return AlertDialog(
          title: const Text('Edit Profile & Address', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Name', isDense: true)),
              const SizedBox(height: 10),
              TextField(controller: phoneCtrl, decoration: const InputDecoration(labelText: 'Phone', isDense: true)),
              const SizedBox(height: 10),
              TextField(controller: addressCtrl, decoration: const InputDecoration(labelText: 'Address / Location Note', isDense: true)),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade700, foregroundColor: Colors.white),
              onPressed: () {
                setState(() {
                  CakeDatabase.currentCustomerName = nameCtrl.text.trim();
                  CakeDatabase.currentUserPhone = phoneCtrl.text.trim();
                  CakeDatabase.currentDeliveryAddress = addressCtrl.text.trim();
                });
                Navigator.pop(context);
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }
}

class VendorAuthAndPortalView extends StatefulWidget {
  const VendorAuthAndPortalView({super.key});

  @override
  State<VendorAuthAndPortalView> createState() => _VendorAuthAndPortalViewState();
}

class _VendorAuthAndPortalViewState extends State<VendorAuthAndPortalView> {
  int _viewMode = 0;

  final regShopNameCtrl = TextEditingController();
  final regPhoneCtrl = TextEditingController();
  final regAddressCtrl = TextEditingController();
  final regPass1Ctrl = TextEditingController();
  final regPass2Ctrl = TextEditingController();

  final loginPhoneCtrl = TextEditingController();
  final loginPassCtrl = TextEditingController();

  final adminCodeCtrl = TextEditingController();
  bool _isLoading = false;

  Future<void> _submitRegistration() async {
    if (regPhoneCtrl.text.trim().length < 10 || regShopNameCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('⚠️ कृपया दुकान का नाम और सही मोबाइल नंबर भरें!'), backgroundColor: Colors.red)
      );
      return;
    }
    if (regPass1Ctrl.text.isEmpty || regPass1Ctrl.text != regPass2Ctrl.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('⚠️ पासवर्ड मेल नहीं खा रहे हैं!'), backgroundColor: Colors.red)
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      var shopData = {
        'name': regShopNameCtrl.text.trim(),
        'phone': regPhoneCtrl.text.trim(),
        'address': regAddressCtrl.text.trim().isEmpty ? 'Faridabad' : regAddressCtrl.text.trim(),
        'pass': regPass1Ctrl.text.trim(),
        'status': 'pending',
        'createdAt': DateTime.now().toIso8601String(),
      };

      await http.post(
        Uri.parse('${CakeDatabase.firebaseRestUrl}/vendor_requests.json'),
        body: json.encode(shopData),
      );

      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('⏳ रिक्वेस्ट सबमिट हो गई'),
            content: const Text('आपकी दुकान का रजिस्ट्रेशन हो गया है। मास्टर एडमिन (तरुण) द्वारा अप्रूव होने के बाद ही आप लॉगिन कर पाएंगे।'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  setState(() => _viewMode = 0);
                },
                child: const Text('ठीक है'),
              ),
            ],
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loginVendor() async {
    String phone = loginPhoneCtrl.text.trim();
    String pass = loginPassCtrl.text.trim();

    if (phone.isEmpty || pass.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('⚠️ कृपया मोबाइल नंबर और पासवर्ड दर्ज करें!'), backgroundColor: Colors.red)
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final res = await http.get(Uri.parse('${CakeDatabase.firebaseRestUrl}/vendor_requests.json'));
      bool isApproved = false;

      if (res.statusCode == 200 && res.body != 'null' && res.body.isNotEmpty) {
        Map<String, dynamic> data = json.decode(res.body);
        data.forEach((key, val) {
          if (val['phone'] == phone && val['pass'] == pass && val['status'] == 'approved') {
            isApproved = true;
          }
        });
      }

      if (isApproved) {
        setState(() => _viewMode = 3);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('✅ स्वागत है! वेंडर डैशबोर्ड खुल गया है।'), backgroundColor: Colors.green)
          );
        }
      } else {
        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('⚠️ लॉगिन असफल (Not Approved)'),
              content: const Text('आपकी दुकान अभी तक मास्टर एडमिन (तरुण) द्वारा अप्रूव नहीं की गई है! कृपया पहले अप्रूवल लें या सही डिटेल्स भरें।'),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('ठीक है')),
              ],
            ),
          );
        }
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _verifyAdminCode() {
    if (adminCodeCtrl.text.trim() == 'tarun#1') {
      setState(() => _viewMode = 5);
      adminCodeCtrl.clear();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('⚠️ गलत गुप्त कोड!'), backgroundColor: Colors.red)
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_viewMode == 0) {
      return Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.storefront, size: 75, color: Colors.green),
            const SizedBox(height: 15),
            const Text('🛍️ वेंडर पोर्टल', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 5),
            const Text('बिना एडमिन अप्रूवल के कोई भी वेंडर लॉगिन नहीं कर सकता', style: TextStyle(fontSize: 11, color: Colors.grey), textAlign: TextAlign.center),
            const SizedBox(height: 40),
            
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade700, foregroundColor: Colors.white),
                onPressed: () => setState(() => _viewMode = 1),
                icon: const Icon(Icons.person_add),
                label: const Text('नई दुकान रजिस्टर करें (New Registration)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              ),
            ),
            const SizedBox(height: 15),

            SizedBox(
              width: double.infinity,
              height: 50,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.green, width: 2), foregroundColor: Colors.green.shade800),
                onPressed: () => setState(() => _viewMode = 2),
                icon: const Icon(Icons.login),
                label: const Text('वेंडर लॉगिन (Existing Vendor Login)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              ),
            ),

            const Spacer(),
            const Divider(),
            TextButton.icon(
              onPressed: () => setState(() => _viewMode = 4),
              icon: const Icon(Icons.admin_panel_settings, color: Colors.green),
              label: const Text('मास्टर शॉप अप्रूवल डैशबोर्ड (Admin)', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
    }

    if (_viewMode == 1) {
      return Padding(
        padding: const EdgeInsets.all(20),
        child: ListView(
          children: [
            const SizedBox(height: 10),
            const Center(child: Text('📝 नया वेंडर रजिस्ट्रेशन', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold))),
            const SizedBox(height: 20),
            TextField(controller: regShopNameCtrl, decoration: const InputDecoration(labelText: 'दुकान का नाम (Shop Name)', border: OutlineInputBorder(), prefixIcon: Icon(Icons.store))),
            const SizedBox(height: 15),
            TextField(controller: regPhoneCtrl, keyboardType: TextInputType.phone, maxLength: 10, decoration: const InputDecoration(labelText: 'मोबाइल नंबर', border: OutlineInputBorder(), counterText: '', prefixIcon: Icon(Icons.phone))),
            const SizedBox(height: 15),
            TextField(controller: regAddressCtrl, decoration: const InputDecoration(labelText: 'दुकान का पता / लोकेशन', border: OutlineInputBorder(), prefixIcon: Icon(Icons.location_on))),
            const SizedBox(height: 15),
            TextField(controller: regPass1Ctrl, obscureText: true, decoration: const InputDecoration(labelText: 'पासवर्ड बनाएं', border: OutlineInputBorder(), prefixIcon: Icon(Icons.lock_outline))),
            const SizedBox(height: 15),
            TextField(controller: regPass2Ctrl, obscureText: true, decoration: const InputDecoration(labelText: 'पासवर्ड दोबारा दर्ज करें', border: OutlineInputBorder(), prefixIcon: Icon(Icons.lock))),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade700, foregroundColor: Colors.white),
                onPressed: _isLoading ? null : _submitRegistration,
                child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text('अप्रूवल के लिए सबमिट करें', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              ),
            ),
            const SizedBox(height: 10),
            TextButton(onPressed: () => setState(() => _viewMode = 0), child: const Text('← वापस जाएं')),
          ],
        ),
      );
    }

    if (_viewMode == 2) {
      return Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lock_open, size: 65, color: Colors.green),
            const SizedBox(height: 15),
            const Text('🔐 वेंडर लॉगिन', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 5),
            const Text('पहले एडमिन से अप्रूव कराना अनिवार्य है', style: TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 25),
            TextField(controller: loginPhoneCtrl, keyboardType: TextInputType.phone, maxLength: 10, decoration: const InputDecoration(labelText: 'मोबाइल नंबर', border: OutlineInputBorder(), counterText: '', prefixIcon: Icon(Icons.phone))),
            const SizedBox(height: 15),
            TextField(controller: loginPassCtrl, obscureText: true, decoration: const InputDecoration(labelText: 'पासवर्ड', border: OutlineInputBorder(), prefixIcon: Icon(Icons.lock))),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade700, foregroundColor: Colors.white),
                onPressed: _isLoading ? null : _loginVendor,
                child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text('लॉगिन करें ➔', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              ),
            ),
            const SizedBox(height: 10),
            TextButton(onPressed: () => setState(() => _viewMode = 0), child: const Text('← वापस जाएं', style: TextStyle(color: Colors.grey))),
          ],
        ),
      );
    }

    if (_viewMode == 3) {
      return DefaultTabController(
        length: 3,
        child: Column(
          children: [
            Container(
              color: Colors.green.shade50,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                children: [
                  const Text('🟢 वेंडर डैशबोर्ड (लाइव)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.green)),
                  const Spacer(),
                  TextButton(
                    onPressed: () => setState(() => _viewMode = 0),
                    child: const Text('लॉग आउट', style: TextStyle(fontSize: 11, color: Colors.red)),
                  ),
                ],
              ),
            ),
            const Material(
              color: Colors.white,
              child: TabBar(
                isScrollable: true,
                labelColor: Colors.green,
                unselectedLabelColor: Colors.grey,
                indicatorColor: Colors.green,
                tabs: [
                  Tab(text: '📦 लाइव ऑर्डर्स (Blinkit Style)'),
                  Tab(text: '🍰 प्रोडक्ट्स जोड़ें & मैनेज'),
                  Tab(text: '⚙️ सेटिंग्स'),
                ],
              ),
            ),
            const Expanded(
              child: TabBarView(
                children: [
                  VendorOrdersTab(),
                  VendorProductsTab(),
                  VendorSettingsTab(),
                ],
              ),
            ),
          ],
        ),
      );
    }

    if (_viewMode == 4) {
      return Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.admin_panel_settings, size: 65, color: Colors.green),
            const SizedBox(height: 15),
            const Text('👑 मास्टर एडमिन पैनल', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 5),
            const Text('दुकानों को अप्रूव करने के लिए गुप्त कोड दर्ज करें', style: TextStyle(fontSize: 12, color: Colors.grey), textAlign: TextAlign.center),
            const SizedBox(height: 25),
            TextField(controller: adminCodeCtrl, obscureText: true, decoration: const InputDecoration(labelText: 'गुप्त कोड (Secret Code)', border: OutlineInputBorder(), prefixIcon: Icon(Icons.security))),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade700, foregroundColor: Colors.white),
                onPressed: _verifyAdminCode,
                child: const Text('डैशबोर्ड खोलें', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              ),
            ),
            const SizedBox(height: 10),
            TextButton(onPressed: () => setState(() => _viewMode = 0), child: const Text('← वापस जाएं')),
          ],
        ),
      );
    }

    return AdminApprovalDashboardView(onBack: () => setState(() => _viewMode = 0));
  }
}

// 👑 मास्टर एडमिन अप्रूवल डैशबोर्ड (Tarun Panel)
class AdminApprovalDashboardView extends StatefulWidget {
  final VoidCallback onBack;
  const AdminApprovalDashboardView({super.key, required this.onBack});

  @override
  State<AdminApprovalDashboardView> createState() => _AdminApprovalDashboardViewState();
}

class _AdminApprovalDashboardViewState extends State<AdminApprovalDashboardView> {
  bool isLoading = false;
  List<dynamic> pendingRequests = [];

  @override
  void initState() {
    super.initState();
    _fetchRequests();
  }

  Future<void> _fetchRequests() async {
    setState(() => isLoading = true);
    try {
      final res = await http.get(Uri.parse('${CakeDatabase.firebaseRestUrl}/vendor_requests.json'));
      if (res.statusCode == 200 && res.body != 'null' && res.body.isNotEmpty) {
        Map<String, dynamic> data = json.decode(res.body);
        List loaded = [];
        data.forEach((key, val) {
          loaded.add({...val, 'id': key});
        });
        setState(() {
          pendingRequests = loaded;
        });
      }
    } catch (e) {
      debugPrint("Error fetching requests: $e");
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _updateStatus(String reqId, String status) async {
    try {
      await http.patch(
        Uri.parse('${CakeDatabase.firebaseRestUrl}/vendor_requests/$reqId.json'),
        body: json.encode({'status': status}),
      );
      _fetchRequests();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('✅ दुकान का स्टेटस "$status" कर दिया गया!'), backgroundColor: Colors.green)
        );
      }
    } catch (e) {
      debugPrint("Update error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          color: Colors.green.shade700,
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              const Text('👑 तरुण का मास्टर एडमिन पैनल', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
              const Spacer(),
              IconButton(icon: const Icon(Icons.refresh, color: Colors.white), onPressed: _fetchRequests),
              IconButton(icon: const Icon(Icons.exit_to_app, color: Colors.white), onPressed: widget.onBack),
            ],
          ),
        ),
        if (isLoading) const LinearProgressIndicator(color: Colors.green),
        Expanded(
          child: pendingRequests.isEmpty
              ? const Center(child: Text('📭 कोई वेंडर रजिस्ट्रेशन रिक्वेस्ट नहीं है।', style: TextStyle(color: Colors.grey)))
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: pendingRequests.length,
                  itemBuilder: (context, index) {
                    var req = pendingRequests[index];
                    String status = req['status'] ?? 'pending';
                    return Card(
                      elevation: 2,
                      margin: const EdgeInsets.only(bottom: 10),
                      child: ListTile(
                        title: Text('${req['name']} (${req['phone']})', style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('📍 पता: ${req['address']}'),
                            Text('📌 स्टेटस: $status', style: TextStyle(fontWeight: FontWeight.bold, color: status == 'approved' ? Colors.green : Colors.orange)),
                          ],
                        ),
                        trailing: status == 'pending'
                            ? Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white, minimumSize: const Size(60, 30)),
                                    onPressed: () => _updateStatus(req['id'], 'approved'),
                                    child: const Text('Approve', style: TextStyle(fontSize: 10)),
                                  ),
                                  const SizedBox(width: 5),
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white, minimumSize: const Size(60, 30)),
                                    onPressed: () => _updateStatus(req['id'], 'rejected'),
                                    child: const Text('Reject', style: TextStyle(fontSize: 10)),
                                  ),
                                ],
                              )
                            : Text(status.toUpperCase(), style: TextStyle(color: status == 'approved' ? Colors.green : Colors.red, fontWeight: FontWeight.bold)),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

// ⚡ ब्लिंकिट / जोमेटो स्टाइल लाइव आर्डर डैशबोर्ड
class VendorOrdersTab extends StatefulWidget {
  const VendorOrdersTab({super.key});

  @override
  State<VendorOrdersTab> createState() => _VendorOrdersTabState();
}

class _VendorOrdersTabState extends State<VendorOrdersTab> {
  bool isLoading = false;
  List<dynamic> liveOrders = [];

  @override
  void initState() {
    super.initState();
    _fetchLiveOrders();
  }

  Future<void> _fetchLiveOrders() async {
    setState(() => isLoading = true);
    try {
      final res = await http.get(Uri.parse('${CakeDatabase.firebaseRestUrl}/orders.json'));
      if (res.statusCode == 200 && res.body != 'null' && res.body.isNotEmpty) {
        Map<String, dynamic> data = json.decode(res.body);
        List loadedOrders = [];
        data.forEach((key, val) {
          loadedOrders.add({...val, 'id': key});
        });
        setState(() {
          liveOrders = loadedOrders.reversed.toList();
        });
      }
    } catch (e) {
      debugPrint("Error fetching orders: $e");
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _updateOrderStatus(String orderId, String newStatus) async {
    try {
      await http.patch(
        Uri.parse('${CakeDatabase.firebaseRestUrl}/orders/$orderId.json'),
        body: json.encode({'status': newStatus}),
      );
      _fetchLiveOrders();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('✅ आर्डर स्टेटस बदलकर "$newStatus" कर दिया गया!'), backgroundColor: Colors.green)
        );
      }
    } catch (e) {
      debugPrint("Status update error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          color: Colors.green.shade50,
          child: Row(
            children: [
              const Icon(Icons.flash_on, color: Colors.orange, size: 18),
              const SizedBox(width: 6),
              const Text('⚡ लाइव कस्टमर ऑर्डर्स (Blinkit Style)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.green)),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.refresh, size: 18, color: Colors.green),
                onPressed: _fetchLiveOrders,
              ),
            ],
          ),
        ),
        if (isLoading)
          const LinearProgressIndicator(color: Colors.green),
        Expanded(
          child: liveOrders.isEmpty
              ? const Center(
                  child: Text('📭 अभी कोई नया लाइव आर्डर नहीं है।', style: TextStyle(color: Colors.grey, fontSize: 13)),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(10),
                  itemCount: liveOrders.length,
                  itemBuilder: (context, index) {
                    final order = liveOrders[index];
                    String status = order['status'] ?? 'Pending';
                    Color statusColor = status == 'Delivered' ? Colors.green : (status == 'Accepted' ? Colors.blue : Colors.orange);
                    
                    List itemsList = [];
                    if (order['items'] != null && order['items'] is List) {
                      itemsList = order['items'];
                    }

                    return Card(
                      elevation: 3,
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text('📦 Order #${order['id'].toString().substring(0, 6).toUpperCase()}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                const Spacer(),
                                if (order['timestamp'] != null)
                                  Text('${order['timestamp']}', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                                  child: Text(status, style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 11)),
                                ),
                              ],
                            ),
                            const Divider(height: 15),
                            Text('👤 ग्राहक: ${order['customerName'] ?? 'Unknown'}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                            Text('📞 फोन: ${order['phone'] ?? 'N/A'}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                            Text('📍 पता: ${order['address'] ?? 'N/A'}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                            const SizedBox(height: 8),
                            
                            const Text('🛍️ ऑर्डर किए गए आइटम्स:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.green)),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(6)),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: itemsList.isEmpty
                                    ? [const Text('• कोई आइटम नहीं मिला', style: TextStyle(fontSize: 11, color: Colors.grey))]
                                    : itemsList.map<Widget>((item) {
                                        String imgUrl = item['image'] ?? item['img'] ?? '';
                                        return Padding(
                                          padding: const EdgeInsets.symmetric(vertical: 4),
                                          child: Row(
                                            children: [
                                              ClipRRect(
                                                borderRadius: BorderRadius.circular(6),
                                                child: imgUrl.isNotEmpty
                                                    ? Image.network(imgUrl, width: 40, height: 40, fit: BoxFit.cover, errorBuilder: (c, e, s) => Container(width: 40, height: 40, color: Colors.grey.shade300, child: const Icon(Icons.image, size: 20, color: Colors.grey)))
                                                    : Container(width: 40, height: 40, color: Colors.grey.shade300, child: const Icon(Icons.fastfood, size: 20, color: Colors.grey)),
                                              ),
                                              const SizedBox(width: 10),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text('${item['title'] ?? item['name'] ?? 'Product'}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                                    Text('Qty: ${item['qty'] ?? 1}', style: const TextStyle(fontSize: 10, color: Colors.blueGrey, fontWeight: FontWeight.w600)),
                                                  ],
                                                ),
                                              ),
                                              Text('₹${item['price'] ?? 0}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.green.shade800)),
                                            ],
                                          ),
                                        );
                                      }).toList(),
                              ),
                            ),

                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Text('💰 कुल राशि: ₹${order['totalAmount'] ?? '0'}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.green)),
                                const Spacer(),
                                if (status == 'Pending') ...[
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white, minimumSize: const Size(70, 30), padding: EdgeInsets.zero),
                                    onPressed: () => _updateOrderStatus(order['id'], 'Accepted'),
                                    child: const Text('Accept', style: TextStyle(fontSize: 10)),
                                  ),
                                ],
                                if (status == 'Accepted') ...[
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white, minimumSize: const Size(70, 30), padding: EdgeInsets.zero),
                                    onPressed: () => _updateOrderStatus(order['id'], 'Delivered'),
                                    child: const Text('Deliver', style: TextStyle(fontSize: 10)),
                                  ),
                                ],
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
    );
  }
}

// प्रोडक्ट्स मैनेजमेंट टैब
class VendorProductsTab extends StatefulWidget {
  const VendorProductsTab({super.key});

  @override
  State<VendorProductsTab> createState() => _VendorProductsTabState();
}

class _VendorProductsTabState extends State<VendorProductsTab> {
  final nameCtrl = TextEditingController();
  final priceCtrl = TextEditingController();
  final descCtrl = TextEditingController();
  String? imageUrl;

  Future<void> _addProduct() async {
    if (nameCtrl.text.isEmpty || priceCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('⚠️ कृपया नाम और कीमत भरें!'), backgroundColor: Colors.red)
      );
      return;
    }

    var newProd = {
      'name': nameCtrl.text.trim(),
      'price': double.tryParse(priceCtrl.text.trim()) ?? 0.0,
      'description': descCtrl.text.trim(),
      'image': imageUrl ?? '',
      'createdAt': DateTime.now().toIso8601String(),
    };

    await http.post(
      Uri.parse('${CakeDatabase.firebaseRestUrl}/products.json'),
      body: json.encode(newProd),
    );

    nameCtrl.clear();
    priceCtrl.clear();
    descCtrl.clear();
    setState(() => imageUrl = null);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ प्रोडक्ट सफलतापूर्वक जुड़ गया!'), backgroundColor: Colors.green)
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('🍰 नया प्रोडक्ट जोड़ें', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'प्रोडक्ट का नाम', border: OutlineInputBorder(), isDense: true)),
        const SizedBox(height: 10),
        TextField(controller: priceCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'कीमत (₹)', border: OutlineInputBorder(), isDense: true)),
        const SizedBox(height: 10),
        TextField(controller: descCtrl, decoration: const InputDecoration(labelText: 'विवरण (Description)', border: OutlineInputBorder(), isDense: true)),
        const SizedBox(height: 10),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.grey.shade200, foregroundColor: Colors.black87),
          onPressed: () async {
            String? url = await ImagePickerHelper.pickAndUploadImage(context);
            if (url != null) {
              setState(() => imageUrl = url);
            }
          },
          icon: const Icon(Icons.image),
          label: Text(imageUrl == null ? 'फोटो चुनें (Pick Image)' : 'फोटो चुन ली गई है ✅'),
        ),
        const SizedBox(height: 15),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade700, foregroundColor: Colors.white, minimumSize: const Size(double.infinity, 45)),
          onPressed: _addProduct,
          child: const Text('मार्केटप्लेस पर डालें', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}

// वेंडर सेटिंग्स टैब
class VendorSettingsTab extends StatefulWidget {
  const VendorSettingsTab({super.key});

  @override
  State<VendorSettingsTab> createState() => _VendorSettingsTabState();
}

class _VendorSettingsTabState extends State<VendorSettingsTab> {
  bool isStoreOpen = true;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('⚙️ दुकान सेटिंग्स', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 15),
        SwitchListTile(
          title: const Text('दुकान खुली/बंद करें (Store Open/Close)'),
          subtitle: const Text('ग्राहकों को लाइव स्टेटस दिखेगा'),
          value: isStoreOpen,
          onChanged: (val) {
            setState(() => isStoreOpen = val);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(val ? '🟢 दुकान अब खुली है!' : '🔴 दुकान बंद कर दी गई है!'))
            );
          },
          activeColor: Colors.green,
        ),
        const Divider(),
        ListTile(
          leading: const Icon(Icons.phone, color: Colors.green),
          title: const Text('सहायता केंद्र (Support)'),
          subtitle: const Text('मास्टर एडमिन तरुण से संपर्क करें'),
          onTap: () {},
        ),
      ],
    );
  }
}
