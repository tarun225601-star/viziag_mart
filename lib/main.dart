import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ChinaGroupBuyEngine()),
      ],
      child: const ChinaGroupBuySingleFileApp(),
    ),
  );
}

class ChinaGroupBuySingleFileApp extends StatelessWidget {
  const ChinaGroupBuySingleFileApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'China G-Leader Fresh Single-File System',
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
// 1. ALL DATA MODELS (पूरा चाइनीज मॉडल डेटा ढांचा)
// ============================================================================

enum OrderStatus { pending, lockedForMandi, readyForPickup, completed, cancelled }

class WeightVariant {
  final String id;
  String label; // उदा: "1 Kg", "3 Kg (फैमिली पैक)", "5 Kg (पेटी)"
  double weightInKg;
  double price;
  double mandiCostPrice;
  bool isAvailable;

  WeightVariant({
    required this.id,
    required this.label,
    required this.weightInKg,
    required this.price,
    required this.mandiCostPrice,
    this.isAvailable = true,
  });
}

class ProductItem {
  final String id;
  String nameHindi;
  String nameEnglish;
  String category;
  List<WeightVariant> variants;
  bool isAvailable;
  bool isFeatured;

  ProductItem({
    required this.id,
    required this.nameHindi,
    required this.nameEnglish,
    required this.category,
    required this.variants,
    this.isAvailable = true,
    this.isFeatured = false,
  });
}

class GroupLeader {
  final String id;
  String name;
  String hubName; // उदा: "तरुण फ्रेश स्टॉल - सेक्टर 15"
  String phone;
  String address;
  double commissionRate;

  GroupLeader({
    required this.id,
    required this.name,
    required this.hubName,
    required this.phone,
    required this.address,
    required this.commissionRate,
  });
}

class OrderLineItem {
  final ProductItem product;
  final WeightVariant variant;
  int quantity;

  OrderLineItem({
    required this.product,
    required this.variant,
    required this.quantity,
  });

  double get totalPrice => variant.price * quantity;
  double get totalMandiCost => variant.mandiCostPrice * quantity;
}

class CustomerOrder {
  final String id;
  final String customerName;
  final String customerPhone;
  final String leaderId;
  final String buildingAddress;
  final List<OrderLineItem> items;
  final double totalAmount;
  OrderStatus status;
  final DateTime orderTime;

  CustomerOrder({
    required this.id,
    required this.customerName,
    required this.customerPhone,
    required this.leaderId,
    required this.buildingAddress,
    required this.items,
    required this.totalAmount,
    this.status = OrderStatus.pending,
    required this.orderTime,
  });
}

// ============================================================================
// 2. CENTRAL STATE ENGINE (ऑटो-कटऑफ, मंडी एग्रीगेटर, कार्ट व ऑर्डर्स)
// ============================================================================

class ChinaGroupBuyEngine extends ChangeNotifier {
  // ग्लोबल कट-ऑफ स्विच (रात को मंडी जाने के समय बंद करने के लिए)
  bool _isOrderBookingOpen = true;
  bool get isOrderBookingOpen => _isOrderBookingOpen;

  // सिलेक्टेड जी-लीडर (ठेले वाला)
  GroupLeader currentLeader = GroupLeader(
    id: 'GL-101',
    name: 'तरुण कुमार',
    hubName: 'तरुण फ्रेश - ठेला पॉइंट #01',
    phone: '9876543210',
    address: 'सेक्टर 15 मार्केट ब्लॉक A',
    commissionRate: 10.0,
  );

  // मास्टर कैटलॉग (आइटम और वजन पैकेट)
  final List<ProductItem> _catalog = [
    ProductItem(
      id: 'P001',
      nameHindi: 'चौसा आम (Chausa)',
      nameEnglish: 'Premium Chausa Mango',
      category: 'ताजे फल',
      isFeatured: true,
      variants: [
        WeightVariant(id: 'V101', label: '1 Kg (पैक)', weightInKg: 1.0, price: 80, mandiCostPrice: 55),
        WeightVariant(id: 'V102', label: '3 Kg (फैमिली पैक)', weightInKg: 3.0, price: 230, mandiCostPrice: 160),
        WeightVariant(id: 'V103', label: '5 Kg (पूरी पेटी)', weightInKg: 5.0, price: 370, mandiCostPrice: 260),
      ],
    ),
    ProductItem(
      id: 'P002',
      nameHindi: 'दशहरी आम (Dasheri)',
      nameEnglish: 'Dasheri Mango',
      category: 'ताजे फल',
      variants: [
        WeightVariant(id: 'V104', label: '1 Kg', weightInKg: 1.0, price: 60, mandiCostPrice: 40),
        WeightVariant(id: 'V105', label: '5 Kg (पेटी)', weightInKg: 5.0, price: 280, mandiCostPrice: 190),
      ],
    ),
    ProductItem(
      id: 'P003',
      nameHindi: 'केला (G-9 Premium)',
      nameEnglish: 'G-9 Banana',
      category: 'ताजे फल',
      variants: [
        WeightVariant(id: 'V106', label: '1 दर्जन (12 pcs)', weightInKg: 1.5, price: 50, mandiCostPrice: 32),
        WeightVariant(id: 'V107', label: '2 दर्जन (24 pcs)', weightInKg: 3.0, price: 95, mandiCostPrice: 60),
      ],
    ),
  ];

