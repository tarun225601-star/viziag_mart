import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:http/http.dart' as http;
import 'database_models.dart';
import 'marketplace_buyer_view.dart';
import 'cart_and_orders_view.dart';
import 'image_picker_helper.dart';
import 'rider_delivery_view.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint('Firebase init warning: $e');
  }
  runApp(const CakeAppEnterpriseApp());
}

class CakeAppEnterpriseApp extends StatelessWidget {
  const CakeAppEnterpriseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(title: 'Viziag Mart', debugShowCheckedModeBanner: false, theme: ThemeData(useMaterial3: true, brightness: Brightness.light, scaffoldBackgroundColor: const Color(0xFFF8F9FA), colorScheme: ColorScheme.fromSeed(seedColor: Colors.green)), home: const CakeMainHubScreen());
  }
}

class CakeMainHubScreen extends StatefulWidget {
  const CakeMainHubScreen({super.key});

  @override
  State<CakeMainHubScreen> createState() => _CakeMainHubScreenState();
}

class _CakeMainHubScreenState extends State<CakeMainHubScreen> {
  int _selectedTabIndex = 0;

  final List<Widget> _tabScreens = [const MarketplaceBuyerView(), const VendorAuthAndPortalView(), const RiderDeliveryScreen(), const CartAndOrdersView()];

