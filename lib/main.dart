import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  runApp(const ViziaGMartApp());
}

// ============================================================================
// 1. GLOBAL MODELS & DATA STRUCTURES
// ============================================================================

enum ProductCategory { vegetable, fruit, exotic, combo }

enum WeightUnit { gram, kg, dozen, pack, piece }

class WeightOption {
  final String label;
  final double valueInKg; // Example: 0.1 for 100g, 1.0 for 1kg
  final bool isPopular;

  const WeightOption({
    required this.label,
    required this.valueInKg,
    this.isPopular = false,
  });
}

class Product {
  final String id;
  final String name;
  final String hindiName;
  final String icon;
  final ProductCategory category;
  double mandiPricePerKg; // बेस मंडी प्राइस
  double marginPerKg; // प्रॉफिट मार्जिन
  bool inStock;
  final String description;
  final bool isBestSeller;

  Product({
    required this.id,
    required this.name,
    required this.hindiName,
    required this.icon,
    required this.category,
    required this.mandiPricePerKg,
    required this.marginPerKg,
    this.inStock = true,
    this.description = '',
    this.isBestSeller = false,
  });

  double get sellingPricePerKg => mandiPricePerKg + marginPerKg;
  double get estimatedMarketPrice => sellingPricePerKg * 1.45; // Retail market comparison
}

class CartItem {
  final Product product;
  double selectedWeightInKg; // Example: 0.25 = 250g
  DateTime addedTime;

  CartItem({
    required this.product,
    required this.selectedWeightInKg,
    required this.addedTime,
  });

  double get totalPrice => product.sellingPricePerKg * selectedWeightInKg;
  double get totalMandiCost => product.mandiPricePerKg * selectedWeightInKg;
  double get totalMargin => product.marginPerKg * selectedWeightInKg;

  String get formattedWeight {
    if (selectedWeightInKg < 1.0) {
      return '${(selectedWeightInKg * 1000).round()} Gram';
    } else {
      double kgVal = selectedWeightInKg;
      return kgVal % 1 == 0
          ? '${kgVal.toInt()} Kg'
          : '${kgVal.toStringAsFixed(1)} Kg';
    }
  }
}

class CustomerOrder {
  final String orderId;
  final String customerName;
  final String customerPhone;
  final String societyName;
  final String flatNumber;
  final List<CartItem> items;
  final DateTime orderTime;
  final String paymentMode;
  bool isDelivered;

  CustomerOrder({
    required this.orderId,
    required this.customerName,
    required this.customerPhone,
    required this.societyName,
    required this.flatNumber,
    required this.items,
    required this.orderTime,
    this.paymentMode = 'Pay on Delivery',
    this.isDelivered = false,
  });

  double get totalBill => items.fold(0.0, (sum, i) => sum + i.totalPrice);
  double get totalWeight => items.fold(0.0, (sum, i) => sum + i.selectedWeightInKg);
}

// ============================================================================
// 2. CENTRAL DATABASE & APPLICATION STATE MANAGERS
// ============================================================================

class ViziaDatabase {
  static String activeUserPhone = "9971968060";
  static String activeUserName = "Tarun Kumar";
  static String activeSociety = "Sector 15A Green Valley, Faridabad";
  static String activeFlatNo = "House #402, Block-B";

  // वज़न की मास्टर रेंज (100 Gram से लेकर 10 Kg तक)
  static const List<WeightOption> masterWeightPresets = [
    WeightOption(label: '100 Gram', valueInKg: 0.1),
    WeightOption(label: '200 Gram', valueInKg: 0.2),
    WeightOption(label: '250 Gram', valueInKg: 0.25, isPopular: true),
    WeightOption(label: '500 Gram', valueInKg: 0.5, isPopular: true),
    WeightOption(label: '750 Gram', valueInKg: 0.75),
    WeightOption(label: '1 Kg', valueInKg: 1.0, isPopular: true),
    WeightOption(label: '1.5 Kg', valueInKg: 1.5),
    WeightOption(label: '2 Kg', valueInKg: 2.0, isPopular: true),
    WeightOption(label: '3 Kg', valueInKg: 3.0),
    WeightOption(label: '5 Kg', valueInKg: 5.0, isPopular: true),
    WeightOption(label: '7 Kg', valueInKg: 7.0),
    WeightOption(label: '10 Kg', valueInKg: 10.0, isPopular: true),
  ];

