import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ============================================================================
// 1. DOMAIN MODELS & ENTITIES
// ============================================================================

enum OrderSource {
  whatsapp,
  phoneCall,
  directShop,
  website,
  zomatoSwiggy,
  other,
}

extension OrderSourceExtension on OrderSource {
  String get displayName {
    switch (this) {
      case OrderSource.whatsapp:
        return 'व्हाट्सएप (WhatsApp)';
      case OrderSource.phoneCall:
        return 'फोन कॉल (Phone Call)';
      case OrderSource.directShop:
        return 'दुकान / ठेले से (Direct Visit)';
      case OrderSource.website:
        return 'वेबसाइट / ऑनलाइन (Website)';
      case OrderSource.zomatoSwiggy:
        return 'जोमैटो / स्विगी (Third Party)';
      case OrderSource.other:
        return 'अन्य (Other)';
    }
  }

  IconData get icon {
    switch (this) {
      case OrderSource.whatsapp:
        return Icons.chat_bubble_outline;
      case OrderSource.phoneCall:
        return Icons.phone_in_talk;
      case OrderSource.directShop:
        return Icons.storefront;
      case OrderSource.website:
        return Icons.language;
      case OrderSource.zomatoSwiggy:
        return Icons.delivery_dining;
      case OrderSource.other:
        return Icons.more_horiz;
    }
  }
}

enum OrderStatus {
  pending,
  confirmed,
  processing,
  outForDelivery,
  delivered,
  cancelled,
}

class Product {
  final String id;
  final String nameHindi;
  final String nameEnglish;
  final String category;
  final double unitPrice;
  final String unitType; // kg, dz, piece, etc.
  final int stockQuantity;
  final String imageUrl;
  final bool isAvailable;

  Product({
    required this.id,
    required this.nameHindi,
    required this.nameEnglish,
    required this.category,
    required this.unitPrice,
    required this.unitType,
    required this.stockQuantity,
    this.imageUrl = '',
    this.isAvailable = true,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nameHindi': nameHindi,
      'nameEnglish': nameEnglish,
      'category': category,
      'unitPrice': unitPrice,
      'unitType': unitType,
      'stockQuantity': stockQuantity,
      'imageUrl': imageUrl,
      'isAvailable': isAvailable ? 1 : 0,
    };
  }

  factory Product.fromMap(Map<String, dynamic> map) {
    return Product(
      id: map['id'],
      nameHindi: map['nameHindi'],
      nameEnglish: map['nameEnglish'],
      category: map['category'],
      unitPrice: map['unitPrice'].toDouble(),
      unitType: map['unitType'],
      stockQuantity: map['stockQuantity'],
      imageUrl: map['imageUrl'] ?? '',
      isAvailable: map['isAvailable'] == 1,
    );
  }
}

class OrderItem {
  final Product product;
  double quantity;
  double totalPrice;

  OrderItem({
    required this.product,
    required this.quantity,
  }) : totalPrice = product.unitPrice * quantity;

  void updateQuantity(double newQty) {
    quantity = newQty;
    totalPrice = product.unitPrice * quantity;
  }
}

class CustomerAddress {
  final String houseNoBuilding;
  final String streetArea;
  final String landmark;
  final String city;
  final String state;
  final String pincode;

  CustomerAddress({
    required this.houseNoBuilding,
    required this.streetArea,
    required this.landmark,
    required this.city,
    required this.state,
    required this.pincode,
  });

  String get fullFormattedAddress {
    List<String> parts = [
      if (houseNoBuilding.isNotEmpty) houseNoBuilding,
      if (streetArea.isNotEmpty) streetArea,
      if (landmark.isNotEmpty) 'निकट: $landmark',
      if (city.isNotEmpty) city,
      if (state.isNotEmpty) state,
      if (pincode.isNotEmpty) pincode,
    ];
    return parts.join(', ');
  }

  Map<String, dynamic> toMap() {
    return {
      'houseNoBuilding': houseNoBuilding,
      'streetArea': streetArea,
      'landmark': landmark,
      'city': city,
      'state': state,
      'pincode': pincode,
    };
  }

  factory CustomerAddress.fromMap(Map<String, dynamic> map) {
    return CustomerAddress(
      houseNoBuilding: map['houseNoBuilding'] ?? '',
      streetArea: map['streetArea'] ?? '',
      landmark: map['landmark'] ?? '',
      city: map['city'] ?? '',
      state: map['state'] ?? '',
      pincode: map['pincode'] ?? '',
    );
  }
}

