import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'shared_preferences_helper.dart'; // सुनिश्चित करें कि आपकी SharedPreferences की फाइल या इम्पोर्ट सही हो
import 'database_models.dart';

class CartAndOrdersView extends StatefulWidget {
  const CartAndOrdersView({super.key});

  @override
  State<CartAndOrdersView> createState() => _CartAndOrdersViewState();
}

class _CartAndOrdersViewState extends State<CartAndOrdersView> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadLocalOrdersAndFetch();
  }

  Future<void> _loadLocalOrdersAndFetch() async {
    setState(() => _isLoading = true);
    try {
      // लोकल स्टोरेज से ऑर्डर्स लोड करें
      await CakeDatabase.loadOrdersLocally();
    } catch (e) {
      debugPrint("Error loading local orders: $e");
    }
    
    // क्लाउड से भी लेटेस्ट ऑर्डर्स सिंक कर लें
    await _fetchOrdersFromCloud();
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _fetchOrdersFromCloud() async {
    try {
      final response = await http.get(Uri.parse('${CakeDatabase.firebaseRestUrl}/orders.json')).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200 && response.body != 'null' && response.body.isNotEmpty) {
        var decoded = json.decode(response.body);
        List<Map<String, dynamic>> cloudOrders = [];
        if (decoded is Map) {
          decoded.forEach((key, value) {
            if (value is Map) {
              var order = Map<String, dynamic>.from(value.map((k, v) => MapEntry(k.toString(), v)));
              cloudOrders.add(order);
            }
          });
        }
        
        // नए ऑर्डर्स को ऊपर दिखाने के लिए सॉर्ट करें
        cloudOrders.sort((a, b) => (b['timestamp'] ?? 0).compareTo(a['timestamp'] ?? 0));
        
        setState(() {
          CakeDatabase.localOrdersCache = cloudOrders;
        });
        await CakeDatabase.saveOrdersLocally();
      }
    } catch (e) {
      debugPrint("Error fetching cloud orders: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.green.shade700,
        title: const Text('📦 मेरे ऑर्डर्स और कार्ट', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: '🛒 मेरी कार्ट (Cart)'),
            Tab(text: '📋 बुक किए गए ऑर्डर्स (Orders)'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadLocalOrdersAndFetch,
          )
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildCartTab(),
          _buildOrdersTab(),
        ],
      ),
    );
  }

  // 🛒 कार्ट टैब व्यू
  Widget _buildCartTab() {
    if (CakeDatabase.cartItems.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.remove_shopping_cart, size: 64, color: Colors.grey),
            SizedBox(height: 12),
            Text('आपकी कार्ट खाली है!', style: TextStyle(fontSize: 16, color: Colors.grey, fontWeight: FontWeight.bold)),
          ],
        ),
      );
    }

    double totalAmount = 0;
    for (var item in CakeDatabase.cartItems) {
      double price = (item['price'] ?? 0.0) is num ? (item['price'] ?? 0.0).toDouble() : double.tryParse(item['price'].toString()) ?? 0.0;
      double qty = (item['qty'] ?? 1.0) is num ? (item['qty'] ?? 1.0).toDouble() : double.tryParse(item['qty'].toString()) ?? 1.0;
      totalAmount += (price * qty);
    }

    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: CakeDatabase.cartItems.length,
            itemBuilder: (context, index) {
              var item = CakeDatabase.cartItems[index];
              double price = (item['price'] ?? 0.0).toDouble();
              double qty = (item['qty'] ?? 1.0).toDouble();
              String unit = item['unit'] ?? 'Kg';

              return Card(
                elevation: 2,
                margin: const EdgeInsets.only(bottom: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: (item['image'] ?? '').toString().isNotEmpty
                        ? Image.network(item['image'], width: 50, height: 50, fit: BoxFit.cover, errorBuilder: (c, e, s) => const Icon(Icons.image))
                        : Container(width: 50, height: 50, color: Colors.grey.shade200, child: const Icon(Icons.shopping_bag)),
                  ),
                  title: Text(item['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('₹$price x $qty $unit'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('₹${(price * qty).toStringAsFixed(1)}', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green.shade700, fontSize: 15)),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                        onPressed: () {
                          setState(() {
                            CakeDatabase.cartItems.removeAt(index);
                          });
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4, offset: const Offset(0, -2))],
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('कुल राशि (Grand Total):', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  Text('₹${totalAmount.toStringAsFixed(1)}', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green.shade700)),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade700, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                  onPressed: () {
                    // यहाँ से आप चेकआउट/ऑर्डर प्लेसमेंट स्क्रीन पर जा सकते हैं या सीधे आर्डर कन्फर्म कर सकते हैं
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('कृपया मार्केटप्लेस व्यू से ऑर्डर फाइनल करें!')));
                  },
                  child: const Text('ऑर्डर पूरा करें', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // 📋 ऑर्डर्स टैब व्यू (यहाँ नए ऑर्डर्स लाल/डार्क शेड में दिखेंगे)
  Widget _buildOrdersTab() {
    List orders = CakeDatabase.localOrdersCache ?? [];

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (orders.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.assignment_outlined, size: 64, color: Colors.grey),
            SizedBox(height: 12),
            Text('अभी तक कोई ऑर्डर नहीं किया गया है!', style: TextStyle(fontSize: 15, color: Colors.grey, fontWeight: FontWeight.bold)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: orders.length,
      itemBuilder: (context, index) {
        var order = orders[index];
        String orderId = order['orderId'] ?? 'N/A';
        String status = order['orderStatus'] ?? order['status'] ?? 'Pending';
        double totalAmt = (order['grandTotal'] ?? order['totalAmount'] ?? 0.0).toDouble();
        List items = order['items'] ?? [];
        String customerName = order['customerName'] ?? 'Customer';
        String address = order['customerAddress'] ?? 'Faridabad';

        // 🔴 निर्देशानुसार: नया या पेंडिंग ऑर्डर लाल/डार्क शेड में हाईलाइट होगा
        bool isPending = status.toLowerCase() == 'pending';

        return Card(
          elevation: 3,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          // अगर ऑर्डर पेंडिंग है तो कार्ड का बॉर्डर या हल्का शेड लाल रहेगा
          color: isPending ? Colors.red.shade50 : Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('ऑर्डर ID: $orderId', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isPending ? Colors.red.shade700 : Colors.green.shade700,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        status.toUpperCase(),
                        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const Divider(),
                Text('ग्राहक: $customerName', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                Text('पता: $address', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                const SizedBox(height: 6),
                Text('सामग्री (${items.length} आइटम्स):', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.black54)),
                ...items.map<Widget>((it) => Padding(
                  padding: const EdgeInsets.only(left: 8, top: 2),
                  child: Text('• ${it['name']} (x${it['qty']} ${it['unit'] ?? 'Kg'}) - ₹${(it['price'] * it['qty']).toStringAsFixed(1)}', style: const TextStyle(fontSize: 12)),
                )),
                const Divider(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('कुल भुगतान:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    Text('₹${totalAmt.toStringAsFixed(1)}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isPending ? Colors.red.shade800 : Colors.green.shade700)),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
