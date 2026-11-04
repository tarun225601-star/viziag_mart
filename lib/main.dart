import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:typed_data';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: "AlzaSyDummyKeyForViziawork",
        appId: "1:23456789:android:abcdef",
        messagingSenderId: "123456789",
        projectId: "viziawork",
        databaseURL: "https://viziawork-default-rtdb.firebaseio.com/",
      ),
    );
  } catch (e) {
    debugPrint("Firebase init warning: $e");
  }

  runApp(const ViziagMartApp());
}

class ViziagDatabase {
  static String firebaseRestUrl = "https://viziawork-default-rtdb.firebaseio.com";
}

class ViziagMartApp extends StatelessWidget {
  const ViziagMartApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Viziag Mart',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        scaffoldBackgroundColor: const Color(0xFFF4F6F8),
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
      ),
      home: const MainHubScreen(),
    );
  }
}

class MainHubScreen extends StatefulWidget {
  const MainHubScreen({super.key});

  @override
  State<MainHubScreen> createState() => _MainHubScreenState();
}

class _MainHubScreenState extends State<MainHubScreen> {
  int _selectedTabIndex = 0;

  final List<Widget> _tabScreens = [
    const CustomerMarketplaceView(),
    const VendorDashboardPortalView(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(65),
        child: AppBar(
          backgroundColor: Colors.white,
          elevation: 1,
          title: const Row(
            children: [
              Icon(Icons.campaign, color: Colors.green, size: 28),
              SizedBox(width: 8),
              Text(
                'VIZIAG MART',
                style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: 1.2),
              ),
            ],
          ),
        ),
      ),
      body: _tabScreens[_selectedTabIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedTabIndex,
        selectedItemColor: Colors.green.shade700,
        unselectedItemColor: Colors.grey,
        backgroundColor: Colors.white,
        onTap: (i) => setState(() => _selectedTabIndex = i),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.storefront_outlined),
            activeIcon: Icon(Icons.storefront),
            label: 'लाइव मार्केट (ग्राहक)',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.add_alert_outlined),
            activeIcon: Icon(Icons.add_alert),
            label: 'नोटिफिकेशन डालें (वेंडर)',
          ),
        ],
      ),
    );
  }
}

// =============================================================
// 1️⃣ ग्राहक डैशबोर्ड (Customer / Buyer Dashboard with Search Bar)
// =============================================================
class CustomerMarketplaceView extends StatefulWidget {
  const CustomerMarketplaceView({super.key});

  @override
  State<CustomerMarketplaceView> createState() => _CustomerMarketplaceViewState();
}

