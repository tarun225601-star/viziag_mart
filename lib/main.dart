import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

void main() {
  runApp(const ViziaGMartApp());
}

class ViziaGMartApp extends StatelessWidget {
  const ViziaGMartApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Vizia G-Mart - Fresh Direct Mandi',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF22C55E), // Fresh Green
          secondary: Color(0xFFF59E0B), // Golden Amber
          surface: Color(0xFF1E293B),
          background: Color(0xFF0F172A),
        ),
        scaffoldBackgroundColor: const Color(0xFF0F172A),
        cardColor: const Color(0xFF1E293B),
      ),
      home: const MainHubScreen(),
    );
  }
}

// ==========================================
// CENTRAL DATABASE & PRODUCT INVENTORY MODEL
// ==========================================
class ViziaDatabase {
  static String firebaseRestUrl = "https://viziagmart-default-rtdb.firebaseio.com/";

  static String currentUserPhone = "9971968060";
  static String currentCustomerName = "Tarun Kumar";
  static String currentDeliveryAddress = "Sector 15A Faridabad";
  static String selectedSociety = "Sector 15A Society, Faridabad";

  // मास्टर शॉप प्रोफाइल
  static Map<String, dynamic> shopProfile = {
    'shopId': 'vizia_faridabad_01',
    'shopName': 'Vizia G-Mart (विज़िया जी-मार्ट)',
    'ownerName': 'Tarun Kumar',
    'ownerPhone': '9971968060',
    'address': 'Sector 15A Mandi, Faridabad',
    'isOpen': true,
  };