class CustomerProfile {
  final String id;
  final String fullName;
  final String phoneNumber;
  final String alternatePhone;
  final CustomerAddress address;
  final String notes;

  CustomerProfile({
    required this.id,
    required this.fullName,
    required this.phoneNumber,
    this.alternatePhone = '',
    required this.address,
    this.notes = '',
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'fullName': fullName,
      'phoneNumber': phoneNumber,
      'alternatePhone': alternatePhone,
      'address': jsonEncode(address.toMap()),
      'notes': notes,
    };
  }

  factory CustomerProfile.fromMap(Map<String, dynamic> map) {
    return CustomerProfile(
      id: map['id'],
      fullName: map['fullName'],
      phoneNumber: map['phoneNumber'],
      alternatePhone: map['alternatePhone'] ?? '',
      address: CustomerAddress.fromMap(jsonDecode(map['address'])),
      notes: map['notes'] ?? '',
    );
  }
}

class OrderModel {
  final String orderId;
  final CustomerProfile customer;
  final List<OrderItem> items;
  final double subtotal;
  final double discount;
  final double deliveryCharge;
  final double grandTotal;
  final OrderSource orderSource;
  final OrderStatus status;
  final DateTime createdAt;
  final String paymentMode;
  final bool isPaid;

  OrderModel({
    required this.orderId,
    required this.customer,
    required this.items,
    required this.subtotal,
    required this.discount,
    required this.deliveryCharge,
    required this.grandTotal,
    required this.orderSource,
    required this.status,
    required this.createdAt,
    required this.paymentMode,
    required this.isPaid,
  });
}

// ============================================================================
// 2. MOCK DATA INITIALIZER & REPOSITORY
// ============================================================================

class AppRepository {
  static final AppRepository _instance = AppRepository._internal();
  factory AppRepository() => _instance;
  AppRepository._internal();

  final List<Product> _products = [
    Product(id: 'P001', nameHindi: 'चौसा आम', nameEnglish: 'Chausa Mango', category: 'फळ (Fruits)', unitPrice: 80.0, unitType: 'kg', stockQuantity: 150),
    Product(id: 'P002', nameHindi: 'दशहरी आम', nameEnglish: 'Dasheri Mango', category: 'फल (Fruits)', unitPrice: 65.0, unitType: 'kg', stockQuantity: 200),
    Product(id: 'P003', nameHindi: 'लंगड़ा आम', nameEnglish: 'Langra Mango', category: 'फल (Fruits)', unitPrice: 75.0, unitType: 'kg', stockQuantity: 100),
    Product(id: 'P004', nameHindi: 'सफेदा / बादामी', nameEnglish: 'Safeda Mango', category: 'फल (Fruits)', unitPrice: 55.0, unitType: 'kg', stockQuantity: 180),
    Product(id: 'P005', nameHindi: 'अल्फोंसो (हापुस)', nameEnglish: 'Alphonso Mango', category: 'फल (Fruits)', unitPrice: 180.0, unitType: 'kg', stockQuantity: 50),
    Product(id: 'P006', nameHindi: 'केला (चीनिया)', nameEnglish: 'Banana (Chiniya)', category: 'फल (Fruits)', unitPrice: 40.0, unitType: 'dz', stockQuantity: 80),
    Product(id: 'P007', nameHindi: 'केला (जी-9)', nameEnglish: 'Banana (G9)', category: 'फल (Fruits)', unitPrice: 50.0, unitType: 'dz', stockQuantity: 90),
    Product(id: 'P008', nameHindi: 'शाही लीची', nameEnglish: 'Shahi Litchi', category: 'फल (Fruits)', unitPrice: 120.0, unitType: 'kg', stockQuantity: 40),
    Product(id: 'P009', nameHindi: 'सेब (रॉयल ड डिलीशियस)', nameEnglish: 'Apple (Royal Delicious)', category: 'फल (Fruits)', unitPrice: 140.0, unitType: 'kg', stockQuantity: 60),
    Product(id: 'P010', nameHindi: 'अनार (कंधारी)', nameEnglish: 'Pomegranate', category: 'फल (Fruits)', unitPrice: 150.0, unitType: 'kg', stockQuantity: 70),
    Product(id: 'P011', nameHindi: 'अंगूर (काला)', nameEnglish: 'Black Grapes', category: 'फल (Fruits)', unitPrice: 90.0, unitType: 'kg', stockQuantity: 30),
    Product(id: 'P012', nameHindi: 'अंगूर (हरा)', nameEnglish: 'Green Grapes', category: 'फल (Fruits)', unitPrice: 70.0, unitType: 'kg', stockQuantity: 45),
    Product(id: 'P013', nameHindi: 'पपीता (डिस्को)', nameEnglish: 'Papaya', category: 'फल (Fruits)', unitPrice: 45.0, unitType: 'kg', stockQuantity: 110),
    Product(id: 'P014', nameHindi: 'संतरा (नागपुरी)', nameEnglish: 'Orange (Nagpur)', category: 'फल (Fruits)', unitPrice: 80.0, unitType: 'kg', stockQuantity: 65),
    Product(id: 'P015', nameHindi: 'मौसमी', nameEnglish: 'Mosambi', category: 'फल (Fruits)', unitPrice: 60.0, unitType: 'kg', stockQuantity: 85),
    Product(id: 'P016', nameHindi: 'तरबूज', nameEnglish: 'Watermelon', category: 'फल (Fruits)', unitPrice: 25.0, unitType: 'kg', stockQuantity: 200),
    Product(id: 'P017', nameHindi: 'खरबूजा', nameEnglish: 'Muskmelon', category: 'फल (Fruits)', unitPrice: 40.0, unitType: 'kg', stockQuantity: 120),
    Product(id: 'P018', nameHindi: 'अमरूद (इलाहाबादी)', nameEnglish: 'Guava', category: 'फल (Fruits)', unitPrice: 50.0, unitType: 'kg', stockQuantity: 75),
    Product(id: 'P019', nameHindi: 'चीकू', nameEnglish: 'Chiku', category: 'फल (Fruits)', unitPrice: 60.0, unitType: 'kg', stockQuantity: 50),
    Product(id: 'P020', nameHindi: 'नारियल पानी', nameEnglish: 'Green Coconut', category: 'फल (Fruits)', unitPrice: 60.0, unitType: 'piece', stockQuantity: 100),
  ];