  // संपूर्ण इन्वेंटरी (सब्जियां + फल)
  static List<Product> masterProducts = [
    // --- VEGETABLES ---
    Product(id: 'v1', name: 'Potato', hindiName: 'आलू (देसी)', icon: '🥔', category: ProductCategory.vegetable, mandiPricePerKg: 12.0, marginPerKg: 4.0, isBestSeller: true, description: 'Direct from Agra Mandi, high starch fresh potatoes.'),
    Product(id: 'v2', name: 'Onion', hindiName: 'प्याज़ (नासिक)', icon: '🧅', category: ProductCategory.vegetable, mandiPricePerKg: 18.0, marginPerKg: 5.0, isBestSeller: true, description: 'Red Nashik Onions, long shelf life.'),
    Product(id: 'v3', name: 'Tomato', hindiName: 'टमाटर (हाइब्रिड)', icon: '🍅', category: ProductCategory.vegetable, mandiPricePerKg: 15.0, marginPerKg: 5.0, isBestSeller: true, description: 'Firm red tomatoes for daily cooking.'),
    Product(id: 'v4', name: 'Green Chilli', hindiName: 'हरी मिर्च', icon: '🌶️', category: ProductCategory.vegetable, mandiPricePerKg: 40.0, marginPerKg: 10.0, description: 'Spicy sharp green chillies.'),
    Product(id: 'v5', name: 'Ginger', hindiName: 'अदरक (देसी)', icon: '🫚', category: ProductCategory.vegetable, mandiPricePerKg: 85.0, marginPerKg: 15.0, description: 'Fresh washed ginger roots.'),
    Product(id: 'v6', name: 'Garlic', hindiName: 'लहसुन (उज्जैन)', icon: '🧄', category: ProductCategory.vegetable, mandiPricePerKg: 130.0, marginPerKg: 20.0, description: 'Big cloves white garlic.'),
    Product(id: 'v7', name: 'Cauliflower', hindiName: 'फूलगोभी', icon: '🥦', category: ProductCategory.vegetable, mandiPricePerKg: 22.0, marginPerKg: 6.0, description: 'Clean white cauliflower heads.'),
    Product(id: 'v8', name: 'Cabbage', hindiName: 'पत्तागोभी', icon: '🥬', category: ProductCategory.vegetable, mandiPricePerKg: 14.0, marginPerKg: 4.0, description: 'Fresh leafy crunchy cabbage.'),
    Product(id: 'v9', name: 'Lady Finger', hindiName: 'भिंडी (नरम)', icon: '🫛', category: ProductCategory.vegetable, mandiPricePerKg: 28.0, marginPerKg: 7.0, description: 'Tender green okra without fibers.'),
    Product(id: 'v10', name: 'Bottle Gourd', hindiName: 'लौकी (ताज़ा)', icon: '🥒', category: ProductCategory.vegetable, mandiPricePerKg: 16.0, marginPerKg: 5.0, description: 'Soft green bottle gourd.'),
    Product(id: 'v11', name: 'Brinjal', hindiName: 'गोल बैंगन (भरता)', icon: '🍆', category: ProductCategory.vegetable, mandiPricePerKg: 20.0, marginPerKg: 5.0, description: 'Dark purple large eggplants.'),
    Product(id: 'v12', name: 'Capsicum', hindiName: 'शिमला मिर्च', icon: '🫑', category: ProductCategory.vegetable, mandiPricePerKg: 36.0, marginPerKg: 9.0, description: 'Crispy green bell peppers.'),
    Product(id: 'v13', name: 'Green Peas', hindiName: 'ताज़ा मटर', icon: '🫛', category: ProductCategory.vegetable, mandiPricePerKg: 55.0, marginPerKg: 10.0, description: 'Sweet green peas pods.'),
    Product(id: 'v14', name: 'Carrot', hindiName: 'गाजर (लाल)', icon: '🥕', category: ProductCategory.vegetable, mandiPricePerKg: 24.0, marginPerKg: 6.0, description: 'Sweet red juicy carrots.'),
    Product(id: 'v15', name: 'Spinach', hindiName: 'पालक (गड्डी)', icon: '🥬', category: ProductCategory.vegetable, mandiPricePerKg: 18.0, marginPerKg: 5.0, description: 'Washed fresh spinach leaves.'),

    // --- FRUITS ---
    Product(id: 'f1', name: 'Chaunsa Mango', hindiName: 'चौसा आम (मीठा)', icon: '🥭', category: ProductCategory.fruit, mandiPricePerKg: 45.0, marginPerKg: 15.0, isBestSeller: true, description: 'Original ripe Chaunsa mangoes.'),
    Product(id: 'f2', name: 'Shimla Apple', hindiName: 'सेब (शिमला रॉयल)', icon: '🍎', category: ProductCategory.fruit, mandiPricePerKg: 80.0, marginPerKg: 20.0, isBestSeller: true, description: 'Crunchy sweet red apples.'),
    Product(id: 'f3', name: 'Banana', hindiName: 'केला (पका हुआ)', icon: '🍌', category: ProductCategory.fruit, mandiPricePerKg: 25.0, marginPerKg: 8.0, isBestSeller: true, description: 'Fresh Robusta bananas per kg.'),
    Product(id: 'f4', name: 'Pomegranate', hindiName: 'अनार (कांधारी)', icon: '🥠', category: ProductCategory.fruit, mandiPricePerKg: 110.0, marginPerKg: 25.0, description: 'Deep red seeds juicy pomegranates.'),
    Product(id: 'f5', name: 'Papaya', hindiName: 'पपीता (डिस्को)', icon: '🍈', category: ProductCategory.fruit, mandiPricePerKg: 22.0, marginPerKg: 8.0, description: 'Sweet yellow ripe papayas.'),
    Product(id: 'f6', name: 'Orange', hindiName: 'संतरा (नागपुर)', icon: '🍊', category: ProductCategory.fruit, mandiPricePerKg: 50.0, marginPerKg: 12.0, description: 'Juicy Nagpur oranges.'),
    Product(id: 'f7', name: 'Grapes', hindiName: 'अंगूर (बिना बीज)', icon: '🍇', category: ProductCategory.fruit, mandiPricePerKg: 65.0, marginPerKg: 15.0, description: 'Sweet green seedless grapes.'),
    Product(id: 'f8', name: 'Watermelon', hindiName: 'तरबूज (लाल)', icon: '🍉', category: ProductCategory.fruit, mandiPricePerKg: 12.0, marginPerKg: 5.0, description: 'Dark green sweet watermelons.'),
  ];