class _CustomerMarketplaceViewState extends State<CustomerMarketplaceView> {
  var _liveBroadcasts = [];
  var _filteredBroadcasts = [];
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchLiveBroadcasts();
    _searchController.addListener(_filterSearch);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchLiveBroadcasts() async {
    try {
      final res = await http.get(Uri.parse('${ViziagDatabase.firebaseRestUrl}/live_broadcasts.json'));
      if (res.statusCode == 200 && res.body != 'null' && res.body.isNotEmpty) {
        var data = json.decode(res.body);
        var loadedList = [];
        int currentTime = DateTime.now().millisecondsSinceEpoch;

        data.forEach((key, val) {
          if (val is Map) {
            var mapVal = Map<String, dynamic>.from(val);
            mapVal['id'] = key;

            int postTime = mapVal['timestamp'] ?? 0;
            int expiryLimit = postTime + (24 * 60 * 60 * 1000); // 24 घंटे की समयावधि

            if (currentTime < expiryLimit) {
              loadedList.add(mapVal);
            }
          }
        });
        setState(() {
          _liveBroadcasts = loadedList.reversed.toList();
          _filteredBroadcasts = _liveBroadcasts;
        });
      }
    } catch (e) {
      debugPrint("Error fetching broadcasts: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _filterSearch() {
    String query = _searchController.text.toLowerCase();
    setState(() {
      _filteredBroadcasts = _liveBroadcasts.where((item) {
        String itemName = (item['itemName'] ?? '').toLowerCase();
        String shopName = (item['shopName'] ?? '').toLowerCase();
        String ownerName = (item['ownerName'] ?? '').toLowerCase();
        String location = (item['location'] ?? '').toLowerCase();
        return itemName.contains(query) || shopName.contains(query) || ownerName.contains(query) || location.contains(query);
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _fetchLiveBroadcasts,
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'समान, दुकान या मालिक का नाम खोजें...',
              prefixIcon: const Icon(Icons.search, color: Colors.green),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
          const SizedBox(height: 12),

          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green.shade700,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Row(
              children: [
                Icon(Icons.notifications_active, color: Colors.white, size: 26),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '⚡ आसपास की दुकानों के लाइव अपडेट देखें और सीधा कॉल करें!',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 15),

          if (_isLoading)
            const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator()))
          else if (_filteredBroadcasts.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(40),
                child: Text('कोई लाइव नोटिफिकेशन नहीं मिला।', style: TextStyle(color: Colors.grey)),
              ),
            )
          else
            ..._filteredBroadcasts.map((item) {
              String serviceMode = item['serviceMode'] ?? 'होम डिलीवरी + पिकअप';
              String? imageBase64 = item['imageBase64'];
              String? shopLogoBase64 = item['shopLogoBase64'];

              return Card(
                margin: const EdgeInsets.only(bottom: 15),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (imageBase64 != null && imageBase64.isNotEmpty)
                      ClipRRect(
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                        child: Image.memory(
                          base64Decode(imageBase64),
                          height: 190,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (c, e, s) => Container(height: 100, color: Colors.grey.shade300, child: const Icon(Icons.broken_image)),
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              shopLogoBase64 != null && shopLogoBase64.isNotEmpty
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(20),
                                      child: Image.memory(
                                        base64Decode(shopLogoBase64),
                                        width: 40,
                                        height: 40,
                                        fit: BoxFit.cover,
                                      ),
                                    )
                                  : CircleAvatar(
                                      backgroundColor: Colors.green.shade100,
                                      radius: 20,
                                      child: const Icon(Icons.store, color: Colors.green, size: 22),
                                    ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item['shopName'] ?? 'दुकानदार',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                    ),
                                    Text(
                                      'मालिक: ${item['ownerName'] ?? "व्यापारी"}',
                                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(6)),
                                child: Text(
                                  '⏰ ${item['validTill'] ?? "आज ही"}',
                                  style: TextStyle(color: Colors.red.shade700, fontSize: 10, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 15),
                          Text(
                            item['itemName'] ?? '',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'कीमत / रेट: ₹${item['rate']}',
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.green),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: Colors.blue.shade200),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  serviceMode.contains('होम डिलीवरी') ? Icons.local_shipping : Icons.storefront,
                                  size: 14,
                                  color: Colors.blue.shade800,
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  serviceMode,
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blue.shade900),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(Icons.location_on, size: 14, color: Colors.grey),
                              const SizedBox(width: 4),
                              Text(item['location'] ?? 'Faridabad', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                            ],
                          ),
                          const Divider(height: 20),
                          SizedBox(
                            width: double.infinity,
                            height: 45,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade700, foregroundColor: Colors.white),
                              onPressed: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('📞 कॉल मिलाया जा रहा है: ${item['phone']}'),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                              },
                              icon: const Icon(Icons.call),
                              label: Text(
                                'दुकान पर सीधे कॉल करें (${item['phone'] ?? "नंबर"})',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}

// =============================================================
// 2️⃣ वेंडर डैशबोर्ड (Permanent Profile + Direct Posting)
// =============================================================
class VendorDashboardPortalView extends StatefulWidget {
  const VendorDashboardPortalView({super.key});

  @override
  State<VendorDashboardPortalView> createState() => _VendorDashboardPortalViewState();
}

class _VendorDashboardPortalViewState extends State<VendorDashboardPortalView> {
  bool _isProfileSetup = false;

  // प्रोफाइल कंट्रोल्स
  final shopNameCtrl = TextEditingController();
  final ownerNameCtrl = TextEditingController();
  final shopPhoneCtrl = TextEditingController();
  String _savedShopLogo = '';

  // पोस्टिंग कंट्रोल्स
  final itemNameCtrl = TextEditingController();
  final rateCtrl = TextEditingController();
  final locationCtrl = TextEditingController();
  final validTimeCtrl = TextEditingController();

  String _imageBase64 = '';
  String _videoBase64 = '';
  bool _isImageSelected = false;
  bool _isVideoSelected = false;

  String _selectedServiceMode = 'होम डिलीवरी + दुकान से पिकअप दोनों उपलब्ध';
  final List<String> _serviceOptions = [
    'होम डिलीवरी + दुकान से पिकअप दोनों उपलब्ध',
    'केवल दुकान से पिकअप (Self Pickup Only)',
    'केवल होम डिलीवरी (Home Delivery Only)'
  ];

  int _vendorWalletBalance = 500;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadVendorProfile();
  }

  // 🟢 मोबाइल की मेमोरी से हमेशा के लिए प्रोफाइल लोड करना
  Future<void> _loadVendorProfile() async {
    final prefs = await SharedPreferences.getInstance();
    String? sName = prefs.getString('shop_name');
    if (sName != null && sName.isNotEmpty) {
      setState(() {
        shopNameCtrl.text = sName;
        ownerNameCtrl.text = prefs.getString('owner_name') ?? '';
        shopPhoneCtrl.text = prefs.getString('shop_phone') ?? '';
        _savedShopLogo = prefs.getString('shop_logo') ?? '';
        _isProfileSetup = true;
      });
    }
  }

  // 🟢 प्रोफाइल को हमेशा के लिए सेव करना (ताकि दोबारा ऑप्शन न आए)
  Future<void> _saveVendorProfile() async {
    if (shopNameCtrl.text.trim().isEmpty || shopPhoneCtrl.text.trim().length < 10) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('⚠️ कृपया दुकान का नाम और सही मोबाइल नंबर भरें!'), backgroundColor: Colors.red));
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('shop_name', shopNameCtrl.text.trim());
    await prefs.setString('owner_name', ownerNameCtrl.text.trim());
    await prefs.setString('shop_phone', shopPhoneCtrl.text.trim());
    await prefs.setString('shop_logo', _savedShopLogo);

    setState(() {
      _isProfileSetup = true;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ दुकान की प्रोफाइल हमेशा के लिए सेव हो गई!')));
    }
  }

  // 🟢 प्रोफाइल एडिट करने का ऑप्शन (यदि कभी बदलना हो)
  void _editProfile() {
    setState(() {
      _isProfileSetup = false;
    });
  }

  Future<void> _pickShopLogo() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 30);
    if (pickedFile != null) {
      Uint8List bytes = await pickedFile.readAsBytes();
      setState(() {
        _savedShopLogo = base64Encode(bytes);
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ लोगो चुन लिया गया!')));
    }
  }

  Future<void> _pickImageFromGallery() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 40);
    if (pickedFile != null) {
      Uint8List bytes = await pickedFile.readAsBytes();
      setState(() {
        _imageBase64 = base64Encode(bytes);
        _isImageSelected = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ सामान की फोटो चुन ली गई!')));
    }
  }

  Future<void> _pickVideoFromGallery() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickVideo(source: ImageSource.gallery, maxDuration: const Duration(seconds: 10));
    if (pickedFile != null) {
      Uint8List bytes = await pickedFile.readAsBytes();
      setState(() {
        _videoBase64 = base64Encode(bytes);
        _isVideoSelected = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ 10s वीडियो चुन लिया गया!')));
    }
  }

  Future<void> _sendLiveNotificationBroadcast() async {
    if (itemNameCtrl.text.trim().isEmpty || rateCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('⚠️ कृपया सामान का नाम और रेट भरें!'), backgroundColor: Colors.red));
      return;
    }

    if (_vendorWalletBalance < 100) {
      showDialog(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('⚠️ वॉलेट बैलेंस कम है'),
          content: const Text('लाइव नोटिफिकेशन पोस्ट करने के लिए कम से कम ₹100 का बैलेंस चाहिए।'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c), child: const Text('ठीक है')),
          ],
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      _vendorWalletBalance -= 100;

      var broadcastData = {
        'shopName': shopNameCtrl.text.trim(),
        'ownerName': ownerNameCtrl.text.trim().isEmpty ? 'व्यापारी' : ownerNameCtrl.text.trim(),
        'phone': shopPhoneCtrl.text.trim(),
        'shopLogoBase64': _savedShopLogo,
        'itemName': itemNameCtrl.text.trim(),
        'rate': rateCtrl.text.trim(),
        'location': locationCtrl.text.trim().isEmpty ? 'Faridabad Market' : locationCtrl.text.trim(),
        'validTill': validTimeCtrl.text.trim().isEmpty ? 'आज शाम तक' : validTimeCtrl.text.trim(),
        'serviceMode': _selectedServiceMode,
        'imageBase64': _imageBase64,
        'videoBase64': _videoBase64,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };

      final response = await http.post(
        Uri.parse('${ViziagDatabase.firebaseRestUrl}/live_broadcasts.json'),
        body: json.encode(broadcastData),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (mounted) {
          itemNameCtrl.clear();
          rateCtrl.clear();
          validTimeCtrl.clear();
          setState(() {
            _imageBase64 = '';
            _videoBase64 = '';
            _isImageSelected = false;
            _isVideoSelected = false;
          });

          showDialog(
            context: context,
            builder: (c) => AlertDialog(
              title: const Text('🚀 नोटिफिकेशन लाइव भेज दिया गया!'),
              content: Text('आपकी दुकान से पोस्ट लाइव हो गई है।\n\nबचा वॉलेट बैलेंस: ₹$_vendorWalletBalance'),
              actions: [
                TextButton(onPressed: () => Navigator.pop(c), child: const Text('शानदार!')),
              ],
            ),
          );
        }
      }
    } catch (e) {
      debugPrint("Broadcast Error: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // 🟢 यदि वेंडर की प्रोफाइल पहले से सेट नहीं है, तो सिर्फ पहली बार यह सेटअप फॉर्म दिखेगा
    if (!_isProfileSetup) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const SizedBox(height: 20),
          const Center(
            child: Icon(Icons.store_mall_directory, size: 70, color: Colors.green),
          ),
          const SizedBox(height: 10),
          const Text(
            '🏪 अपनी दुकान की परमानेंट प्रोफाइल बनाएं',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 5),
          const Text(
            'यह जानकारी सिर्फ एक बार भरनी है, फिर हमेशा सेव रहेगी।',
            style: TextStyle(fontSize: 12, color: Colors.grey),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 25),

          TextField(
            controller: shopNameCtrl,
            decoration: const InputDecoration(labelText: 'दुकान का नाम (Shop Name)', border: OutlineInputBorder(), prefixIcon: Icon(Icons.store)),
          ),
          const SizedBox(height: 15),
          TextField(
            controller: ownerNameCtrl,
            decoration: const InputDecoration(labelText: 'मालिक का नाम (Owner Name)', border: OutlineInputBorder(), prefixIcon: Icon(Icons.person)),
          ),
          const SizedBox(height: 15),
          TextField(
            controller: shopPhoneCtrl,
            keyboardType: TextInputType.phone,
            maxLength: 10,
            decoration: const InputDecoration(labelText: 'मोबाइल नंबर (Calling Number)', border: OutlineInputBorder(), counterText: '', prefixIcon: Icon(Icons.phone)),
          ),
          const SizedBox(height: 15),

          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: _savedShopLogo.isNotEmpty ? Colors.green : Colors.black87,
              side: BorderSide(color: _savedShopLogo.isNotEmpty ? Colors.green : Colors.grey),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            onPressed: _pickShopLogo,
            icon: const Icon(Icons.add_a_photo, size: 18),
            label: Text(_savedShopLogo.isNotEmpty ? '✅ दुकान का लोगो/फोटो सेट हो गया' : 'दुकान का लोगो/प्रोफाइल फोटो लगाएं', style: const TextStyle(fontSize: 12)),
          ),
          const SizedBox(height: 25),

          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade700, foregroundColor: Colors.white),
              onPressed: _saveVendorProfile,
              child: const Text('प्रोफाइल सेव करें और आगे बढ़ें ➔', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            ),
          ),
        ],
      );
    }