  final List<OrderModel> _orderHistory = [];

  List<Product> getAllProducts() => List.unmodifiable(_products);

  List<Product> searchProducts(String query) {
    if (query.trim().isEmpty) return getAllProducts();
    final q = query.toLowerCase();
    return _products.where((p) {
      return p.nameHindi.toLowerCase().contains(q) ||
          p.nameEnglish.toLowerCase().contains(q) ||
          p.id.toLowerCase().contains(q);
    }).toList();
  }

  void saveOrder(OrderModel order) {
    _orderHistory.insert(0, order);
  }

  List<OrderModel> getOrders() => List.unmodifiable(_orderHistory);
}

// ============================================================================
// 3. MAIN APP & STATE MANAGEMENT PROVIDERS
// ============================================================================

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  runApp(const MultiStoreApp());
}

class MultiStoreApp extends StatelessWidget {
  const MultiStoreApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'स्मार्ट फ्रूट & ऑर्डर ट्रैकर PRO',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF00875A),
          primary: const Color(0xFF00875A),
          secondary: const Color(0xFFE65100),
          surface: const Color(0xFFF8F9FA),
        ),
        fontFamily: 'Roboto',
        appBarTheme: const AppBarTheme(
          elevation: 0,
          centerTitle: true,
          backgroundColor: Color(0xFF00875A),
          foregroundColor: Colors.white,
          titleTextStyle: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        cardTheme: CardTheme(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Colors.grey),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFF00875A), width: 2),
          ),
        ),
      ),
      home: const MainDashboardScreen(),
    );
  }
}

// ============================================================================
// 4. MAIN DASHBOARD CONTAINER
// ============================================================================

class MainDashboardScreen extends StatefulWidget {
  const MainDashboardScreen({super.key});

  @override
  State<MainDashboardScreen> createState() => _MainDashboardScreenState();
}

class _MainDashboardScreenState extends State<MainDashboardScreen> {
  int _currentIndex = 0;