  // संपूर्ण सब्जियां और फल मास्टर इन्वेंट्री (100g से 10kg तक का सपोर्ट)
  static List<Map<String, dynamic>> productInventory = [
    // --- सब्जियां (VEGETABLES) ---
    {'id': 'v1', 'name': 'आलू (Potato)', 'icon': '🥔', 'category': 'Vegetable', 'mandiPrice': 10.0, 'margin': 5.0, 'unit': 'kg', 'inStock': true, 'tier': 'basic'},
    {'id': 'v2', 'name': 'प्याज़ (Onion)', 'icon': '🧅', 'category': 'Vegetable', 'mandiPrice': 17.0, 'margin': 5.0, 'unit': 'kg', 'inStock': true, 'tier': 'basic'},
    {'id': 'v3', 'name': 'टमाटर (Tomato)', 'icon': '🍅', 'category': 'Vegetable', 'mandiPrice': 20.0, 'margin': 5.0, 'unit': 'kg', 'inStock': true, 'tier': 'basic'},
    {'id': 'v4', 'name': 'हरी मिर्च (Green Chilli)', 'icon': '🌶️', 'category': 'Vegetable', 'mandiPrice': 40.0, 'margin': 5.0, 'unit': 'kg', 'inStock': true, 'tier': 'basic'},
    {'id': 'v5', 'name': 'अदरक (Ginger)', 'icon': '🫚', 'category': 'Vegetable', 'mandiPrice': 80.0, 'margin': 10.0, 'unit': 'kg', 'inStock': true, 'tier': 'premium'},
    {'id': 'v6', 'name': 'लहसुन (Garlic)', 'icon': '🧄', 'category': 'Vegetable', 'mandiPrice': 120.0, 'margin': 10.0, 'unit': 'kg', 'inStock': true, 'tier': 'premium'},
    {'id': 'v7', 'name': 'धनिया (Coriander)', 'icon': '🌿', 'category': 'Vegetable', 'mandiPrice': 30.0, 'margin': 5.0, 'unit': 'kg', 'inStock': true, 'tier': 'basic'},
    {'id': 'v8', 'name': 'गोभी (Cauliflower)', 'icon': '🥦', 'category': 'Vegetable', 'mandiPrice': 25.0, 'margin': 5.0, 'unit': 'kg', 'inStock': true, 'tier': 'basic'},
    {'id': 'v9', 'name': 'पत्तागोभी (Cabbage)', 'icon': '🥬', 'category': 'Vegetable', 'mandiPrice': 15.0, 'margin': 5.0, 'unit': 'kg', 'inStock': true, 'tier': 'basic'},
    {'id': 'v10', 'name': 'बैंगन (Brinjal)', 'icon': '🍆', 'category': 'Vegetable', 'mandiPrice': 20.0, 'margin': 5.0, 'unit': 'kg', 'inStock': true, 'tier': 'basic'},
    {'id': 'v11', 'name': 'भिंडी (Lady Finger)', 'icon': '🫛', 'category': 'Vegetable', 'mandiPrice': 30.0, 'margin': 5.0, 'unit': 'kg', 'inStock': true, 'tier': 'basic'},
    {'id': 'v12', 'name': 'लौकी (Bottle Gourd)', 'icon': '🥒', 'category': 'Vegetable', 'mandiPrice': 15.0, 'margin': 5.0, 'unit': 'kg', 'inStock': true, 'tier': 'basic'},
    {'id': 'v13', 'name': 'गाजर (Carrot)', 'icon': '🥕', 'category': 'Vegetable', 'mandiPrice': 25.0, 'margin': 5.0, 'unit': 'kg', 'inStock': true, 'tier': 'basic'},
    {'id': 'v14', 'name': 'मूली (Radish)', 'icon': '🥗', 'category': 'Vegetable', 'mandiPrice': 15.0, 'margin': 5.0, 'unit': 'kg', 'inStock': true, 'tier': 'basic'},
    {'id': 'v15', 'name': 'पालक (Spinach)', 'icon': '🥬', 'category': 'Vegetable', 'mandiPrice': 20.0, 'margin': 5.0, 'unit': 'kg', 'inStock': true, 'tier': 'basic'},
    {'id': 'v16', 'name': 'शिमला मिर्च (Capsicum)', 'icon': '🫑', 'category': 'Vegetable', 'mandiPrice': 35.0, 'margin': 5.0, 'unit': 'kg', 'inStock': true, 'tier': 'basic'},
    {'id': 'v17', 'name': 'मटर (Green Peas)', 'icon': '🫛', 'category': 'Vegetable', 'mandiPrice': 50.0, 'margin': 5.0, 'unit': 'kg', 'inStock': true, 'tier': 'basic'},
    {'id': 'v18', 'name': 'खीरा (Cucumber)', 'icon': '🥒', 'category': 'Vegetable', 'mandiPrice': 20.0, 'margin': 5.0, 'unit': 'kg', 'inStock': true, 'tier': 'basic'},
    {'id': 'v19', 'name': 'कद्दू (Pumpkin)', 'icon': '🎃', 'category': 'Vegetable', 'mandiPrice': 15.0, 'margin': 5.0, 'unit': 'kg', 'inStock': true, 'tier': 'basic'},
    {'id': 'v20', 'name': 'मशरूम (Mushroom)', 'icon': '🍄', 'category': 'Vegetable', 'mandiPrice': 40.0, 'margin': 10.0, 'unit': 'pack', 'inStock': true, 'tier': 'premium'},

    // --- फल (FRUITS) ---
    {'id': 'f1', 'name': 'ताज़ा आम (Mango - Chaunsa/Dashahari)', 'icon': '🥭', 'category': 'Fruit', 'mandiPrice': 40.0, 'margin': 10.0, 'unit': 'kg', 'inStock': true, 'tier': 'premium'},
    {'id': 'f2', 'name': 'सेब (Apple - Shimla/Kashmir)', 'icon': '🍎', 'category': 'Fruit', 'mandiPrice': 90.0, 'margin': 10.0, 'unit': 'kg', 'inStock': true, 'tier': 'premium'},
    {'id': 'f3', 'name': 'केला (Banana - Fresh)', 'icon': '🍌', 'category': 'Fruit', 'mandiPrice': 30.0, 'margin': 5.0, 'unit': 'dozen', 'inStock': true, 'tier': 'basic'},
    {'id': 'f4', 'name': 'अनार (Pomegranate)', 'icon': '🥠', 'category': 'Fruit', 'mandiPrice': 110.0, 'margin': 10.0, 'unit': 'kg', 'inStock': true, 'tier': 'premium'},
    {'id': 'f5', 'name': 'संतरा / मौसमी (Orange/Mosambi)', 'icon': '🍊', 'category': 'Fruit', 'mandiPrice': 45.0, 'margin': 10.0, 'unit': 'kg', 'inStock': true, 'tier': 'premium'},
    {'id': 'f6', 'name': 'पपीता (Papaya)', 'icon': '🍈', 'category': 'Fruit', 'mandiPrice': 25.0, 'margin': 5.0, 'unit': 'kg', 'inStock': true, 'tier': 'basic'},
    {'id': 'f7', 'name': 'अंगूर (Grapes)', 'icon': '🍇', 'category': 'Fruit', 'mandiPrice': 60.0, 'margin': 10.0, 'unit': 'kg', 'inStock': true, 'tier': 'premium'},
    {'id': 'f8', 'name': 'तरबूज (Watermelon)', 'icon': '🍉', 'category': 'Fruit', 'mandiPrice': 15.0, 'margin': 5.0, 'unit': 'kg', 'inStock': true, 'tier': 'basic'},
    {'id': 'f9', 'name': 'खरबूजा (Muskmelon)', 'icon': '🍈', 'category': 'Fruit', 'mandiPrice': 20.0, 'margin': 5.0, 'unit': 'kg', 'inStock': true, 'tier': 'basic'},
    {'id': 'f10', 'name': 'अमरूद (Guava)', 'icon': '🍏', 'category': 'Fruit', 'mandiPrice': 35.0, 'margin': 5.0, 'unit': 'kg', 'inStock': true, 'tier': 'basic'},
    {'id': 'f11', 'name': 'चीकू (Chiku)', 'icon': '🥔', 'category': 'Fruit', 'mandiPrice': 40.0, 'margin': 10.0, 'unit': 'kg', 'inStock': true, 'tier': 'premium'},
    {'id': 'f12', 'name': 'किवी (Kiwi Packet)', 'icon': '🥝', 'category': 'Fruit', 'mandiPrice': 70.0, 'margin': 10.0, 'unit': 'pack', 'inStock': true, 'tier': 'premium'},
    {'id': 'f13', 'name': 'नारियल पानी (Green Coconut)', 'icon': '🥥', 'category': 'Fruit', 'mandiPrice': 35.0, 'margin': 10.0, 'unit': 'piece', 'inStock': true, 'tier': 'premium'},
    {'id': 'f14', 'name': 'आड़ू / आलूबुखारा (Peach/Plum)', 'icon': '🍑', 'category': 'Fruit', 'mandiPrice': 80.0, 'margin': 10.0, 'unit': 'kg', 'inStock': true, 'tier': 'premium'},
  ];

