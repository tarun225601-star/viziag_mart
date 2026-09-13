import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'database_models.dart';

class VendorAuthAndPortalView extends StatefulWidget {
  const VendorAuthAndPortalView({super.key});

  @override
  State<VendorAuthAndPortalView> createState() => _VendorAuthAndPortalViewState();
}

class _VendorAuthAndPortalViewState extends State<VendorAuthAndPortalView> {
  int _viewMode = 0;

  final regShopNameCtrl = TextEditingController();
  final regPhoneCtrl = TextEditingController();
  final regAddressCtrl = TextEditingController();
  final regPass1Ctrl = TextEditingController();
  final regPass2Ctrl = TextEditingController();

  final loginPhoneCtrl = TextEditingController();
  final loginPassCtrl = TextEditingController();
  final adminCodeCtrl = TextEditingController();

  bool _isLoading = false;
  bool _isShopOpen = true; 

  List<Map<String, dynamic>> _vendorOrders = [];
  StreamSubscription<DatabaseEvent>? _ordersSubscription; 
  Timer? _uiRefreshTimer; // 🕒 लाइव टाइमर को हर 30 सेकंड में अपडेट रखने के लिए
  
  Set<String> _localSeenOrderIds = {};
  bool _isFirstLoad = true;

  @override
  void initState() {
    super.initState();
    _isShopOpen = CakeDatabase.bakeryShop['isOpen'] ?? true;
    _loadLocalSeenOrders();
    
    // 🕒 लाइव टाइमर अपडेट करने वाला टिकर
    _uiRefreshTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (mounted) setState(() {});
    });
  }

  Future<void> _loadLocalSeenOrders() async {
    final prefs = await SharedPreferences.getInstance();
    List<String> savedIds = prefs.getStringList('vendor_seen_order_ids') ?? [];
    setState(() {
      _localSeenOrderIds = savedIds.toSet();
    });
  }

  Future<void> _saveSeenOrderIds() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('vendor_seen_order_ids', _localSeenOrderIds.toList());
  }

  @override
  void dispose() {
    _ordersSubscription?.cancel(); 
    _uiRefreshTimer?.cancel();
    regShopNameCtrl.dispose();
    regPhoneCtrl.dispose();
    regAddressCtrl.dispose();
    regPass1Ctrl.dispose();
    regPass2Ctrl.dispose();
    loginPhoneCtrl.dispose();
    loginPassCtrl.dispose();
    adminCodeCtrl.dispose();
    super.dispose();
  }

  void _startVendorOrderListener() {
    _ordersSubscription?.cancel();
    DatabaseReference ordersRef = FirebaseDatabase.instance.ref('orders');

    _ordersSubscription = ordersRef.onValue.listen((event) {
      final snapshot = event.snapshot;
      
      if (snapshot.value == null) {
        if (mounted) {
          setState(() {
            _vendorOrders = [];
          });
        }
        return;
      }

      Map<String, dynamic> data = Map<String, dynamic>.from(snapshot.value as Map);
      List<Map<String, dynamic>> loadedOrders = [];
      bool hasNewOrder = false;

      data.forEach((key, val) {
        if (val is Map) {
          var ord = Map<String, dynamic>.from(val);
          ord['orderId'] = key;
          
          if (!_localSeenOrderIds.contains(key)) {
            hasNewOrder = true;
            _localSeenOrderIds.add(key);
          }

          loadedOrders.add(ord);
        }
      });

      _saveSeenOrderIds();
      loadedOrders = loadedOrders.reversed.toList();

      if (mounted) {
        if (!_isFirstLoad && hasNewOrder) {
          HapticFeedback.heavyImpact();
          ScaffoldMessenger.of(context).removeCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('⚡ 🛒 नया आर्डर प्राप्त हुआ है!'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 4),
            ),
          );
        }

        setState(() {
          _vendorOrders = loadedOrders;
          _isFirstLoad = false;
        });
      }
    }, onError: (error) {
      debugPrint("Realtime database error: $error");
    });
  }

  // 🕒 आर्डर की सही तारीख, समय और टाइमर कैलकुलेट करने का शानदार फंक्शन
  String _getOrderTimeInfo(dynamic timestamp) {
    if (timestamp == null || timestamp.toString().isEmpty) return 'अभी-अभी';
    try {
      DateTime orderTime;
      if (timestamp is int) {
        orderTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
      } else {
        orderTime = DateTime.parse(timestamp.toString());
      }

      Duration diff = DateTime.now().difference(orderTime);
      
      String dateStr = "${orderTime.day}/${orderTime.month}/${orderTime.year}";
      String timeStr = "${orderTime.hour > 12 ? orderTime.hour - 12 : (orderTime.hour == 0 ? 12 : orderTime.hour)}:${orderTime.minute.toString().padLeft(2, '0')} ${orderTime.hour >= 12 ? 'PM' : 'AM'}";

      String ago = '';
      if (diff.inMinutes < 1) {
        ago = 'अभी-अभी (Just now)';
      } else if (diff.inMinutes < 60) {
        ago = '${diff.inMinutes} मिनट पहले';
      } else if (diff.inHours < 24) {
        ago = '${diff.inHours} घंटे पहले';
      } else {
        ago = '${diff.inDays} दिन पहले';
      }

      return '📅 $dateStr | ⏰ $timeStr  ($ago)';
    } catch (e) {
      return timestamp.toString();
    }
  }

  Future<void> _deleteOrder(String orderId) async {
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('⚠️ आर्डर डिलीट करें?'),
        content: const Text('क्या आप इस आर्डर को हमेशा के लिए हटाना चाहते हैं?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('नहीं')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('हाँ, डिलीट करें', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await FirebaseDatabase.instance.ref('orders/$orderId').remove();
        _localSeenOrderIds.remove(orderId);
        _saveSeenOrderIds();

        HapticFeedback.mediumImpact();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('🗑️ आर्डर डिलीट कर दिया गया!'), backgroundColor: Colors.red),
          );
        }
      } catch (e) {
        debugPrint("Delete order error: $e");
      }
    }
  }

  Future<void> _updateOrderStatus(String orderId, String newStatus) async {
    try {
      await FirebaseDatabase.instance.ref('orders/$orderId').update({
        'status': newStatus,
        'orderStatus': newStatus,
      });
      HapticFeedback.mediumImpact();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('✅ आर्डर स्टेटस बदलकर "$newStatus" कर दिया गया!'), backgroundColor: Colors.green));
      }
    } catch (e) {
      debugPrint("Status update error: $e");
    }
  }

  Future<void> _submitRegistration() async {
    if (regPhoneCtrl.text.trim().length < 10 || regShopNameCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('⚠️ कृपया दुकान का नाम और सही मोबाइल नंबर भरें!'), backgroundColor: Colors.red));
      return;
    }
    if (regPass1Ctrl.text.isEmpty || regPass1Ctrl.text != regPass2Ctrl.text) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('⚠️ पासवर्ड मेल नहीं खा रहे हैं!'), backgroundColor: Colors.red));
      return;
    }

    setState(() => _isLoading = true);
    try {
      var shopData = {
        'name': regShopNameCtrl.text.trim(),
        'phone': regPhoneCtrl.text.trim(),
        'shopAddress': regAddressCtrl.text.trim().isEmpty ? 'Sector 89A Faridabad' : regAddressCtrl.text.trim(),
        'address': regAddressCtrl.text.trim().isEmpty ? 'Sector 89A Faridabad' : regAddressCtrl.text.trim(),
        'pass': regPass1Ctrl.text.trim(),
        'status': 'pending',
      };

      await http.post(
        Uri.parse('${CakeDatabase.firebaseRestUrl}/vendor_requests.json'),
        body: json.encode(shopData),
      );

      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('⏳ रिक्वेस्ट सबमिट हो गई'),
            content: const Text('आपकी दुकान का रजिस्ट्रेशन हो गया है। मास्टर एडमिन (तरुण) द्वारा अप्रूव होने के बाद ही आप लॉगिन कर पाएंगे।'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  setState(() => _viewMode = 0);
                },
                child: const Text('ठीक है'),
              ),
            ],
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loginVendor() async {
    String phone = loginPhoneCtrl.text.trim();
    String pass = loginPassCtrl.text.trim();

    if (phone.isEmpty || pass.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('⚠️ कृपया मोबाइल नंबर और पासवर्ड दर्ज करें!'), backgroundColor: Colors.red));
      return;
    }

    setState(() => _isLoading = true);
    try {
      final res = await http.get(Uri.parse('${CakeDatabase.firebaseRestUrl}/vendor_requests.json'));
      bool isApproved = false;

      if (res.statusCode == 200 && res.body != 'null' && res.body.isNotEmpty) {
        Map<String, dynamic> data = json.decode(res.body);
        data.forEach((key, val) {
          if (val['phone'] == phone && val['pass'] == pass && val['status'] == 'approved') {
            isApproved = true;
          }
        });
      }

      if (isApproved) {
        setState(() => _viewMode = 3);
        _startVendorOrderListener();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ स्वागत है! वेंडर डैशबोर्ड खुल गया है।'), backgroundColor: Colors.green));
        }
      } else {
        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('⚠️ लॉगिन असफल (Not Approved)'),
              content: const Text('आपकी दुकान अभी तक मास्टर एडमिन (तरुण) द्वारा अप्रूव नहीं की गई है! कृपया पहले अप्रूवल लें।'),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('ठीक है')),
              ],
            ),
          );
        }
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleShopStatus(bool value) async {
    setState(() => _isShopOpen = value);
    CakeDatabase.bakeryShop['isOpen'] = value;

    try {
      await http.patch(
        Uri.parse('${CakeDatabase.firebaseRestUrl}/shop_profile.json'),
        body: json.encode({'isOpen': value}),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(value ? '🟢 दुकान अब खुली (Open) है।' : '🔴 दुकान अब बंद (Closed) कर दी गई है।'),
            backgroundColor: value ? Colors.green : Colors.red,
          ),
        );
      }
    } catch (e) {
      debugPrint("Shop status update error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_viewMode == 0) {
      return Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.storefront, size: 75, color: Colors.green),
            const SizedBox(height: 15),
            const Text('🛍️ वेंडर पोर्टल', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 5),
            const Text('बिना एडमिन अप्रूवल के कोई भी वेंडर लॉगिन नहीं कर सकता', style: TextStyle(fontSize: 11, color: Colors.grey), textAlign: TextAlign.center),
            const SizedBox(height: 40),
            
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade700, foregroundColor: Colors.white),
                onPressed: () => setState(() => _viewMode = 1),
                icon: const Icon(Icons.person_add),
                label: const Text('नई दुकान रजिस्टर करें (New Registration)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              ),
            ),
            const SizedBox(height: 15),

            SizedBox(
              width: double.infinity,
              height: 50,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.green, width: 2), foregroundColor: Colors.green.shade800),
                onPressed: () => setState(() => _viewMode = 2),
                icon: const Icon(Icons.login),
                label: const Text('वेंडर लॉगिन (Existing Vendor Login)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              ),
            ),
          ],
        ),
      );
    }

    if (_viewMode == 1) {
      return Padding(
        padding: const EdgeInsets.all(20),
        child: ListView(
          children: [
            const SizedBox(height: 10),
            const Center(child: Text('📝 नया वेंडर रजिस्ट्रेशन', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold))),
            const SizedBox(height: 20),
            TextField(controller: regShopNameCtrl, decoration: const InputDecoration(labelText: 'दुकान का नाम (Shop Name)', border: OutlineInputBorder(), prefixIcon: Icon(Icons.store))),
            const SizedBox(height: 15),
            TextField(controller: regPhoneCtrl, keyboardType: TextInputType.phone, maxLength: 10, decoration: const InputDecoration(labelText: 'मोबाइल नंबर', border: OutlineInputBorder(), counterText: '', prefixIcon: Icon(Icons.phone))),
            const SizedBox(height: 15),
            TextField(controller: regAddressCtrl, decoration: const InputDecoration(labelText: 'दुकान का पता / लोकेशन', border: OutlineInputBorder(), prefixIcon: Icon(Icons.location_on))),
            const SizedBox(height: 15),
            TextField(controller: regPass1Ctrl, obscureText: true, decoration: const InputDecoration(labelText: 'पासवर्ड बनाएं', border: OutlineInputBorder(), prefixIcon: Icon(Icons.lock_outline))),
            const SizedBox(height: 15),
            TextField(controller: regPass2Ctrl, obscureText: true, decoration: const InputDecoration(labelText: 'पासवर्ड दोबारा दर्ज करें', border: OutlineInputBorder(), prefixIcon: Icon(Icons.lock))),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade700, foregroundColor: Colors.white),
                onPressed: _isLoading ? null : _submitRegistration,
                child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text('अप्रूवल के लिए सबमिट करें', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              ),
            ),
            const SizedBox(height: 10),
            TextButton(onPressed: () => setState(() => _viewMode = 0), child: const Text('← वापस जाएं')),
          ],
        ),
      );
    }

    if (_viewMode == 2) {
      return Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lock_open, size: 65, color: Colors.green),
            const SizedBox(height: 15),
            const Text('🔐 वेंडर लॉगिन', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 5),
            const Text('पहले एडमिन से अप्रूव कराना अनिवार्य है', style: TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 25),
            TextField(controller: loginPhoneCtrl, keyboardType: TextInputType.phone, maxLength: 10, decoration: const InputDecoration(labelText: 'मोबाइल नंबर', border: OutlineInputBorder(), counterText: '', prefixIcon: Icon(Icons.phone))),
            const SizedBox(height: 15),
            TextField(controller: loginPassCtrl, obscureText: true, decoration: const InputDecoration(labelText: 'पासवर्ड', border: OutlineInputBorder(), prefixIcon: Icon(Icons.lock))),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade700, foregroundColor: Colors.white),
                onPressed: _isLoading ? null : _loginVendor,
                child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text('लॉगिन करें ➔', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              ),
            ),
            const SizedBox(height: 10),
            TextButton(onPressed: () => setState(() => _viewMode = 0), child: const Text('← वापस जाएं', style: TextStyle(color: Colors.grey))),
          ],
        ),
      );
    }

    // 🟢 वेंडर डैशबोर्ड (आइटम फोटो, नाम, क्वांटिटी, पूरा बिल, डेट, टाइम और टाइमर के साथ)
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Card(
            elevation: 3,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('दुकान की स्थिति', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      Text(
                        _isShopOpen ? '🟢 खुली हुई है (Open)' : '🔴 बंद है (Closed)',
                        style: TextStyle(color: _isShopOpen ? Colors.green.shade700 : Colors.red, fontWeight: FontWeight.bold, fontSize: 11),
                      ),
                    ],
                  ),
                  Switch(
                    value: _isShopOpen,
                    activeColor: Colors.green,
                    onChanged: _toggleShopStatus,
                  ),
                  IconButton(
                    icon: const Icon(Icons.logout, color: Colors.red, size: 22),
                    onPressed: () {
                      _ordersSubscription?.cancel();
                      setState(() => _viewMode = 0);
                    },
                    tooltip: 'लॉग आउट',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('🚀 लाइव ऑर्डर्स (Itemized Bill & Timer)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: Colors.green.shade100, borderRadius: BorderRadius.circular(12)),
                child: const Text('🟢 Live Connected', style: TextStyle(color: Colors.green, fontSize: 10, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const Divider(height: 8),

          Expanded(
            child: _vendorOrders.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.receipt_long_outlined, size: 50, color: Colors.grey),
                        SizedBox(height: 8),
                        Text('कोई आर्डर नहीं मिला', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: _vendorOrders.length,
                    itemBuilder: (context, index) {
                      var ord = _vendorOrders[index];
                      String orderId = ord['orderId'] ?? '';
                      String custName = ord['customerName'] ?? ord['name'] ?? 'ग्राहक';
                      String custPhone = ord['customerPhone'] ?? ord['phone'] ?? '';
                      String custAddress = ord['customerAddress'] ?? ord['deliveryAddress'] ?? ord['address'] ?? 'पता उपलब्ध नहीं';
                      dynamic grandTotal = ord['grandTotal'] ?? ord['totalAmount'] ?? 0;
                      String status = ord['status'] ?? ord['orderStatus'] ?? 'Pending';
                      dynamic timestamp = ord['timestamp'];
                      List itemsList = ord['items'] ?? [];

                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        elevation: 2,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      'ग्राहक: $custName',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.green),
                                    ),
                                  ),
                                  PopupMenuButton<String>(
                                    onSelected: (val) {
                                      if (val == 'delete') {
                                        _deleteOrder(orderId);
                                      } else {
                                        _updateOrderStatus(orderId, val);
                                      }
                                    },
                                    itemBuilder: (context) => [
                                      const PopupMenuItem(value: 'Pending', child: Text('⏳ Pending')),
                                      const PopupMenuItem(value: 'Accept', child: Text('✅ Accept (स्वीकार करें)')),
                                      const PopupMenuItem(value: 'Out for Delivery', child: Text('🛵 Out for Delivery')),
                                      const PopupMenuItem(value: 'Delivered', child: Text('🎉 Delivered')),
                                      const PopupMenuItem(value: 'Cancelled', child: Text('❌ Cancelled', style: TextStyle(color: Colors.red))),
                                      const PopupMenuItem(value: 'delete', child: Text('🗑️ डिलीट करें', style: TextStyle(color: Colors.red))),
                                    ],
                                  ),
                                ],
                              ),
                              if (custPhone.isNotEmpty)
                                Text('📞 ($custPhone)', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87)),
                              const SizedBox(height: 2),
                              Text('पता: $custAddress', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                              const SizedBox(height: 6),
                              
                              // 🕒 टाइमर और तारीख
                              Text(_getOrderTimeInfo(timestamp), style: const TextStyle(fontSize: 10, color: Colors.blueGrey, fontStyle: FontStyle.italic)),
                              const Divider(height: 12),

                              // 🛒 आर्डर के आइटम्स, फोटो और क्वांटिटी दिखाने की लिस्ट
                              ...itemsList.map((it) {
                                var m = it is Map ? it : {};
                                String itemName = m['name'] ?? m['title'] ?? 'आइटम';
                                var itemQty = m['qty'] ?? 1;
                                var itemPrice = double.tryParse(m['price'].toString()) ?? 0;
                                String? img = m['image'] ?? m['imageUrl'];

                                return Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 3.0),
                                  child: Row(
                                    children: [
                                      if (img != null && img.isNotEmpty)
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(4),
                                          child: Image.network(
                                            img, 
                                            width: 30, 
                                            height: 30, 
                                            fit: BoxFit.cover,
                                            errorBuilder: (context, error, stackTrace) => const Icon(Icons.fastfood, size: 24, color: Colors.grey),
                                          ),
                                        )
                                      else
                                        const Icon(Icons.fastfood, size: 24, color: Colors.grey),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text('• $itemName (x$itemQty)', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                                      ),
                                      Text('₹${itemPrice * (double.tryParse(itemQty.toString()) ?? 1)}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                );
                              }),

                              const Divider(height: 12),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('कुल राशि: ₹$grandTotal', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.green.shade800)),
                                  Text('स्टेटस: $status', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: status == 'Accept' ? Colors.green : (status == 'Delivered' ? Colors.blue : Colors.orange))),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