  final List<Widget> _pages = [
    const CreateOrderScreen(),
    const OrderHistoryScreen(),
    const ProductInventoryScreen(),
    const AnalyticsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: const Color(0xFF00875A),
        unselectedItemColor: Colors.grey.shade600,
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold),
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.add_shopping_cart),
            activeIcon: Icon(Icons.add_shopping_cart, size: 28),
            label: 'नया ऑर्डर',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.receipt_long),
            activeIcon: Icon(Icons.receipt_long, size: 28),
            label: 'ऑर्डर्स',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.inventory_2),
            activeIcon: Icon(Icons.inventory_2, size: 28),
            label: 'आइटम लिस्ट',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.analytics),
            activeIcon: Icon(Icons.analytics, size: 28),
            label: 'रिपोर्ट्स',
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// 5. SCREEN 1: CREATE NEW ORDER (WITH ADVANCED SEARCH & CUSTOMER PANEL)
// ============================================================================

class CreateOrderScreen extends StatefulWidget {
  const CreateOrderScreen({super.key});

  @override
  State<CreateOrderScreen> createState() => _CreateOrderScreenState();
}

class _CreateOrderScreenState extends State<CreateOrderScreen> {
  final AppRepository _repository = AppRepository();
  final _formKey = GlobalKey<FormState>();

  // Search State
  final TextEditingController _searchController = TextEditingController();
  List<Product> _filteredProducts = [];
  bool _isSearching = false;

  // Selected Cart Items
  final Map<String, OrderItem> _cartItems = {};

  // Customer Form Controllers
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _altPhoneController = TextEditingController();
  final TextEditingController _houseController = TextEditingController();
  final TextEditingController _streetController = TextEditingController();
  final TextEditingController _landmarkController = TextEditingController();
  final TextEditingController _cityController = TextEditingController(text: 'फरीदाबाद');
  final TextEditingController _stateController = TextEditingController(text: 'हरियाणा');
  final TextEditingController _pincodeController = TextEditingController(text: '121001');
  final TextEditingController _discountController = TextEditingController(text: '0');
  final TextEditingController _deliveryChargeController = TextEditingController(text: '0');
  final TextEditingController _notesController = TextEditingController();

  OrderSource _selectedOrderSource = OrderSource.whatsapp;
  String _selectedPaymentMode = 'कैश ऑन डिलीवरी (COD)';
  bool _isPaid = false;

