import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

void main() {
  runApp(const CakeAppEnterpriseApp());
}

class CakeAppEnterpriseApp extends StatelessWidget {
  const CakeAppEnterpriseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CakeApp - Ultra Premium Edition',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.dark(
          primary: const Color(0xFFF59E0B), // Rich Neon Gold / Amber
          secondary: const Color(0xFFEC4899), // Vibrant Pink Accent
          surface: const Color(0xFF1E293B), // Dark Slate Card BG
          background: const Color(0xFF0F172A), // Deep Rich Dark Background
        ),
        scaffoldBackgroundColor: const Color(0xFF0F172A),
        cardColor: const Color(0xFF1E293B),
      ),
      home: const CakeMainHubScreen(),
    );
  }
}

// ==========================================
// CENTRAL DATABASE & CLOUD SYNC MODEL
// ==========================================
class CakeDatabase {
  static String firebaseRestUrl = "https://viziagmart-default-rtdb.firebaseio.com/"; 

  static String currentUserPhone = "9971968060";
  static String currentCustomerName = "Tarun Kumar";
  static String currentDeliveryAddress = "Sector 15A Faridabad";

  static Map<String, dynamic> bakeryShop = {
    'shopId': 'shop_cake_01',
    'shopName': 'Tarun Fruit & Vegetable Shop',
    'ownerName': 'Tarun Kumar',
    'ownerPhone': '9971968060',
    'ownerPhotoPath': '', 
    'bannerPhotoPath': '',
    'shopPhotoPath': '',
    'phone': '9971968060',
    'whatsappNumber': '919971968060',
    'address': 'Sector 15A Ajronda Sabji Mandi, Faridabad',
    'bio': 'ताज़ा फल, सब्जियां और बेकरी उत्पाद उपलब्ध।',
    'isOpen': true,
  };

  static List<Map<String, dynamic>> productInventory = [];
  static List<Map<String, dynamic>> cartItems = [];
}