  @override
  Widget build(BuildContext context) {
    final int totalCartCount = CakeDatabase.cartItems.fold(0, (sum, item) => sum + ((item['qty'] as num?)?.toInt() ?? 1));
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(75),
        child: AppBar(
          backgroundColor: Colors.white,
          elevation: 1,
          title: Row(children: [
            const Text('VIZIAG MART', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: 1.5)),
            const Spacer(),
            ElevatedButton.icon(style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade700, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), minimumSize: Size.zero), onPressed: () => setState(() => _selectedTabIndex = 0), icon: const Icon(Icons.store, size: 14), label: const Text('Shop', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold))),
            const SizedBox(width: 6),
            ElevatedButton.icon(style: ElevatedButton.styleFrom(backgroundColor: Colors.grey.shade200, foregroundColor: Colors.black87, padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), minimumSize: Size.zero), onPressed: () => setState(() => _selectedTabIndex = 1), icon: const Icon(Icons.lock_outline, size: 14), label: const Text('Vendor', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold))),
          ]),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(30),
            child: Container(
              color: Colors.green.shade50,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              child: Row(children: [
                GestureDetector(onTap: () => _showProfileEditDialog(context), child: Row(children: [Icon(Icons.person_pin_circle, color: Colors.green.shade700, size: 15), const SizedBox(width: 6), Text(CakeDatabase.currentCustomerName, style: const TextStyle(color: Colors.black87, fontSize: 11, fontWeight: FontWeight.bold))])),
                const Spacer(),
                GestureDetector(onTap: () => _showProfileEditDialog(context), child: Text('(Edit Profile & Address)', style: TextStyle(color: Colors.green.shade700, fontSize: 10, fontWeight: FontWeight.w600))),
              ]),
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
          BottomNavigationBarItem(icon: Stack(children: [const Icon(Icons.shopping_cart_outlined), if (totalCartCount > 0) Positioned(right: 0, top: 0, child: Container(padding: const EdgeInsets.all(2), decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle), constraints: const BoxConstraints(minWidth: 14, minHeight: 14), child: Text('$totalCartCount', style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold), textAlign: TextAlign.center)))]), label: 'Cart & Orders'),
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
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Name', isDense: true)),
            const SizedBox(height: 10),
            TextField(controller: phoneCtrl, decoration: const InputDecoration(labelText: 'Phone', isDense: true)),
            const SizedBox(height: 10),
            TextField(controller: addressCtrl, decoration: const InputDecoration(labelText: 'Address / Location Note', isDense: true)),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade700, foregroundColor: Colors.white), onPressed: () { setState(() { CakeDatabase.currentCustomerName = nameCtrl.text.trim(); CakeDatabase.currentUserPhone = phoneCtrl.text.trim(); CakeDatabase.currentDeliveryAddress = addressCtrl.text.trim(); }); Navigator.pop(context); }, child: const Text('Save')),
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
  final regShopNameCtrl = TextEditingController(), regPhoneCtrl = TextEditingController(), regAddressCtrl = TextEditingController(), regPass1Ctrl = TextEditingController(), regPass2Ctrl = TextEditingController();
  final loginPhoneCtrl = TextEditingController(), loginPassCtrl = TextEditingController(), adminCodeCtrl = TextEditingController();
  bool _isLoading = false;

  Future<void> _submitRegistration() async {
    if (regPhoneCtrl.text.trim().length < 10 || regShopNameCtrl.text.trim().isEmpty) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('⚠️ कृपया दुकान का नाम और सही मोबाइल नंबर भरें!'), backgroundColor: Colors.red)); return; }
    if (regPass1Ctrl.text.isEmpty || regPass1Ctrl.text != regPass2Ctrl.text) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('⚠️ पासवर्ड मेल नहीं खा रहे हैं!'), backgroundColor: Colors.red)); return; }
    setState(() => _isLoading = true);
    try {
      final shopData = {'name': regShopNameCtrl.text.trim(), 'phone': regPhoneCtrl.text.trim(), 'address': regAddressCtrl.text.trim().isEmpty ? 'Faridabad' : regAddressCtrl.text.trim(), 'pass': regPass1Ctrl.text.trim(), 'status': 'pending'};
      final response = await http.post(Uri.parse('${CakeDatabase.firebaseRestUrl}/vendor_requests.json'), body: json.encode(shopData));
      if (response.statusCode < 200 || response.statusCode >= 300) throw Exception('Registration failed: ${response.statusCode}');
      if (mounted) showDialog(context: context, builder: (context) => AlertDialog(title: const Text('⏳ रिक्वेस्ट सबमिट हो गई'), content: const Text('आपकी दुकान का रजिस्ट्रेशन हो गया है। मास्टर एडमिन द्वारा अप्रूव होने के बाद ही आप लॉगिन कर पाएंगे।'), actions: [TextButton(onPressed: () { Navigator.pop(context); setState(() => _viewMode = 0); }, child: const Text('ठीक है'))]));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('❌ Registration failed: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loginVendor() async {
    final phone = loginPhoneCtrl.text.trim(), pass = loginPassCtrl.text.trim();
    if (phone.isEmpty || pass.isEmpty) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('⚠️ कृपया मोबाइल नंबर और पासवर्ड दर्ज करें!'), backgroundColor: Colors.red)); return; }
    setState(() => _isLoading = true);
    try {
      final res = await http.get(Uri.parse('${CakeDatabase.firebaseRestUrl}/vendor_requests.json'));
      bool isApproved = false;
      if (res.statusCode == 200 && res.body != 'null' && res.body.isNotEmpty) {
        final decoded = json.decode(res.body);
        if (decoded is Map) decoded.forEach((key, val) { if (val is Map && val['phone']?.toString() == phone && val['pass']?.toString() == pass && val['status']?.toString() == 'approved') isApproved = true; });
      }
      if (isApproved) {
        setState(() => _viewMode = 3);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ स्वागत है! वेंडर डैशबोर्ड खुल गया है।'), backgroundColor: Colors.green));
      } else if (mounted) {
        showDialog(context: context, builder: (context) => AlertDialog(title: const Text('⚠️ लॉगिन असफल'), content: const Text('आपकी दुकान अभी तक मास्टर एडमिन द्वारा अप्रूव नहीं की गई है या लॉगिन डिटेल गलत हैं।'), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('ठीक है'))]));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('❌ Login failed: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _verifyAdminCode() {
    if (adminCodeCtrl.text.trim() == 'tarun#1') { setState(() => _viewMode = 5); adminCodeCtrl.clear(); } else { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('⚠️ गलत गुप्त कोड!'), backgroundColor: Colors.red)); }
  }

  Widget _field(TextEditingController controller, String label, IconData icon, {bool password = false, TextInputType? keyboard}) {
    return TextField(controller: controller, obscureText: password, keyboardType: keyboard, decoration: InputDecoration(labelText: label, border: const OutlineInputBorder(), prefixIcon: Icon(icon)));
  }

  @override
  Widget build(BuildContext context) {
    if (_viewMode == 0) {
      return Padding(padding: const EdgeInsets.all(20), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Icons.storefront, size: 75, color: Colors.green),
        const SizedBox(height: 15),
        const Text('🛍️ वेंडर पोर्टल', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
        const SizedBox(height: 5),
        const Text('बिना एडमिन अप्रूवल के कोई भी वेंडर लॉगिन नहीं कर सकता', style: TextStyle(fontSize: 11, color: Colors.grey), textAlign: TextAlign.center),
        const SizedBox(height: 40),
        SizedBox(width: double.infinity, height: 50, child: ElevatedButton.icon(style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade700, foregroundColor: Colors.white), onPressed: () => setState(() => _viewMode = 1), icon: const Icon(Icons.person_add), label: const Text('नई दुकान रजिस्टर करें', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)))),
        const SizedBox(height: 15),
        SizedBox(width: double.infinity, height: 50, child: OutlinedButton.icon(style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.green, width: 2), foregroundColor: Colors.green.shade800), onPressed: () => setState(() => _viewMode = 2), icon: const Icon(Icons.login), label: const Text('वेंडर लॉगिन', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)))),
        const Spacer(),
        const Divider(),
        TextButton.icon(onPressed: () => setState(() => _viewMode = 4), icon: const Icon(Icons.admin_panel_settings, color: Colors.green), label: const Text('मास्टर शॉप अप्रूवल डैशबोर्ड', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold))),
      ]));
    }

    if (_viewMode == 1) {
      return Padding(padding: const EdgeInsets.all(20), child: ListView(children: [
        const SizedBox(height: 10),
        const Center(child: Text('📝 नया वेंडर रजिस्ट्रेशन', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold))),
        const SizedBox(height: 20),
        _field(regShopNameCtrl, 'दुकान का नाम', Icons.store),
        const SizedBox(height: 15),
        _field(regPhoneCtrl, 'मोबाइल नंबर', Icons.phone, keyboard: TextInputType.phone),
        const SizedBox(height: 15),
        _field(regAddressCtrl, 'दुकान का पता / लोकेशन', Icons.location_on),
        const SizedBox(height: 15),
        _field(regPass1Ctrl, 'पासवर्ड बनाएं', Icons.lock_outline, password: true),
        const SizedBox(height: 15),
        _field(regPass2Ctrl, 'पासवर्ड दोबारा दर्ज करें', Icons.lock, password: true),
        const SizedBox(height: 20),
        SizedBox(width: double.infinity, height: 48, child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade700, foregroundColor: Colors.white), onPressed: _isLoading ? null : _submitRegistration, child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text('अप्रूवल के लिए सबमिट करें', style: TextStyle(fontWeight: FontWeight.bold)))),
        TextButton(onPressed: () => setState(() => _viewMode = 0), child: const Text('← वापस जाएं')),
      ]));
    }

    if (_viewMode == 2) {
      return Padding(padding: const EdgeInsets.all(20), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Icons.lock_open, size: 65, color: Colors.green),
        const SizedBox(height: 15),
        const Text('🔐 वेंडर लॉगिन', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 5),
        const Text('पहले एडमिन से अप्रूव कराना अनिवार्य है', style: TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 25),
        _field(loginPhoneCtrl, 'मोबाइल नंबर', Icons.phone, keyboard: TextInputType.phone),
        const SizedBox(height: 15),
        _field(loginPassCtrl, 'पासवर्ड', Icons.lock, password: true),
        const SizedBox(height: 20),
        SizedBox(width: double.infinity, height: 48, child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade700, foregroundColor: Colors.white), onPressed: _isLoading ? null : _loginVendor, child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text('लॉगिन करें ➔', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)))),
        TextButton(onPressed: () => setState(() => _viewMode = 0), child: const Text('← वापस जाएं')),
      ]));
    }

    if (_viewMode == 3) {
      return DefaultTabController(length: 3, child: Column(children: [
        Container(color: Colors.green.shade50, padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), child: Row(children: [const Text('🟢 वेंडर डैशबोर्ड (लाइव)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.green)), const Spacer(), TextButton(onPressed: () => setState(() => _viewMode = 0), child: const Text('लॉग आउट', style: TextStyle(fontSize: 11, color: Colors.red)))])),
        const Material(color: Colors.white, child: TabBar(isScrollable: true, labelColor: Colors.green, unselectedLabelColor: Colors.grey, indicatorColor: Colors.green, tabs: [Tab(text: '📦 प्रोडक्ट्स'), Tab(text: '🛒 ऑर्डर्स'), Tab(text: '⚙️ सेटिंग्स')])),
        const Expanded(child: TabBarView(children: [VendorInventoryTab(), VendorOrdersTab(), VendorSettingsTab()])),
      ]));
    }

    if (_viewMode == 4) {
      return Padding(padding: const EdgeInsets.all(20), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Icons.admin_panel_settings, size: 70, color: Colors.green),
        const SizedBox(height: 15),
        const Text('🔐 मास्टर एडमिन', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        const Text('अप्रूवल पैनल खोलने के लिए गुप्त कोड दर्ज करें', style: TextStyle(color: Colors.grey)),
        const SizedBox(height: 25),
        TextField(controller: adminCodeCtrl, obscureText: true, decoration: const InputDecoration(labelText: 'Secret Admin Code', border: OutlineInputBorder(), prefixIcon: Icon(Icons.key))),
        const SizedBox(height: 20),
        SizedBox(width: double.infinity, height: 48, child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade700, foregroundColor: Colors.white), onPressed: _verifyAdminCode, child: const Text('अप्रूवल पैनल खोलें', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)))),
        TextButton(onPressed: () => setState(() => _viewMode = 0), child: const Text('← वापस जाएं')),
      ]));
    }

    return Column(children: [
      Container(color: Colors.green.shade800, padding: const EdgeInsets.all(12), child: Row(children: [const Icon(Icons.admin_panel_settings, color: Colors.white), const SizedBox(width: 8), const Text('शॉप अप्रूवल मास्टर डैशबोर्ड', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)), const Spacer(), IconButton(icon: const Icon(Icons.logout, color: Colors.white), onPressed: () => setState(() => _viewMode = 0))])),
      Expanded(child: FutureBuilder<http.Response>(
        future: http.get(Uri.parse('${CakeDatabase.firebaseRestUrl}/vendor_requests.json')),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (!snapshot.hasData || snapshot.data!.body == 'null' || snapshot.data!.body.isEmpty) return const Center(child: Text('अप्रूवल के लिए कोई नई दुकान नहीं है', style: TextStyle(color: Colors.grey)));
          try {
            final decoded = json.decode(snapshot.data!.body);
            if (decoded is! Map) return const Center(child: Text('कोई दुकान उपलब्ध नहीं है'));
            final data = Map<String, dynamic>.from(decoded);
            final pendingList = <Map<String, dynamic>>[];
            data.forEach((key, val) { if (val is Map) { final shop = Map<String, dynamic>.from(val); shop['firebaseKey'] = key; if (shop['status'] == 'pending') pendingList.add(shop); } });
            if (pendingList.isEmpty) return const Center(child: Text('अप्रूवल के लिए कोई पेंडिंग दुकान नहीं है', style: TextStyle(color: Colors.grey)));
            return ListView.builder(padding: const EdgeInsets.all(12), itemCount: pendingList.length, itemBuilder: (context, index) {
              final shop = pendingList[index];
              return Card(child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('🏪 ${shop['name'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                Text('मोबाइल: ${shop['phone'] ?? ''} | पता: ${shop['address'] ?? ''}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                const Divider(height: 20),
                Row(children: [
                  Expanded(child: ElevatedButton.icon(style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white), onPressed: () async { await http.patch(Uri.parse('${CakeDatabase.firebaseRestUrl}/vendor_requests/${shop['firebaseKey']}.json'), body: json.encode({'status': 'approved'})); if (mounted) { setState(() {}); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ दुकान स्थायी रूप से अप्रूव हो गई!'), backgroundColor: Colors.green)); } }, icon: const Icon(Icons.check_circle, size: 16), label: const Text('Approve'))),
                  const SizedBox(width: 10),
                  Expanded(child: ElevatedButton.icon(style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white), onPressed: () async { await http.delete(Uri.parse('${CakeDatabase.firebaseRestUrl}/vendor_requests/${shop['firebaseKey']}.json')); if (mounted) { setState(() {}); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('🗑️ दुकान डिलीट कर दी गई!'), backgroundColor: Colors.red)); } }, icon: const Icon(Icons.delete, size: 16), label: const Text('Delete'))),
                ]),
              ])));
            });
          } catch (e) { return Center(child: Text('डेटा लोड करने में त्रुटि: $e')); }
        },
      )),
    ]);
  }
}