  @override
  void initState() {
    super.initState();
    _filteredProducts = _repository.getAllProducts();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _altPhoneController.dispose();
    _houseController.dispose();
    _streetController.dispose();
    _landmarkController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _pincodeController.dispose();
    _discountController.dispose();
    _deliveryChargeController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      _filteredProducts = _repository.searchProducts(_searchController.text);
      _isSearching = _searchController.text.isNotEmpty;
    });
  }

  void _addToCart(Product product) {
    setState(() {
      if (_cartItems.containsKey(product.id)) {
        _cartItems[product.id]!.updateQuantity(_cartItems[product.id]!.quantity + 1);
      } else {
        _cartItems[product.id] = OrderItem(product: product, quantity: 1.0);
      }
    });
  }

  void _removeFromCart(String productId) {
    setState(() {
      _cartItems.remove(productId);
    });
  }

  void _updateItemQuantity(String productId, double change) {
    if (!_cartItems.containsKey(productId)) return;
    setState(() {
      double newQty = _cartItems[productId]!.quantity + change;
      if (newQty <= 0) {
        _cartItems.remove(productId);
      } else {
        _cartItems[productId]!.updateQuantity(newQty);
      }
    });
  }

  double get _subtotal {
    double total = 0.0;
    _cartItems.forEach((key, item) {
      total += item.totalPrice;
    });
    return total;
  }

  double get _discount => double.tryParse(_discountController.text) ?? 0.0;
  double get _deliveryCharge => double.tryParse(_deliveryChargeController.text) ?? 0.0;
  double get _grandTotal => (_subtotal - _discount + _deliveryCharge).clamp(0, double.infinity);

  void _submitOrder() {
    if (_cartItems.isEmpty) {
      _showSnackBar('कृपया कम से कम एक आइटम चुनें!', Colors.red);
      return;
    }

    if (!_formKey.currentState!.validate()) {
      _showSnackBar('कृपया सभी अनिवार्य फ़ील्ड भरें!', Colors.orange);
      return;
    }

    final customer = CustomerProfile(
      id: 'CUST-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
      fullName: _nameController.text.trim(),
      phoneNumber: _phoneController.text.trim(),
      alternatePhone: _altPhoneController.text.trim(),
      address: CustomerAddress(
        houseNoBuilding: _houseController.text.trim(),
        streetArea: _streetController.text.trim(),
        landmark: _landmarkController.text.trim(),
        city: _cityController.text.trim(),
        state: _stateController.text.trim(),
        pincode: _pincodeController.text.trim(),
      ),
      notes: _notesController.text.trim(),
    );

    final order = OrderModel(
      orderId: 'ORD-${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}',
      customer: customer,
      items: _cartItems.values.toList(),
      subtotal: _subtotal,
      discount: _discount,
      deliveryCharge: _deliveryCharge,
      grandTotal: _grandTotal,
      orderSource: _selectedOrderSource,
      status: OrderStatus.confirmed,
      createdAt: DateTime.now(),
      paymentMode: _selectedPaymentMode,
      isPaid: _isPaid,
    );

    _repository.saveOrder(order);
    _showOrderSuccessDialog(order);
  }

  void _resetForm() {
    setState(() {
      _cartItems.clear();
      _nameController.clear();
      _phoneController.clear();
      _altPhoneController.clear();
      _houseController.clear();
      _streetController.clear();
      _landmarkController.clear();
      _notesController.clear();
      _discountController.text = '0';
      _deliveryChargeController.text = '0';
      _selectedOrderSource = OrderSource.whatsapp;
      _selectedPaymentMode = 'कैश ऑन डिलीवरी (COD)';
      _isPaid = false;
      _searchController.clear();
    });
  }

  void _showSnackBar(String text, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text, style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showOrderSuccessDialog(OrderModel order) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 30),
            SizedBox(width: 10),
            Text('ऑर्डर सेव हो गया!'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('ऑर्डर ID: ${order.orderId}', style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 5),
            Text('कस्टमर: ${order.customer.fullName}'),
            Text('फोन: ${order.customer.phoneNumber}'),
            Text('कुल राशि: ₹${order.grandTotal.toStringAsFixed(2)}'),
            Text('स्त्रोत: ${order.orderSource.displayName}'),
            const SizedBox(height: 10),
            const Divider(),
            Text('एड्रेस: ${order.customer.address.fullFormattedAddress}', style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _resetForm();
            },
            child: const Text('नया ऑर्डर बनाएं'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00875A)),
            onPressed: () {
              Navigator.pop(context);
              _resetForm();
            },
            child: const Text('रसीद प्रिंट करें', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('स्मार्ट ऑर्डर पैनल'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'फॉर्म रीसेट करें',
            onPressed: _resetForm,
          )
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(12.0),
          children: [
            // ==========================================
            // SECTION 1: SEARCH & ITEM LIST SELECTION
            // ==========================================
            _buildHeaderCard(
              title: '1. सामान खोजें एवं जोड़ें (Item Search)',
              icon: Icons.search,
              color: Colors.blue.shade700,
            ),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  children: [
                    TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'आइटम का नाम खोजें (उदा. Chausa, केला, P001)...',
                        prefixIcon: const Icon(Icons.search, color: Color(0xFF00875A)),
                        suffixIcon: _isSearching
                            ? IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () => _searchController.clear(),
                              )
                            : null,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      height: 220,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: _filteredProducts.isNotEmpty
                          ? ListView.separated(
                              itemCount: _filteredProducts.length,
                              separatorBuilder: (ctx, idx) => const Divider(height: 1),
                              itemBuilder: (context, index) {
                                final product = _filteredProducts[index];
                                final inCart = _cartItems.containsKey(product.id);
                                return ListTile(
                                  dense: true,
                                  title: Text(
                                    '${product.nameHindi} (${product.nameEnglish})',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                  ),
                                  subtitle: Text('कोड: ${product.id} | स्टॉक: ${product.stockQuantity} ${product.unitType}'),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        '₹${product.unitPrice}/${product.unitType}',
                                        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green, fontSize: 14),
                                      ),
                                      const SizedBox(width: 8),
                                      IconButton(
                                        icon: Icon(
                                          inCart ? Icons.add_circle : Icons.add_circle_outline,
                                          color: const Color(0xFF00875A),
                                        ),
                                        onPressed: () => _addToCart(product),
                                      )
                                    ],
                                  ),
                                );
                              },
                            )
                          : const Center(
                              child: Text('कोई आइटम नहीं मिला!'),
                            ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // ==========================================
            // SECTION 2: CART SUMMARY & QUANTITY ADJUSTMENT
            // ==========================================
            if (_cartItems.isNotEmpty) ...[
              _buildHeaderCard(
                title: 'च चुने गए आइटम (Cart: ${_cartItems.length})',
                icon: Icons.shopping_basket,
                color: Colors.orange.shade800,
              ),
              const SizedBox(height: 8),
              Card(
                color: Colors.orange.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    children: _cartItems.values.map((item) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4.0),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: Text(
                                '${item.product.nameHindi} (${item.product.nameEnglish})',
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                            ),
                            Row(
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                                  onPressed: () => _updateItemQuantity(item.product.id, -0.5),
                                ),
                                Text(
                                  '${item.quantity} ${item.product.unitType}',
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.add_circle_outline, color: Colors.green),
                                  onPressed: () => _updateItemQuantity(item.product.id, 0.5),
                                ),
                              ],
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                '₹${item.totalPrice.toStringAsFixed(1)}',
                                textAlign: TextAlign.right,
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                              onPressed: () => _removeFromCart(item.product.id),
                            )
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // ==========================================
            // SECTION 3: ORDER SOURCE SELECTION
            // ==========================================
            _buildHeaderCard(
              title: '2. ऑर्डर कहाँ से आया है? (Order Source)',
              icon: Icons.alt_route,
              color: Colors.purple.shade700,
            ),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: DropdownButtonFormField<OrderSource>(
                  value: _selectedOrderSource,
                  decoration: const InputDecoration(
                    labelText: 'ऑर्डर का जरिया/माध्यम चुनें',
                    prefixIcon: Icon(Icons.storefront, color: Colors.purple),
                  ),
                  items: OrderSource.values.map((OrderSource source) {
                    return DropdownMenuItem<OrderSource>(
                      value: source,
                      child: Row(
                        children: [
                          Icon(source.icon, color: Colors.purple, size: 20),
                          const SizedBox(width: 10),
                          Text(source.displayName),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (OrderSource? newValue) {
                    if (newValue != null) {
                      setState(() {
                        _selectedOrderSource = newValue;
                      });
                    }
                  },
                ),
              ),
            ),

            const SizedBox(height: 16),

            // ==========================================
            // SECTION 4: CUSTOMER DETAILS & ADDRESS PANEL
            // ==========================================
            _buildHeaderCard(
              title: '3. कस्टमर एवं डिलीवरी एड्रेस PANEL',
              icon: Icons.location_on,
              color: const Color(0xFF00875A),
            ),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  children: [
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'कस्टमर का नाम *',
                        prefixIcon: Icon(Icons.person),
                      ),
                      validator: (v) => v == null || v.trim().isEmpty ? 'नाम दर्ज करना जरूरी है' : null,
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _phoneController,
                            keyboardType: TextInputType.phone,
                            decoration: const InputDecoration(
                              labelText: 'मोबाइल नंबर *',
                              prefixIcon: Icon(Icons.phone),
                            ),
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) return 'नंबर दर्ज करें';
                              if (v.trim().length < 10) return 'वैध 10-अंकीय नंबर डालें';
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextFormField(
                            controller: _altPhoneController,
                            keyboardType: TextInputType.phone,
                            decoration: const InputDecoration(
                              labelText: 'दूसरा नंबर (Optional)',
                              prefixIcon: Icon(Icons.phone_android),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _houseController,
                      decoration: const InputDecoration(
                        labelText: 'मकान नंबर / बिल्डिंग / फ्लैट नंबर *',
                        prefixIcon: Icon(Icons.home),
                      ),
                      validator: (v) => v == null || v.trim().isEmpty ? 'मकान नंबर दर्ज करें' : null,
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _streetController,
                      decoration: const InputDecoration(
                        labelText: 'गली नंबर / रोड / मोहल्ला / सेक्टर *',
                        prefixIcon: Icon(Icons.streetview),
                      ),
                      validator: (v) => v == null || v.trim().isEmpty ? 'गली या रोड का नाम दर्ज करें' : null,
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _landmarkController,
                      decoration: const InputDecoration(
                        labelText: 'लैंडमार्क (मशहूर जगह जैसे- मंदिर, स्कूल, अस्पताल)',
                        prefixIcon: Icon(Icons.near_me),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _cityController,
                            decoration: const InputDecoration(
                              labelText: 'शहर / जिला',
                              prefixIcon: Icon(Icons.location_city),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextFormField(
                            controller: _stateController,
                            decoration: const InputDecoration(
                              labelText: 'राज्य',
                              prefixIcon: Icon(Icons.map),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextFormField(
                            controller: _pincodeController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'पिनकोड',
                              prefixIcon: Icon(Icons.pin_drop),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _notesController,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'विशेष निर्देश / डिलीवरी नोट (Optional)',
                        prefixIcon: Icon(Icons.note_alt),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // ==========================================
            // SECTION 5: BILLING & PAYMENT DETAILS
            // ==========================================
            _buildHeaderCard(
              title: '4. बिल एवं भुगतान (Billing & Payment)',
              icon: Icons.payments,
              color: Colors.teal.shade800,
            ),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _discountController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'डिस्काउंट (₹)',
                              prefixIcon: Icon(Icons.discount),
                            ),
                            onChanged: (v) => setState(() {}),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextFormField(
                            controller: _deliveryChargeController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'डिलीवरी चार्ज (₹)',
                              prefixIcon: Icon(Icons.local_shipping),
                            ),
                            onChanged: (v) => setState(() {}),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      value: _selectedPaymentMode,
                      decoration: const InputDecoration(
                        labelText: 'पेमेंट का तरीका',
                        prefixIcon: Icon(Icons.account_balance_wallet),
                      ),
                      items: ['कैश ऑन डिलीवरी (COD)', 'PhonePe / UPI', 'Paytm', 'Google Pay', 'बैंक ट्रांसफर', 'उधार / बाकी']
                          .map((mode) => DropdownMenuItem(value: mode, child: Text(mode)))
                          .toList(),
                      onChanged: (val) => setState(() => _selectedPaymentMode = val!),
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      title: const Text('क्या पेमेंट प्राप्त हो गया है? (Paid Status)'),
                      subtitle: Text(_isPaid ? 'हाँ (Paid)' : 'नहीं (Pending)'),
                      value: _isPaid,
                      activeColor: Colors.green,
                      onChanged: (val) => setState(() => _isPaid = val),
                    ),
                    const Divider(),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        children: [
                          _buildBillRow('कुल सामान का मूल्य (Subtotal):', '₹${_subtotal.toStringAsFixed(2)}'),
                          _buildBillRow('डिस्काउंट (Discount):', '- ₹${_discount.toStringAsFixed(2)}', color: Colors.red),
                          _buildBillRow('डिलीवरी शुल्क (Delivery):', '+ ₹${_deliveryCharge.toStringAsFixed(2)}'),
                          const Divider(),
                          _buildBillRow(
                            'कुल देय राशि (Grand Total):',
                            '₹${_grandTotal.toStringAsFixed(2)}',
                            isBold: true,
                            size: 18,
                            color: const Color(0xFF00875A),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // SUBMIT BUTTON
            SizedBox(
              height: 55,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00875A),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.check_circle_outline, size: 28, color: Colors.white),
                label: const Text(
                  'ऑर्डर कन्फर्म करें एवं सेव करें',
                  style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold),
                ),
                onPressed: _submitOrder,
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderCard({required String title, required IconData icon, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 22),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
          ),
        ],
      ),
    );
  }

  Widget _buildBillRow(String label, String value, {bool isBold = false, double size = 14, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: size, fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
          Text(
            value,
            style: TextStyle(
              fontSize: size,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: color ?? Colors.black,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// 6. SCREEN 2: ORDER HISTORY & ADDRESS VIEWER
// ============================================================================

class OrderHistoryScreen extends StatefulWidget {
  const OrderHistoryScreen({super.key});

  @override
  State<OrderHistoryScreen> createState() => _OrderHistoryScreenState();
}

class _OrderHistoryScreenState extends State<OrderHistoryScreen> {
  final AppRepository _repository = AppRepository();

  @override
  Widget build(BuildContext context) {
    final orders = _repository.getOrders();

    return Scaffold(
      appBar: AppBar(
        title: Text('सभी ऑर्डर्स (${orders.length})'),
      ),
      body: orders.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.assignment_outlined, size: 80, color: Colors.grey.shade400),
                  const SizedBox(height: 10),
                  Text('अभी तक कोई ऑर्डर दर्ज नहीं हुआ है!', style: TextStyle(color: Colors.grey.shade600, fontSize: 16)),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: orders.length,
              itemBuilder: (context, index) {
                final order = orders[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ExpansionTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.green.shade100,
                      child: Icon(order.orderSource.icon, color: const Color(0xFF00875A)),
                    ),
                    title: Text('${order.customer.fullName} - ₹${order.grandTotal.toStringAsFixed(0)}',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('ID: ${order.orderId} | स्त्रोत: ${order.orderSource.displayName}'),
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Divider(),
                            Text('📱 फोन: ${order.customer.phoneNumber}', style: const TextStyle(fontWeight: FontWeight.w500)),
                            const SizedBox(height: 4),
                            Text('📍 पता: ${order.customer.address.fullFormattedAddress}'),
                            const SizedBox(height: 8),
                            const Text('📦 खरीदे गए सामान:', style: TextStyle(fontWeight: FontWeight.bold)),
                            ...order.items.map((i) => Text(' • ${i.product.nameHindi}: ${i.quantity} ${i.product.unitType} = ₹${i.totalPrice}')),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('भुगतान मोड: ${order.paymentMode}'),
                                Chip(
                                  label: Text(order.isPaid ? 'Paid' : 'Pending', style: const TextStyle(color: Colors.white, fontSize: 12)),
                                  backgroundColor: order.isPaid ? Colors.green : Colors.red,
                                )
                              ],
                            )
                          ],
                        ),
                      )
                    ],
                  ),
                );
              },
            ),
    );
  }
}

