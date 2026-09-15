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
  
  // 🟢 यहाँ try-catch लगाने से वाइट स्क्रीन की दिक्कत जड़ से खत्म हो जाएगी
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
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ स्वागत है! वेंडर डैशबोर्ड खुल गया है।'), backgroundColor: Colors.green));
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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('⚠️ गलत गुप्त कोड!'), backgroundColor: Colors.red));
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
                  Tab(text: '📦 प्रोडक्ट्स जोड़ें & मैनेज करें'),
                  Tab(text: '📋 कस्टमर आर्डर्स'),
                  Tab(text: '⚙️ दुकान सेटिंग्स'),
                ],
              ),
            ),
            const Expanded(
              child: TabBarView(
                children: [
                  VendorInventoryTab(),
                  VendorOrdersTab(),
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
            const Text('🔐 मास्टर एडमिन लॉगिन', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 25),
            TextField(controller: adminCodeCtrl, obscureText: true, decoration: const InputDecoration(labelText: 'गुप्त कोड (Secret Code)', border: OutlineInputBorder(), prefixIcon: Icon(Icons.key))),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade700, foregroundColor: Colors.white),
                onPressed: _verifyAdminCode,
                child: const Text('अप्रूवल पैनल खोलें', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              ),
            ),
            TextButton(onPressed: () => setState(() => _viewMode = 0), child: const Text('← वापस जाएं', style: TextStyle(color: Colors.grey))),
          ],
        ),
      );
    }

    return Column(
      children: [
        Container(
          color: Colors.green.shade800,
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              const Icon(Icons.admin_panel_settings, color: Colors.white),
              const SizedBox(width: 8),
              const Text('शॉप अप्रूवल मास्टर डैशबोर्ड', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
              const Spacer(),
              IconButton(icon: const Icon(Icons.logout, color: Colors.white), onPressed: () => setState(() => _viewMode = 0)),
            ],
          ),
        ),
        Expanded(
          child: FutureBuilder<http.Response>(
            future: http.get(Uri.parse('${CakeDatabase.firebaseRestUrl}/vendor_requests.json')),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!snapshot.hasData || snapshot.data!.body == 'null' || snapshot.data!.body.isEmpty) {
                return const Center(child: Text('अप्रूवल के लिए कोई नई दुकान नहीं है', style: TextStyle(color: Colors.grey)));
              }

              try {
                Map<String, dynamic> data = json.decode(snapshot.data!.body);
                List<Map<String, dynamic>> pendingList = [];
                data.forEach((key, val) {
                  var shop = Map<String, dynamic>.from(val);
                  shop['firebaseKey'] = key;
                  if (shop['status'] == 'pending') {
                    pendingList.add(shop);
                  }
                });

                if (pendingList.isEmpty) {
                  return const Center(child: Text('अप्रूवल के लिए कोई पेंडिंग दुकान नहीं है', style: TextStyle(color: Colors.grey)));
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: pendingList.length,
                  itemBuilder: (context, index) {
                    var shop = pendingList[index];
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('🏪 ${shop['name']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            Text('मोबाइल: ${shop['phone']} | पता: ${shop['address']}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                            const Divider(height: 20),
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                                    onPressed: () async {
                                      await http.patch(
                                        Uri.parse('${CakeDatabase.firebaseRestUrl}/vendor_requests/${shop['firebaseKey']}.json'),
                                        body: json.encode({'status': 'approved'}),
                                      );
                                      setState(() {});
                                      if (mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ दुकान स्थायी रूप से अप्रूव हो गई!'), backgroundColor: Colors.green));
                                      }
                                    },
                                    icon: const Icon(Icons.check_circle, size: 16),
                                    label: const Text('Approve'),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                                    onPressed: () async {
                                      await http.delete(Uri.parse('${CakeDatabase.firebaseRestUrl}/vendor_requests/${shop['firebaseKey']}.json'));
                                      setState(() {});
                                      if (mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('🗑️ दुकान डिलीट कर दी गई!'), backgroundColor: Colors.red));
                                      }
                                    },
                                    icon: const Icon(Icons.delete, size: 16),
                                    label: const Text('Delete'),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              } catch (_) {
                return const Center(child: Text('डेटा लोड करने में त्रुटि'));
              }
            },
          ),
        ),
      ],
    );
  }
}