  static List<Map<String, dynamic>> cartItems = [];
}

// ==========================================
// MAIN HUB SCREEN WITH BOTTOM NAVIGATION
// ==========================================
class MainHubScreen extends StatefulWidget {
  const MainHubScreen({super.key});

  @override
  State<MainHubScreen> createState() => _MainHubScreenState();
}

class _MainHubScreenState extends State<MainHubScreen> {
  int _selectedTabIndex = 0;

  final List<Widget> _tabScreens = [
    const CustomerShopView(),
    const AdminStockManagerView(),
    const GLeaderPortalView(),
    const CartAndCheckoutView(),
  ];

  @override
  Widget build(BuildContext context) {
    double totalCartQty = ViziaDatabase.cartItems.fold(0.0, (sum, item) => sum + (item['qty'] as double));

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B0F19),
        elevation: 3,
        title: Row(
          children: [
            const Text(
              'VIZIA G-MART',
              style: TextStyle(color: Color(0xFF22C55E), fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: 1.2),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: const Color(0xFFF59E0B), borderRadius: BorderRadius.circular(4)),
              child: const Text('Mandi Rates', style: TextStyle(color: Colors.black, fontSize: 9, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(28),
          child: Container(
            color: const Color(0xFF1E293B),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Row(
              children: [
                const Icon(Icons.location_on, color: Color(0xFF22C55E), size: 14),
                const SizedBox(width: 4),
                Text(
                  'Delivering to: ${ViziaDatabase.currentDeliveryAddress}',
                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                ),
                const Spacer(),
                const Text('Pay on Delivery', style: TextStyle(color: Color(0xFFF59E0B), fontSize: 10, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ),
      ),
      body: IndexedStack(
        index: _selectedTabIndex,
        children: _tabScreens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedTabIndex,
        selectedItemColor: const Color(0xFF22C55E),
        unselectedItemColor: Colors.grey.shade400,
        backgroundColor: const Color(0xFF0B0F19),
        type: BottomNavigationBarType.fixed,
        onTap: (index) => setState(() => _selectedTabIndex = index),
        items: [
          const BottomNavigationBarItem(icon: Icon(Icons.shopping_basket_outlined), label: 'Shop'),
          const BottomNavigationBarItem(icon: Icon(Icons.admin_panel_settings_outlined), label: 'Admin'),
          const BottomNavigationBarItem(icon: Icon(Icons.groups_outlined), label: 'G-Leader'),
          BottomNavigationBarItem(
            icon: Stack(
              children: [
                const Icon(Icons.shopping_cart_outlined),
                if (totalCartQty > 0)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                      constraints: const BoxConstraints(minWidth: 14, minHeight: 14),
                      child: Text(
                        totalCartQty.toStringAsFixed(1),
                        style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
            label: 'Cart',
          ),
        ],
      ),
    );
  }
}

// ==========================================
// 1. CUSTOMER SHOP VIEW (SABJI & FRUITS)
// ==========================================
class CustomerShopView extends StatefulWidget {
  const CustomerShopView({super.key});

  @override
  State<CustomerShopView> createState() => _CustomerShopViewState();
}

class _CustomerShopViewState extends State<CustomerShopView> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  void _updateCartQuantity(Map<String, dynamic> prod, double change) {
    if (!prod['inStock']) return;

    String id = prod['id'];
    var existingIndex = ViziaDatabase.cartItems.indexWhere((item) => item['id'] == id);

    setState(() {
      double currentQty = existingIndex >= 0 ? ViziaDatabase.cartItems[existingIndex]['qty'] : 0.0;
      double newQty = currentQty + change;

      // 0.1 kg (100 gram) से कम होने पर हटा दें, और 10 kg से ज़्यादा न होने दें
      if (newQty < 0.09) {
        if (existingIndex >= 0) ViziaDatabase.cartItems.removeAt(existingIndex);
      } else if (newQty <= 10.0) {
        double finalPrice = prod['mandiPrice'] + prod['margin'];
        if (existingIndex >= 0) {
          ViziaDatabase.cartItems[existingIndex]['qty'] = double.parse(newQty.toStringAsFixed(1));
        } else {
          ViziaDatabase.cartItems.add({
            'id': id,
            'name': prod['name'],
            'icon': prod['icon'],
            'price': finalPrice,
            'unit': prod['unit'],
            'qty': double.parse(newQty.toStringAsFixed(1)),
          });
        }
      }
    });
  }

  double _getItemQtyInCart(String id) {
    var item = ViziaDatabase.cartItems.firstWhere((element) => element['id'] == id, orElse: () => {});
    return item.isNotEmpty ? (item['qty'] as double) : 0.0;
  }

  @override
  Widget build(BuildContext context) {
    var vegList = ViziaDatabase.productInventory.where((p) => p['category'] == 'Vegetable').toList();
    var fruitList = ViziaDatabase.productInventory.where((p) => p['category'] == 'Fruit').toList();

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          // कैटेगरी टैब्स (सब्जियां vs फल)
          Container(
            color: const Color(0xFF1E293B),
            child: TabBar(
              controller: _tabController,
              indicatorColor: const Color(0xFF22C55E),
              labelColor: const Color(0xFF22C55E),
              unselectedLabelColor: Colors.grey,
              tabs: const [
                Tab(icon: Icon(Icons.eco), text: '🥦 ताज़ा सब्जियाँ'),
                Tab(icon: Icon(Icons.apple), text: '🍎 ताज़ा फल (Fruits)'),
              ],
            ),
          ),

          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildProductGrid(vegList),
                _buildProductGrid(fruitList),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductGrid(List<Map<String, dynamic>> products) {
    return ListView.builder(
      padding: const EdgeInsets.all(10),
      itemCount: products.length,
      itemBuilder: (context, index) {
        final item = products[index];
        bool inStock = item['inStock'];
        double finalPrice = item['mandiPrice'] + item['margin'];
        double marketRateEstimate = finalPrice * 1.8; // मार्केट रेट तुलना
        double currentQty = _getItemQtyInCart(item['id']);

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: inStock ? const Color(0xFF1E293B) : Colors.grey.shade900.withOpacity(0.5),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: inStock ? Colors.grey.shade800 : Colors.red.shade900),
          ),
          child: Row(
            children: [
              // Emoji / Thumbnail
              Container(
                width: 50,
                height: 50,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(8)),
                child: Text(item['icon'], style: const TextStyle(fontSize: 28)),
              ),
              const SizedBox(width: 12),

              // Name & Pricing
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item['name'],
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: inStock ? Colors.white : Colors.grey,
                        decoration: inStock ? null : TextDecoration.lineThrough,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text('₹${finalPrice.toStringAsFixed(0)}/${item['unit']}',
                            style: TextStyle(color: inStock ? const Color(0xFF22C55E) : Colors.grey, fontWeight: FontWeight.bold, fontSize: 14)),
                        const SizedBox(width: 8),
                        Text(
                          'मार्केट: ₹${marketRateEstimate.toStringAsFixed(0)}',
                          style: const TextStyle(color: Colors.grey, fontSize: 10, decoration: TextDecoration.lineThrough),
                        ),
                      ],
                    ),
                    if (!inStock)
                      const Text('❌ आज उपलब्ध नहीं है (Out of Stock)', style: TextStyle(color: Colors.redAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),

              // Quantity Selector (+ / - Buttons for 100g to 10kg)
              if (inStock)
                Container(
                  decoration: BoxDecoration(color: Colors.black38, borderRadius: BorderRadius.circular(8)),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.remove, color: Colors.redAccent, size: 18),
                        onPressed: () => _updateCartQuantity(item, -0.1), // -100 ग्राम
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: Column(
                          children: [
                            Text(
                              currentQty > 0 ? '${currentQty.toStringAsFixed(1)} ${item['unit']}' : '0',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                            const Text('100g step', style: TextStyle(color: Colors.grey, fontSize: 8)),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add, color: Color(0xFF22C55E), size: 18),
                        onPressed: () => _updateCartQuantity(item, 0.1), // +100 ग्राम
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

// ==========================================
// 2. ADMIN STOCK MANAGER VIEW (TOGGLE IN/OUT OF STOCK)
// ==========================================
class AdminStockManagerView extends StatefulWidget {
  const AdminStockManagerView({super.key});

  @override
  State<AdminStockManagerView> createState() => _AdminStockManagerViewState();
}

class _AdminStockManagerViewState extends State<AdminStockManagerView> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(10)),
            child: Row(
              children: [
                const Icon(Icons.edit_note, color: Color(0xFFF59E0B)),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text('मंडी रेट व स्टॉक ऑन/ऑफ मैनेजर', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF22C55E), foregroundColor: Colors.black),
                  onPressed: () => setState(() {}),
                  child: const Text('Save Changes', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                )
              ],
            ),
          ),
          const SizedBox(height: 10),

          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: ViziaDatabase.productInventory.length,
            itemBuilder: (context, index) {
              final item = ViziaDatabase.productInventory[index];
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: item['inStock'] ? Colors.transparent : Colors.red.shade800),
                ),
                child: Row(
                  children: [
                    Text(item['icon'], style: const TextStyle(fontSize: 22)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(item['name'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                          Text(
                            'मंडी रेट: ₹${item['mandiPrice']} | मार्जिन: +₹${item['margin']} = VIP: ₹${item['mandiPrice'] + item['margin']}',
                            style: const TextStyle(color: Colors.grey, fontSize: 10),
                          ),
                        ],
                      ),
                    ),
                    Row(
                      children: [
                        Text(
                          item['inStock'] ? 'In Stock' : 'Out',
                          style: TextStyle(
                            color: item['inStock'] ? const Color(0xFF22C55E) : Colors.redAccent,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Switch(
                          value: item['inStock'],
                          activeColor: const Color(0xFF22C55E),
                          inactiveThumbColor: Colors.redAccent,
                          onChanged: (val) {
                            setState(() {
                              item['inStock'] = val;
                            });
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

// ==========================================
// 3. G-LEADER COMMUNITY HUB VIEW
// ==========================================
class GLeaderPortalView extends StatelessWidget {
  const GLeaderPortalView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF1E293B), Color(0xFF0F172A)]),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFF59E0B)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('🤝 G-Leader Community Dashboard', style: TextStyle(color: Color(0xFFF59E0B), fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 4),
                Text('सोसाइटी: ${ViziaDatabase.selectedSociety}', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                const Divider(color: Colors.grey),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: const [
                    _StatBox(title: "आज का ऑर्डर", value: "140 kg"),
                    _StatBox(title: "कुल घर", value: "38 Families"),
                    _StatBox(title: "कमीशन कमाई", value: "₹280"),
                  ],
                )
              ],
            ),
          ),
          const SizedBox(height: 14),

          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF25D366), // WhatsApp Green
              foregroundColor: Colors.white,
              padding: const EdgeInsets.all(12),
            ),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('📲 सोसाइटी व्हाट्सएप ग्रुप में रेट लिस्ट शेयर हो गई!')));
            },
            icon: const Icon(Icons.share),
            label: const Text('सोसाइटी WhatsApp ग्रुप में आज के रेट शेयर करें', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

class _StatBox extends StatelessWidget {
  final String title;
  final String value;
  const _StatBox({required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(title, style: const TextStyle(color: Colors.grey, fontSize: 10)),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
      ],
    );
  }
}

// ==========================================
// 4. CART & PAY ON DELIVERY CHECKOUT VIEW
// ==========================================
class CartAndCheckoutView extends StatefulWidget {
  const CartAndCheckoutView({super.key});

  @override
  State<CartAndCheckoutView> createState() => _CartAndCheckoutViewState();
}

class _CartAndCheckoutViewState extends State<CartAndCheckoutView> {
  @override
  Widget build(BuildContext context) {
    var cart = ViziaDatabase.cartItems;
    double totalBill = cart.fold(0.0, (sum, item) => sum + ((item['price'] as double) * (item['qty'] as double)));
    double estimatedSavings = totalBill * 0.8; // बचत का अनुमान

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: cart.isEmpty
          ? const Center(child: Text('🛒 आपकी कार्ट खाली है! कुछ सब्जियाँ या फल जोड़ें।', style: TextStyle(color: Colors.grey)))
          : Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: cart.length,
                    itemBuilder: (context, index) {
                      final item = cart[index];
                      double itemTotal = (item['price'] as double) * (item['qty'] as double);

                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(8)),
                        child: Row(
                          children: [
                            Text(item['icon'], style: const TextStyle(fontSize: 22)),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(item['name'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                  Text('₹${item['price']}/${item['unit']} × ${item['qty']} ${item['unit']}', style: const TextStyle(color: Colors.grey, fontSize: 11)),
                                ],
                              ),
                            ),
                            Text('₹${itemTotal.toStringAsFixed(0)}', style: const TextStyle(color: Color(0xFF22C55E), fontWeight: FontWeight.bold, fontSize: 15)),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                              onPressed: () {
                                setState(() {
                                  cart.removeAt(index);
                                });
                              },
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),

                // Bill Summary Card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(
                    color: Color(0xFF1E293B),
                    borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('कुल बिल (VIP Mandi Rate):', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                          Text('₹${totalBill.toStringAsFixed(0)}', style: const TextStyle(color: Color(0xFF22C55E), fontSize: 18, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('🎉 आपकी आज की अनुमानित बचत:', style: TextStyle(color: Color(0xFFF59E0B), fontSize: 12)),
                          Text('₹${estimatedSavings.toStringAsFixed(0)}', style: const TextStyle(color: Color(0xFFF59E0B), fontSize: 12, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const Divider(color: Colors.grey),
                      const Text('💳 भुगतान का तरीका: Pay on Delivery (Cash / UPI on Delivery)', style: TextStyle(color: Colors.white70, fontSize: 11)),
                      const SizedBox(height: 10),

                      SizedBox(
                        width: double.infinity,
                        height: 45,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF22C55E),
                            foregroundColor: Colors.black,
                          ),
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Text('🎉 ऑर्डर कन्फर्म हो गया!'),
                                content: const Text('आपका ऑर्डर ले लिया गया है। कल सुबह G-Leader आपके घर पर ताज़ा माल पहुँचाकर भुगतान (Cash/UPI) ले लेगा।'),
                                actions: [
                                  TextButton(
                                    onPressed: () {
                                      setState(() {
                                        ViziaDatabase.cartItems.clear();
                                      });
                                      Navigator.pop(ctx);
                                    },
                                    child: const Text('OK'),
                                  )
                                ],
                              ),
                            );
                          },
                          child: const Text('ऑर्डर पक्का करें (Confirm Order)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
