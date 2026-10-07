import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => CentralFaridabadEngine()),
      ],
      child: const CentralFaridabadApp(),
    ),
  );
}

class CentralFaridabadApp extends StatelessWidget {
  const CentralFaridabadApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Faridabad Central Fresh System',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFFF5000), // Meituan Orange
          primary: const Color(0xFFFF5000),
          secondary: const Color(0xFF2B8C00), // Fresh Green
          surface: const Color(0xFFF4F5F7),
        ),
        scaffoldBackgroundColor: const Color(0xFFF4F5F7),
      ),
      home: const MainSystemControllerHub(),
    );
  }
}

// ============================================================================
// 1. FIREBASE BACKEND ENGINE
// ============================================================================

class CentralFaridabadEngine extends ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  final String hubName = 'फरीदाबाद सेंट्रल हब';
  bool isBookingOpen = true;

  CentralFaridabadEngine() {
    _listenToCutoffStatus();
  }

  void _listenToCutoffStatus() {
    _db.collection('system_config').doc('mandi_status').snapshots().listen((snap) {
      if (snap.exists && snap.data() != null) {
        isBookingOpen = snap.data()!['isBookingOpen'] ?? true;
        notifyListeners();
      }
    });
  }

  // कट-ऑफ ऑन/ऑफ़ करना
  Future<void> setBookingStatus(bool status) async {
    await _db.collection('system_config').doc('mandi_status').set({
      'isBookingOpen': status,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // ग्राहक: ऑर्डर बनाना
  Future<void> createRealOrder({
    required String name,
    required String phone,
    required String areaSector,
    required String fullAddress,
    required String productId,
    required String productName,
    required String variantLabel,
    required double weightInKg,
    required double price,
    required int quantity,
  }) async {
    await _db.collection('orders').add({
      'customerName': name,
      'customerPhone': phone,
      'areaSector': areaSector,
      'fullAddress': fullAddress,
      'productId': productId,
      'productName': productName,
      'variantLabel': variantLabel,
      'weightInKg': weightInKg,
      'unitPrice': price,
      'quantity': quantity,
      'totalAmount': price * quantity,
      'status': 'PENDING',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // एडमिन: नया फल/सब्जी फोटो और रेट्स के साथ जोड़ना
  Future<void> addNewProduct({
    required String nameHindi,
    required String nameEnglish,
    required String category,
    required String imageUrl,
    required List<Map<String, dynamic>> variants,
  }) async {
    await _db.collection('products').add({
      'nameHindi': nameHindi,
      'nameEnglish': nameEnglish,
      'category': category,
      'imageUrl': imageUrl,
      'inStock': true,
      'variants': variants,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // स्टॉक कंट्रोल (In Stock / Out of Stock)
  Future<void> toggleProductStock(String productId, bool currentStatus) async {
    await _db.collection('products').doc(productId).update({
      'inStock': !currentStatus,
    });
  }

  // एडमिन: प्रोडक्ट रेट्स अपडेट करना
  Future<void> updateProductVariants(String productId, List<Map<String, dynamic>> variants) async {
    await _db.collection('products').doc(productId).update({
      'variants': variants,
    });
  }

  // डिलीवरी स्टेटस अपडेट
  Future<void> updateOrderStatus(String orderId, String newStatus) async {
    await _db.collection('orders').doc(orderId).update({
      'status': newStatus,
    });
  }
}

// ============================================================================
// 2. MAIN HUB CONTROLLER
// ============================================================================

class MainSystemControllerHub extends StatefulWidget {
  const MainSystemControllerHub({super.key});

  @override
  State<MainSystemControllerHub> createState() => _MainSystemControllerHubState();
}

class _MainSystemControllerHubState extends State<MainSystemControllerHub> {
  int _selectedTab = 0;

  final List<Widget> _screens = const [
    CustomerStorefrontModule(),
    FaridabadCentralHubModule(),
    MasterAdminControlModule(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_selectedTab],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedTab,
        selectedItemColor: const Color(0xFFFF5000),
        unselectedItemColor: Colors.grey.shade600,
        onTap: (index) => setState(() => _selectedTab = index),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.shopping_bag_outlined),
            activeIcon: Icon(Icons.shopping_bag),
            label: '1. ग्राहक ऐप',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.local_shipping_outlined),
            activeIcon: Icon(Icons.local_shipping),
            label: '2. फरीदाबाद हब',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.admin_panel_settings_outlined),
            activeIcon: Icon(Icons.admin_panel_settings),
            label: '3. एडमिन (कंट्रोल)',
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// MODULE 1: CUSTOMER STOREFRONT (विद प्रोडक्ट इमेज)
// ============================================================================

class CustomerStorefrontModule extends StatelessWidget {
  const CustomerStorefrontModule({super.key});

  @override
  Widget build(BuildContext context) {
    final engine = Provider.of<CentralFaridabadEngine>(context);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFFFF5000),
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('फरीदाबाद ताज़ा फल सप्लाई', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            Text('डायरेक्ट मंडी से आपके घर तक', style: TextStyle(color: Colors.white70, fontSize: 11)),
          ],
        ),
      ),
      body: Column(
        children: [
          // CUTOFF BANNER
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
            color: engine.isBookingOpen ? Colors.amber.shade100 : Colors.red.shade100,
            child: Row(
              children: [
                Icon(
                  engine.isBookingOpen ? Icons.access_time_filled : Icons.block,
                  color: engine.isBookingOpen ? Colors.amber.shade900 : Colors.red.shade900,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    engine.isBookingOpen
                        ? '⏰ आज का फरीदाबाद ग्रुप ऑर्डर चालू है!'
                        : '⛔ आज के ऑर्डर बंद हो चुके हैं। मंडी से गाड़ियां लोड हो रही हैं!',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: engine.isBookingOpen ? Colors.amber.shade900 : Colors.red.shade900,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // LIVE PRODUCTS
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('products').snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text('अभी कोई फल लिस्टेड नहीं है।\nAdmin टैब से नया फ्रूट ऐड करें।', textAlign: TextAlign.center));
                }

                final products = snapshot.data!.docs;

                return ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: products.length,
                  itemBuilder: (context, index) {
                    var doc = products[index];
                    var pData = doc.data() as Map<String, dynamic>;
                    bool inStock = pData['inStock'] ?? true;
                    List variants = pData['variants'] ?? [];
                    String imageUrl = pData['imageUrl'] ?? '';

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // PRODUCT IMAGE / PHOTO
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: imageUrl.isNotEmpty
                                  ? Image.network(
                                      imageUrl,
                                      width: 80,
                                      height: 80,
                                      fit: BoxFit.cover,
                                      errorBuilder: (ctx, err, stack) => _buildPlaceholderImage(),
                                    )
                                  : _buildPlaceholderImage(),
                            ),
                            const SizedBox(width: 12),

                            // DETAILS & VARIANTS
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(pData['nameHindi'] ?? '', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                      Chip(
                                        padding: EdgeInsets.zero,
                                        label: Text(inStock ? 'In Stock' : 'Out of Stock'),
                                        backgroundColor: inStock ? Colors.green.shade50 : Colors.red.shade50,
                                        labelStyle: TextStyle(
                                          color: inStock ? Colors.green : Colors.red,
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      )
                                    ],
                                  ),
                                  Text(pData['nameEnglish'] ?? '', style: const TextStyle(color: Colors.grey, fontSize: 11)),
                                  const SizedBox(height: 8),

                                  if (inStock) ...[
                                    Wrap(
                                      spacing: 6,
                                      runSpacing: 6,
                                      children: variants.map<Widget>((v) {
                                        return OutlinedButton(
                                          style: OutlinedButton.styleFrom(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            side: const BorderSide(color: Color(0xFFFF5000)),
                                            backgroundColor: const Color(0xFFFFF5F0),
                                          ),
                                          onPressed: engine.isBookingOpen
                                              ? () => _openCheckoutSheet(context, engine, doc.id, pData['nameHindi'], v)
                                              : null,
                                          child: Text(
                                            '${v['label']} - ₹${v['price']}',
                                            style: const TextStyle(color: Color(0xFFFF5000), fontSize: 11, fontWeight: FontWeight.bold),
                                          ),
                                        );
                                      }).toList(),
                                    )
                                  ] else
                                    const Text('आज मंडी में समाप्त', style: TextStyle(color: Colors.red, fontSize: 11, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            )
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          )
        ],
      ),
    );
  }

  Widget _buildPlaceholderImage() {
    return Container(
      width: 80,
      height: 80,
      color: Colors.orange.shade50,
      child: const Icon(Icons.fastfood, color: Color(0xFFFF5000), size: 36),
    );
  }

  void _openCheckoutSheet(BuildContext context, CentralFaridabadEngine engine, String productId, String productName, Map vData) {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final sectorCtrl = TextEditingController();
    final addressCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom + 20, top: 20, left: 20, right: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('ऑर्डर फॉर्म', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const Divider(),
            Text('सामान: $productName (${vData['label']})', style: const TextStyle(fontWeight: FontWeight.bold)),
            Text('कीमत: ₹${vData['price']}', style: const TextStyle(color: Color(0xFFFF5000), fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),

            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'आपका नाम', border: OutlineInputBorder())),
            const SizedBox(height: 8),
            TextField(controller: phoneCtrl, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'मोबाइल नंबर', border: OutlineInputBorder())),
            const SizedBox(height: 8),
            TextField(controller: sectorCtrl, decoration: const InputDecoration(labelText: 'सेक्टर / इलाका (उदा. सेक्टर 15)', border: OutlineInputBorder())),
            const SizedBox(height: 8),
            TextField(controller: addressCtrl, decoration: const InputDecoration(labelText: 'मकान / फ्लैट नंबर', border: OutlineInputBorder())),
            const SizedBox(height: 15),

            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF5000)),
                onPressed: () async {
                  if (nameCtrl.text.isNotEmpty && phoneCtrl.text.isNotEmpty) {
                    await engine.createRealOrder(
                      name: nameCtrl.text,
                      phone: phoneCtrl.text,
                      areaSector: sectorCtrl.text,
                      fullAddress: addressCtrl.text,
                      productId: productId,
                      productName: productName,
                      variantLabel: vData['label'],
                      weightInKg: (vData['weightInKg'] as num).toDouble(),
                      price: (vData['price'] as num).toDouble(),
                      quantity: 1,
                    );
                    if (context.mounted) {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('✅ आपका ऑर्डर सेंट्रल हब में बुक हो गया है!')),
                      );
                    }
                  }
                },
                child: const Text('ऑर्डर कंफर्म करें', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            )
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// MODULE 2: CENTRAL FARIDABAD HUB (Aggregator Counter + Dispatch)
// ============================================================================

class FaridabadCentralHubModule extends StatelessWidget {
  const FaridabadCentralHubModule({super.key});

  @override
  Widget build(BuildContext context) {
    final engine = Provider.of<CentralFaridabadEngine>(context);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: const Color(0xFF2B8C00),
          title: Text(engine.hubName, style: const TextStyle(color: Colors.white)),
          bottom: const TabBar(
            indicatorColor: Colors.amber,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            tabs: [
              Tab(icon: Icon(Icons.shopping_cart), text: '1. मंडी कुल खरीद (Aggregator)'),
              Tab(icon: Icon(Icons.local_shipping), text: '2. गाड़ी डिलीवरी लिस्ट'),
            ],
          ),
        ),
        body: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('orders').snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return const Center(child: Text('अभी कोई ऑर्डर नहीं आया है।'));
            }

            final orders = snapshot.data!.docs;

            Map<String, Map<String, dynamic>> mandiSummary = {};

            for (var doc in orders) {
              var data = doc.data() as Map<String, dynamic>;
              if (data['status'] == 'CANCELLED') continue;

              String itemKey = "${data['productName']} - [${data['variantLabel']}]";
              int qty = (data['quantity'] as num).toInt();
              double totalKg = ((data['weightInKg'] as num).toDouble()) * qty;

              if (!mandiSummary.containsKey(itemKey)) {
                mandiSummary[itemKey] = {'totalPkts': 0, 'totalKg': 0.0};
              }

              mandiSummary[itemKey]!['totalPkts'] = mandiSummary[itemKey]!['totalPkts'] + qty;
              mandiSummary[itemKey]!['totalKg'] = mandiSummary[itemKey]!['totalKg'] + totalKg;
            }

            return TabBarView(
              children: [
                // TAB 1: MANDI AGGREGATED SUMMARY
                ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: mandiSummary.length,
                  itemBuilder: (context, index) {
                    String key = mandiSummary.keys.elementAt(index);
                    var summary = mandiSummary[key]!;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: const Color(0xFF2B8C00),
                          child: Text('${index + 1}', style: const TextStyle(color: Colors.white)),
                        ),
                        title: Text(key, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('कुल वजन: ${summary['totalKg']} Kg'),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(color: Colors.green.shade100, borderRadius: BorderRadius.circular(20)),
                          child: Text(
                            '${summary['totalPkts']} पैकेट',
                            style: const TextStyle(color: Color(0xFF2B8C00), fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    );
                  },
                ),

                // TAB 2: DELIVERY DISPATCH LIST
                ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: orders.length,
                  itemBuilder: (context, index) {
                    var doc = orders[index];
                    var oData = doc.data() as Map<String, dynamic>;
                    bool isDelivered = oData['status'] == 'DELIVERED';

                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: ListTile(
                        title: Text('${oData['customerName']} (${oData['areaSector']})', style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('पता: ${oData['fullAddress']}\nसामान: ${oData['productName']} (${oData['variantLabel']})\n📞 ${oData['customerPhone']} | ₹${oData['totalAmount']}'),
                        trailing: Checkbox(
                          activeColor: const Color(0xFF2B8C00),
                          value: isDelivered,
                          onChanged: (bool? val) {
                            engine.updateOrderStatus(doc.id, val == true ? 'DELIVERED' : 'PENDING');
                          },
                        ),
                      ),
                    );
                  },
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ============================================================================
// MODULE 3: MASTER ADMIN CONTROL (प्रोडक्ट फोटो, रेट्स और स्टॉक मैनेजमेंट)
// ============================================================================

class MasterAdminControlModule extends StatelessWidget {
  const MasterAdminControlModule({super.key});

  @override
  Widget build(BuildContext context) {
    final engine = Provider.of<CentralFaridabadEngine>(context);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('मालिक (Admin Master Control)', style: TextStyle(color: Colors.white)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 1. CUTOFF SWITCH
          const Text('1. फरीदाबाद कट-ऑफ कंट्रोल', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Card(
            color: engine.isBookingOpen ? Colors.green.shade50 : Colors.red.shade50,
            child: SwitchListTile(
              activeColor: Colors.green,
              title: const Text('ग्लोबल ऑर्डर स्विच', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(engine.isBookingOpen ? 'ऑर्डर चालू हैं (Live)' : 'ऑर्डर बंद हैं (मंडी मोड)'),
              value: engine.isBookingOpen,
              onChanged: (val) => engine.setBookingStatus(val),
            ),
          ),
          const SizedBox(height: 25),

          // 2. PRODUCT & CATALOG MANAGEMENT
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('2. प्रोडक्ट, फोटो और स्टॉक मैनेजर', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF5000), foregroundColor: Colors.white),
                onPressed: () => _openAddProductDialog(context, engine),
                icon: const Icon(Icons.add_a_photo),
                label: const Text('नया फल जोड़ें'),
              )
            ],
          ),
          const SizedBox(height: 10),

          // PRODUCT LIST
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('products').snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const LinearProgressIndicator();
              final products = snapshot.data!.docs;

              return Column(
                children: products.map((doc) {
                  var pData = doc.data() as Map<String, dynamic>;
                  bool inStock = pData['inStock'] ?? true;
                  String imageUrl = pData['imageUrl'] ?? '';
                  List variants = pData['variants'] ?? [];

                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Row(
                        children: [
                          // THUMBNAIL PHOTO
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: imageUrl.isNotEmpty
                                ? Image.network(imageUrl, width: 50, height: 50, fit: BoxFit.cover, errorBuilder: (c, e, s) => _smallPlaceholder())
                                : _smallPlaceholder(),
                          ),
                          const SizedBox(width: 10),

                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(pData['nameHindi'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                Text('${pData['nameEnglish']} | ${variants.length} रेट पैक', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                              ],
                            ),
                          ),

                          // IN-STOCK SWITCH
                          Column(
                            children: [
                              const Text('Stock', style: TextStyle(fontSize: 10)),
                              Switch(
                                value: inStock,
                                activeColor: Colors.green,
                                onChanged: (val) => engine.toggleProductStock(doc.id, inStock),
                              ),
                            ],
                          ),

                          // DELETE BUTTON
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.red),
                            onPressed: () => FirebaseFirestore.instance.collection('products').doc(doc.id).delete(),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          )
        ],
      ),
    );
  }

  Widget _smallPlaceholder() {
    return Container(
      width: 50,
      height: 50,
      color: Colors.grey.shade200,
      child: const Icon(Icons.image, color: Colors.grey),
    );
  }

  // DIALOG: फोटो और रेट्स के साथ नया फल जोड़ने का फॉर्म
  void _openAddProductDialog(BuildContext context, CentralFaridabadEngine engine) {
    final hindiCtrl = TextEditingController();
    final engCtrl = TextEditingController();
    final imageCtrl = TextEditingController();

    final p1Price = TextEditingController(text: '80');
    final p3Price = TextEditingController(text: '230');
    final p5Price = TextEditingController(text: '370');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('नया फल व फोटो जोड़ें'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: hindiCtrl, decoration: const InputDecoration(labelText: 'हिंदी नाम (उदा. चौसा आम)', border: OutlineInputBorder())),
              const SizedBox(height: 8),
              TextField(controller: engCtrl, decoration: const InputDecoration(labelText: 'अंग्रेजी नाम (उदा. Chausa Mango)', border: OutlineInputBorder())),
              const SizedBox(height: 8),
              TextField(
                controller: imageCtrl,
                decoration: const InputDecoration(
                  labelText: 'फोटो लिंक (Image URL)',
                  hintText: 'https://example.com/mango.jpg',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              const Align(alignment: Alignment.centerLeft, child: Text('रेट्स सेट करें (₹):', style: TextStyle(fontWeight: FontWeight.bold))),
              const SizedBox(height: 8),
              TextField(controller: p1Price, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: '1 Kg का रेट (₹)', border: OutlineInputBorder())),
              const SizedBox(height: 8),
              TextField(controller: p3Price, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: '3 Kg (फैमिली) का रेट (₹)', border: OutlineInputBorder())),
              const SizedBox(height: 8),
              TextField(controller: p5Price, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: '5 Kg (पेटी) का रेट (₹)', border: OutlineInputBorder())),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('रद्द करें')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF5000)),
            onPressed: () async {
              if (hindiCtrl.text.isNotEmpty) {
                await engine.addNewProduct(
                  nameHindi: hindiCtrl.text.trim(),
                  nameEnglish: engCtrl.text.trim(),
                  category: 'ताजे फल',
                  imageUrl: imageCtrl.text.trim(),
                  variants: [
                    {'label': '1 Kg', 'weightInKg': 1.0, 'price': double.tryParse(p1Price.text) ?? 80.0},
                    {'label': '3 Kg (फैमिली pack)', 'weightInKg': 3.0, 'price': double.tryParse(p3Price.text) ?? 230.0},
                    {'label': '5 Kg (पूरी पेटी)', 'weightInKg': 5.0, 'price': double.tryParse(p5Price.text) ?? 370.0},
                  ],
                );
                if (context.mounted) Navigator.pop(ctx);
              }
            },
            child: const Text('सेव करें', style: TextStyle(color: Colors.white)),
          )
        ],
      ),
    );
  }
}
