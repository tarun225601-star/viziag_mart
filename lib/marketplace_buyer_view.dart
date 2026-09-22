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

  final List<String> categories = ['All', 'Fresh Fruits', 'Vegetables', 'Organic Items', 'Daily Essentials'];

  // कार्ट में आइटम्स की क्वांटिटी स्टोर करने के लिए (productId -> quantity)
  final Map<String, double> _cartQuantities = {};

  @override
  void initState() {
    super.initState();
    _loadInstantDataAndFetch();
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
              
              // मल्टी-वेंडर और इमेज की सही मैपिंग
              item['shopId'] = item['shopId'] ?? item['vendorPhone'] ?? 'tarun_fruit_shop';
              item['shopName'] = item['shopName'] ?? 'Tarun Fruit Shop';
              item['shopAddress'] = item['shopAddress'] ?? 'sector 89a ajronda sabji mandi faridabad';
              
              // इमेज की अलग-अलग संभावित की (keys) को हैंडल करना
              item['image'] = item['image'] ?? item['imageUrl'] ?? item['img'] ?? '';

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
        CakeDatabase.cartItems.removeWhere((item) => item['name'] == prod['name'] && item['shopId'] == prod['shopId']);
      } else {
        _cartQuantities[prodId] = newQty;
        String shopName = prod['shopName'] ?? 'Tarun Fruit Shop';
        String shopAddress = prod['shopAddress'] ?? 'Faridabad';
        String vendorPhone = prod['shopId'] ?? '';
        String imageUrl = prod['image'] ?? '';

        var existingIndex = CakeDatabase.cartItems.indexWhere((item) => item['name'] == prod['name'] && item['shopId'] == vendorPhone);
        if (existingIndex >= 0) {
          CakeDatabase.cartItems[existingIndex]['qty'] = newQty;
        } else {
          CakeDatabase.cartItems.add({
            'name': prod['name'] ?? 'Item',
            'price': prod['price'] ?? 0.0,
            'unit': prod['unit'] ?? 'Kg',
            'qty': newQty,
            'image': imageUrl,
            'shopName': shopName,
            'shopAddress': shopAddress,
            'shopId': vendorPhone,
            'vendorPhone': vendorPhone,
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
                                leading: item['image'] != null && item['image'].toString().isNotEmpty
                                    ? ClipRRect(borderRadius: BorderRadius.circular(6), child: Image.network(item['image'], width: 40, height: 40, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.image)))
                                    : const Icon(Icons.image, size: 40),
                                title: Text(item['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                                subtitle: Text('₹${item['price']} x ${item['qty']} ${item['unit'] ?? 'Kg'} (${item['shopName'] ?? ''})'),
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

  void _checkAndProceedCheckout() {
    String savedName = CakeDatabase.bakeryShop['savedCustomerName'] ?? '';
    String savedPhone = CakeDatabase.bakeryShop['savedCustomerPhone'] ?? '';
    String savedAddress = CakeDatabase.bakeryShop['savedCustomerAddress'] ?? '';

    if (savedName.isNotEmpty && savedPhone.isNotEmpty && savedAddress.isNotEmpty) {
      _confirmFinalOrderAndPushToCloud(savedName, savedPhone, savedAddress);
    } else {
      _showCustomerDetailsDialog();
    }
  }

  void _showCustomerDetailsDialog() {
    final TextEditingController nameController = TextEditingController(text: CakeDatabase.bakeryShop['savedCustomerName'] ?? '');
    final TextEditingController phoneController = TextEditingController(text: CakeDatabase.bakeryShop['savedCustomerPhone'] ?? '');
    final TextEditingController addressController = TextEditingController(text: CakeDatabase.bakeryShop['savedCustomerAddress'] ?? '');

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
                  decoration: const InputDecoration(labelText: 'आपका नाम', prefixIcon: Icon(Icons.person)),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'मोबाइल नंबर', prefixIcon: Icon(Icons.phone)),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: addressController,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: 'पूरा डिलीवरी पता', hintText: 'मकान नंबर, गली, एरिया, फरीदाबाद', prefixIcon: Icon(Icons.location_on)),
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
              onPressed: () {
                String name = nameController.text.trim();
                String phone = phoneController.text.trim();
                String address = addressController.text.trim();

                if (name.isEmpty || phone.isEmpty || address.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('⚠️ कृपया सभी जानकारी भरें!'), backgroundColor: Colors.orange),
                  );
                  return;
                }

                CakeDatabase.bakeryShop['savedCustomerName'] = name;
                CakeDatabase.bakeryShop['savedCustomerPhone'] = phone;
                CakeDatabase.bakeryShop['savedCustomerAddress'] = address;

                Navigator.pop(context);
                _confirmFinalOrderAndPushToCloud(name, phone, address);
              },
              child: const Text('ऑर्डर कन्फर्म करें'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _confirmFinalOrderAndPushToCloud(String customerName, String customerPhone, String customerAddress) async {
    if (CakeDatabase.cartItems.isEmpty) return;

    double totalAmount = totalCartAmount;
    Map<String, dynamic> finalOrderData = {
      'customerName': customerName,
      'customerPhone': customerPhone,
      'customerAddress': customerAddress,
      'items': List.from(CakeDatabase.cartItems),
      'grandTotal': totalAmount,
      'totalAmount': totalAmount,
      'paymentMode': 'COD',
      'orderStatus': 'Pending',
      'status': 'Pending',
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };

    try {
      final riderUri = Uri.parse('${CakeDatabase.firebaseRestUrl}/orders.json');
      await http.post(riderUri, body: json.encode(finalOrderData));

      final vendorUri = Uri.parse('${CakeDatabase.firebaseRestUrl}/vendor_orders.json');
      await http.post(vendorUri, body: json.encode(finalOrderData));

      setState(() {
        _cartQuantities.clear();
        CakeDatabase.cartItems.clear();
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🎉 आर्डर सफलतापूर्वक भेज दिया गया!', style: TextStyle(fontWeight: FontWeight.bold)),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      debugPrint("Order error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    Map<String, Map<String, dynamic>> shopsMap = {};

    for (var prod in CakeDatabase.productInventory) {
      bool matchesCategory = (selectedCategory == 'All' || prod['category'] == selectedCategory);
      String productName = (prod['name'] ?? '').toString().toLowerCase();
      bool matchesSearch = productName.contains(_searchQuery.toLowerCase());

      if (!matchesCategory || !matchesSearch) {
        continue;
      }

      String shopId = prod['shopId'] ?? prod['vendorPhone'] ?? 'tarun_fruit_shop';
      String shopName = prod['shopName'] ?? 'Tarun Fruit Shop';
      String shopAddress = prod['shopAddress'] ?? 'sector 89a ajronda sabji mandi faridabad';

      if (!shopsMap.containsKey(shopId)) {
        shopsMap[shopId] = {
          'shopId': shopId,
          'shopName': shopName,
          'shopAddress': shopAddress,
          'products': <Map<String, dynamic>>[],
        };
      }
      shopsMap[shopId]!['products'].add(prod);
    }

    List<Map<String, dynamic>> groupedShopsList = shopsMap.values.toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: _fetchShopProfileAndProducts,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 90),
              children: [
                // 🔍 सर्च बार और रिफ्रेश बटन (Search Bar & Refresh Button)
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        onChanged: (val) => setState(() => _searchQuery = val),
                        decoration: InputDecoration(
                          hintText: 'फल, सब्जियां या आइटम खोजें...',
                          prefixIcon: const Icon(Icons.search, color: Colors.green),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() => _searchQuery = '');
                                  },
                                )
                              : null,
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.refresh, color: Colors.green),
                        tooltip: 'डेटा रिफ्रेश करें',
                        onPressed: _fetchShopProfileAndProducts,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // कैटेगरी फिल्टर्स (Categories)
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: categories.map((cat) {
                      bool isSelected = selectedCategory == cat;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(cat),
                          selected: isSelected,
                          selectedColor: Colors.green.shade700,
                          labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.black87),
                          onSelected: (val) => setState(() => selectedCategory = cat),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 10),

                _isLoadingCloud
                    ? const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator()))
                    : groupedShopsList.isEmpty
                        ? const Padding(
                            padding: EdgeInsets.all(50),
                            child: Center(child: Text('कोई दुकान या सामान उपलब्ध नहीं है!', style: TextStyle(color: Colors.grey))),
                          )
                        : ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: groupedShopsList.length,
                            itemBuilder: (context, shopIndex) {
                              var shopData = groupedShopsList[shopIndex];
                              List shopProducts = shopData['products'];

                              return Container(
                                margin: const EdgeInsets.only(bottom: 20),
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: Colors.grey.shade300),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // 🏬 दुकान की हैडर पट्टी (Shop Header)
                                    Row(
                                      children: [
                                        const CircleAvatar(
                                          backgroundColor: Colors.green,
                                          child: Icon(Icons.store, color: Colors.white),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(shopData['shopName'], style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                              Text('📍 ${shopData['shopAddress']}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    const Divider(height: 20),

                                    // 🍎 इस दुकान के प्रोडक्ट्स की ग्रिड लिस्ट
                                    GridView.builder(
                                      shrinkWrap: true,
                                      physics: const NeverScrollableScrollPhysics(),
                                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                        crossAxisCount: 2,
                                        crossAxisSpacing: 10,
                                        mainAxisSpacing: 10,
                                        childAspectRatio: 0.72,
                                      ),
                                      itemCount: shopProducts.length,
                                      itemBuilder: (context, prodIndex) {
                                        var prod = shopProducts[prodIndex];
                                        String prodId = prod['firebaseKey'] ?? prod['id'] ?? prod['name'];
                                        double qty = _cartQuantities[prodId] ?? 0.0;
                                        String unit = prod['unit'] ?? 'Kg';
                                        String imageUrl = prod['image'] ?? '';

                                        return Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: Colors.grey.shade50,
                                            borderRadius: BorderRadius.circular(12),
                                            border: Border.all(color: Colors.grey.shade200),
                                          ),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Expanded(
                                                child: ClipRRect(
                                                  borderRadius: BorderRadius.circular(8),
                                                  child: imageUrl.isNotEmpty
                                                      ? Image.network(
                                                          imageUrl,
                                                          fit: BoxFit.cover,
                                                          width: double.infinity,
                                                          errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.broken_image, size: 40, color: Colors.grey)),
                                                        )
                                                      : const Center(child: Icon(Icons.image, size: 40, color: Colors.grey)),
                                                ),
                                              ),
                                              const SizedBox(height: 6),
                                              Text(prod['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                                              Text('₹${prod['price']} / $unit', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12)),
                                              const SizedBox(height: 6),
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
                                                      mainAxisAlignment: MainAxisAlignment.center,
                                                      children: [
                                                        IconButton(
                                                          icon: const Icon(Icons.remove_circle, color: Colors.red, size: 20),
                                                          onPressed: () => _decrementQty(prod),
                                                          padding: EdgeInsets.zero,
                                                          constraints: const BoxConstraints(),
                                                        ),
                                                        GestureDetector(
                                                          onTap: () => _showCustomQuantityDialog(prod),
                                                          child: Padding(
                                                            padding: const EdgeInsets.symmetric(horizontal: 4),
                                                            child: Text('$qty', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                                          ),
                                                        ),
                                                        IconButton(
                                                          icon: const Icon(Icons.add_circle, color: Colors.green, size: 20),
                                                          onPressed: () => _incrementQty(prod),
                                                          padding: EdgeInsets.zero,
                                                          constraints: const BoxConstraints(),
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
                            },
                          ),
              ],
            ),
          ),

          // 🛒 नीचे व्यू कार्ट (View Cart) फ्लोटिंग बार
          if (totalCartItems > 0)
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade800,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 6,
                ),
                onPressed: _showCartBottomSheet,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(left: 10),
                      child: Text('${totalCartItems.toStringAsFixed(0)} आइटम चुने गए', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    ),
                    Row(
                      children: [
                        Text('₹$totalCartAmount', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(width: 6),
                        const Icon(Icons.shopping_cart, size: 20),
                        const SizedBox(width: 10),
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