// ==========================================
// MAIN HUB SCREEN WITH INDEXED STACK
// ==========================================
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
    const CartAndWhatsAppCheckoutView(),
  ];

  @override
  Widget build(BuildContext context) {
    int totalCartCount = CakeDatabase.cartItems.fold(0, (sum, item) => sum + ((item['qty'] as num?)?.toInt() ?? 1));

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(75),
        child: AppBar(
          backgroundColor: const Color(0xFF0B0F19),
          elevation: 4,
          shadowColor: const Color(0xFFF59E0B).withOpacity(0.3),
          title: Row(
            children: [
              ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(
                  colors: [Color(0xFFF59E0B), Color(0xFFEF4444), Color(0xFFEC4899)],
                ).createShader(bounds),
                child: const Text(
                  'CAKEAPP',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: 1.5),
                ),
              ),
              const Spacer(),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF59E0B),
                  foregroundColor: Colors.black87,
                  elevation: 6,
                  shadowColor: const Color(0xFFF59E0B).withOpacity(0.5),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: () => setState(() => _selectedTabIndex = 0),
                icon: const Icon(Icons.cake, size: 14),
                label: const Text('Shop', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 6),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF334155),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: () => setState(() => _selectedTabIndex = 1),
                icon: const Icon(Icons.lock_outline, size: 14),
                label: const Text('Vendor', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(32),
            child: Container(
              color: const Color(0xFF1E293B),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => _showProfileEditDialog(context),
                    child: Row(
                      children: [
                        const Icon(Icons.person_pin_circle, color: Color(0xFFF59E0B), size: 15),
                        const SizedBox(width: 6),
                        Text(
                          CakeDatabase.currentCustomerName,
                          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => _showProfileEditDialog(context),
                    child: const Text('(Edit Profile & Address)', style: TextStyle(color: Color(0xFFF59E0B), fontSize: 10, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0F172A), Color(0xFF1E1B4B)],
          ),
        ),
        child: IndexedStack(
          index: _selectedTabIndex > 2 ? 2 : _selectedTabIndex,
          children: _tabScreens,
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedTabIndex > 2 ? 2 : _selectedTabIndex,
        selectedItemColor: const Color(0xFFF59E0B),
        unselectedItemColor: Colors.grey.shade400,
        backgroundColor: const Color(0xFF0B0F19),
        type: BottomNavigationBarType.fixed,
        onTap: (index) {
          setState(() => _selectedTabIndex = index);
        },
        items: [
          const BottomNavigationBarItem(icon: Icon(Icons.storefront_outlined), label: 'Shop'),
          const BottomNavigationBarItem(icon: Icon(Icons.admin_panel_settings_outlined), label: 'Vendor'),
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
                      decoration: const BoxDecoration(color: Color(0xFFEF4444), shape: BoxShape.circle),
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
          backgroundColor: const Color(0xFF1E293B),
          title: const Text('Edit Profile & Address', style: TextStyle(fontSize: 15, color: Color(0xFFF59E0B), fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Name', isDense: true)),
                const SizedBox(height: 10),
                TextField(controller: phoneCtrl, decoration: const InputDecoration(labelText: 'Phone', isDense: true)),
                const SizedBox(height: 10),
                TextField(controller: addressCtrl, decoration: const InputDecoration(labelText: 'Address / Location Note', isDense: true)),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel', style: TextStyle(color: Colors.grey))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF59E0B), foregroundColor: Colors.black87),
              onPressed: () {
                setState(() {
                  CakeDatabase.currentCustomerName = nameCtrl.text.trim();
                  CakeDatabase.currentUserPhone = phoneCtrl.text.trim();
                  CakeDatabase.currentDeliveryAddress = addressCtrl.text.trim();
                });
                Navigator.pop(context);
              },
              child: const Text('Save', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }
}

// ==========================================
// IMAGE HELPER
// ==========================================
Widget buildShopOrProdImage(String? path, double height, double width, IconData fallbackIcon) {
  if (path != null && path.isNotEmpty) {
    if (path.startsWith('http')) {
      return Image.network(path, height: height, width: width, fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => Container(height: height, width: width, color: const Color(0xFF334155), child: Icon(fallbackIcon, size: height * 0.4, color: const Color(0xFFF59E0B))));
    } else if (path.startsWith('data:image')) {
      try {
        final bytes = base64Decode(path.split(',').last);
        return Image.memory(bytes, height: height, width: width, fit: BoxFit.cover);
      } catch (_) {}
    } else if (File(path).existsSync()) {
      return Image.file(File(path), height: height, width: width, fit: BoxFit.cover);
    }
  }
  return Container(
    height: height,
    width: width,
    decoration: BoxDecoration(
      gradient: const LinearGradient(colors: [Color(0xFF334155), Color(0xFF1E293B)]),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Icon(fallbackIcon, size: height * 0.4, color: const Color(0xFFF59E0B)),
  );
}

// ==========================================
// MARKETPLACE BUYER VIEW (DIRECT CAKES)
// ==========================================
class MarketplaceBuyerView extends StatefulWidget {
  const MarketplaceBuyerView({super.key});

  @override
  State<MarketplaceBuyerView> createState() => _MarketplaceBuyerViewState();
}

class _MarketplaceBuyerViewState extends State<MarketplaceBuyerView> {
  String selectedCategory = 'All';
  bool _isLoadingCloud = false;
  
  final Map<String, double> _itemQuantities = {};
  final Map<String, TextEditingController> _cakeMessageControllers = {};
  final Map<String, TextEditingController> _qtyControllers = {};

  final List<String> cakeCategories = [
    'All',
    'Birthday Cake',
    'Anniversary Cake',
    'Chocolate Cake',
    'Kids / Cartoon Cake',
    'Fruit Cake',
    'Red Velvet',
    'Heart Shaped Cake',
    'Tier / Wedding Cake',
    'Cupcakes & Pastries',
    'Designer / Custom Cake',
    'Truffle Cake',
    'Butterscotch',
    'Black Forest',
    'Pineapple Cake',
    'Strawberry Cake',
    'Coffee / Mocha Cake',
    'Photo Cake',
    'Combos (Cake + Flowers)',
    'Midnight Special Cake',
    'Fasting / Eggless Special'
  ];

  @override
  void initState() {
    super.initState();
    _fetchShopProfileAndProducts();
  }

  @override
  void dispose() {
    for (var ctrl in _cakeMessageControllers.values) {
      ctrl.dispose();
    }
    for (var ctrl in _qtyControllers.values) {
      ctrl.dispose();
    }
    super.dispose();
  }

  Future<void> _fetchShopProfileAndProducts() async {
    setState(() => _isLoadingCloud = true);
    try {
      final shopRes = await http.get(Uri.parse('${CakeDatabase.firebaseRestUrl}/shop_profile.json'));
      if (shopRes.statusCode == 200 && shopRes.body != 'null' && shopRes.body.isNotEmpty) {
        var data = json.decode(shopRes.body);
        if (data is Map) {
          setState(() {
            CakeDatabase.bakeryShop = Map<String, dynamic>.from(data);
          });
        }
      }

      final response = await http.get(Uri.parse('${CakeDatabase.firebaseRestUrl}/products.json'));
      if (response.statusCode == 200 && response.body != 'null' && response.body.isNotEmpty) {
        Map<String, dynamic> data = json.decode(response.body);
        List<Map<String, dynamic>> fetchedList = [];
        data.forEach((key, value) {
          var item = Map<String, dynamic>.from(value);
          item['firebaseKey'] = key;
          fetchedList.add(item);
        });
        setState(() {
          CakeDatabase.productInventory = fetchedList.reversed.toList();
        });
      }
    } catch (e) {
      debugPrint("Cloud sync error: $e");
    } finally {
      if (mounted) setState(() => _isLoadingCloud = false);
    }
  }

  void _addToCart(Map<String, dynamic> prod, double qty, String cakeMsg) {
    if (CakeDatabase.bakeryShop['isOpen'] == false) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('⚠️ Sorry! Shop is currently CLOSED.'), backgroundColor: Colors.red));
      return;
    }
    if (prod['inStock'] == false) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('⚠️ This item is currently OUT OF STOCK!')));
      return;
    }

    String prodName = prod['name'];
    var existingIndex = CakeDatabase.cartItems.indexWhere((item) => item['name'] == prodName);

    setState(() {
      if (existingIndex >= 0) {
        CakeDatabase.cartItems[existingIndex]['qty'] = qty;
        CakeDatabase.cartItems[existingIndex]['cakeMessage'] = cakeMsg;
      } else {
        CakeDatabase.cartItems.add({
          'name': prodName,
          'price': prod['price'],
          'unit': prod['unit'] ?? 'Piece',
          'qty': qty,
          'cakeMessage': cakeMsg,
          'shopName': CakeDatabase.bakeryShop['shopName'],
        });
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('🛒 Added $qty ${prod['unit'] ?? 'Piece'} $prodName to Cart!'), backgroundColor: const Color(0xFFF59E0B), duration: const Duration(milliseconds: 900)),
    );
  }

  @override
  Widget build(BuildContext context) {
    var filteredProducts = CakeDatabase.productInventory.where((p) {
      if (selectedCategory == 'All') return true;
      return p['category'] == selectedCategory;
    }).toList();

    var shop = CakeDatabase.bakeryShop;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          // Ultra High-End Shop Header Card with Glassmorphism & Gold Border
          Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.5), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFF59E0B).withOpacity(0.15),
                  blurRadius: 12,
                  spreadRadius: 2,
                )
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if ((shop['bannerPhotoPath'] ?? '').toString().isNotEmpty)
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
                    child: buildShopOrProdImage(shop['bannerPhotoPath'], 140, double.infinity, Icons.store),
                  ),
                Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Row(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFF59E0B), width: 1.5),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(9),
                          child: buildShopOrProdImage(shop['shopPhotoPath'] ?? shop['ownerPhotoPath'], 65, 65, Icons.store),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              shop['shopName'] ?? 'Tarun Fruit & Vegetable Shop',
                              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: Color(0xFFF59E0B)),
                            ),
                            const SizedBox(height: 3),
                            Text('👤 Owner: ${shop['ownerName'] ?? 'Tarun Kumar'}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white70)),
                            const SizedBox(height: 2),
                            Text('📍 ${shop['address'] ?? 'Faridabad'}', style: TextStyle(fontSize: 10, color: Colors.grey.shade400)),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: _fetchShopProfileAndProducts,
                        icon: const Icon(Icons.sync, color: Color(0xFFF59E0B)),
                        tooltip: 'Sync Shop & Products',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Categories Horizontal Scroll with Premium Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: cakeCategories.map((category) {
                bool isSelected = selectedCategory == category;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(category, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isSelected ? Colors.black87 : Colors.white70)),
                    selected: isSelected,
                    selectedColor: const Color(0xFFF59E0B),
                    backgroundColor: const Color(0xFF1E293B),
                    elevation: isSelected ? 4 : 0,
                    shadowColor: const Color(0xFFF59E0B),
                    side: BorderSide(color: isSelected ? const Color(0xFFF59E0B) : Colors.grey.shade700),
                    onSelected: (bool selected) {
                      setState(() => selectedCategory = category);
                    },
                  ),
                );
              }).toList(),
            ),
          ),
          
          if (_isLoadingCloud) ...[
            const SizedBox(height: 10),
            const LinearProgressIndicator(color: Color(0xFFF59E0B)),
          ],
          const SizedBox(height: 10),

          // Products List with High-End Card UI
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: filteredProducts.length,
            itemBuilder: (context, index) {
              var prod = filteredProducts[index];
              String prodKey = prod['firebaseKey'] ?? prod['id'] ?? prod['name'] ?? index.toString();
              double unitPrice = (prod['price'] ?? 499.0).toDouble();
              double selectedQty = _itemQuantities[prodKey] ?? 1.0;
              double totalPrice = unitPrice * selectedQty;
              bool inStock = prod['inStock'] ?? true;

              if (!_cakeMessageControllers.containsKey(prodKey)) {
                _cakeMessageControllers[prodKey] = TextEditingController();
              }
              var msgController = _cakeMessageControllers[prodKey]!;

              if (!_qtyControllers.containsKey(prodKey)) {
                _qtyControllers[prodKey] = TextEditingController(text: selectedQty.toInt().toString());
              }
              var qtyController = _qtyControllers[prodKey]!;

              return Container(
                margin: const EdgeInsets.symmetric(vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white10),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 6,
                      offset: const Offset(0, 3),
                    )
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(10.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: buildShopOrProdImage(prod['imagePath'], 95, 95, Icons.cake),
                          ),
                          if (!inStock)
                            Container(
                              height: 95,
                              width: 95,
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.7),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Center(
                                child: Text('OUT OF STOCK', style: TextStyle(color: Colors.redAccent, fontSize: 8, fontWeight: FontWeight.w900), textAlign: TextAlign.center),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(prod['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white), maxLines: 1, overflow: TextOverflow.ellipsis),
                            const SizedBox(height: 2),
                            Text(prod['category'] ?? 'General', style: TextStyle(fontSize: 10, color: Colors.grey.shade400)),
                            const SizedBox(height: 4),
                            Text('₹${unitPrice.toInt()} / ${prod['unit'] ?? 'Piece'}', style: const TextStyle(color: Color(0xFFF59E0B), fontWeight: FontWeight.w900, fontSize: 12)),
                            const SizedBox(height: 8),

                            TextField(
                              controller: msgController,
                              style: const TextStyle(fontSize: 11, color: Colors.white),
                              decoration: InputDecoration(
                                labelText: 'विशेष निर्देश / नोट (यदि हो)',
                                labelStyle: TextStyle(fontSize: 10, color: Colors.grey.shade400),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade700)),
                                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFF59E0B))),
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                              ),
                            ),
                            const SizedBox(height: 8),

                            Row(
                              children: [
                                const Text('Qty:', style: TextStyle(fontSize: 10, color: Colors.white70)),
                                const SizedBox(width: 4),
                                SizedBox(
                                  width: 35,
                                  height: 24,
                                  child: TextField(
                                    controller: qtyController,
                                    keyboardType: TextInputType.number,
                                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                                    decoration: InputDecoration(
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                                    ),
                                    onChanged: (val) {
                                      double? q = double.tryParse(val);
                                      if (q != null && q > 0) {
                                        setState(() => _itemQuantities[prodKey] = q);
                                      }
                                    },
                                  ),
                                ),
                                const Spacer(),
                                Text('₹${totalPrice.toInt()}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Color(0xFFEC4899))),
                                const SizedBox(width: 8),
                                SizedBox(
                                  height: 28,
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: inStock ? const Color(0xFFF59E0B) : Colors.grey,
                                      foregroundColor: Colors.black87,
                                      elevation: 4,
                                      padding: const EdgeInsets.symmetric(horizontal: 10),
                                    ),
                                    onPressed: inStock ? () => _addToCart(prod, selectedQty, msgController.text.trim()) : null,
                                    child: Text(inStock ? 'Add to Cart' : 'Out of Stock', style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900)),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
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
// VENDOR LOGIN & PORTAL
// ==========================================
class VendorAuthAndPortalView extends StatefulWidget {
  const VendorAuthAndPortalView({super.key});

  @override
  State<VendorAuthAndPortalView> createState() => _VendorAuthAndPortalViewState();
}

class _VendorAuthAndPortalViewState extends State<VendorAuthAndPortalView> {
  bool _isLoggedIn = false;
  final TextEditingController _loginPhoneCtrl = TextEditingController();
  final TextEditingController _loginPinCtrl = TextEditingController();
  final TextEditingController _regPhoneCtrl = TextEditingController();
  final TextEditingController _createPinCtrl = TextEditingController();
  final TextEditingController _reEnterPinCtrl = TextEditingController();
  bool _isRegisteringNew = false;
  bool _isLoadingAuth = false;

  Future<void> _verifyOrLoginVendor() async {
    String phone = _loginPhoneCtrl.text.trim();
    String pin = _loginPinCtrl.text.trim();

    if (phone.isEmpty || pin.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('कृपया मोबाइल नंबर और पिन दर्ज करें!')));
      return;
    }

    setState(() => _isLoadingAuth = true);
    try {
      final response = await http.get(Uri.parse('${CakeDatabase.firebaseRestUrl}/vendors/$phone.json'));
      if (response.statusCode == 200 && response.body != 'null' && response.body.isNotEmpty) {
        var data = json.decode(response.body);
        if (data['pin'] == pin) {
          setState(() {
            _isLoggedIn = true;
            CakeDatabase.currentUserPhone = phone;
          });
        } else {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('❌ गलत पिन!')));
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('⚠️ नंबर रजिस्टर्ड नहीं है।')));
      }
    } catch (e) {
      debugPrint("Error: $e");
    } finally {
      if (mounted) setState(() => _isLoadingAuth = false);
    }
  }

  Future<void> _saveNewVendorPin() async {
    String phone = _regPhoneCtrl.text.trim();
    String pin1 = _createPinCtrl.text.trim();
    String pin2 = _reEnterPinCtrl.text.trim();

    if (phone.isEmpty || pin1.length != 4 || pin1 != pin2) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('कृपया सही विवरण भरें!')));
      return;
    }

    setState(() => _isLoadingAuth = true);
    try {
      await http.put(
        Uri.parse('${CakeDatabase.firebaseRestUrl}/vendors/$phone.json'),
        body: json.encode({'phone': phone, 'pin': pin1}),
      );
      if (mounted) {
        setState(() {
          _isLoggedIn = true;
          _isRegisteringNew = false;
          CakeDatabase.currentUserPhone = phone;
        });
      }
    } catch (e) {
      debugPrint("Error: $e");
    } finally {
      if (mounted) setState(() => _isLoadingAuth = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isLoggedIn) {
      return Padding(
        padding: const EdgeInsets.all(16.0),
        child: Center(
          child: SingleChildScrollView(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.3)),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 10)],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(Icons.admin_panel_settings, size: 55, color: Color(0xFFF59E0B)),
                  const SizedBox(height: 10),
                  Text(_isRegisteringNew ? '🛠️ नया पिन बनाएं' : '🔐 ओनर लॉगिन', textAlign: TextAlign.center, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                  const SizedBox(height: 15),
                  if (!_isRegisteringNew) ...[
                    TextField(controller: _loginPhoneCtrl, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'मोबाइल नंबर', border: OutlineInputBorder(), isDense: true)),
                    const SizedBox(height: 10),
                    TextField(controller: _loginPinCtrl, obscureText: true, keyboardType: TextInputType.number, maxLength: 4, decoration: const InputDecoration(labelText: '4-अंक का पिन', border: OutlineInputBorder(), isDense: true, counterText: '')),
                    const SizedBox(height: 15),
                    _isLoadingAuth ? const Center(child: CircularProgressIndicator()) : ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF59E0B), foregroundColor: Colors.black87), onPressed: _verifyOrLoginVendor, child: const Text('लॉगिन करें', style: TextStyle(fontWeight: FontWeight.bold))),
                    TextButton(onPressed: () => setState(() => _isRegisteringNew = true), child: const Text('नया अकाउंट है? पिन सेट करें', style: TextStyle(color: Color(0xFFEC4899)))),
                  ] else ...[
                    TextField(controller: _regPhoneCtrl, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'मोबाइल नंबर', border: OutlineInputBorder(), isDense: true)),
                    const SizedBox(height: 10),
                    TextField(controller: _createPinCtrl, obscureText: true, keyboardType: TextInputType.number, maxLength: 4, decoration: const InputDecoration(labelText: 'पिन दर्ज करें', border: OutlineInputBorder(), isDense: true, counterText: '')),
                    const SizedBox(height: 10),
                    TextField(controller: _reEnterPinCtrl, obscureText: true, keyboardType: TextInputType.number, maxLength: 4, decoration: const InputDecoration(labelText: 'दोबारा पिन डालें', border: OutlineInputBorder(), isDense: true, counterText: '')),
                    const SizedBox(height: 15),
                    _isLoadingAuth ? const Center(child: CircularProgressIndicator()) : ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white), onPressed: _saveNewVendorPin, child: const Text('पिन सेव करें', style: TextStyle(fontWeight: FontWeight.bold))),
                    TextButton(onPressed: () => setState(() => _isRegisteringNew = false), child: const Text('लॉगिन पर वापस जाएं', style: TextStyle(color: Color(0xFFEC4899)))),
                  ],
                ],
              ),
            ),
          ),
        ),
      );
    }
    return const VendorPortalDashboardView();
  }
}