class VendorInventoryTab extends StatefulWidget {
  const VendorInventoryTab({super.key});

  @override
  State<VendorInventoryTab> createState() => _VendorInventoryTabState();
}

class _VendorInventoryTabState extends State<VendorInventoryTab> {
  final nameCtrl = TextEditingController();
  final priceCtrl = TextEditingController();
  final unitCtrl = TextEditingController(text: 'Kg');
  String category = 'Fresh Fruits';
  String? itemImageBase64;
  bool _isLoading = false;

  Future<void> _addProduct() async {
    if (nameCtrl.text.isEmpty || priceCtrl.text.isEmpty) return;
    setState(() => _isLoading = true);
    var newProd = {
      'name': nameCtrl.text.trim(),
      'price': double.tryParse(priceCtrl.text) ?? 0.0,
      'category': category,
      'unit': unitCtrl.text.trim().isEmpty ? 'Kg' : unitCtrl.text.trim(),
      'image': itemImageBase64 ?? '',
      'inStock': true,
    };
    await http.post(Uri.parse('${CakeDatabase.firebaseRestUrl}/products.json'), body: json.encode(newProd));
    nameCtrl.clear();
    priceCtrl.clear();
    unitCtrl.text = 'Kg';
    setState(() {
      itemImageBase64 = null;
      _isLoading = false;
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ प्रोडक्ट सफलतापूर्वक जुड़ गया!'), backgroundColor: Colors.green));
    }
  }

  Future<void> _deleteProduct(String firebaseKey) async {
    await http.delete(Uri.parse('${CakeDatabase.firebaseRestUrl}/products/$firebaseKey.json'));
    setState(() {});
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('🗑️ प्रोडक्ट डिलीट हो गया!')));
  }

  Future<void> _toggleStock(String firebaseKey, bool currentStatus) async {
    await http.patch(
      Uri.parse('${CakeDatabase.firebaseRestUrl}/products/$firebaseKey.json'),
      body: json.encode({'inStock': !currentStatus}),
    );
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('✨ नया आइटम जोड़ें', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.green)),
                const SizedBox(height: 10),
                GestureDetector(
                  onTap: () async {
                    String? img = await pickAndConvertToBase64();
                    if (img != null) setState(() => itemImageBase64 = img);
                  },
                  child: Container(
                    height: 90,
                    decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade300)),
                    child: itemImageBase64 == null
                        ? const Center(child: Text('📷 आइटम फोटो अपलोड करें', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)))
                        : ClipRRect(borderRadius: BorderRadius.circular(8), child: buildShopOrProdImage(itemImageBase64, 90, double.infinity, Icons.image)),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'प्रोडक्ट का नाम', isDense: true)),
                const SizedBox(height: 10),
                TextField(controller: priceCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'कीमत (₹)', isDense: true)),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: category,
                  items: ['Fresh Fruits', 'Vegetables', 'Organic Items', 'Daily Essentials'].map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                  onChanged: (val) => setState(() => category = val!),
                  decoration: const InputDecoration(labelText: 'कैटेगरी', isDense: true),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: unitCtrl,
                  decoration: const InputDecoration(
                    labelText: 'यूनिट (मात्रा इकाई - जैसे Kg, Box, Piece, Packet)',
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 15),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade700, foregroundColor: Colors.white),
                    onPressed: _isLoading ? null : _addProduct,
                    child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text('नया आइटम जोड़ें', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        const Text('📋 आपके मौजूदा प्रोडक्ट्स (मैनेज करें)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.black87)),
        const SizedBox(height: 10),
        FutureBuilder<http.Response>(
          future: http.get(Uri.parse('${CakeDatabase.firebaseRestUrl}/products.json')),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (!snapshot.hasData || snapshot.data!.body == 'null' || snapshot.data!.body.isEmpty) {
              return const Padding(
                padding: EdgeInsets.all(20),
                child: Center(child: Text('कोई प्रोडक्ट उपलब्ध नहीं है', style: TextStyle(color: Colors.grey))),
              );
            }
            try {
              Map<String, dynamic> data = json.decode(snapshot.data!.body);
              List<Map<String, dynamic>> items = [];
              data.forEach((key, val) {
                var item = Map<String, dynamic>.from(val);
                item['firebaseKey'] = key;
                items.add(item);
              });
              items = items.reversed.toList();

              return ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: items.length,
                itemBuilder: (context, index) {
                  var p = items[index];
                  bool inStock = p['inStock'] ?? true;
                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    child: ListTile(
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: buildShopOrProdImage(p['image'], 45, 45, Icons.eco),
                      ),
                      title: Text(p['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('₹${p['price']} / ${p['unit'] ?? 'Kg'}\nस्टेटस: ${inStock ? '🟢 In Stock' : '🔴 Out of Stock'}', style: const TextStyle(fontSize: 11)),
                      isThreeLine: true,
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Switch(
                            value: inStock,
                            activeColor: Colors.green,
                            onChanged: (val) async {
                              await _toggleStock(p['firebaseKey'], inStock);
                              setState(() {});
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => _deleteProduct(p['firebaseKey']),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            } catch (_) {
              return const Text('डेटा लोड करने में त्रुटि');
            }
          },
        ),
      ],
    );
  }
}

class VendorOrdersTab extends StatefulWidget {
  const VendorOrdersTab({super.key});

  @override
  State<VendorOrdersTab> createState() => _VendorOrdersTabState();
}

class _VendorOrdersTabState extends State<VendorOrdersTab> {
  List<Map<String, dynamic>> allOrders = [];
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchOrders();
  }

  Future<void> _fetchOrders() async {
    setState(() => isLoading = true);
    try {
      final res = await http.get(Uri.parse('${CakeDatabase.firebaseRestUrl}/orders.json'));
      if (res.statusCode == 200 && res.body != 'null' && res.body.isNotEmpty) {
        Map<String, dynamic> data = json.decode(res.body);
        List<Map<String, dynamic>> list = [];
        data.forEach((key, val) {
          var item = Map<String, dynamic>.from(val);
          item['firebaseKey'] = key;
          list.add(item);
        });
        setState(() => allOrders = list.reversed.toList());
      }
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _updateStatus(String firebaseKey, String newStatus) async {
    await http.patch(
      Uri.parse('${CakeDatabase.firebaseRestUrl}/orders/$firebaseKey.json'),
      body: json.encode({'status': newStatus}),
    );
    _fetchOrders();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade700, foregroundColor: Colors.white),
            onPressed: _fetchOrders,
            icon: const Icon(Icons.sync),
            label: const Text('आर्डर्स रिफ्रेश करें', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ),
        if (isLoading) const LinearProgressIndicator(color: Colors.green),
        Expanded(
          child: allOrders.isEmpty
              ? const Center(child: Text('कोई आर्डर नहीं आया है', style: TextStyle(color: Colors.grey)))
              : ListView.builder(
                  itemCount: allOrders.length,
                  itemBuilder: (context, index) {
                    var ord = allOrders[index];
                    return Card(
                      margin: const EdgeInsets.all(8),
                      child: ListTile(
                        title: Text('ग्राहक: ${ord['customerName']} (${ord['customerPhone']})', style: TextStyle(color: Colors.green.shade800, fontWeight: FontWeight.bold)),
                        subtitle: Text('पता: ${ord['customerAddress']}\nकुल राशि: ₹${ord['grandTotal']?.toInt()}\nस्टेटस: ${ord['status']}', style: const TextStyle(color: Colors.black87)),
                        isThreeLine: true,
                        trailing: PopupMenuButton<String>(
                          onSelected: (val) => _updateStatus(ord['firebaseKey'], val),
                          itemBuilder: (context) => [
                            const PopupMenuItem(value: 'Accepted ✅', child: Text('Accept')),
                            const PopupMenuItem(value: 'Dispatched 🚚', child: Text('Dispatch')),
                            const PopupMenuItem(value: 'Delivered 🎉', child: Text('Deliver')),
                            const PopupMenuItem(value: 'Cancelled ❌', child: Text('Cancel')),
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

class VendorSettingsTab extends StatefulWidget {
  const VendorSettingsTab({super.key});

  @override
  State<VendorSettingsTab> createState() => _VendorSettingsTabState();
}

class _VendorSettingsTabState extends State<VendorSettingsTab> {
  final shopNameCtrl = TextEditingController(text: CakeDatabase.bakeryShop['shopName']);
  final addressCtrl = TextEditingController(text: CakeDatabase.bakeryShop['address']);
  bool isOpen = CakeDatabase.bakeryShop['isOpen'] ?? true;

  Future<void> _saveSettings() async {
    CakeDatabase.bakeryShop['shopName'] = shopNameCtrl.text;
    CakeDatabase.bakeryShop['address'] = addressCtrl.text;
    CakeDatabase.bakeryShop['isOpen'] = isOpen;
    await http.put(Uri.parse('${CakeDatabase.firebaseRestUrl}/shop_profile.json'), body: json.encode(CakeDatabase.bakeryShop));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ दुकान सेटिंग्स सेव हो गई!'), backgroundColor: Colors.green));
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Card(
          color: isOpen ? Colors.green.shade50 : Colors.red.shade50,
          child: SwitchListTile(
            title: Text(isOpen ? '🟢 दुकान खुली (Open) है' : '🔴 दुकान बंद (Closed) है', style: TextStyle(fontWeight: FontWeight.bold, color: isOpen ? Colors.green.shade800 : Colors.red.shade800)),
            subtitle: const Text('कस्टमर को आर्डर करने से रोकने या अनुमति देने के लिए टॉगल करें'),
            value: isOpen,
            activeColor: Colors.green,
            onChanged: (val) => setState(() => isOpen = val),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            Column(
              children: [
                const Text('दुकान की फोटो', style: TextStyle(fontSize: 11, color: Colors.grey)),
                const SizedBox(height: 5),
                GestureDetector(
                  onTap: () async {
                    String? img = await pickAndConvertToBase64();
                    if (img != null) setState(() => CakeDatabase.bakeryShop['shopPhotoPath'] = img);
                  },
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: buildShopOrProdImage(CakeDatabase.bakeryShop['shopPhotoPath'], 70, 70, Icons.store),
                  ),
                ),
              ],
            ),
            Column(
              children: [
                const Text('बैनर फोटो', style: TextStyle(fontSize: 11, color: Colors.grey)),
                const SizedBox(height: 5),
                GestureDetector(
                  onTap: () async {
                    String? img = await pickAndConvertToBase64();
                    if (img != null) setState(() => CakeDatabase.bakeryShop['bannerPhotoPath'] = img);
                  },
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: buildShopOrProdImage(CakeDatabase.bakeryShop['bannerPhotoPath'], 70, 120, Icons.image),
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 15),
        TextField(controller: shopNameCtrl, decoration: const InputDecoration(labelText: 'दुकान का नाम')),
        TextField(controller: addressCtrl, decoration: const InputDecoration(labelText: 'दुकान का पता')),
        const SizedBox(height: 15),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade700, foregroundColor: Colors.white),
          onPressed: _saveSettings,
          child: const Text('सेव करें', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}
