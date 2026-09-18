import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'database_models.dart';
import 'image_picker_helper.dart';

class MarketplaceBuyerView extends StatefulWidget {
  const MarketplaceBuyerView({super.key});

  @override
  State<MarketplaceBuyerView> createState() => _MarketplaceBuyerViewState();
}

class _MarketplaceBuyerViewState extends State<MarketplaceBuyerView> {
  String selectedCategory = 'All';
  bool _isLoadingCloud = false;
  String _errorMessage = '';
  
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  final String _targetCity = 'faridabad';

  final List<String> categories = ['All', 'Fresh Fruits', 'Vegetables', 'Organic Items', 'Daily Essentials'];

  // कार्ट में आइटम्स की क्वांटिटी स्टोर करने के लिए (productId -> quantity)
  final Map<String, int> _cartQuantities = {};

  @override
  void initState() {
    super.initState();
    _loadInstantDataAndFetch();
  }

  // कुल आइटम्स की गिनती
  int get totalCartItems {
    int total = 0;
    _cartQuantities.forEach((key, qty) => total += qty);
    return total;
  }

  // कुल बिल की रकम
  double get totalCartAmount {
    double amount = 0;
    _cartQuantities.forEach((id, qty) {
      try {
        var prod = CakeDatabase.productInventory.firstWhere((p) => (p['firebaseKey'] ?? p['id'] ?? '') == id);
        double price = (prod['price'] ?? 0.0) is num ? (prod['price'] ?? 0.0).toDouble() : double.tryParse(prod['price'].toString()) ?? 0.0;
        amount += (price * qty);
      } catch (_) {}
    });
    return amount;
  }

  Future<void> _loadInstantDataAndFetch() async {
    try {
      await CakeDatabase.loadInventoryLocally();
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint("Local load error: $e");
    }
    _fetchShopProfileAndProducts();
  }