  // Active User Cart
  static List<CartItem> userCart = [];

  // G-Leader Aggregate Pool Database (Simulated orders from other society members)
  static List<CustomerOrder> dummySocietyOrders = [
    CustomerOrder(
      orderId: 'ORD-901',
      customerName: 'Rajesh Sharma',
      customerPhone: '9811223344',
      societyName: 'Sector 15A Green Valley',
      flatNumber: 'A-102',
      orderTime: DateTime.now().subtract(const Duration(minutes: 25)),
      items: [
        CartItem(product: masterProducts[0], selectedWeightInKg: 5.0, addedTime: DateTime.now()), // 5kg Potato
        CartItem(product: masterProducts[1], selectedWeightInKg: 3.0, addedTime: DateTime.now()), // 3kg Onion
        CartItem(product: masterProducts[15], selectedWeightInKg: 2.0, addedTime: DateTime.now()), // 2kg Mango
      ],
    ),
    CustomerOrder(
      orderId: 'ORD-902',
      customerName: 'Pooja Verma',
      customerPhone: '9876543210',
      societyName: 'Sector 15A Green Valley',
      flatNumber: 'C-504',
      orderTime: DateTime.now().subtract(const Duration(minutes: 10)),
      items: [
        CartItem(product: masterProducts[0], selectedWeightInKg: 2.0, addedTime: DateTime.now()), // 2kg Potato
        CartItem(product: masterProducts[2], selectedWeightInKg: 1.0, addedTime: DateTime.now()), // 1kg Tomato
        CartItem(product: masterProducts[3], selectedWeightInKg: 0.25, addedTime: DateTime.now()), // 250g Chilli
        CartItem(product: masterProducts[16], selectedWeightInKg: 1.0, addedTime: DateTime.now()), // 1kg Apple
      ],
    ),
  ];
}

// ============================================================================
// 3. MAIN ROOT APP
// ============================================================================

class ViziaGMartApp extends StatelessWidget {
  const ViziaGMartApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Vizia G-Mart',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF22C55E), // Emerald Green
          secondary: Color(0xFFF59E0B), // Golden Amber
          surface: Color(0xFF1E293B), // Slate Grey
          background: Color(0xFF0F172A), // Dark Navy
          error: Color(0xFFEF4444),
        ),
        scaffoldBackgroundColor: const Color(0xFF0F172A),
        cardColor: const Color(0xFF1E293B),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF0B0F19),
          elevation: 0,
          centerTitle: false,
        ),
      ),
      home: const MainHubScreen(),
    );
  }
}

// ============================================================================
// 4. MAIN HUB SCREEN (TAB CONTROLLER)
// ============================================================================

class MainHubScreen extends StatefulWidget {
  const MainHubScreen({super.key});

  @override
  State<MainHubScreen> createState() => _MainHubScreenState();
}

class _MainHubScreenState extends State<MainHubScreen> {
  int _currentTabIndex = 0;

  void _triggerRebuild() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final double currentCartTotal = ViziaDatabase.userCart.fold(
      0.0,
      (sum, item) => sum + item.totalPrice,
    );