    // 🟢 एक बार प्रोफाइल बनने के बाद हमेशा यह सीधा पोस्टिंग डैशबोर्ड दिखेगा (बिना दोबारा डिटेल्स मांगे)
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // वॉलेट और परमानेंट प्रोफाइल कार्ड
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [Colors.green.shade800, Colors.green.shade600]),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('वेंडर वॉलेट बैलेंस', style: TextStyle(color: Colors.white70, fontSize: 12)),
                  const SizedBox(height: 4),
                  Text('₹$_vendorWalletBalance', style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Text('🏪 ${shopNameCtrl.text}', style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                ],
              ),
              const Spacer(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.amber, foregroundColor: Colors.black, padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6)),
                    onPressed: () {
                      setState(() => _vendorWalletBalance += 500);
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('💳 ₹500 का रीचार्ज सफल!'), backgroundColor: Colors.green));
                    },
                    icon: const Icon(Icons.add_card, size: 14),
                    label: const Text('रीचार्ज (+₹500)', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(height: 6),
                  GestureDetector(
                    onTap: _editProfile,
                    child: const Text('✏️ प्रोफाइल बदलें', style: TextStyle(color: Colors.white70, fontSize: 11, decoration: TextDecoration.underline)),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // सामान पोस्ट करने का फॉर्म (बिना बार-बार दुकान का नाम पूछे)
        Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.send_to_mobile, color: Colors.green),
                    const SizedBox(width: 8),
                    const Text('नया नोटिफिकेशन पोस्ट करें', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(6)),
                      child: Text('शुल्क: ₹100 / पोस्ट', style: TextStyle(color: Colors.red.shade700, fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                const Divider(height: 20),

                TextField(
                  controller: itemNameCtrl,
                  decoration: const InputDecoration(labelText: 'सामान / स्टॉक का नाम (उदा: 5G मोबाइल / मीठा शरीफा)', border: OutlineInputBorder(), isDense: true),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: rateCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'रेट / कीमत', border: OutlineInputBorder(), isDense: true, prefixText: '₹ '),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: validTimeCtrl,
                        decoration: const InputDecoration(labelText: 'ऑफर कब तक है?', border: OutlineInputBorder(), isDense: true),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: locationCtrl,
                  decoration: const InputDecoration(labelText: 'दुकान का पता / लोकेशन', border: OutlineInputBorder(), isDense: true, prefixIcon: Icon(Icons.my_location)),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _selectedServiceMode,
                  decoration: const InputDecoration(labelText: 'डिलीवरी / पिकअप सुविधा', border: OutlineInputBorder(), isDense: true),
                  items: _serviceOptions.map((String opt) {
                    return DropdownMenuItem<String>(
                      value: opt,
                      child: Text(opt, style: const TextStyle(fontSize: 11)),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedServiceMode = val);
                  },
                ),
                const SizedBox(height: 15),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _isImageSelected ? Colors.green.shade100 : Colors.grey.shade200,
                          foregroundColor: Colors.black87,
                        ),
                        onPressed: _pickImageFromGallery,
                        icon: const Icon(Icons.photo_library, size: 16),
                        label: Text(_isImageSelected ? '✅ फोटो चुन ली' : 'गैलरी से फोटो चुनें', style: const TextStyle(fontSize: 11)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _isVideoSelected ? Colors.amber.shade100 : Colors.grey.shade200,
                          foregroundColor: Colors.black87,
                        ),
                        onPressed: _pickVideoFromGallery,
                        icon: const Icon(Icons.videocam, size: 16),
                        label: Text(_isVideoSelected ? '✅ वीडियो चुन लिया' : '10s वीडियो चुनें', style: const TextStyle(fontSize: 11)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade700, foregroundColor: Colors.white),
                    onPressed: _isLoading ? null : _sendLiveNotificationBroadcast,
                    icon: const Icon(Icons.notifications_active),
                    label: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text('₹100 काटें और लाइव पोस्ट करें 🚀', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