class VendorPortalDashboardView extends StatefulWidget {
  const VendorPortalDashboardView({super.key});

  @override
  State<VendorPortalDashboardView> createState() => _VendorPortalDashboardViewState();
}

class _VendorPortalDashboardViewState extends State<VendorPortalDashboardView> {
  Map<String, dynamic> get activeShop => CakeDatabase.bakeryShop;

  final TextEditingController _prodNameCtrl = TextEditingController();
  final TextEditingController _priceCtrl = TextEditingController();
  final TextEditingController _stockCtrl = TextEditingController();
  
  late final TextEditingController _shopNameCtrl = TextEditingController(text: activeShop['shopName']);
  late final TextEditingController _ownerNameCtrl = TextEditingController(text: activeShop['ownerName']);
  late final TextEditingController _ownerPhoneCtrl = TextEditingController(text: activeShop['ownerPhone'] ?? activeShop['phone']);
  late final TextEditingController _addressCtrl = TextEditingController(text: activeShop['address']);

  final String _selectedUnit = 'Piece';
  String _selectedCategory = 'Birthday Cake';
  bool _isUploadingToCloud = false;
  bool _isSavingShop = false;
  String? _pickedProdImagePath;
  String? _pickedShopImagePath;
  String? _pickedBannerImagePath;
  