// ============================================================================
// 7. SCREEN 3: PRODUCT INVENTORY SEARCH
// ============================================================================

class ProductInventoryScreen extends StatefulWidget {
  const ProductInventoryScreen({super.key});

  @override
  State<ProductInventoryScreen> createState() => _ProductInventoryScreenState();
}

class _ProductInventoryScreenState extends State<ProductInventoryScreen> {
  final AppRepository _repository = AppRepository();
  final TextEditingController _searchController = TextEditingController();
  List<Product> _products = [];

  @override
  void initState() {
    super.initState();
    _products = _repository.getAllProducts();
    _searchController.addListener(() {
      setState(() {
        _products = _repository.searchProducts(_searchController.text);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('आइटम एवं रेट लिस्ट'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                hintText: 'स्टॉक में खोजें...',
                prefixIcon: Icon(Icons.search),
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _products.length,
              itemBuilder: (context, index) {
                final product = _products[index];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.blue.shade50,
                    child: Text(product.id.substring(1)),
                  ),
                  title: Text('${product.nameHindi} (${product.nameEnglish})', style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('स्टॉक: ${product.stockQuantity} ${product.unitType}'),
                  trailing: Text('₹${product.unitPrice}/${product.unitType}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.green)),
                );
              },
            ),
          )
        ],
      ),
    );
  }
}

