import 'vendor_auth_portal.dart';

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
    debugPrint("Firebase init warning: $e");
  }

  runApp(const CakeAppEnterpriseApp());
}

class CakeAppEnterpriseApp extends StatelessWidget {
  const CakeAppEnterpriseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Viziag Mart',
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
    int totalCartCount = CakeDatabase.cartItems.fold(0, (sum, item) => sum + ((item['qty'] as num?)?.toInt() ?? 1));

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
                style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: 1.5),
              ),
              const Spacer(),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade700, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), minimumSize: Size.zero),
                onPressed: () => setState(() => _selectedTabIndex = 0),
                icon: const Icon(Icons.store, size: 14),
                label: const Text('Shop', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 6),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.grey.shade200, foregroundColor: Colors.black87, padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), minimumSize: Size.zero),
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
                        Text(CakeDatabase.currentCustomerName, style: const TextStyle(color: Colors.black87, fontSize: 11, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => _showProfileEditDialog(context),
                    child: Text('(Edit Profile & Address)', style: TextStyle(color: Colors.green.shade700, fontSize: 10, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: IndexedStack(index: _selectedTabIndex > 3 ? 3 : _selectedTabIndex, children: _tabScreens),
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
                      child: Text('$totalCartCount', style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
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
  int _viewMode = 0; // 0: Main, 1: Register, 2: Login, 3: Vendor Portal, 4: Admin Code, 5: Admin Panel

  final regShopNameCtrl = TextEditingController();
  final regPhoneCtrl = TextEditingController();
  final regAddressCtrl = TextEditingController();
  final regPass1Ctrl = TextEditingController();
  final regPass2Ctrl = TextEditingController();

  final loginPhoneCtrl = TextEditingController();
  final loginPassCtrl = TextEditingController();

  final adminCodeCtrl = TextEditingController();
  bool _isLoading = false;

  List<dynamic> allVendorOrders = [];
  List<dynamic> pendingVendorRequests = [];
  bool isLoadingOrders = false;
  bool isLoadingRequests = false;

  @override
  void initState() {
    super.initState();
    _fetchVendorOrders();
    _fetchPendingRequests();
  }

  Future<void> _fetchVendorOrders() async {
    setState(() => isLoadingOrders = true);
    try {
      final res = await http.get(Uri.parse('${CakeDatabase.firebaseRestUrl}/orders.json'));
      if (res.statusCode == 200 && res.body != 'null' && res.body.isNotEmpty) {
        Map<String, dynamic> data = json.decode(res.body);
        List<dynamic> loadedOrders = [];
        data.forEach((key, val) {
          if (val is Map) {
            val['firebaseKey'] = key;
            loadedOrders.add(val);
          }
        });
        setState(() {
          allVendorOrders = loadedOrders.reversed.toList();
          isLoadingOrders = false;
        });
      } else {
        setState(() {
          allVendorOrders = [];
          isLoadingOrders = false;
        });
      }
    } catch (e) {
      setState(() => isLoadingOrders = false);
    }
  }

  Future<void> _fetchPendingRequests() async {
    setState(() => isLoadingRequests = true);
    try {
      final res = await http.get(Uri.parse('${CakeDatabase.firebaseRestUrl}/vendor_requests.json'));
      if (res.statusCode == 200 && res.body != 'null' && res.body.isNotEmpty) {
        Map<String, dynamic> data = json.decode(res.body);
        List<dynamic> loadedReqs = [];
        data.forEach((key, val) {
          if (val is Map) {
            val['firebaseKey'] = key;
            loadedReqs.add(val);
          }
        });
        setState(() {
          pendingVendorRequests = loadedReqs;
          isLoadingRequests = false;
        });
      } else {
        setState(() {
          pendingVendorRequests = [];
          isLoadingRequests = false;
        });
      }
    } catch (e) {
      setState(() => isLoadingRequests = false);
    }
  }

  Future<void> _updateOrderStatus(String orderKey, String newStatus) async {
    try {
      await http.patch(
        Uri.parse('${CakeDatabase.firebaseRestUrl}/orders/$orderKey.json'),
        body: json.encode({'orderStatus': newStatus}),
      );
      _fetchVendorOrders();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ आर्डर स्टेटस सफलतापर्वक अपडेट हो गया!'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ एरर: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _approveVendorRequest(String reqKey, String status) async {
    try {
      await http.patch(
        Uri.parse('${CakeDatabase.firebaseRestUrl}/vendor_requests/$reqKey.json'),
        body: json.encode({'status': status}),
      );
      _fetchPendingRequests();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('✅ वेंडर स्टेटस अपडेट किया गया: $status'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ एरर: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _submitRegistration() async {
    if (regPhoneCtrl.text.trim().length < 10 || regShopNameCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('⚠️ कृपया दुकान का नाम और सही मोबाइल नंबर भरें!'), backgroundColor: Colors.red));
      return;
    }
    if (regPass1Ctrl.text.isEmpty || regPass1Ctrl.text != regPass2Ctrl.text) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('⚠️ पासवर्ड मेल नहीं खा रहे हैं!'), backgroundColor: Colors.red));
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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('⚠️ कृपया मोबाइल नंबर और पासवर्ड दर्ज करें!'), backgroundColor: Colors.red));
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
        _fetchVendorOrders();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ स्वागत है! वेंडर डैशबोर्ड सफलतापूर्वक खुल गया है।'), backgroundColor: Colors.green));
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
      _fetchPendingRequests();
      adminCodeCtrl.clear();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('⚠️ गलत गुप्त कोड दर्ज किया गया है!'), backgroundColor: Colors.red));
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
            const Center(child: Text('📝 नया वेंडर रजिस्ट्रेशन फॉर्म', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold))),
            const SizedBox(height: 20),
            TextField(controller: regShopNameCtrl, decoration: const InputDecoration(labelText: 'दुकान का नाम (Shop Name)', border: OutlineInputBorder(), prefixIcon: Icon(Icons.store))),
            const SizedBox(height: 15),
            TextField(controller: regPhoneCtrl, keyboardType: TextInputType.phone, maxLength: 10, decoration: const InputDecoration(labelText: 'मोबाइल नंबर', border: OutlineInputBorder(), counterText: '', prefixIcon: Icon(Icons.phone))),
            const SizedBox(height: 15),
            TextField(controller: regAddressCtrl, decoration: const InputDecoration(labelText: 'दुकान का पूरा पता / लोकेशन', border: OutlineInputBorder(), prefixIcon: Icon(Icons.location_on))),
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
            const Text('🔐 वेंडर लॉगिन पोर्टल', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
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
        length: 2,
        child: Column(
          children: [
            Container(
              color: Colors.green.shade50,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Row(
                children: [
                  const Text('🟢 वेंडर डैशबोर्ड (लाइव)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.green)),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.refresh, size: 18, color: Colors.green),
                    onPressed: _fetchVendorOrders,
                  ),
                  TextButton(
                    onPressed: () => setState(() => _viewMode = 0),
                    child: const Text('लॉग आउट', style: TextStyle(fontSize: 12, color: Colors.red, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
            const Material(
              color: Colors.white,
              child: TabBar(
                labelColor: Colors.green,
                unselectedLabelColor: Colors.grey,
                indicatorColor: Colors.green,
                tabs: [
                  Tab(icon: Icon(Icons.list_alt), text: 'कस्टमर ऑर्डर्स'),
                  Tab(icon: Icon(Icons.inventory), text: 'मेरी दुकानें/आइटम्स'),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                children: [
                  // Tab 1: Orders List with Complete Item Details & Images
                  isLoadingOrders
                      ? const Center(child: CircularProgressIndicator(color: Colors.green))
                      : allVendorOrders.isEmpty
                          ? const Center(
                              child: Text(
                                'कोई नया आर्डर उपलब्ध नहीं है',
                                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey),
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.all(12),
                              itemCount: allVendorOrders.length,
                              itemBuilder: (context, index) {
                                var ord = allVendorOrders[index];
                                String orderId = ord['orderId'] ?? ord['firebaseKey'] ?? '';
                                String customerName = ord['customerName'] ?? ord['name'] ?? 'Customer';
                                String phone = ord['customerPhone'] ?? ord['phone'] ?? '';
                                String deliveryAddress = ord['customerAddress'] ?? ord['deliveryAddress'] ?? ord['address'] ?? 'पता उपलब्ध नहीं';
                                String status = ord['orderStatus'] ?? ord['status'] ?? 'Pending ⏳';
                                
                                var items = ord['items'] ?? ord['cartItems'] ?? ord['products'] ?? [];
                                if (items is! List) items = [];

                                double totalAmount = (ord['totalAmount'] ?? ord['grandTotal'] ?? 0.0).toDouble();

                                bool isAccepted = status.toLowerCase().contains('accepted');
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
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              '📦 #${orderId.length > 8 ? orderId.substring(0, 8) : orderId}',
                                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.orange.shade800),
                                            ),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                              decoration: BoxDecoration(
                                                color: isDelivered ? Colors.green.shade100 : (isAccepted ? Colors.blue.shade100 : Colors.orange.shade100),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                status,
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.bold,
                                                  color: isDelivered ? Colors.green.shade800 : (isAccepted ? Colors.blue.shade800 : Colors.orange.shade800),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        Text('ग्राहक: $customerName ($phone)', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                        const SizedBox(height: 8),
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
                                              Expanded(child: Text('पता: $deliveryAddress', style: const TextStyle(fontSize: 11, color: Colors.black87, fontWeight: FontWeight.w500))),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(height: 10),
                                        const Text('🛒 आर्डर किए गए आइटम्स (फूट्स/सामान):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.grey)),
                                        const SizedBox(height: 6),
                                        
                                        items.isEmpty
                                            ? const Text('कोई आइटम डेटा नहीं मिला', style: TextStyle(fontSize: 11, color: Colors.red))
                                            : Column(
                                                children: items.map<Widget>((it) {
                                                  var m = it is Map ? it : {};
                                                  String itemName = m['name'] ?? m['title'] ?? 'आइटम';
                                                  var itemQty = m['qty'] ?? m['quantity'] ?? 1;
                                                  var itemPrice = double.tryParse((m['price'] ?? 0).toString()) ?? 0;
                                                  String imageUrl = m['image'] ?? m['img'] ?? m['imageUrl'] ?? '';

                                                  return Container(
                                                    margin: const EdgeInsets.only(bottom: 6),
                                                    padding: const EdgeInsets.all(6),
                                                    decoration: BoxDecoration(
                                                      color: Colors.grey.shade50,
                                                      borderRadius: BorderRadius.circular(8),
                                                      border: Border.all(color: Colors.grey.shade200),
                                                    ),
                                                    child: Row(
                                                      children: [
                                                        ClipRRect(
                                                          borderRadius: BorderRadius.circular(6),
                                                          child: imageUrl.isNotEmpty
                                                              ? Image.network(
                                                                  imageUrl,
                                                                  width: 45,
                                                                  height: 45,
                                                                  fit: BoxFit.cover,
                                                                  errorBuilder: (c, e, s) => const Icon(Icons.broken_image, size: 30, color: Colors.grey),
                                                                )
                                                              : Container(
                                                                  width: 45,
                                                                  height: 45,
                                                                  color: Colors.green.shade100,
                                                                  child: const Icon(Icons.shopping_bag, size: 22, color: Colors.green),
                                                                ),
                                                        ),
                                                        const SizedBox(width: 10),
                                                        Expanded(
                                                          child: Column(
                                                            crossAxisAlignment: CrossAxisAlignment.start,
                                                            children: [
                                                              Text(itemName, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                                              const SizedBox(height: 2),
                                                              Text('मात्रा (Qty): $itemQty', style: const TextStyle(fontSize: 11, color: Colors.black54, fontWeight: FontWeight.w600)),
                                                            ],
                                                          ),
                                                        ),
                                                        Text('₹${itemPrice * (double.tryParse(itemQty.toString()) ?? 1)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.green)),
                                                      ],
                                                    ),
                                                  );
                                                }).toList(),
                                              ),

                                        const Divider(height: 14),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text('कुल राशि: ₹$totalAmount', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.orange.shade800)),
                                            PopupMenuButton<String>(
                                              onSelected: (val) => _updateOrderStatus(ord['firebaseKey'] ?? orderId, val),
                                              itemBuilder: (context) => [
                                                const PopupMenuItem(value: 'Accepted ✅', child: Text('स्वीकार करें')),
                                                const PopupMenuItem(value: 'Ready / Packed 📦', child: Text('पैक हो गया')),
                                                const PopupMenuItem(value: 'Delivered 🎉', child: Text('डिलीवर')),
                                                const PopupMenuItem(value: 'Cancelled ❌', child: Text('रद्द करें')),
                                              ],
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                                decoration: BoxDecoration(color: Colors.orange, borderRadius: BorderRadius.circular(6)),
                                                child: const Text('स्टेटस बदलें ▾', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
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
                  // Tab 2: Products Management
                  const Center(child: Text('🛠️ यहाँ वेंडर अपने प्रोडक्ट्स मैनेज कर सकता है', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold))),
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
            const Icon(Icons.security, size: 65, color: Colors.green),
            const SizedBox(height: 15),
            const Text('🔒 मास्टर एडमिन सत्यापन', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 5),
            const Text('केवल तरुण (मास्टर एडमिन) के लिए सुरक्षित', style: TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 25),
            TextField(controller: adminCodeCtrl, obscureText: true, decoration: const InputDecoration(labelText: 'गुप्त कोड दर्ज करें (Secret Passcode)', border: OutlineInputBorder(), prefixIcon: Icon(Icons.key))),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade700, foregroundColor: Colors.white),
                onPressed: _verifyAdminCode,
                child: const Text('वेरिफ़ाई करें', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              ),
            ),
            const SizedBox(height: 10),
            TextButton(onPressed: () => setState(() => _viewMode = 0), child: const Text('← वापस जाएं')),
          ],
        ),
      );
    }

    // ViewMode 5: Master Admin Panel for Approving Vendors
    return Column(
      children: [
        Container(
          color: Colors.green.shade100,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              const Text('👑 मास्टर एडमिन पैनल (तरुण)', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green, fontSize: 13)),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.refresh, size: 18, color: Colors.green),
                onPressed: _fetchPendingRequests,
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white, minimumSize: const Size(60, 30)),
                onPressed: () => setState(() => _viewMode = 0),
                child: const Text('बंद करें', style: TextStyle(fontSize: 11)),
              ),
            ],
          ),
        ),
        Expanded(
          child: isLoadingRequests
              ? const Center(child: CircularProgressIndicator(color: Colors.green))
              : pendingVendorRequests.isEmpty
                  ? const Center(
                      child: Text(
                        'कोई नई वेंडर अप्रूवल रिक्वेस्ट नहीं है',
                        style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: pendingVendorRequests.length,
                      itemBuilder: (context, index) {
                        var req = pendingVendorRequests[index];
                        String reqKey = req['firebaseKey'] ?? '';
                        String shopName = req['name'] ?? 'दुकान';
                        String phone = req['phone'] ?? '';
                        String address = req['address'] ?? '';
                        String status = req['status'] ?? 'pending';

                        return Card(
                          margin: const EdgeInsets.only(bottom: 10),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(shopName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: status == 'approved' ? Colors.green.shade100 : Colors.orange.shade100,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        status.toUpperCase(),
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: status == 'approved' ? Colors.green.shade800 : Colors.orange.shade800,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text('📞 फोन: $phone', style: const TextStyle(fontSize: 12)),
                                Text('📍 पता: $address', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                const SizedBox(height: 10),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    OutlinedButton(
                                      style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                                      onPressed: () => _approveVendorRequest(reqKey, 'rejected'),
                                      child: const Text('रिजेक्ट करें', style: TextStyle(fontSize: 11)),
                                    ),
                                    const SizedBox(width: 8),
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade700, foregroundColor: Colors.white),
                                      onPressed: () => _approveVendorRequest(reqKey, 'approved'),
                                      child: const Text('अप्रूव करें ✅', style: TextStyle(fontSize: 11)),
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
    );
  }
}