    final double currentCartWeight = ViziaDatabase.userCart.fold(
      0.0,
      (sum, item) => sum + item.selectedWeightInKg,
    );

    final List<Widget> screens = [
      CustomerShopView(onCartChanged: _triggerRebuild),
      AdminStockManagerView(onDataChanged: _triggerRebuild),
      const GLeaderPortalView(),
      CartAndCheckoutView(onCartChanged: _triggerRebuild),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFF22C55E).withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text('🥦', style: TextStyle(fontSize: 20)),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'VIZIA G-MART',
                  style: TextStyle(
                    color: Color(0xFF22C55E),
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                    letterSpacing: 1.1,
                  ),
                ),
                Text(
                  'Direct Mandi Rates • ${ViziaDatabase.activeSociety}',
                  style: const TextStyle(color: Colors.grey, fontSize: 10),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Color(0xFF22C55E)),
            onPressed: () {
              _triggerRebuild();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('मंडी भाव और स्टॉक सिंक हो गए हैं!'),
                  duration: Duration(seconds: 1),
                  backgroundColor: Color(0xFF22C55E),
                ),
              );
            },
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(26),
          child: Container(
            color: const Color(0xFF1E293B),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Row(
              children: [
                const Icon(Icons.location_on, color: Color(0xFFF59E0B), size: 12),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    'डिलीवरी का पता: ${ViziaDatabase.activeFlatNo}, ${ViziaDatabase.activeSociety}',
                    style: const TextStyle(color: Colors.white70, fontSize: 11),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF59E0B).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'COD/Pay Later',
                    style: TextStyle(color: Color(0xFFF59E0B), fontSize: 9, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: IndexedStack(
        index: _currentTabIndex,
        children: screens,
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: Colors.white10, width: 1)),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentTabIndex,
          selectedItemColor: const Color(0xFF22C55E),
          unselectedItemColor: Colors.grey.shade500,
          backgroundColor: const Color(0xFF0B0F19),
          type: BottomNavigationBarType.fixed,
          selectedFontSize: 12,
          unselectedFontSize: 11,
          onTap: (index) => setState(() => _currentTabIndex = index),
          items: [
            const BottomNavigationBarItem(
              icon: Icon(Icons.storefront),
              activeIcon: Icon(Icons.storefront, color: Color(0xFF22C55E)),
              label: 'दुकान (Shop)',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.admin_panel_settings_outlined),
              activeIcon: Icon(Icons.admin_panel_settings, color: Color(0xFF22C55E)),
              label: 'एडमिन (Stock)',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.groups_outlined),
              activeIcon: Icon(Icons.groups, color: Color(0xFF22C55E)),
              label: 'जी-लीडर (Pool)',
            ),
            BottomNavigationBarItem(
              icon: Stack(
                clipBehavior: Clip.none,
                children: [
                  const Icon(Icons.shopping_cart_outlined),
                  if (ViziaDatabase.userCart.isNotEmpty)
                    Positioned(
                      right: -6,
                      top: -4,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: const BoxDecoration(
                          color: Color(0xFFEF4444),
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                        child: Text(
                          '${ViziaDatabase.userCart.length}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              ),
              activeIcon: const Icon(Icons.shopping_cart, color: Color(0xFF22C55E)),
              label: currentCartTotal > 0
                  ? '₹${currentCartTotal.toStringAsFixed(0)} (${currentCartWeight < 1 ? '${(currentCartWeight * 1000).toInt()}g' : '${currentCartWeight.toStringAsFixed(1)}kg'})'
                  : 'कार्ट (Cart)',
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// 5. CUSTOMER SHOP VIEW (SABJI & FRUITS WITH WEIGHT CONTROL)
// ============================================================================

class CustomerShopView extends StatefulWidget {
  final VoidCallback onCartChanged;
  const CustomerShopView({super.key, required this.onCartChanged});

  @override
  State<CustomerShopView> createState() => _CustomerShopViewState();
}

class _CustomerShopViewState extends State<CustomerShopView> with SingleTickerProviderStateMixin {
  late TabController _categoryTabController;

  @override
  void initState() {
    super.initState();
    _categoryTabController = TabController(length: 2, vsync: this);
  }

  void _addItemToCart(Product product, double weightInKg) {
    var existingIndex = ViziaDatabase.userCart.indexWhere((item) => item.product.id == product.id);
    if (existingIndex >= 0) {
      ViziaDatabase.userCart[existingIndex].selectedWeightInKg = weightInKg;
    } else {
      ViziaDatabase.userCart.add(CartItem(
        product: product,
        selectedWeightInKg: weightInKg,
        addedTime: DateTime.now(),
      ));
    }
    widget.onCartChanged();
    setState(() {});
  }

  void _updateCartWeight(String productId, double newWeightInKg) {
    var existingIndex = ViziaDatabase.userCart.indexWhere((item) => item.product.id == productId);
    if (existingIndex >= 0) {
      if (newWeightInKg <= 0.05) {
        ViziaDatabase.userCart.removeAt(existingIndex);
      } else {
        ViziaDatabase.userCart[existingIndex].selectedWeightInKg = newWeightInKg;
      }
      widget.onCartChanged();
      setState(() {});
    }
  }

  CartItem? _getCartItemOfProduct(String productId) {
    try {
      return ViziaDatabase.userCart.firstWhere((item) => item.product.id == productId);
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final vegProducts = ViziaDatabase.masterProducts.where((p) => p.category == ProductCategory.vegetable).toList();
    final fruitProducts = ViziaDatabase.masterProducts.where((p) => p.category == ProductCategory.fruit).toList();

    return Column(
      children: [
        // Category Switcher
        Container(
          color: const Color(0xFF1E293B),
          child: TabBar(
            controller: _categoryTabController,
            indicatorColor: const Color(0xFF22C55E),
            indicatorWeight: 3,
            labelColor: const Color(0xFF22C55E),
            unselectedLabelColor: Colors.grey,
            labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            tabs: const [
              Tab(icon: Icon(Icons.eco), text: '🥦 ताज़ा सब्जियाँ'),
              Tab(icon: Icon(Icons.apple), text: '🍎 ताज़ा फल (Fruits)'),
            ],
          ),
        ),

        // Sub-Header Info Banner
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          color: const Color(0xFF22C55E).withOpacity(0.1),
          child: const Row(
            children: [
              Icon(Icons.verified, color: Color(0xFF22C55E), size: 16),
              SizedBox(width: 6),
              Text(
                'मंडी का सीधा भाव | 100 ग्राम से 10 किलो तक चुनें',
                style: TextStyle(color: Color(0xFF22C55E), fontSize: 11, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),

        // Products List View
        Expanded(
          child: TabBarView(
            controller: _categoryTabController,
            children: [
              _buildProductListView(vegProducts),
              _buildProductListView(fruitProducts),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildProductListView(List<Product> products) {
    return ListView.builder(
      padding: const EdgeInsets.all(10),
      itemCount: products.length,
      itemBuilder: (context, index) {
        final product = products[index];
        final cartItem = _getCartItemOfProduct(product.id);
        final bool isInCart = cartItem != null;
        final double currentWeight = isInCart ? cartItem.selectedWeightInKg : 1.0;

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: isInCart ? const Color(0xFF22C55E) : Colors.grey.shade800,
              width: isInCart ? 1.5 : 1,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Info Section
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Emoji / Thumbnail
                    Container(
                      width: 52,
                      height: 52,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.black38,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(product.icon, style: const TextStyle(fontSize: 30)),
                    ),
                    const SizedBox(width: 12),

                    // Name & Price Info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                product.hindiName,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color: product.inStock ? Colors.white : Colors.grey,
                                  decoration: product.inStock ? null : TextDecoration.lineThrough,
                                ),
                              ),
                              if (product.isBestSeller) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF59E0B).withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text('Top', style: TextStyle(color: Color(0xFFF59E0B), fontSize: 9, fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Text(
                                '₹${product.sellingPricePerKg.toStringAsFixed(0)} / Kg',
                                style: TextStyle(
                                  color: product.inStock ? const Color(0xFF22C55E) : Colors.grey,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'बाज़ार: ₹${product.estimatedMarketPrice.toStringAsFixed(0)}',
                                style: const TextStyle(
                                  color: Colors.grey,
                                  fontSize: 11,
                                  decoration: TextDecoration.lineThrough,
                                ),
                              ),
                            ],
                          ),
                          Text(
                            product.description,
                            style: TextStyle(color: Colors.grey.shade400, fontSize: 10),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),

                    // Add Button / Out of Stock Banner
                    if (!product.inStock)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.red.shade900.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'आउट ऑफ स्टॉक',
                          style: TextStyle(color: Colors.redAccent, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      )
                    else if (!isInCart)
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF22C55E),
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        icon: const Icon(Icons.add_shopping_cart, size: 16),
                        label: const Text('ADD', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        onPressed: () => _addItemToCart(product, 1.0), // डिफ़ॉल्ट 1 kg ऐड होगा
                      ),
                  ],
                ),

                // Cart Controller & Weight Picker (जब प्रोडक्ट कार्ट में ऐड हो जाए)
                if (product.inStock && isInCart) ...[
                  const Divider(color: Colors.white12, height: 18),
                  
                  // Row 1: Weight Dropdown & Direct Stepper (+ / -)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Dropdown Selector (100g to 10kg)
                      Container(
                        height: 38,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F172A),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFF22C55E).withOpacity(0.6)),
                        ),
                        child: DropdownButton<double>(
                          value: ViziaDatabase.masterWeightPresets.any((w) => (w.valueInKg - currentWeight).abs() < 0.01)
                              ? ViziaDatabase.masterWeightPresets.firstWhere((w) => (w.valueInKg - currentWeight).abs() < 0.01).valueInKg
                              : null,
                          hint: Text(
                            cartItem.formattedWeight,
                            style: const TextStyle(color: Color(0xFF22C55E), fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                          dropdownColor: const Color(0xFF1E293B),
                          underline: const SizedBox(),
                          icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF22C55E)),
                          items: ViziaDatabase.masterWeightPresets.map((preset) {
                            return DropdownMenuItem<double>(
                              value: preset.valueInKg,
                              child: Row(
                                children: [
                                  Text(
                                    preset.label,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: preset.isPopular ? const Color(0xFF22C55E) : Colors.white,
                                      fontWeight: preset.isPopular ? FontWeight.bold : FontWeight.normal,
                                    ),
                                  ),
                                  if (preset.isPopular) ...[
                                    const SizedBox(width: 4),
                                    const Icon(Icons.star, color: Color(0xFFF59E0B), size: 10),
                                  ],
                                ],
                              ),
                            );
                          }).toList(),
                          onChanged: (double? newWeight) {
                            if (newWeight != null) {
                              _updateCartWeight(product.id, newWeight);
                            }
                          },
                        ),
                      ),

                      // Stepper (+ / -)
                      Container(
                        height: 38,
                        decoration: BoxDecoration(
                          color: Colors.black45,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.remove, color: Colors.redAccent, size: 18),
                              onPressed: () {
                                double nextWeight = currentWeight - 0.1;
                                _updateCartWeight(product.id, nextWeight < 0.09 ? 0.0 : double.parse(nextWeight.toStringAsFixed(2)));
                              },
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    cartItem.formattedWeight,
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                                  ),
                                  Text(
                                    '₹${cartItem.totalPrice.toStringAsFixed(0)}',
                                    style: const TextStyle(color: Color(0xFF22C55E), fontSize: 10, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.add, color: Color(0xFF22C55E), size: 18),
                              onPressed: () {
                                double nextWeight = currentWeight + 0.1;
                                if (nextWeight <= 10.05) {
                                  _updateCartWeight(product.id, double.parse(nextWeight.toStringAsFixed(2)));
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),

                  // Row 2: Smooth Weight Slider (100g to 10kg Continuous Scroll Bar)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('स्क्रॉल करके वज़न चुनें (Slider):', style: TextStyle(color: Colors.grey, fontSize: 10)),
                          Text(
                            'चुना गया: ${cartItem.formattedWeight}',
                            style: const TextStyle(color: Color(0xFFF59E0B), fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          activeTrackColor: const Color(0xFF22C55E),
                          inactiveTrackColor: Colors.grey.shade800,
                          thumbColor: const Color(0xFFF59E0B),
                          overlayColor: const Color(0xFFF59E0B).withOpacity(0.2),
                          trackHeight: 3,
                          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                        ),
                        child: Slider(
                          value: currentWeight.clamp(0.1, 10.0),
                          min: 0.1, // 100 gram
                          max: 10.0, // 10 kg
                          divisions: 99, // 100g increments
                          onChanged: (double val) {
                            _updateCartWeight(product.id, double.parse(val.toStringAsFixed(2)));
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

// ============================================================================
// 6. ADMIN STOCK MANAGER VIEW (TOGGLE IN/OUT STOCK + MARGIN CONTROL)
// ============================================================================

class AdminStockManagerView extends StatefulWidget {
  final VoidCallback onDataChanged;
  const AdminStockManagerView({super.key, required this.onDataChanged});

  @override
  State<AdminStockManagerView> createState() => _AdminStockManagerViewState();
}

class _AdminStockManagerViewState extends State<AdminStockManagerView> {
  void _editPriceDialog(Product product) {
    final mandiController = TextEditingController(text: product.mandiPricePerKg.toString());
    final marginController = TextEditingController(text: product.marginPerKg.toString());

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: Text('${product.icon} ${product.hindiName} - रेट बदलें'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: mandiController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'मंडी खरीद रेट (Per Kg)', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: marginController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'मार्जिन रेट (Per Kg)', border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('रद्द करें', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF22C55E)),
            onPressed: () {
              setState(() {
                product.mandiPricePerKg = double.tryParse(mandiController.text) ?? product.mandiPricePerKg;
                product.marginPerKg = double.tryParse(marginController.text) ?? product.marginPerKg;
              });
              widget.onDataChanged();
              Navigator.pop(context);
            },
            child: const Text('सेव करें', style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: ViziaDatabase.masterProducts.length,
      itemBuilder: (context, index) {
        final product = ViziaDatabase.masterProducts[index];

        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: SwitchListTile(
              secondary: Text(product.icon, style: const TextStyle(fontSize: 28)),
              title: Text(
                product.hindiName,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('मंडी: ₹${product.mandiPricePerKg} | मार्जिन: ₹${product.marginPerKg}'),
                  Text(
                    'ग्राहक रेट: ₹${product.sellingPricePerKg.toStringAsFixed(0)} / kg',
                    style: const TextStyle(color: Color(0xFF22C55E), fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              value: product.inStock,
              activeColor: const Color(0xFF22C55E),
              onChanged: (bool val) {
                setState(() {
                  product.inStock = val;
                });
                widget.onDataChanged();
              },
            ),
          ),
        );
      },
    );
  }
}

// ============================================================================
// 7. G-LEADER PORTAL (AGGREGATED POOL & BULK MANDI PROCUREMENT)
// ============================================================================

class GLeaderPortalView extends StatelessWidget {
  const GLeaderPortalView({super.key});

  @override
  Widget build(BuildContext context) {
    // 1. Calculate Aggregate Pool Data (All Society Orders Combined)
    Map<String, double> aggregatedWeightsPerProduct = {};
    Map<String, Product> productMap = {};
    double totalSocietyCollection = 0.0;
    double totalSocietyWeight = 0.0;
    int totalSocietyOrders = ViziaDatabase.dummySocietyOrders.length;

    // Active User order also included in aggregate
    if (ViziaDatabase.userCart.isNotEmpty) {
      totalSocietyOrders += 1;
    }

    // Process Dummy Orders
    for (var order in ViziaDatabase.dummySocietyOrders) {
      totalSocietyCollection += order.totalBill;
      for (var item in order.items) {
        aggregatedWeightsPerProduct[item.product.id] =
            (aggregatedWeightsPerProduct[item.product.id] ?? 0.0) + item.selectedWeightInKg;
        productMap[item.product.id] = item.product;
        totalSocietyWeight += item.selectedWeightInKg;
      }
    }

    // Process Active User Cart
    for (var item in ViziaDatabase.userCart) {
      totalSocietyCollection += item.totalPrice;
      aggregatedWeightsPerProduct[item.product.id] =
          (aggregatedWeightsPerProduct[item.product.id] ?? 0.0) + item.selectedWeightInKg;
      productMap[item.product.id] = item.product;
      totalSocietyWeight += item.selectedWeightInKg;
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Summary Card
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFF59E0B)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.groups, color: Color(0xFFF59E0B)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'जी-लीडर मंडी पूल डैशबोर्ड (${ViziaDatabase.activeSociety})',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFFF59E0B)),
                      ),
                    ),
                  ],
                ),
                const Divider(color: Colors.white24, height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildSummaryStat('कुल ऑर्डर्स', '$totalSocietyOrders'),
                    _buildSummaryStat('कुल वज़न', '${totalSocietyWeight.toStringAsFixed(1)} Kg'),
                    _buildSummaryStat('कुल कलेक्शन', '₹${totalSocietyCollection.toStringAsFixed(0)}'),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          const Text(
            '📦 मंडी थोक खरीदारी सूची (Combined Procurement List):',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF22C55E)),
          ),
          const Text(
            'मंडी से सुबह मंडी भाव पर यही सामान एक साथ उठाना है:',
            style: TextStyle(fontSize: 11, color: Colors.grey),
          ),
          const SizedBox(height: 10),

          if (aggregatedWeightsPerProduct.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(30.0),
                child: Text('अभी सोसाइटी से कोई ऑर्डर नहीं आया है।', style: TextStyle(color: Colors.grey)),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: aggregatedWeightsPerProduct.keys.length,
              itemBuilder: (context, index) {
                String productId = aggregatedWeightsPerProduct.keys.elementAt(index);
                double totalKg = aggregatedWeightsPerProduct[productId]!;
                Product prod = productMap[productId]!;
                double mandiCost = totalKg * prod.mandiPricePerKg;
                double totalBill = totalKg * prod.sellingPricePerKg;

                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Row(
                    children: [
                      Text(prod.icon, style: const TextStyle(fontSize: 24)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(prod.hindiName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                            Text(
                              'मंडी रेट: ₹${prod.mandiPricePerKg}/kg | मंडी खर्च: ₹${mandiCost.toStringAsFixed(0)}',
                              style: const TextStyle(color: Colors.grey, fontSize: 10),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF22C55E).withOpacity(0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              totalKg < 1 ? '${(totalKg * 1000).toInt()} Gram' : '${totalKg.toStringAsFixed(1)} Kg',
                              style: const TextStyle(color: Color(0xFF22C55E), fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text('कुल बिल: ₹${totalBill.toStringAsFixed(0)}', style: const TextStyle(color: Color(0xFFF59E0B), fontSize: 11, fontWeight: FontWeight.bold)),
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

  Widget _buildSummaryStat(String label, String value) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 10)),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white)),
      ],
    );
  }
}

// ============================================================================
// 8. CART & CHECKOUT VIEW
// ============================================================================

class CartAndCheckoutView extends StatefulWidget {
  final VoidCallback onCartChanged;
  const CartAndCheckoutView({super.key, required this.onCartChanged});

  @override
  State<CartAndCheckoutView> createState() => _CartAndCheckoutViewState();
}

class _CartAndCheckoutViewState extends State<CartAndCheckoutView> {
  @override
  Widget build(BuildContext context) {
    if (ViziaDatabase.userCart.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.shopping_cart_outlined, size: 70, color: Colors.grey),
            const SizedBox(height: 12),
            const Text('आपकी कार्ट खाली है!', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            const Text('दुकान से ताज़ा फल व सब्जियाँ जोड़ें', style: TextStyle(color: Colors.grey, fontSize: 12)),
          ],
        ),
      );
    }

    double totalCartBill = ViziaDatabase.userCart.fold(0.0, (sum, item) => sum + item.totalPrice);
    double totalCartWeight = ViziaDatabase.userCart.fold(0.0, (sum, item) => sum + item.selectedWeightInKg);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('🛒 आपके कार्ट आइटम्स:', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF22C55E))),
          const SizedBox(height: 10),

          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: ViziaDatabase.userCart.length,
            itemBuilder: (context, index) {
              final item = ViziaDatabase.userCart[index];

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white10),
                ),
                child: Row(
                  children: [
                    Text(item.product.icon, style: const TextStyle(fontSize: 26)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(item.product.hindiName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          Text(
                            '₹${item.product.sellingPricePerKg}/kg × ${item.formattedWeight}',
                            style: const TextStyle(color: Colors.grey, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('₹${item.totalPrice.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF22C55E), fontSize: 14)),
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent, size: 18),
                              onPressed: () {
                                setState(() {
                                  double next = item.selectedWeightInKg - 0.1;
                                  if (next < 0.09) {
                                    ViziaDatabase.userCart.removeAt(index);
                                  } else {
                                    item.selectedWeightInKg = double.parse(next.toStringAsFixed(2));
                                  }
                                });
                                widget.onCartChanged();
                              },
                              constraints: const BoxConstraints(),
                              padding: EdgeInsets.zero,
                            ),
                            const SizedBox(width: 6),
                            IconButton(
                              icon: const Icon(Icons.add_circle_outline, color: Color(0xFF22C55E), size: 18),
                              onPressed: () {
                                setState(() {
                                  item.selectedWeightInKg = double.parse((item.selectedWeightInKg + 0.1).toStringAsFixed(2));
                                });
                                widget.onCartChanged();
                              },
                              constraints: const BoxConstraints(),
                              padding: EdgeInsets.zero,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),

          const SizedBox(height: 16),

          // Bill Summary Box
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFF59E0B)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('📊 बिल का विवरण (Bill Summary)', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFF59E0B), fontSize: 13)),
                const Divider(color: Colors.white24, height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('कुल वज़न (Total Weight):', style: TextStyle(color: Colors.white70, fontSize: 12)),
                    Text(
                      totalCartWeight < 1 ? '${(totalCartWeight * 1000).toInt()} Gram' : '${totalCartWeight.toStringAsFixed(1)} Kg',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF22C55E), fontSize: 12),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('डिलीवरी चार्ज (Mandi Direct Delivery):', style: TextStyle(color: Colors.white70, fontSize: 12)),
                    const Text('FREE', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF22C55E), fontSize: 12)),
                  ],
                ),
                const Divider(color: Colors.white24, height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('कुल रकम (Total Payable):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    Text('₹${totalCartBill.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF22C55E))),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF22C55E),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('ऑर्डर प्लेस हो गया! कुल वज़न: ${totalCartWeight.toStringAsFixed(1)}kg'),
                    backgroundColor: const Color(0xFF22C55E),
                  ),
                );
              },
              child: Text(
                'ऑर्डर प्लेस करें (₹${totalCartBill.toStringAsFixed(0)})',
                style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 15),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