// ============================================================================
// 8. SCREEN 4: ANALYTICS & SOURCE REPORTING
// ============================================================================

class AnalyticsScreen extends StatelessWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final repository = AppRepository();
    final orders = repository.getOrders();

    double totalRevenue = 0;
    Map<OrderSource, int> sourceCount = {};

    for (var o in orders) {
      totalRevenue += o.grandTotal;
      sourceCount[o.orderSource] = (sourceCount[o.orderSource] ?? 0) + 1;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('बिक्री एवं ऑर्डर रिपोर्ट'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            color: const Color(0xFF00875A),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                children: [
                  const Text('कुल बिक्री (Total Revenue)', style: TextStyle(color: Colors.white, fontSize: 16)),
                  const SizedBox(height: 8),
                  Text('₹${totalRevenue.toStringAsFixed(2)}', style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text('कुल ऑर्डर्स: ${orders.length}', style: const TextStyle(color: Colors.white70)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text('ऑर्डर के मुख्य स्रोत (Order Sources):', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          ...OrderSource.values.map((source) {
            final count = sourceCount[source] ?? 0;
            return Card(
              child: ListTile(
                leading: Icon(source.icon, color: Colors.purple),
                title: Text(source.displayName),
                trailing: Text('$count ऑर्डर्स', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            );
          }),
        ],
      ),
    );
  }
}