  Future<void> _fetchShopProfileAndProducts() async {
    if (CakeDatabase.productInventory.isEmpty) {
      if (mounted) setState(() => _isLoadingCloud = true);
    }
    
    try {
      final shopRes = await http.get(Uri.parse('${CakeDatabase.firebaseRestUrl}/shop_profile.json')).timeout(const Duration(seconds: 10));
      if (shopRes.statusCode == 200 && shopRes.body != 'null' && shopRes.body.isNotEmpty) {
        var decodedShop = json.decode(shopRes.body);
        if (decodedShop is Map && mounted) {
          setState(() {
            CakeDatabase.bakeryShop = Map<String, dynamic>.from(
              decodedShop.map((key, value) => MapEntry(key.toString(), value))
            );
          });
        }
      }

      final response = await http.get(Uri.parse('${CakeDatabase.firebaseRestUrl}/products.json')).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200 && response.body != 'null' && response.body.isNotEmpty) {
        var decodedProducts = json.decode(response.body);
        List<Map<String, dynamic>> fetchedList = [];
        if (decodedProducts is Map) {
          decodedProducts.forEach((key, value) {
            if (value is Map) {
              var item = Map<String, dynamic>.from(
                value.map((k, v) => MapEntry(k.toString(), v))
              );
              item['firebaseKey'] = key.toString();
              if (item['price'] != null) item['price'] = (item['price'] as num).toDouble();
              fetchedList.add(item);
            }
          });
        }
        
        CakeDatabase.productInventory = fetchedList.reversed.toList();
        await CakeDatabase.saveInventoryLocally();

        if (mounted) setState(() => _errorMessage = '');
      }
    } catch (e) {
      debugPrint("Cloud fetch error: $e");
      if (mounted) setState(() => _errorMessage = 'सर्वर कनेक्ट करने में समस्या');
    } finally {
      if (mounted) setState(() => _isLoadingCloud = false);
    }
  }

  // आइटम की मात्रा बढ़ाने का फंक्शन
  void _incrementQty(Map<String, dynamic> prod) {
    bool isShopOpen = CakeDatabase.bakeryShop['isOpen'] ?? true;
    if (!isShopOpen) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('🔴 दुकान अभी बंद (Closed) है!'), backgroundColor: Colors.red));
      return;
    }

    int stock = (prod['stock'] ?? 1) is int ? (prod['stock'] ?? 1) : int.tryParse(prod['stock'].toString()) ?? 1;
    String prodId = prod['firebaseKey'] ?? prod['id'] ?? prod['name'];
    int currentQty = _cartQuantities[prodId] ?? 0;

    if (currentQty >= stock) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('⚠️ स्टॉक limit पूरी हो गई है!'), backgroundColor: Colors.orange));
      return;
    }

    setState(() {
      _cartQuantities[prodId] = currentQty + 1;
      
      String prodVendorPhone = prod['vendorPhone'] ?? prod['phone'] ?? '';
      String shopAddress = CakeDatabase.bakeryShop['address'] ?? 'Faridabad';
      String shopName = CakeDatabase.bakeryShop['shopName'] ?? 'Tarun Fruit Shop';

      var existingIndex = CakeDatabase.cartItems.indexWhere((item) => item['name'] == prod['name']);
      if (existingIndex >= 0) {
        CakeDatabase.cartItems[existingIndex]['qty'] = (_cartQuantities[prodId] ?? 1).toDouble();
      } else {
        CakeDatabase.cartItems.add({
          'name': prod['name'] ?? 'Item',
          'price': prod['price'] ?? 0.0,
          'unit': prod['unit'] ?? 'Kg',
          'qty': 1.0,
          'image': prod['image'] ?? '',
          'shopName': shopName,
          'shopAddress': shopAddress,
          'vendorPhone': prodVendorPhone,
        });
      }
    });
  }

  // आइटम की मात्रा घटाने का फंक्शन
  void _decrementQty(Map<String, dynamic> prod) {
    String prodId = prod['firebaseKey'] ?? prod['id'] ?? prod['name'];
    int currentQty = _cartQuantities[prodId] ?? 0;

    if (currentQty > 0) {
      setState(() {
        if (currentQty == 1) {
          _cartQuantities.remove(prodId);
          CakeDatabase.cartItems.removeWhere((item) => item['name'] == prod['name']);
        } else {
          _cartQuantities[prodId] = currentQty - 1;
          var existingIndex = CakeDatabase.cartItems.indexWhere((item) => item['name'] == prod['name']);
          if (existingIndex >= 0) {
            CakeDatabase.cartItems[existingIndex]['qty'] = (_cartQuantities[prodId] ?? 1).toDouble();
          }
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    var shop = CakeDatabase.bakeryShop;
    bool isShopOpen = shop['isOpen'] ?? true;
    String shopAddress = (shop['address'] ?? 'Faridabad').toString().toLowerCase();
    bool isLocalFaridabadShop = shopAddress.contains(_targetCity) || shopAddress.isEmpty;

    var filtered = <Map<String, dynamic>>[];
    try {
      filtered = CakeDatabase.productInventory.where((p) {
        if (!isLocalFaridabadShop) return false; 
        bool matchesCategory = (selectedCategory == 'All' || p['category'] == selectedCategory);
        String productName = (p['name'] ?? '').toString().toLowerCase();
        bool matchesSearch = productName.contains(_searchQuery.toLowerCase());
        return matchesCategory && matchesSearch;
      }).toList();
    } catch (e) {
      debugPrint("Filtering error: $e");
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA), 
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 90),
            children: [
              if (!isShopOpen)
                Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.red.shade700, borderRadius: BorderRadius.circular(10)),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.store_mall_directory, color: Colors.white),
                      SizedBox(width: 8),
                      Text('🔴 दुकान अभी बंद (Closed) है!', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                    ],
                  ),
                ),

              TextField(
                controller: _searchController,
                onChanged: (val) => setState(() => _searchQuery = val),
                decoration: InputDecoration(
                  hintText: 'फल, सब्ज़ी या आइटम खोजें (फरीदाबाद)...',
                  prefixIcon: const Icon(Icons.search, color: Colors.green),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(icon: const Icon(Icons.clear), onPressed: () => setState(() { _searchController.clear(); _searchQuery = ''; }))
                      : null,
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
                ),
              ),
              const SizedBox(height: 10),

              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                  boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 6, offset: const Offset(0, 2))],
                ),
                child: Column(
                  children: [
                    if ((shop['bannerPhotoPath'] ?? '').toString().isNotEmpty)
                      ClipRRect(borderRadius: const BorderRadius.vertical(top: Radius.circular(12)), child: buildShopOrProdImage(shop['bannerPhotoPath'], 110, double.infinity, Icons.store)),
                    Padding(
                      padding: const EdgeInsets.all(10.0),
                      child: Row(
                        children: [
                          ClipRRect(borderRadius: BorderRadius.circular(8), child: buildShopOrProdImage(shop['shopPhotoPath'] ?? shop['ownerPhotoPath'], 45, 45, Icons.store)),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(shop['shopName'] ?? 'Tarun Fruit & Vegetable Shop', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87, fontSize: 13)),
                                const SizedBox(height: 2),
                                Text('📍 ${shop['address'] ?? 'Faridabad'}', style: const TextStyle(fontSize: 10, color: Colors.black54)),
                              ],
                            ),
                          ),
                          IconButton(icon: const Icon(Icons.sync, color: Colors.green), onPressed: _fetchShopProfileAndProducts),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: categories.map((cat) => Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      label: Text(cat, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                      selected: selectedCategory == cat,
                      selectedColor: Colors.green.shade700,
                      backgroundColor: Colors.white,
                      labelStyle: TextStyle(color: selectedCategory == cat ? Colors.white : Colors.black87),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: selectedCategory == cat ? Colors.transparent : Colors.grey.shade300)),
                      onSelected: (_) => setState(() => selectedCategory = cat),
                    ),
                  )).toList(),
                ),
              ),
              if (_isLoadingCloud) const LinearProgressIndicator(color: Colors.green),
              if (_errorMessage.isNotEmpty) Padding(padding: const EdgeInsets.all(8.0), child: Text(_errorMessage, style: const TextStyle(color: Colors.red, fontSize: 11))),
              const SizedBox(height: 10),

              filtered.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(40),
                      child: Center(
                        child: Text(
                          !isLocalFaridabadShop ? '⚠️ यह दुकान फरीदाबाद के बाहर की है।' : 'कोई प्रोडक्ट नहीं मिला',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.black45, fontSize: 13),
                        ),
                      ),
                    )
                  : GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        childAspectRatio: 0.72,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                      ),
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        var prod = filtered[index];
                        int stock = (prod['stock'] ?? 1) is int ? (prod['stock'] ?? 1) : int.tryParse(prod['stock'].toString()) ?? 1;
                        String prodId = prod['firebaseKey'] ?? prod['id'] ?? prod['name'];
                        int currentQty = _cartQuantities[prodId] ?? 0;
                        
                        bool isDimmed = !isShopOpen || stock <= 0;

                        return Opacity(
                          opacity: isDimmed ? 0.4 : 1.0,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey.shade200, width: 1),
                              boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.12), blurRadius: 5, offset: const Offset(0, 2))],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: ClipRRect(
                                    borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                                    child: Stack(
                                      children: [
                                        SizedBox(width: double.infinity, child: buildShopOrProdImage(prod['image'], double.infinity, double.infinity, Icons.eco)),
                                        Positioned(
                                          top: 6,
                                          left: 6,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(color: !isShopOpen ? Colors.red : Colors.blue.shade700, borderRadius: BorderRadius.circular(4)),
                                            child: Text(!isShopOpen ? 'CLOSED' : '⚡ 9 MINS', style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(prod['name'] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 12)),
                                      const SizedBox(height: 2),
                                      Text(stock <= 0 ? 'Out of Stock' : '1 ${prod['unit'] ?? 'Kg'}', style: TextStyle(color: stock <= 0 ? Colors.red : Colors.black54, fontSize: 10, fontWeight: stock <= 0 ? FontWeight.bold : FontWeight.normal)),
                                      const SizedBox(height: 6),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text('₹${prod['price'] ?? 0}', style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 13)),
                                          
                                          // पहले ADD बटन दिखेगा, क्लिक करते ही काउंटर (- 1 +) में बदल जाएगा
                                          currentQty == 0
                                              ? SizedBox(
                                                  height: 28,
                                                  child: OutlinedButton(
                                                    style: OutlinedButton.styleFrom(
                                                      foregroundColor: isDimmed ? Colors.grey : Colors.green.shade700,
                                                      side: BorderSide(color: isDimmed ? Colors.grey : Colors.green.shade700, width: 1.2),
                                                      padding: const EdgeInsets.symmetric(horizontal: 16),
                                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                                    ),
                                                    onPressed: isDimmed ? null : () => _incrementQty(prod),
                                                    child: Text(stock <= 0 ? 'SOLD' : 'ADD', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                                                  ),
                                                )
                                              : Container(
                                                  height: 28,
                                                  decoration: BoxDecoration(color: Colors.green.shade700, borderRadius: BorderRadius.circular(6)),
                                                  child: Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      InkWell(
                                                        onTap: () => _decrementQty(prod),
                                                        child: const Padding(
                                                          padding: EdgeInsets.symmetric(horizontal: 8),
                                                          child: Icon(Icons.remove, color: Colors.white, size: 14),
                                                        ),
                                                      ),
                                                      Text('$currentQty', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                                                      InkWell(
                                                        onTap: () => _incrementQty(prod),
                                                        child: const Padding(
                                                          padding: EdgeInsets.symmetric(horizontal: 8),
                                                          child: Icon(Icons.add, color: Colors.white, size: 14),
                                                        ),
                                                      ),
                                                    ],
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

          // ब्लिंकिट जैसा बॉटम फ्लोटिंग कार्ट बार
          if (totalCartItems > 0)
            Positioned(
              left: 12,
              right: 12,
              bottom: 15,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF0C831F),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 4))],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.shopping_cart, color: Colors.white, size: 20),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('$totalCartItems ITEMS', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                            Text('₹${totalCartAmount.toInt()}', style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ],
                    ),
                    const Row(
                      children: [
                        Text('View Cart', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                        Icon(Icons.arrow_right, color: Colors.white),
                      ],
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