  // ऑर्डर्स की लिस्ट
  final List<CustomerOrder> _orders = [
    CustomerOrder(
      id: 'ORD-901',
      customerName: 'अमित शर्मा',
      customerPhone: '9811223344',
      leaderId: 'GL-101',
      buildingAddress: 'टावर C, फ्लैट 402',
      totalAmount: 740,
      orderTime: DateTime.now().subtract(const Duration(minutes: 40)),
      items: [
        OrderLineItem(
          product: ProductItem(id: 'P001', nameHindi: 'चौसा आम', nameEnglish: 'Chausa', category: 'फल', variants: []),
          variant: WeightVariant(id: 'V103', label: '5 Kg (पूरी पेटी)', weightInKg: 5.0, price: 370, mandiCostPrice: 260),
          quantity: 2,
        )
      ],
    ),
    CustomerOrder(
      id: 'ORD-902',
      customerName: 'विक्रम सिंह',
      customerPhone: '9899001122',
      leaderId: 'GL-101',
      buildingAddress: 'टावर A, फ्लैट 101',
      totalAmount: 290,
      orderTime: DateTime.now().subtract(const Duration(minutes: 10)),
      items: [
        OrderLineItem(
          product: ProductItem(id: 'P001', nameHindi: 'चौसा आम', nameEnglish: 'Chausa', category: 'फल', variants: []),
          variant: WeightVariant(id: 'V101', label: '1 Kg (पैक)', weightInKg: 1.0, price: 80, mandiCostPrice: 55),
          quantity: 3,
        ),
        OrderLineItem(
          product: ProductItem(id: 'P003', nameHindi: 'केला', nameEnglish: 'Banana', category: 'फल', variants: []),
          variant: WeightVariant(id: 'V106', label: '1 दर्जन', weightInKg: 1.5, price: 50, mandiCostPrice: 32),
          quantity: 1,
        ),
      ],
    )
  ];

  List<ProductItem> get catalog => _catalog;
  List<CustomerOrder> get orders => _orders;

  // ==========================================================================
  // CHINA MANDI AGGREGATOR ALGORITHM: पूरी मंडी खरीद का कुल जोड़ निकालना
  // ==========================================================================
  Map<String, Map<String, dynamic>> generateMandiProcurementSummary() {
    Map<String, Map<String, dynamic>> summary = {};

    for (var order in _orders) {
      if (order.status == OrderStatus.cancelled) continue;

      for (var item in order.items) {
        String key = "${item.product.nameHindi} - [${item.variant.label}]";

        if (!summary.containsKey(key)) {
          summary[key] = {
            'qty': 0,
            'totalWeightKg': 0.0,
            'unitLabel': item.variant.label,
          };
        }

        summary[key]!['qty'] = summary[key]!['qty'] + item.quantity;
        summary[key]!['totalWeightKg'] =
            summary[key]!['totalWeightKg'] + (item.variant.weightInKg * item.quantity);
      }
    }
    return summary;
  }

  // Admin Controls
  void toggleBookingStatus(bool status) {
    _isOrderBookingOpen = status;
    notifyListeners();
  }

  void addProduct(ProductItem product) {
    _catalog.add(product);
    notifyListeners();
  }

  void addVariantToProduct(String productId, WeightVariant variant) {
    final index = _catalog.indexWhere((p) => p.id == productId);
    if (index != -1) {
      _catalog[index].variants.add(variant);
      notifyListeners();
    }
  }

