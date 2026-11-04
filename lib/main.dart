import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint("Firebase init warning: $e");
  }

  runApp(const ViziagMartApp());
}

// 🌐 डेटाबेस कॉन्फिग और लोकल स्टेट
class ViziagDatabase {
  static String firebaseRestUrl = "https://viziag-mart-default-rtdb.firebaseio.com";
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
// 1️⃣ ग्राहक डैशबोर्ड (Customer / Buyer Dashboard)
// =============================================================
class CustomerMarketplaceView extends StatefulWidget {
  const CustomerMarketplaceView({super.key});

  @override
  State<CustomerMarketplaceView> createState() => _CustomerMarketplaceViewState();
}

class _CustomerMarketplaceViewState extends State<CustomerMarketplaceView> {
  List> _liveBroadcasts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchLiveBroadcasts();
  }

  Future<void> _fetchLiveBroadcasts() async {
    try {
      final res = await http.get(Uri.parse('${ViziagDatabase.firebaseRestUrl}/live_broadcasts.json'));
      if (res.statusCode == 200 && res.body != 'null' && res.body.isNotEmpty) {
        Map<String, dynamic> data = json.decode(res.body);
        List> loadedList = [];
        data.forEach((key, val) {
          if (val is Map) {
            loadedList.add({...Map<String, dynamic>.from(val), 'id': key});
          }
        });
        setState(() {
          _liveBroadcasts = loadedList.reversed.toList();
        });
      }
    } catch (e) {
      debugPrint("Error fetching broadcasts: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _fetchLiveBroadcasts,
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
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
                    '⚡ आसपास की दुकानों (मोबाइल, कपड़े, फल, किराना) के लाइव अपडेट देखें!',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 15),

          if (_isLoading)
            const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator()))
          else if (_liveBroadcasts.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(40),
                child: Text('फिलहाल कोई लाइव नोटिफिकेशन उपलब्ध नहीं है।', style: TextStyle(color: Colors.grey)),
              ),
            )
          else
            ..._liveBroadcasts.map((item) {
              String serviceMode = item['serviceMode'] ?? 'होम डिलीवरी + पिकअप';
              bool hasVideo = item['videoUrl'] != null && item['videoUrl'].toString().isNotEmpty;

              return Card(
                margin: const EdgeInsets.only(bottom: 15),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Stack(
                      children: [
                        if (item['image'] != null && item['image'].toString().isNotEmpty)
                          ClipRRect(
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                            child: Image.network(
                              item['image'],
                              height: 190,
                              width: double.infinity,
                              fit: BoxFit.cover,
                              errorBuilder: (c, e, s) => Container(height: 100, color: Colors.grey.shade300, child: const Icon(Icons.broken_image)),
                            ),
                          ),
                        if (hasVideo)
                          Positioned(
                            top: 10,
                            right: 10,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(color: Colors.black.withOpacity(0.8), borderRadius: BorderRadius.circular(20)),
                              child: const Row(
                                children: [
                                  Icon(Icons.play_circle_fill, color: Colors.amber, size: 16),
                                  SizedBox(width: 4),
                                  Text('10s वीडियो', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.store, size: 18, color: Colors.green.shade700),
                              const SizedBox(width: 6),
                              Text(
                                item['shopName'] ?? 'दुकानदार',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                              const Spacer(),
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
                          const SizedBox(height: 8),
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
// 2️⃣ वेंडर डैशबोर्ड (Vendor / Broadcast Posting Dashboard)
// =============================================================
class VendorDashboardPortalView extends StatefulWidget {
  const VendorDashboardPortalView({super.key});

  @override
  State<VendorDashboardPortalView> createState() => _VendorDashboardPortalViewState();
}

class _VendorDashboardPortalViewState extends State<VendorDashboardPortalView> {
  final itemNameCtrl = TextEditingController();
  final rateCtrl = TextEditingController();
  final locationCtrl = TextEditingController();
  final validTimeCtrl = TextEditingController();

  String _imageUrl = '';
  String _videoUrl = '';
  String _selectedServiceMode = 'होम डिलीवरी + दुकान से पिकअप दोनों उपलब्ध';
  
  final List<String> _serviceOptions = [
    'होम डिलीवरी + दुकान से पिकअप दोनों उपलब्ध',
    'केवल दुकान से पिकअप (Self Pickup Only)',
    'केवल होम डिलीवरी (Home Delivery Only)'
  ];

  int _vendorWalletBalance = 500;
  bool _isLoading = false;
  final String _shopName = 'मेरी दुकान (ऑल इन वन)';
  final String _shopPhone = '9876543210';

  Future<void> _sendLiveNotificationBroadcast() async {
    if (itemNameCtrl.text.trim().isEmpty || rateCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('⚠️ कृपया आइटम का नाम और रेट भरें!'), backgroundColor: Colors.red));
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
        'shopName': _shopName,
        'phone': _shopPhone,
        'itemName': itemNameCtrl.text.trim(),
        'rate': rateCtrl.text.trim(),
        'location': locationCtrl.text.trim().isEmpty ? 'Faridabad Market' : locationCtrl.text.trim(),
        'validTill': validTimeCtrl.text.trim().isEmpty ? 'आज शाम तक' : validTimeCtrl.text.trim(),
        'serviceMode': _selectedServiceMode,
        'image': _imageUrl.isEmpty ? 'https://images.unsplash.com/photo-1601004890684-d8cbf643f5f2?auto=format&fit=crop&w=600&q=80' : _imageUrl,
        'videoUrl': _videoUrl,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };

      await http.post(
        Uri.parse('${ViziagDatabase.firebaseRestUrl}/live_broadcasts.json'),
        body: json.encode(broadcastData),
      );

      if (mounted) {
        itemNameCtrl.clear();
        rateCtrl.clear();
        validTimeCtrl.clear();
        _imageUrl = '';
        _videoUrl = '';

        showDialog(
          context: context,
          builder: (c) => AlertDialog(
            title: const Text('🚀 नोटिफिकेशन लाइव भेज दिया गया!'),
            content: Text('फोटो, 10s वीडियो और डिलीवरी मोड के साथ नोटिफिकेशन पोस्ट हो गया है।\n\nबचा वॉलेट बैलेंस: ₹$_vendorWalletBalance'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(c), child: const Text('शानदार!')),
            ],
          ),
        );
      }
    } catch (e) {
      debugPrint("Broadcast Error: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
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
                  Text('₹$_vendorWalletBalance', style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold)),
                ],
              ),
              const Spacer(),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.amber, foregroundColor: Colors.black, padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
                onPressed: () {
                  setState(() => _vendorWalletBalance += 500);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('💳 ₹500 का रीचार्ज सफल!'), backgroundColor: Colors.green));
                },
                icon: const Icon(Icons.add_card, size: 16),
                label: const Text('रीचार्ज (+₹500)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

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
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(backgroundColor: _imageUrl.isEmpty ? Colors.grey.shade200 : Colors.green.shade100, foregroundColor: Colors.black87),
                        onPressed: () {
                          setState(() {
                            _imageUrl = 'https://images.unsplash.com/photo-1601004890684-d8cbf643f5f2?auto=format&fit=crop&w=600&q=80';
                          });
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('📷 फोटो अटैच हो गई!')));
                        },
                        icon: const Icon(Icons.add_a_photo, size: 16),
                        label: Text(_imageUrl.isEmpty ? 'फोटो जोड़ें' : '✅ फोटो जुड़ गई', style: const TextStyle(fontSize: 11)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(backgroundColor: _videoUrl.isEmpty ? Colors.grey.shade200 : Colors.amber.shade100, foregroundColor: Colors.black87),
                        onPressed: () {
                          setState(() {
                            _videoUrl = 'https://sample-videos.com/video123/mp4/720/big_buck_bunny_720p_1mb.mp4';
                          });
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('📹 10s वीडियो अटैच हो गया!')));
                        },
                        icon: const Icon(Icons.videocam, size: 16),
                        label: Text(_videoUrl.isEmpty ? '10s वीडियो' : '✅ वीडियो जुड़ गया', style: const TextStyle(fontSize: 11)),
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
