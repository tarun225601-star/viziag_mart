import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
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
  final Map<String, double> _cartQuantities = {};

  @override
  void initState() {
    super.initState();
    _loadSavedCustomerData();
    _loadInstantDataAndFetch();
  }

  // 💾 लोकल स्टोरेज से कस्टमर का सेव्ड एड्रेस लोड करना
  Future<void> _loadSavedCustomerData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      CakeDatabase.bakeryShop['savedCustomerName'] = prefs.getString('savedCustomerName') ?? '';
      CakeDatabase.bakeryShop['savedCustomerPhone'] = prefs.getString('savedCustomerPhone') ?? '';
      CakeDatabase.bakeryShop['savedCustomerAddress'] = prefs.getString('savedCustomerAddress') ?? '';
    } catch (e) {
      debugPrint("Error loading saved customer data: $e");
    }
  }

  // 💾 कस्टमर का डेटा परमानेंट सेव करना
  Future<void> _saveCustomerDataLocally(String name, String phone, String address) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('savedCustomerName', name);
      await prefs.setString('savedCustomerPhone', phone);
      await prefs.setString('savedCustomerAddress', address);
      
      CakeDatabase.bakeryShop['savedCustomerName'] = name;
      CakeDatabase.bakeryShop['savedCustomerPhone'] = phone;
      CakeDatabase.bakeryShop['savedCustomerAddress'] = address;
    } catch (e) {
      debugPrint("Error saving customer data: $e");
    }
  }

  // कुल आइटम्स की गिनती
  double get totalCartItems {
    double total = 0;
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
            // रीलोड के बाद भी सेव्ड कस्टमर डेटा बनाए रखें
            _loadSavedCustomerData();
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

    double stock = (prod['stock'] ?? 50) is num ? (prod['stock'] ?? 50).toDouble() : double.tryParse(prod['stock'].toString()) ?? 50.0;
    String prodId = prod['firebaseKey'] ?? prod['id'] ?? prod['name'];
    double currentQty = _cartQuantities[prodId] ?? 0.0;

    if (currentQty >= stock) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('⚠️ स्टॉक limit पूरी हो गई है!'), backgroundColor: Colors.orange));
      return;
    }

    double newQty = currentQty + 1.0;
    _updateCartWithQuantity(prod, newQty);
  }

  // आइटम की मात्रा घटाने का फंक्शन
  void _decrementQty(Map<String, dynamic> prod) {
    String prodId = prod['firebaseKey'] ?? prod['id'] ?? prod['name'];
    double currentQty = _cartQuantities[prodId] ?? 0.0;

    if (currentQty > 0) {
      double newQty = currentQty <= 1.0 ? 0.0 : currentQty - 1.0;
      _updateCartWithQuantity(prod, newQty);
    }
  }

  // ✏️ कस्टमर द्वारा लिखकर क्वांटिटी सेट करने का डायलॉग
  void _showCustomQuantityDialog(Map<String, dynamic> prod) {
    String prodId = prod['firebaseKey'] ?? prod['id'] ?? prod['name'];
    double currentQty = _cartQuantities[prodId] ?? 1.0;
    final TextEditingController qtyController = TextEditingController(text: currentQty.toString());
    String unit = prod['unit'] ?? 'Kg';

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          title: Text('${prod['name']} की मात्रा लिखें', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          content: TextField(
            controller: qtyController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            autofocus: true,
            decoration: InputDecoration(
              labelText: 'कितना चाहिए? ($unit में दर्ज करें)',
              hintText: 'जैसे: 2.5 या 5',
              suffixText: unit,
              prefixIcon: const Icon(Icons.edit, color: Colors.green),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('रद्द करें', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade700, foregroundColor: Colors.white),
              onPressed: () {
                double? enteredQty = double.tryParse(qtyController.text.trim());
                if (enteredQty == null || enteredQty < 0) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('⚠️ कृपया सही संख्या लिखें!'), backgroundColor: Colors.orange));
                  return;
                }
                Navigator.pop(context);
                _updateCartWithQuantity(prod, enteredQty);
              },
              child: const Text('लागू करें (Apply)'),
            ),
          ],
        );
      },
    );
  }

  // कार्ट और स्टेट को अपडेट करने का मुख्य फंक्शन
  void _updateCartWithQuantity(Map<String, dynamic> prod, double newQty) {
    String prodId = prod['firebaseKey'] ?? prod['id'] ?? prod['name'];
    
    setState(() {
      if (newQty <= 0) {
        _cartQuantities.remove(prodId);
        CakeDatabase.cartItems.removeWhere((item) => item['name'] == prod['name']);
      } else {
        _cartQuantities[prodId] = newQty;
        String prodVendorPhone = prod['vendorPhone'] ?? prod['phone'] ?? '';
        String shopAddress = CakeDatabase.bakeryShop['address'] ?? 'Faridabad';
        String shopName = CakeDatabase.bakeryShop['shopName'] ?? 'Tarun Fruit Shop';

        var existingIndex = CakeDatabase.cartItems.indexWhere((item) => item['name'] == prod['name']);
        if (existingIndex >= 0) {
          CakeDatabase.cartItems[existingIndex]['qty'] = newQty;
        } else {
          CakeDatabase.cartItems.add({
            'name': prod['name'] ?? 'Item',
            'price': prod['price'] ?? 0.0,
            'unit': prod['unit'] ?? 'Kg',
            'qty': newQty,
            'image': prod['image'] ?? '',
            'shopName': shopName,
            'shopAddress': shopAddress,
            'vendorPhone': prodVendorPhone,
          });
        }
      }
    });
  }

  // कार्ट देखने और आइटम्स की पूरी लिस्ट दिखाने के लिए बॉटम शीट
  void _showCartBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: const EdgeInsets.all(16),
              constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('🛒 आपकी कार्ट (Cart Items)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const Divider(),
                  CakeDatabase.cartItems.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.all(30.0),
                          child: Center(child: Text('आपकी कार्ट खाली है!', style: TextStyle(color: Colors.grey, fontSize: 14))),
                        )
                      : Expanded(
                          child: ListView.builder(
                            shrinkWrap: true,
                            itemCount: CakeDatabase.cartItems.length,
                            itemBuilder: (context, index) {
                              var item = CakeDatabase.cartItems[index];
                              return ListTile(
                                title: Text(item['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                                subtitle: Text('₹${item['price']} x ${item['qty']} ${item['unit'] ?? 'Kg'}'),
                                trailing: Text('₹${(item['price'] * item['qty']).toStringAsFixed(1)}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                              );
                            },
                          ),
                        ),
                  const Divider(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('कुल राशि (Total):', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      Text('₹$totalCartAmount', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (CakeDatabase.cartItems.isNotEmpty)
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade700, foregroundColor: Colors.white),
                        onPressed: () {
                          Navigator.pop(context);
                          _checkAndProceedCheckout();
                        },
                        child: const Text('ऑर्डर आगे बढ़ाएं (Proceed to Checkout)', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // 🔍 चेक फंक्शन: देखिएगा कि एड्रेस सेव है या नहीं
  void _checkAndProceedCheckout() {
    String savedName = CakeDatabase.bakeryShop['savedCustomerName'] ?? '';
    String savedPhone = CakeDatabase.bakeryShop['savedCustomerPhone'] ?? '';
    String savedAddress = CakeDatabase.bakeryShop['savedCustomerAddress'] ?? '';

    if (savedName.isNotEmpty && savedPhone.isNotEmpty && savedAddress.isNotEmpty) {
      _confirmFinalOrderAndPushToCloud(savedName, savedPhone, savedAddress);
    } else {
      _showCustomerDetailsDialog(savedName, savedPhone, savedAddress);
    }
  }

  // 📝 कस्टमर का नाम, फोन नंबर और डिलीवरी एड्रेस लेने के लिए पॉप-अप डायलॉग
  void _showCustomerDetailsDialog(String existingName, String existingPhone, String existingAddress) {
    final TextEditingController nameController = TextEditingController(text: existingName);
    final TextEditingController phoneController = TextEditingController(text: existingPhone);
    final TextEditingController addressController = TextEditingController(text: existingAddress);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          title: const Text('📍 डिलीवरी की जानकारी भरें', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'आपका नाम (Customer Name)', prefixIcon: Icon(Icons.person)),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'मोबाइल नंबर (Mobile Number)', prefixIcon: Icon(Icons.phone)),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: addressController,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: 'पूरा डिलीवरी पता (Delivery Address)', hintText: 'जैसे: मकान नंबर, गली, एरिया, फरीदाबाद', prefixIcon: Icon(Icons.location_on)),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('रद्द करें', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade700, foregroundColor: Colors.white),
              onPressed: () async {
                String name = nameController.text.trim();
                String phone = phoneController.text.trim();
                String address = addressController.text.trim();

                if (name.isEmpty || phone.isEmpty || address.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('⚠️ कृपया सभी जानकारी (नाम, फोन, पता) भरें!'), backgroundColor: Colors.orange),
                  );
                  return;
                }

                // 💾 शेयर प्रेफरेंस में परमानेंट सेव करना
                await _saveCustomerDataLocally(name, phone, address);
                
                if (mounted) Navigator.pop(context);
                _confirmFinalOrderAndPushToCloud(name, phone, address);
              },
              child: const Text('ऑर्डर कन्फर्म करें'),
            ),
          ],
        );
      },
    );
  }

  // 🚀 फाइनल ऑर्डर कन्फर्मेशन और क्लाउड पर भेजने का फंक्शन
  Future<void> _confirmFinalOrderAndPushToCloud(String customerName, String customerPhone, String customerAddress) async {
    if (CakeDatabase.cartItems.isEmpty) return;

    var shop = CakeDatabase.bakeryShop;
    String shopName = shop['shopName'] ?? 'Tarun Fruit & Vegetable Shop';
    String shopAddress = shop['address'] ?? 'Faridabad';
    double totalAmount = totalCartAmount;

    String uniqueOrderId = "ORD_${DateTime.now().millisecondsSinceEpoch}";

    Map<String, dynamic> finalOrderData = {
      'orderId': uniqueOrderId,
      'customerName': customerName,
      'customerPhone': customerPhone,
      'customerAddress': customerAddress,
      'shopName': shopName,
      'shopAddress': shopAddress,
      'items': List.from(CakeDatabase.cartItems),
      'grandTotal': totalAmount,
      'totalAmount': totalAmount,
      'paymentMode': 'COD',
      'orderStatus': 'Pending',
      'status': 'Pending',
      'orderTime': DateTime.now().toIso8601String(),
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };

    try {
      final riderUri = Uri.parse('${CakeDatabase.firebaseRestUrl}/orders/$uniqueOrderId.json');
      final riderResponse = await http.put(riderUri, body: json.encode(finalOrderData));

      final vendorUri = Uri.parse('${CakeDatabase.firebaseRestUrl}/vendor_orders/$uniqueOrderId.json');
      await http.put(vendorUri, body: json.encode(finalOrderData));

      if (riderResponse.statusCode == 200 || riderResponse.statusCode == 201) {
        if (CakeDatabase.localOrdersCache == null) {
          CakeDatabase.localOrdersCache = [];
        }
        
        setState(() {
          CakeDatabase.localOrdersCache.insert(0, finalOrderData);
          _cartQuantities.clear();
          CakeDatabase.cartItems.clear();
        });
        
        await CakeDatabase.saveOrdersLocally();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('🎉 आपका ऑर्डर सफलतापूर्वक बुक हो गया!', style: TextStyle(fontWeight: FontWeight.bold)),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 4),
            ),
          );
        }
      } else {
        throw Exception('Failed to upload order to server');
      }
    } catch (e) {
      debugPrint("Final order push error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ ऑर्डर भेजने में विफल: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    var shop =CakeDatabase.bakeryShop;
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
      appBar: AppBar(
        backgroundColor: Colors.green.shade700,
        title: const Text('🛍️ मार्केटप्लेस (फ्रूट & वेजिटेबल)', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _fetchShopProfileAndProducts,
          )
        ],
      ),
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
                      Text('🔴 दुकान अभी बंद (Closed) है!', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              // Search Bar
              TextField(
                controller: _searchController,
                onChanged: (val) => setState(() => _searchQuery = val),
                decoration: InputDecoration(
                  hintText: 'फल या सब्जियां खोजें...',
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                ),
              ),
              const SizedBox(height: 10),
              // Categories
              SizedBox(
                height: 40,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: categories.length,
                  itemBuilder: (context, index) {
                    String cat = categories[index];
                    bool isSelected = selectedCategory == cat;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(cat),
                        selected: isSelected,
                        selectedColor: Colors.green.shade700,
                        labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.black87, fontWeight: FontWeight.bold),
                        onSelected: (bool selected) => setState(() => selectedCategory = cat),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 10),
              if (_isLoadingCloud && CakeDatabase.productInventory.isEmpty)
                const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator()))
              else if (filtered.isEmpty)
                const Center(child: Padding(padding: EdgeInsets.all(40), child: Text('कोई सामान उपलब्ध नहीं है।', style: TextStyle(color: Colors.grey))))
              else
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 0.75,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                  ),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    var prod = filtered[index];
                    String prodId = prod['firebaseKey'] ?? prod['id'] ?? prod['name'];
                    double qty = _cartQuantities[prodId] ?? 0.0;
                    String unit = prod['unit'] ?? 'Kg';
                    String imgUrl = prod['image'] ?? '';

                    return Card(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                              child: imgUrl.isNotEmpty
                                  ? Image.network(imgUrl, width: double.infinity, fit: BoxFit.cover, errorBuilder: (c, e, s) => Container(color: Colors.grey.shade200, child: const Icon(Icons.broken_image)))
                                  : Container(color: Colors.grey.shade200, child: const Center(child: Icon(Icons.image, color: Colors.grey))),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(prod['name'] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                const SizedBox(height: 2),
                                Text('₹${prod['price']} / $unit', style: TextStyle(color: Colors.green.shade700, fontWeight: FontWeight.bold, fontSize: 13)),
                                const SizedBox(height: 8),
                                qty == 0
                                    ? SizedBox(
                                        width: double.infinity,
                                        height: 32,
                                        child: ElevatedButton(
                                          style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade700, foregroundColor: Colors.white, padding: EdgeInsets.zero),
                                          onPressed: () => _incrementQty(prod),
                                          child: const Text('जोड़ें (Add)', style: TextStyle(fontSize: 12)),
                                        ),
                                      )
                                    : Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          IconButton(
                                            constraints: const BoxConstraints(),
                                            padding: EdgeInsets.zero,
                                            icon: const Icon(Icons.remove_circle, color: Colors.red, size: 28),
                                            onPressed: () => _decrementQty(prod),
                                          ),
                                          InkWell(
                                            onTap: () => _showCustomQuantityDialog(prod),
                                            child: Padding(
                                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                              child: Text('$qty $unit', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, decoration: TextDecoration.underline)),
                                            ),
                                          ),
                                          IconButton(
                                            constraints: const BoxConstraints(),
                                            padding: EdgeInsets.zero,
                                            icon: const Icon(Icons.add_circle, color: Colors.green, size: 28),
                                            onPressed: () => _incrementQty(prod),
                                          ),
                                        ],
                                      ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
            ],
          ),
          if (totalCartItems > 0)
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade700,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 6,
                ),
                onPressed: _showCartBottomSheet,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.shopping_cart),
                    const SizedBox(width: 8),
                    Text('कार्ट देखें (${totalCartItems.toStringAsFixed(0)} Items) • ₹$totalCartAmount', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