  void toggleProductAvailability(String productId) {
    final index = _catalog.indexWhere((p) => p.id == productId);
    if (index != -1) {
      _catalog[index].isAvailable = !_catalog[index].isAvailable;
      notifyListeners();
    }
  }

  void updateOrderStatus(String orderId, OrderStatus status) {
    final index = _orders.indexWhere((o) => o.id == orderId);
    if (index != -1) {
      _orders[index].status = status;
      notifyListeners();
    }
  }

  void placeCustomerOrder({
    required String name,
    required String phone,
    required String address,
    required ProductItem product,
    required WeightVariant variant,
    required int quantity,
  }) {
    final newOrder = CustomerOrder(
      id: 'ORD-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
      customerName: name,
      customerPhone: phone,
      leaderId: currentLeader.id,
      buildingAddress: address,
      items: [
        OrderLineItem(product: product, variant: variant, quantity: quantity),
      ],
      totalAmount: variant.price * quantity,
      orderTime: DateTime.now(),
    );

    _orders.insert(0, newOrder);
    notifyListeners();
  }
}

// ============================================================================
// 3. MAIN NAVIGATION HUB (ग्राहक, G-Leader और Admin तीनों एक ही जगह)
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
    GLeaderDashboardModule(),
    MasterAdminControlModule(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: _screens[_selectedTab],
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 8)],
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedTab,
          selectedItemColor: const Color(0xFFFF5000),
          unselectedItemColor: Colors.grey.shade600,
          onTap: (index) => setState(() => _selectedTab = index),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.shopping_bag_outlined),
              activeIcon: Icon(Icons.shopping_bag),
              label: '1. ग्राहक स्टोर',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.storefront_outlined),
              activeIcon: Icon(Icons.storefront),
              label: '2. G-Leader हब',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.admin_panel_settings_outlined),
              activeIcon: Icon(Icons.admin_panel_settings),
              label: '3. मालिक (Admin)',
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// MODULE 1: CUSTOMER GROUP BUYING APP (ग्राहक स्टोर)
// ============================================================================

class CustomerStorefrontModule extends StatelessWidget {
  const CustomerStorefrontModule({super.key});