  final ImagePicker _picker = ImagePicker();
  
  List<Map<String, dynamic>> _vendorOrders = [];
  List<Map<String, dynamic>> _vendorProducts = [];
  bool _isLoadingOrders = false;
  bool _isLoadingProducts = false;

  final List<String> vendorCategories = [
    'Birthday Cake',
    'Anniversary Cake',
    'Chocolate Cake',
    'Kids / Cartoon Cake',
    'Fruit Cake',
    'Red Velvet',
    'Heart Shaped Cake',
    'Tier / Wedding Cake',
    'Cupcakes & Pastries',
    'Designer / Custom Cake',
    'Truffle Cake',
    'Butterscotch',
    'Black Forest',
    'Pineapple Cake',
    'Strawberry Cake',
    'Coffee / Mocha Cake',
    'Photo Cake',
    'Combos (Cake + Flowers)',
    'Midnight Special Cake',
    'Fasting / Eggless Special'
  ];

  @override
  void initState() {
    super.initState();
    _fetchShopProfile().then((_) {
      _fetchVendorOrders();
      _fetchVendorProducts();
    });
  }

  Future<void> _fetchShopProfile() async {
    try {
      final response = await http.get(Uri.parse('${CakeDatabase.firebaseRestUrl}/shop_profile.json'));
      if (response.statusCode == 200 && response.body != 'null' && response.body.isNotEmpty) {
        var data = json.decode(response.body);
        if (data is Map) {
          setState(() {
            CakeDatabase.bakeryShop = Map<String, dynamic>.from(data);
            _shopNameCtrl.text = CakeDatabase.bakeryShop['shopName'] ?? '';
            _ownerNameCtrl.text = CakeDatabase.bakeryShop['ownerName'] ?? '';
            _ownerPhoneCtrl.text = CakeDatabase.bakeryShop['ownerPhone'] ?? CakeDatabase.bakeryShop['phone'] ?? '';
            _addressCtrl.text = CakeDatabase.bakeryShop['address'] ?? '';
            _pickedShopImagePath = CakeDatabase.bakeryShop['shopPhotoPath'];
            _pickedBannerImagePath = CakeDatabase.bakeryShop['bannerPhotoPath'];
          });
        }
      }
    } catch (e) {
      debugPrint("Error fetching shop profile: $e");
    }
  }