class VendorInventoryTab extends StatefulWidget {
  const VendorInventoryTab({super.key});

  @override
  State<VendorInventoryTab> createState() => _VendorInventoryTabState();
}

class _VendorInventoryTabState extends State<VendorInventoryTab> {
  final nameCtrl = TextEditingController(), priceCtrl = TextEditingController(), unitCtrl = TextEditingController(text: 'Kg');
  String category = 'Fresh Fruits';
  String? itemImageBase64;
  bool _isLoading = false;

  Future<void> _addProduct() async {
    if (nameCtrl.text.trim().isEmpty || priceCtrl.text.trim().isEmpty) return;
    setState(() => _isLoading = true);
    try {
      final newProd = {'name': nameCtrl.text.trim(), 'price': double.tryParse(priceCtrl.text.trim()) ?? 0.0, 'category': category, 'unit': unitCtrl.text.trim().isEmpty ? 'Kg' : unitCtrl.text.trim(), 'image': itemImageBase64 ?? '', 'inStock': true};
      final response = await http.post(Uri.parse('${CakeDatabase.firebaseRestUrl}/products.json'), body: json.encode(newProd));
      if (response.statusCode < 200 || response.statusCode >= 300) throw Exception('Product save failed');
      nameCtrl.clear(); priceCtrl.clear(); unitCtrl.text = 'Kg';
      if (mounted) { setState(() => itemImageBase64 = null); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ प्रोडक्ट सफलतापूर्वक जुड़ गया!'), backgroundColor: Colors.green)); }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('❌ Product save failed: $e'), backgroundColor: Colors.red));
    } finally { if (mounted) setState(() => _isLoading = false); }
  }

  Future<void> _deleteProduct(String firebaseKey) async {
    await http.delete(Uri.parse('${CakeDatabase.firebaseRestUrl}/products/$firebaseKey.json'));
    if (mounted) { setState(() {}); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('🗑️ प्रोडक्ट डिलीट हो गया!'))); }
  }

  Future<void> _toggleStock(String firebaseKey, bool currentStatus) async {
    await http.patch(Uri.parse('${CakeDatabase.firebaseRestUrl}/products/$firebaseKey.json'), body: json.encode({'inStock': !currentStatus}));
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return ListView(padding: const EdgeInsets.all(12), children: [
      Card(elevation: 2, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('✨ नया आइटम जोड़ें', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.green)),
        const SizedBox(height: 10),
        GestureDetector(onTap: () async { final img = await pickAndConvertToBase64(); if (img != null && mounted) setState(() => itemImageBase64 = img); }, child: Container(height: 90, decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade300)), child: itemImageBase64 == null ? const Center(child: Text('📷 आइटम फोटो अपलोड करें', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold))) : ClipRRect(borderRadius: BorderRadius.circular(8), child: buildShopOrProdImage(itemImageBase64, 90, double.infinity, Icons.image)))),
        const SizedBox(height: 10),
        TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'प्रोडक्ट का नाम', isDense: true)),
        const SizedBox(height: 10),
        TextField(controller: priceCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'कीमत (₹)', isDense: true)),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(value: category, items: ['Fresh Fruits', 'Vegetables', 'Organic Items', 'Daily Essentials'].map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(), onChanged: (val) { if (val != null) setState(() => category = val); }, decoration: const InputDecoration(labelText: 'कैटेगरी', isDense: true)),
        const SizedBox(height: 10),
        TextField(controller: unitCtrl, decoration: const InputDecoration(labelText: 'यूनिट - Kg, Box, Piece, Packet', isDense: true)),
        const SizedBox(height: 15),
        SizedBox(width: double.infinity, child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade700, foregroundColor: Colors.white), onPressed: _isLoading ? null : _addProduct, child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text('नया आइटम जोड़ें', style: TextStyle(fontWeight: FontWeight.bold)))),
      ]))),
      const SizedBox(height: 20),
      const Text('📋 आपके मौजूदा प्रोडक्ट्स', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
      const SizedBox(height: 10),
      FutureBuilder<http.Response>(future: http.get(Uri.parse('${CakeDatabase.firebaseRestUrl}/products.json')), builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        if (!snapshot.hasData || snapshot.data!.body == 'null' || snapshot.data!.body.isEmpty) return const Padding(padding: EdgeInsets.all(20), child: Center(child: Text('कोई प्रोडक्ट उपलब्ध नहीं है', style: TextStyle(color: Colors.grey))));
        try {
          final decoded = json.decode(snapshot.data!.body);
          if (decoded is! Map) return const Text('कोई प्रोडक्ट उपलब्ध नहीं है');
          final data = Map<String, dynamic>.from(decoded);
          final items = <Map<String, dynamic>>[];
          data.forEach((key, val) { if (val is Map) { final item = Map<String, dynamic>.from(val); item['firebaseKey'] = key; items.add(item); } });
          items.reverse();
          return ListView.builder(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), itemCount: items.length, itemBuilder: (context, index) {
            final p = items[index];
            final bool inStock = p['inStock'] ?? true;
            return Card(margin: const EdgeInsets.symmetric(vertical: 6), child: ListTile(leading: ClipRRect(borderRadius: BorderRadius.circular(6), child: buildShopOrProdImage(p['image'], 45, 45, Icons.eco)), title: Text(p['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)), subtitle: Text('₹${p['price']} / ${p['unit'] ?? 'Kg'}\nस्टेटस: ${inStock ? '🟢 In Stock' : '🔴 Out of Stock'}', style: const TextStyle(fontSize: 11)), isThreeLine: true, trailing: Row(mainAxisSize: MainAxisSize.min, children: [Switch(value: inStock, activeColor: Colors.green, onChanged: (_) => _toggleStock(p['firebaseKey'], inStock)), IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => _deleteProduct(p['firebaseKey']))])));
          });
        } catch (e) { return Text('डेटा लोड करने में त्रुटि: $e'); }
      }),
    ]);
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
  void initState() { super.initState(); _fetchOrders(); }

  String _text(dynamic value, [String fallback = '—']) { if (value == null) return fallback; final text = value.toString().trim(); return text.isEmpty || text == 'null' ? fallback : text; }

  double _number(dynamic value) { if (value == null) return 0; if (value is num) return value.toDouble(); return double.tryParse(value.toString()) ?? 0; }

  int _quantity(dynamic value) { final q = _number(value).round(); return q <= 0 ? 1 : q; }

  String? _getProductImage(dynamic item) {
    if (item is! Map) return null;
    for (final key in ['image', 'imagePath', 'photo', 'photoPath', 'productImage', 'productImagePath', 'imageUrl', 'photoUrl']) { final value = item[key]; if (value != null && value.toString().trim().isNotEmpty) return value.toString(); }
    return null;
  }

  String _getProductName(dynamic item) {
    if (item is! Map) return 'Unknown Product';
    for (final key in ['name', 'productName', 'title', 'productTitle', 'itemName']) { final value = item[key]; if (value != null && value.toString().trim().isNotEmpty) return value.toString(); }
    return 'Unknown Product';
  }

  List<Map<String, dynamic>> _getOrderItems(Map<String, dynamic> order) {
    dynamic rawItems = order['items'] ?? order['orderItems'] ?? order['cartItems'] ?? order['products'];
    if (rawItems is List) return rawItems.where((e) => e is Map).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    if (rawItems is Map) return rawItems.entries.map((entry) { final value = entry.value; if (value is Map) { final item = Map<String, dynamic>.from(value); item['firebaseKey'] = entry.key.toString(); return item; } return <String, dynamic>{'name': entry.key.toString(), 'qty': value}; }).toList();
    return [];
  }

  Future<void> _fetchOrders() async {
    if (mounted) setState(() => isLoading = true);
    try {
      final response = await http.get(Uri.parse('${CakeDatabase.firebaseRestUrl}/orders.json'));
      if (response.statusCode != 200) throw Exception('Firebase error: ${response.statusCode}');
      if (response.body == 'null' || response.body.trim().isEmpty) { if (mounted) setState(() => allOrders = []); return; }
      final decoded = json.decode(response.body);
      if (decoded is! Map) { if (mounted) setState(() => allOrders = []); return; }
      final data = Map<String, dynamic>.from(decoded);
      final list = <Map<String, dynamic>>[];
      data.forEach((key, value) { if (value is Map) { final order = Map<String, dynamic>.from(value); order['firebaseKey'] = key; order['items'] = _getOrderItems(order); list.add(order); } });
      list.sort((a, b) => _number(b['createdAt'] ?? b['timestamp'] ?? b['orderTime'] ?? 0).compareTo(_number(a['createdAt'] ?? a['timestamp'] ?? a['orderTime'] ?? 0)));
      if (mounted) setState(() => allOrders = list);
    } catch (e) {
      debugPrint('Vendor Orders Error: $e');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('❌ Orders load नहीं हुए: $e'), backgroundColor: Colors.red));
    } finally { if (mounted) setState(() => isLoading = false); }
  }

  Future<void> _updateStatus(String firebaseKey, String newStatus) async {
    try {
      final response = await http.patch(Uri.parse('${CakeDatabase.firebaseRestUrl}/orders/$firebaseKey.json'), body: json.encode({'status': newStatus}));
      if (response.statusCode < 200 || response.statusCode >= 300) throw Exception('HTTP ${response.statusCode}');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('✅ Order status: $newStatus'), backgroundColor: Colors.green));
      await _fetchOrders();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('❌ Status update failed: $e'), backgroundColor: Colors.red));
    }
  }

  Widget _productImage(String? imagePath) {
    if (imagePath == null || imagePath.trim().isEmpty) return Container(width: 65, height: 65, decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.grey.shade300)), child: const Icon(Icons.image_not_supported_outlined, color: Colors.grey, size: 28));
    return ClipRRect(borderRadius: BorderRadius.circular(10), child: buildShopOrProdImage(imagePath, 65, 65, Icons.shopping_bag));
  }

  Widget _buildOrderItem(Map<String, dynamic> item) {
    final name = _getProductName(item), image = _getProductImage(item);
    final qty = _quantity(item['qty'] ?? item['quantity'] ?? item['count'] ?? 1);
    final price = _number(item['price'] ?? item['unitPrice'] ?? item['sellingPrice'] ?? item['amount'] ?? 0);
    final subtotal = _number(item['subtotal'] ?? item['subTotal'] ?? item['total'] ?? item['lineTotal'] ?? (price * qty));
    return Container(margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _productImage(image),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        Row(children: [Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(6)), child: Text('Qty: $qty', style: TextStyle(color: Colors.green.shade800, fontWeight: FontWeight.bold, fontSize: 12))), const SizedBox(width: 8), Text('₹${price.toStringAsFixed(0)} × $qty', style: const TextStyle(color: Colors.grey, fontSize: 12))]),
        const SizedBox(height: 5),
        Text('Subtotal: ₹${subtotal.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
      ])),
    ]));
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(padding: const EdgeInsets.only(bottom: 5), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(icon, size: 17, color: Colors.green.shade700), const SizedBox(width: 8), Text('$label: ', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)), Expanded(child: Text(value, style: const TextStyle(fontSize: 12)))]));
  }

  Widget _buildOrderCard(Map<String, dynamic> order) {
    final firebaseKey = _text(order['firebaseKey']);
    final customerName = _text(order['customerName'] ?? order['name'] ?? order['customer'], 'Guest Customer');
    final customerPhone = _text(order['customerPhone'] ?? order['phone'] ?? order['mobile'], 'Phone नहीं दिया');
    final customerAddress = _text(order['customerAddress'] ?? order['deliveryAddress'] ?? order['address'], 'Address नहीं दिया');
    final grandTotal = _number(order['grandTotal'] ?? order['totalAmount'] ?? order['total'] ?? order['amount']);
    final status = _text(order['status'], 'Pending ⏳');
    final items = _getOrderItems(order);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(padding: const EdgeInsets.all(9), decoration: BoxDecoration(color: Colors.green.shade50, shape: BoxShape.circle), child: Icon(Icons.receipt_long, color: Colors.green.shade700)),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('🛒 नया ऑर्डर', style: TextStyle(color: Colors.green.shade800, fontSize: 16, fontWeight: FontWeight.bold)), const SizedBox(height: 3), Text('Order ID: $firebaseKey', style: const TextStyle(fontSize: 10, color: Colors.grey))])),
          PopupMenuButton<String>(onSelected: (value) { if (firebaseKey != '—') _updateStatus(firebaseKey, value); }, itemBuilder: (context) => const [PopupMenuItem(value: 'Accepted ✅', child: Text('Accept Order')), PopupMenuItem(value: 'Dispatched 🚚', child: Text('Dispatch Order')), PopupMenuItem(value: 'Delivered 🎉', child: Text('Delivered')), PopupMenuItem(value: 'Cancelled ❌', child: Text('Cancel Order'))]),
        ]),
        const Divider(height: 20),
        Text('👤 ग्राहक की जानकारी', style: TextStyle(color: Colors.green.shade800, fontWeight: FontWeight.bold, fontSize: 13)),
        const SizedBox(height: 7),
        _infoRow(Icons.person, 'नाम', customerName),
        _infoRow(Icons.phone, 'मोबाइल', customerPhone),
        _infoRow(Icons.location_on, 'डिलीवरी पता', customerAddress),
        const SizedBox(height: 10),
        Row(children: [Text('📦 ऑर्डर के आइटम', style: TextStyle(color: Colors.green.shade800, fontWeight: FontWeight.bold, fontSize: 14)), const Spacer(), if (items.isNotEmpty) Text('${items.length} Item${items.length == 1 ? '' : 's'}', style: const TextStyle(color: Colors.grey, fontSize: 11))]),
        const SizedBox(height: 8),
        if (items.isEmpty) Container(width: double.infinity, padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.orange.shade200)), child: const Row(children: [Icon(Icons.warning_amber, color: Colors.orange), SizedBox(width: 8), Expanded(child: Text('इस पुराने ऑर्डर में Product Items save नहीं हैं। नए orders में नाम, फोटो और quantity दिखाई जाएगी।', style: TextStyle(fontSize: 11)))])) else ...items.map((item) => _buildOrderItem(item)),
        const Divider(height: 20),
        Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('कुल राशि', style: TextStyle(color: Colors.grey, fontSize: 11)), const SizedBox(height: 2), Text('₹${grandTotal.toStringAsFixed(0)}', style: TextStyle(color: Colors.green.shade800, fontSize: 20, fontWeight: FontWeight.w900))])),
          Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7), decoration: BoxDecoration(color: status.toLowerCase().contains('cancel') ? Colors.red.shade50 : status.toLowerCase().contains('deliver') ? Colors.green.shade50 : Colors.orange.shade50, borderRadius: BorderRadius.circular(20)), child: Text(status, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: status.toLowerCase().contains('cancel') ? Colors.red.shade700 : status.toLowerCase().contains('deliver') ? Colors.green.shade700 : Colors.orange.shade800))),
        ]),
      ])),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Container(color: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), child: Row(children: [const Text('🛒 सभी ग्राहक ऑर्डर्स', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)), const Spacer(), IconButton(onPressed: isLoading ? null : _fetchOrders, icon: const Icon(Icons.refresh, color: Colors.green))])),
      Expanded(child: isLoading && allOrders.isEmpty ? const Center(child: CircularProgressIndicator()) : allOrders.isEmpty ? RefreshIndicator(onRefresh: _fetchOrders, child: ListView(children: const [SizedBox(height: 120), Center(child: Text('📭 अभी कोई ऑर्डर नहीं मिला', style: TextStyle(color: Colors.grey, fontSize: 14)))])) : RefreshIndicator(onRefresh: _fetchOrders, child: ListView.builder(padding: const EdgeInsets.only(top: 5, bottom: 20), itemCount: allOrders.length, itemBuilder: (context, index) => _buildOrderCard(allOrders[index])))),
    ]);
  }
}

class VendorSettingsTab extends StatelessWidget {
  const VendorSettingsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(padding: const EdgeInsets.all(16), children: [
      Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [Icon(Icons.store, color: Colors.green.shade700, size: 30), const SizedBox(width: 10), const Text('Vendor Settings', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))]),
        const SizedBox(height: 15),
        const Text('यहाँ से आपकी दुकान और Vendor Portal की settings manage की जा सकती हैं।', style: TextStyle(color: Colors.grey, fontSize: 13)),
      ]))),
      const SizedBox(height: 12),
      Card(child: ListTile(leading: const Icon(Icons.inventory_2, color: Colors.green), title: const Text('Product Management'), subtitle: const Text('Products tab से product add, stock और delete manage करें।'))),
      Card(child: ListTile(leading: const Icon(Icons.shopping_bag, color: Colors.blue), title: const Text('Order Management'), subtitle: const Text('Orders tab में customer orders और delivery status manage करें।'))),
      Card(child: ListTile(leading: const Icon(Icons.info_outline, color: Colors.orange), title: const Text('Viziag Mart Vendor Portal'), subtitle: const Text('Vendor account approval master admin द्वारा नियंत्रित है।'))),
    ]);
  }
}