  @override
  Widget build(BuildContext context) {
    final engine = Provider.of<ChinaGroupBuyEngine>(context);

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFFFF5000),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              engine.currentLeader.hubName,
              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
            Text(
              'पिकअप पॉइंट: ${engine.currentLeader.address}',
              style: const TextStyle(color: Colors.white70, fontSize: 11),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // CUTOFF BANNER
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
            color: engine.isOrderBookingOpen ? Colors.amber.shade100 : Colors.red.shade100,
            child: Row(
              children: [
                Icon(
                  engine.isOrderBookingOpen ? Icons.access_time_filled : Icons.block,
                  color: engine.isOrderBookingOpen ? Colors.amber.shade900 : Colors.red.shade900,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    engine.isOrderBookingOpen
                        ? '⏰ आज का ग्रुप ऑर्डर चालू है! रात 10 बजे कट-ऑफ होगा।'
                        : '⛔ आज के ऑर्डर बंद हो चुके हैं। मंडी से माल लोड हो रहा है!',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: engine.isOrderBookingOpen ? Colors.amber.shade900 : Colors.red.shade900,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // PRODUCT LIST
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: engine.catalog.length,
              itemBuilder: (context, index) {
                final product = engine.catalog[index];
                if (!product.isAvailable) return const SizedBox.shrink();

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              product.nameHindi,
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            Chip(
                              label: Text(product.category),
                              backgroundColor: Colors.green.shade50,
                              labelStyle: const TextStyle(color: Colors.green, fontSize: 10, fontWeight: FontWeight.bold),
                            )
                          ],
                        ),
                        Text(product.nameEnglish, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                        const SizedBox(height: 12),
                        const Text('वजन / पैकेट चुनें:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        const SizedBox(height: 8),

                        // WEIGHT VARIANT SELECTOR
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: product.variants.map((variant) {
                            return OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Color(0xFFFF5000)),
                                backgroundColor: const Color(0xFFFFF5F0),
                              ),
                              onPressed: engine.isOrderBookingOpen
                                  ? () => _openOrderDialog(context, engine, product, variant)
                                  : null,
                              child: Text(
                                '${variant.label} - ₹${variant.price}',
                                style: const TextStyle(color: Color(0xFFFF5000), fontWeight: FontWeight.bold),
                              ),
                            );
                          }).toList(),
                        )
                      ],
                    ),
                  ),
                );
              },
            ),
          )
        ],
      ),
    );
  }

  void _openOrderDialog(BuildContext context, ChinaGroupBuyEngine engine, ProductItem product, WeightVariant variant) {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final addressCtrl = TextEditingController();
    int qty = 1;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
            top: 20,
            left: 20,
            right: 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('ग्रुप बाइंग - ऑर्डर फॉर्म', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const Divider(),
              Text('सामान: ${product.nameHindi}'),
              Text('पैकेट: ${variant.label}', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFFF5000))),
              const SizedBox(height: 10),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('मात्रा (Quantity):'),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline),
                        onPressed: qty > 1 ? () => setModalState(() => qty--) : null,
                      ),
                      Text('$qty', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline),
                        onPressed: () => setModalState(() => qty++),
                      ),
                    ],
                  )
                ],
              ),
              const SizedBox(height: 10),

              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'आपका नाम')),
              TextField(controller: phoneCtrl, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'मोबाइल नंबर')),
              TextField(controller: addressCtrl, decoration: const InputDecoration(labelText: 'फ्लैट / मकान नंबर')),
              const SizedBox(height: 15),

              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF5000)),
                  onPressed: () {
                    if (nameCtrl.text.isNotEmpty && phoneCtrl.text.isNotEmpty) {
                      engine.placeCustomerOrder(
                        name: nameCtrl.text,
                        phone: phoneCtrl.text,
                        address: addressCtrl.text,
                        product: product,
                        variant: variant,
                        quantity: qty,
                      );
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('✅ आपका ऑर्डर सफलतापूर्वक ग्रुप में जुड़ गया है!')),
                      );
                    }
                  },
                  child: Text('₹${variant.price * qty} - ऑर्डर प्लेस करें', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// MODULE 2: G-LEADER DASHBOARD (मंडी प्रोक्योरमेंट + डिलीवरी लिस्ट)
// ============================================================================

class GLeaderDashboardModule extends StatelessWidget {
  const GLeaderDashboardModule({super.key});

  @override
  Widget build(BuildContext context) {
    final engine = Provider.of<ChinaGroupBuyEngine>(context);
    final summary = engine.generateMandiProcurementSummary();

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: const Color(0xFF2B8C00),
          title: Text('G-Leader: ${engine.currentLeader.name}', style: const TextStyle(color: Colors.white)),
          bottom: const TabBar(
            indicatorColor: Colors.amber,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            tabs: [
              Tab(icon: Icon(Icons.analytics), text: 'मंडी कुल खरीद (Aggregator)'),
              Tab(icon: Icon(Icons.checklist), text: 'कस्टमर वितरण सूची'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // MANDI SUMMARY SHEET
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Card(
                    color: Colors.green.shade50,
                    child: const Padding(
                      padding: EdgeInsets.all(12),
                      child: Row(
                        children: [
                          Icon(Icons.shopping_cart, color: Colors.green),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'मंडी से उठाने के लिए कुल माल (सभी ग्राहकों का लाइव जोड़):',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: ListView.builder(
                      itemCount: summary.length,
                      itemBuilder: (context, index) {
                        String key = summary.keys.elementAt(index);
                        var data = summary[key]!;

                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: const Color(0xFF2B8C00),
                              child: Text('${index + 1}', style: const TextStyle(color: Colors.white)),
                            ),
                            title: Text(key, style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text('कुल वजन: ${data['totalWeightKg']} Kg approx.'),
                            trailing: Text(
                              'TOTAL: ${data['qty']} Pkts',
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF2B8C00)),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),

            // CUSTOMER DELIVERY CHECKLIST
            ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: engine.orders.length,
              itemBuilder: (context, index) {
                final order = engine.orders[index];

                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ExpansionTile(
                    title: Text('${order.customerName} (${order.buildingAddress})', style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('ID: ${order.id} | बिल: ₹${order.totalAmount}'),
                    trailing: Checkbox(
                      activeColor: const Color(0xFF2B8C00),
                      value: order.status == OrderStatus.completed,
                      onChanged: (bool? val) {
                        engine.updateOrderStatus(
                          order.id,
                          val == true ? OrderStatus.completed : OrderStatus.pending,
                        );
                      },
                    ),
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        color: Colors.grey.shade50,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('📞 फोन: ${order.customerPhone}'),
                            const Divider(),
                            ...order.items.map((i) => Text('• ${i.product.nameHindi} (${i.variant.label}) x ${i.quantity} = ₹${i.totalPrice}')),
                          ],
                        ),
                      )
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// MODULE 3: MASTER ADMIN CONTROL MODULE (मालिक एडमिन)
// ============================================================================

class MasterAdminControlModule extends StatelessWidget {
  const MasterAdminControlModule({super.key});

  @override
  Widget build(BuildContext context) {
    final engine = Provider.of<ChinaGroupBuyEngine>(context);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('Master System Admin', style: TextStyle(color: Colors.white)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // CUTOFF SWITCH
          const Text('ग्लोबल ऑटो-कटऑफ स्विच', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Card(
            color: engine.isOrderBookingOpen ? Colors.green.shade50 : Colors.red.shade50,
            child: SwitchListTile(
              activeColor: Colors.green,
              title: const Text('Order Booking Switch', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(engine.isOrderBookingOpen ? 'ऑर्डर चालू हैं (Live)' : 'ऑर्डर ब्लॉक हैं (Mandi Mode)'),
              value: engine.isOrderBookingOpen,
              onChanged: (val) => engine.toggleBookingStatus(val),
            ),
          ),

          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('कैटलॉग और वजन कंट्रोल', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.black, foregroundColor: Colors.white),
                onPressed: () => _openAddProductDialog(context, engine),
                icon: const Icon(Icons.add),
                label: const Text('नया फल जोड़ें'),
              )
            ],
          ),
          const SizedBox(height: 10),

          // PRODUCTS LIST & VARIANT MANAGERS
          ...engine.catalog.map((product) {
            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: ExpansionTile(
                title: Text(product.nameHindi, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('ID: ${product.id} | पैकेट्स: ${product.variants.length}'),
                trailing: Switch(
                  value: product.isAvailable,
                  onChanged: (_) => engine.toggleProductAvailability(product.id),
                ),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('सेट वजन और रेट्स:', style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 5),
                        ...product.variants.map((v) => Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('• ${v.label} (${v.weightInKg} Kg)'),
                                Text('₹${v.price}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                              ],
                            )),
                        const SizedBox(height: 10),
                        TextButton.icon(
                          onPressed: () => _openAddVariantDialog(context, engine, product.id),
                          icon: const Icon(Icons.add_circle_outline),
                          label: const Text('नया वजन पैकेट जोड़ें'),
                        )
                      ],
                    ),
                  )
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  void _openAddProductDialog(BuildContext context, ChinaGroupBuyEngine engine) {
    final nameCtrl = TextEditingController();
    final engCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('नया फल/सब्जी जोड़ें'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'हिंदी नाम')),
            TextField(controller: engCtrl, decoration: const InputDecoration(labelText: 'अंग्रेजी नाम')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('रद्द करें')),
          ElevatedButton(
            onPressed: () {
              if (nameCtrl.text.isNotEmpty) {
                engine.addProduct(
                  ProductItem(
                    id: 'P${DateTime.now().millisecondsSinceEpoch}',
                    nameHindi: nameCtrl.text,
                    nameEnglish: engCtrl.text,
                    category: 'ताजे फल',
                    variants: [],
                  ),
                );
                Navigator.pop(ctx);
              }
            },
            child: const Text('सेव करें'),
          )
        ],
      ),
    );
  }

  void _openAddVariantDialog(BuildContext context, ChinaGroupBuyEngine engine, String productId) {
    final labelCtrl = TextEditingController();
    final weightCtrl = TextEditingController();
    final priceCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('नया वजन पैकेट जोड़ें'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: labelCtrl, decoration: const InputDecoration(labelText: 'पैकेट नाम (उदा. 5 Kg पेटी)')),
            TextField(controller: weightCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'वजन (Kg)')),
            TextField(controller: priceCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'रेट (₹)')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('रद्द करें')),
          ElevatedButton(
            onPressed: () {
              if (labelCtrl.text.isNotEmpty && priceCtrl.text.isNotEmpty) {
                engine.addVariantToProduct(
                  productId,
                  WeightVariant(
                    id: 'V${DateTime.now().millisecondsSinceEpoch}',
                    label: labelCtrl.text,
                    weightInKg: double.tryParse(weightCtrl.text) ?? 1.0,
                    price: double.parse(priceCtrl.text),
                    mandiCostPrice: double.parse(priceCtrl.text) * 0.7,
                  ),
                );
                Navigator.pop(ctx);
              }
            },
            child: const Text('जोड़ें'),
          )
        ],
      ),
    );
  }
}