  Future<void> _fetchVendorOrders() async {
    setState(() => _isLoadingOrders = true);
    try {
      final response = await http.get(Uri.parse('${CakeDatabase.firebaseRestUrl}/orders.json'));
      if (response.statusCode == 200 && response.body != 'null' && response.body.isNotEmpty) {
        Map<String, dynamic> data = json.decode(response.body);
        List<Map<String, dynamic>> list = [];
        data.forEach((key, val) {
          var item = Map<String, dynamic>.from(val);
          item['firebaseKey'] = key;
          list.add(item);
        });
        if (mounted) setState(() => _vendorOrders = list.reversed.toList());
      } else {
        if (mounted) setState(() => _vendorOrders = []);
      }
    } catch (e) {
      debugPrint("Error fetching orders: $e");
    } finally {
      if (mounted) setState(() => _isLoadingOrders = false);
    }
  }

  Future<void> _fetchVendorProducts() async {
    setState(() => _isLoadingProducts = true);
    try {
      final response = await http.get(Uri.parse('${CakeDatabase.firebaseRestUrl}/products.json'));
      if (response.statusCode == 200 && response.body != 'null' && response.body.isNotEmpty) {
        Map<String, dynamic> data = json.decode(response.body);
        List<Map<String, dynamic>> list = [];
        data.forEach((key, val) {
          var item = Map<String, dynamic>.from(val);
          item['firebaseKey'] = key;
          list.add(item);
        });
        if (mounted) {
          setState(() {
            _vendorProducts = list.reversed.toList();
            CakeDatabase.productInventory = _vendorProducts;
          });
        }
      } else {
        if (mounted) setState(() => _vendorProducts = []);
      }
    } catch (e) {
      debugPrint("Error fetching products: $e");
    } finally {
      if (mounted) setState(() => _isLoadingProducts = false);
    }
  }

  Future<void> _acceptOrder(String orderKey) async {
    try {
      String timeNow = "${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2, '0')} (${DateTime.now().day}/${DateTime.now().month})";
      await http.patch(
        Uri.parse('${CakeDatabase.firebaseRestUrl}/orders/$orderKey.json'),
        body: json.encode({'status': 'Out for Delivery 🛵', 'vendorAcceptedTime': timeNow}),
      );
      _fetchVendorOrders();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Order Accepted & Marked Out for Delivery!'), backgroundColor: Colors.green));
      }
    } catch (_) {}
  }

  Future<void> _rejectOrder(String orderKey) async {
    try {
      await http.patch(
        Uri.parse('${CakeDatabase.firebaseRestUrl}/orders/$orderKey.json'),
        body: json.encode({'status': 'Rejected / Not Accepted ❌'}),
      );
      _fetchVendorOrders();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('❌ Order Rejected!'), backgroundColor: Colors.red));
      }
    } catch (_) {}
  }

  Future<void> _shareLocationToCustomer(String customerPhone, String customerAddress) async {
    try {
      if (customerPhone.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('⚠️ Customer phone number not found!')));
        return;
      }

      String locationText = "📍 नमस्ते! यह रही डिलीवरी लोकेशन: $customerAddress. (कृपया व्हाट्सएप के अटैचमेंट आइकॉन से अपनी लाइव लोकेशन शेयर करें)";
      String whatsappUrl = "https://wa.me/$customerPhone?text=${Uri.encodeComponent(locationText)}";
      final Uri uri = Uri.parse(whatsappUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint("Error sharing location: $e");
    }
  }

  Future<void> _deleteProduct(String firebaseKey) async {
    try {
      await http.delete(Uri.parse('${CakeDatabase.firebaseRestUrl}/products/$firebaseKey.json'));
      _fetchVendorProducts();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('🗑️ Item Deleted Successfully!'), backgroundColor: Colors.red));
      }
    } catch (e) {
      debugPrint("Error deleting product: $e");
    }
  }

  Future<void> _toggleStockStatus(String firebaseKey, bool currentStatus) async {
    try {
      await http.patch(
        Uri.parse('${CakeDatabase.firebaseRestUrl}/products/$firebaseKey.json'),
        body: json.encode({'inStock': !currentStatus}),
      );
      _fetchVendorProducts();
    } catch (e) {
      debugPrint("Error toggling stock: $e");
    }
  }

  Future<void> _pickShopImage(bool isBanner) async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 50);
    if (image != null) {
      final bytes = await image.readAsBytes();
      String base64Img = "data:image/jpeg;base64,${base64Encode(bytes)}";
      setState(() {
        if (isBanner) {
          _pickedBannerImagePath = base64Img;
          CakeDatabase.bakeryShop['bannerPhotoPath'] = base64Img;
        } else {
          _pickedShopImagePath = base64Img;
          CakeDatabase.bakeryShop['shopPhotoPath'] = base64Img;
        }
      });
    }
  }

  Future<void> _saveShopDetailsToCloud() async {
    setState(() => _isSavingShop = true);
    try {
      CakeDatabase.bakeryShop['shopName'] = _shopNameCtrl.text.trim();
      CakeDatabase.bakeryShop['ownerName'] = _ownerNameCtrl.text.trim();
      CakeDatabase.bakeryShop['ownerPhone'] = _ownerPhoneCtrl.text.trim();
      CakeDatabase.bakeryShop['phone'] = _ownerPhoneCtrl.text.trim();
      CakeDatabase.bakeryShop['whatsappNumber'] = '91${_ownerPhoneCtrl.text.trim().replaceAll(RegExp(r'[^0-9]'), '')}';
      CakeDatabase.bakeryShop['address'] = _addressCtrl.text.trim();
      if (_pickedShopImagePath != null) {
        CakeDatabase.bakeryShop['shopPhotoPath'] = _pickedShopImagePath;
      }
      if (_pickedBannerImagePath != null) {
        CakeDatabase.bakeryShop['bannerPhotoPath'] = _pickedBannerImagePath;
      }

      await http.put(
        Uri.parse('${CakeDatabase.firebaseRestUrl}/shop_profile.json'),
        body: json.encode(CakeDatabase.bakeryShop),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Shop Profile & Photos Saved Permanently!'), backgroundColor: Colors.green));
      }
    } catch (e) {
      debugPrint("Error saving shop: $e");
    } finally {
      if (mounted) setState(() => _isSavingShop = false);
    }
  }

  Future<void> _pickProductImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 50);
    if (image != null) {
      final bytes = await image.readAsBytes();
      if (mounted) setState(() => _pickedProdImagePath = "data:image/jpeg;base64,${base64Encode(bytes)}");
    }
  }

  Future<void> _publishProductToCloud() async {
    if (_prodNameCtrl.text.isEmpty || _priceCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('⚠️ Please fill item name and price!')));
      return;
    }
    setState(() => _isUploadingToCloud = true);

    var newProduct = {
      'id': 'c_${DateTime.now().millisecondsSinceEpoch}',
      'shopName': CakeDatabase.bakeryShop['shopName'],
      'owner': CakeDatabase.bakeryShop['ownerName'],
      'name': _prodNameCtrl.text.trim(),
      'price': double.tryParse(_priceCtrl.text) ?? 499.0,
      'unit': _selectedUnit,
      'stock': int.tryParse(_stockCtrl.text) ?? 20,
      'imagePath': _pickedProdImagePath ?? '',
      'category': _selectedCategory,
      'inStock': true,
    };

    try {
      final response = await http.post(
        Uri.parse('${CakeDatabase.firebaseRestUrl}/products.json'),
        body: json.encode(newProduct),
      );
      if ((response.statusCode == 200 || response.statusCode == 201) && mounted) {
        _prodNameCtrl.clear();
        _priceCtrl.clear();
        _stockCtrl.clear();
        setState(() => _pickedProdImagePath = null);
        _fetchVendorProducts();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('🚀 Item Added Successfully!'), backgroundColor: Colors.green));
      }
    } finally {
      if (mounted) setState(() => _isUploadingToCloud = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        // Shop Profile Full Form Container
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.4)),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 8)],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('🏪 Complete Shop Profile Form (Permanent Storage)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFFF59E0B))),
              const SizedBox(height: 12),
              
              Row(
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: buildShopOrProdImage(_pickedShopImagePath, 75, 75, Icons.store),
                        ),
                        const SizedBox(height: 4),
                        const Text('Shop Photo', style: TextStyle(fontSize: 10, color: Colors.grey)),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: buildShopOrProdImage(_pickedBannerImagePath, 75, 130, Icons.image),
                        ),
                        const SizedBox(height: 4),
                        const Text('Banner Photo', style: TextStyle(fontSize: 10, color: Colors.grey)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              TextField(controller: _shopNameCtrl, decoration: const InputDecoration(labelText: 'Shop Name', border: OutlineInputBorder(), isDense: true)),
              const SizedBox(height: 10),
              TextField(controller: _ownerNameCtrl, decoration: const InputDecoration(labelText: 'Owner Name', border: OutlineInputBorder(), isDense: true)),
              const SizedBox(height: 10),
              TextField(controller: _ownerPhoneCtrl, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Owner Phone / WhatsApp Number', border: OutlineInputBorder(), isDense: true)),
              const SizedBox(height: 10),
              TextField(controller: _addressCtrl, maxLines: 2, decoration: const InputDecoration(labelText: 'Full Shop Address (Sector/Area, City, Pincode)', border: OutlineInputBorder(), isDense: true)),
              const SizedBox(height: 12),
              
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(side: const BorderSide(color: Color(0xFFF59E0B))),
                      onPressed: () => _pickShopImage(false),
                      icon: const Icon(Icons.store, size: 16, color: Color(0xFFF59E0B)),
                      label: Text(_pickedShopImagePath == null ? 'Select Shop Photo' : 'Shop Photo ✓', style: const TextStyle(fontSize: 10, color: Colors.white)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(side: const BorderSide(color: Color(0xFFF59E0B))),
                      onPressed: () => _pickShopImage(true),
                      icon: const Icon(Icons.image, size: 16, color: Color(0xFFF59E0B)),
                      label: Text(_pickedBannerImagePath == null ? 'Select Banner' : 'Banner Photo ✓', style: const TextStyle(fontSize: 10, color: Colors.white)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _isSavingShop
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF59E0B), foregroundColor: Colors.black87),
                      onPressed: _saveShopDetailsToCloud,
                      child: const Text('Save Shop Profile Permanently', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
            ],
          ),
        ),

        const SizedBox(height: 16),
        const Divider(thickness: 2, color: Color(0xFF334155)),

        // Add New Item Form
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFEC4899).withOpacity(0.4)),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 8)],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('📦 Add New Item / Product (20+ Categories)', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFFEC4899))),
              const SizedBox(height: 12),
              TextField(controller: _prodNameCtrl, decoration: const InputDecoration(labelText: 'Item Name', border: OutlineInputBorder(), isDense: true)),
              const SizedBox(height: 10),
              TextField(controller: _priceCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Price (₹)', border: OutlineInputBorder(), isDense: true)),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: _selectedCategory,
                dropdownColor: const Color(0xFF1E293B),
                decoration: const InputDecoration(labelText: 'Category', border: OutlineInputBorder(), isDense: true),
                items: vendorCategories.map((cat) {
                  return DropdownMenuItem(value: cat, child: Text(cat, style: const TextStyle(fontSize: 12, color: Colors.white)));
                }).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedCategory = val);
                },
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(side: const BorderSide(color: Color(0xFFEC4899))),
                onPressed: _pickProductImage,
                icon: const Icon(Icons.add_a_photo, size: 16, color: Color(0xFFEC4899)),
                label: Text(_pickedProdImagePath == null ? 'Select Image' : 'Image Selected ✓', style: const TextStyle(fontSize: 11, color: Colors.white)),
              ),
              const SizedBox(height: 12),
              _isUploadingToCloud 
                  ? const Center(child: CircularProgressIndicator()) 
                  : ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEC4899), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 12)), 
                      onPressed: _publishProductToCloud, 
                      child: const Text('Add Item', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
            ],
          ),
        ),

        const SizedBox(height: 16),
        const Divider(thickness: 2, color: Color(0xFF334155)),

        Row(
          children: [
            const Text('📋 Inventory & Management', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
            const Spacer(),
            IconButton(onPressed: _fetchVendorProducts, icon: const Icon(Icons.sync, size: 18, color: Color(0xFFF59E0B)), tooltip: 'Refresh Products'),
          ],
        ),
        const SizedBox(height: 6),
        _isLoadingProducts
            ? const Center(child: CircularProgressIndicator())
            : _vendorProducts.isEmpty
                ? const Card(child: Padding(padding: EdgeInsets.all(12), child: Center(child: Text('कोई आइटम उपलब्ध नहीं है'))))
                : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _vendorProducts.length,
                    itemBuilder: (context, index) {
                      var prod = _vendorProducts[index];
                      bool inStock = prod['inStock'] ?? true;
                      return Card(
                        color: const Color(0xFF1E293B),
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        child: ListTile(
                          leading: ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: buildShopOrProdImage(prod['imagePath'], 45, 45, Icons.cake),
                          ),
                          title: Text(prod['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white)),
                          subtitle: Text('${prod['category']} • ₹${prod['price']}\nStatus: ${inStock ? '🟢 In Stock' : '🔴 Out of Stock'}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                          isThreeLine: true,
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Switch(
                                value: inStock,
                                activeColor: Colors.green,
                                onChanged: (val) => _toggleStockStatus(prod['firebaseKey'], inStock),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete, color: Colors.redAccent, size: 20),
                                onPressed: () => _deleteProduct(prod['firebaseKey']),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),

        const SizedBox(height: 16),
        const Divider(thickness: 2, color: Color(0xFF334155)),

        Row(
          children: [
            const Text('🛒 Incoming Vendor Orders', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFFF59E0B))),
            const Spacer(),
            IconButton(onPressed: _fetchVendorOrders, icon: const Icon(Icons.sync, size: 18, color: Color(0xFFF59E0B)), tooltip: 'Refresh Orders'),
          ],
        ),
        const SizedBox(height: 6),
        _isLoadingOrders 
            ? const Center(child: CircularProgressIndicator())
            : _vendorOrders.isEmpty
                ? const Card(child: Padding(padding: EdgeInsets.all(12), child: Center(child: Text('कोई आर्डर नहीं मिला'))))
                : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _vendorOrders.length,
                    itemBuilder: (context, index) {
                      var ord = _vendorOrders[index];
                      String status = ord['status'] ?? 'Pending ⏳';
                      List itemsList = ord['items'] ?? [];
                      String custPhone = ord['customerPhone'] ?? '';
                      String custAddr = ord['customerAddress'] ?? '';

                      return Card(
                        color: const Color(0xFF1E293B),
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        child: Padding(
                          padding: const EdgeInsets.all(10.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text('${ord['customerName']} - ₹${ord['grandTotal']?.toInt()}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white)),
                                  const Spacer(),
                                  Chip(
                                    label: Text(status, style: const TextStyle(color: Colors.white, fontSize: 9)),
                                    backgroundColor: status.contains('Pending') ? Colors.orange : (status.contains('Rejected') ? Colors.red : Colors.green),
                                    padding: EdgeInsets.zero,
                                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text('🕒 आर्डर समय: ${ord['orderTime'] ?? 'N/A'}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFF59E0B))),
                              Text('📞 WhatsApp: $custPhone', style: const TextStyle(fontSize: 11, color: Colors.blueAccent)),
                              Text('📍 पता / लोकेशन: $custAddr', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                              const SizedBox(height: 6),
                              const Text('📦 आर्डर किए गए आइटम:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFEC4899))),
                              ...itemsList.map<Widget>((it) {
                                String cakeMsg = it['cakeMessage'] ?? '';
                                return Padding(
                                  padding: const EdgeInsets.only(left: 6, top: 2),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('• ${it['name']} (${it['qty']} ${it['unit']}) - ₹${(it['price'] * it['qty']).toInt()}', style: const TextStyle(fontSize: 11, color: Colors.white70)),
                                      if (cakeMsg.isNotEmpty)
                                        Container(
                                          margin: const EdgeInsets.only(top: 2, bottom: 4),
                                          padding: const EdgeInsets.all(6),
                                          decoration: BoxDecoration(color: Colors.pink.shade900.withOpacity(0.3), borderRadius: BorderRadius.circular(4)),
                                          child: Text('💬 नोट: "$cakeMsg"', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFEC4899))),
                                        ),
                                    ],
                                  ),
                                );
                              }).toList(),
                              const SizedBox(height: 8),
                              
                              Row(
                                children: [
                                  if (status.contains('Pending')) ...[
                                    Expanded(
                                      child: SizedBox(
                                        height: 32,
                                        child: ElevatedButton(
                                          style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                                          onPressed: () => _acceptOrder(ord['firebaseKey']),
                                          child: const Text('Accept', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: SizedBox(
                                        height: 32,
                                        child: ElevatedButton(
                                          style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                                          onPressed: () => _rejectOrder(ord['firebaseKey']),
                                          child: const Text('Reject', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                  ],
                                  Expanded(
                                    child: SizedBox(
                                      height: 32,
                                      child: ElevatedButton.icon(
                                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF25D366), foregroundColor: Colors.white),
                                        onPressed: () => _shareLocationToCustomer(custPhone, custAddr),
                                        icon: const Icon(Icons.share_location, size: 14),
                                        label: const Text('📍 Location', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                      ),
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
      ],
    );
  }
}

// ==========================================
// WHATSAPP CHECKOUT CART & LOCATION SHARING
// ==========================================
class CartAndWhatsAppCheckoutView extends StatefulWidget {
  const CartAndWhatsAppCheckoutView({super.key});

  @override
  State<CartAndWhatsAppCheckoutView> createState() => _CartAndWhatsAppCheckoutViewState();
}

class _CartAndWhatsAppCheckoutViewState extends State<CartAndWhatsAppCheckoutView> // ✅ यहाँ पूरा 'State' कर दे
  
