import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'database_models.dart';

class CartAndOrdersView extends StatefulWidget {
  const CartAndOrdersView({super.key});

  @override
  State<CartAndOrdersView> createState() => _CartAndOrdersViewState();
}

class _CartAndOrdersViewState extends State<CartAndOrdersView> {
  bool _isFetching = false;

  @override
  void initState() {
    super.initState();
    if (CakeDatabase.localOrdersCache == null) {
      CakeDatabase.localOrdersCache = [];
    }
    // ऐप खुलते ही एक बार क्लाउड से लेटेस्ट स्टेटस सिंक कर लेंगे
    _syncOrdersFromServer();
  }

  // 🔄 सर्वर से आर्डर्स का लेटेस्ट स्टेटस चेक करने का फंक्शन
  Future<void> _syncOrdersFromServer() async {
    if (_isFetching) return;
    setState(() => _isFetching = true);

    try {
      final res = await http.get(Uri.parse('${CakeDatabase.firebaseRestUrl}/orders.json'));
      if (res.statusCode == 200 && res.body != 'null' && res.body.isNotEmpty) {
        Map<String, dynamic> cloudOrders = json.decode(res.body);
        
        // लोकल cache को क्लाउड के लेटेस्ट स्टेटस के साथ अपडेट करना
        setState(() {
          for (int i = 0; i < CakeDatabase.localOrdersCache.length; i++) {
            String? localId = CakeDatabase.localOrdersCache[i]['orderId']?.toString();
            if (localId != null && cloudOrders.containsKey(localId)) {
              var cloudData = cloudOrders[localId];
              if (cloudData is Map) {
                CakeDatabase.localOrdersCache[i]['orderStatus'] = cloudData['orderStatus'] ?? cloudData['status'] ?? CakeDatabase.localOrdersCache[i]['orderStatus'];
                CakeDatabase.localOrdersCache[i]['status'] = cloudData['status'] ?? cloudData['orderStatus'] ?? CakeDatabase.localOrdersCache[i]['status'];
              }
            }
          }
        });
        await CakeDatabase.saveOrdersLocally();
      }
    } catch (e) {
      debugPrint("Orders sync error: $e");
    } finally {
      if (mounted) setState(() => _isFetching = false);
    }
  }

  bool _isToday(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return false;
    try {
      DateTime orderDate = DateTime.parse(dateStr);
      DateTime now = DateTime.now();
      return orderDate.year == now.year && orderDate.month == now.month && orderDate.day == now.day;
    } catch (e) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    int todayOrdersCount = 0;
    double todayOrdersTotal = 0.0;

    for (var ord in CakeDatabase.localOrdersCache) {
      // अगर orderTime नहीं है तो timestamp चेक कर लेंगे
      String timeCheck = ord['orderTime'] ?? ord['timestamp']?.toString() ?? '';
      if (_isToday(timeCheck)) {
        todayOrdersCount++;
        todayOrdersTotal += double.tryParse((ord['grandTotal'] ?? ord['totalAmount'] ?? 0).toString()) ?? 0.0;
      }
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('📦 मेरी आर्डर हिस्ट्री & स्टेटस', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: _isFetching 
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.refresh, color: Colors.white),
            tooltip: 'स्टेटस रिफ्रेश करें',
            onPressed: _syncOrdersFromServer,
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            margin: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF334155)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Column(
                  children: [
                    const Text('आज के कुल आर्डर', style: TextStyle(color: Colors.grey, fontSize: 12)),
                    const SizedBox(height: 4),
                    Text('$todayOrdersCount', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  ],
                ),
                Container(height: 30, width: 1, color: Colors.grey.shade700),
                Column(
                  children: [
                    const Text('आज की कुल राशि', style: TextStyle(color: Colors.grey, fontSize: 12)),
                    const SizedBox(height: 4),
                    Text('₹${todayOrdersTotal.toInt()}', style: const TextStyle(color: Color(0xFFF59E0B), fontSize: 18, fontWeight: FontWeight.bold)),
                  ],
                ),
                Container(height: 30, width: 1, color: Colors.grey.shade700),
                Column(
                  children: [
                    const Text('कुल इतिहास', style: TextStyle(color: Colors.grey, fontSize: 12)),
                    const SizedBox(height: 4),
                    Text('${CakeDatabase.localOrdersCache.length}', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: CakeDatabase.localOrdersCache.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(20.0),
                      child: Text('आपने अभी तक कोई नया आर्डर नहीं दिया है!\nशॉप से जाकर आर्डर बुक करें।', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontSize: 14)),
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _syncOrdersFromServer,
                    child: ListView.builder(
                      itemCount: CakeDatabase.localOrdersCache.length,
                      itemBuilder: (context, index) {
                        var ord = CakeDatabase.localOrdersCache[index];
                        String status = (ord['orderStatus'] ?? ord['status'] ?? 'Pending').toString();
                        var orderTotal = ord['grandTotal'] ?? ord['totalAmount'] ?? 0;
                        var itemsList = ord['items'] as List<dynamic>? ?? [];
                        
                        String rawTime = ord['orderTime'] ?? '';
                        String formattedDateTime = '';
                        if (rawTime.isNotEmpty) {
                          try {
                            DateTime dt = DateTime.parse(rawTime);
                            formattedDateTime = "${dt.day.toString().padLeft(2, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.year} | ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";
                          } catch (e) {
                            formattedDateTime = rawTime.length >= 16 ? rawTime.substring(0, 16).replaceAll('T', ' ') : rawTime;
                          }
                        } else if (ord['timestamp'] != null) {
                          try {
                            DateTime dt = DateTime.fromMillisecondsSinceEpoch(int.parse(ord['timestamp'].toString()));
                            formattedDateTime = "${dt.day.toString().padLeft(2, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.year} | ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";
                          } catch (_) {}
                        }

                        bool isTodayOrder = _isToday(rawTime) || ord['timestamp'] != null;

                        return Card(
                          color: const Color(0xFF1E293B),
                          margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          'आर्डर #${ord['orderId'] != null && ord['orderId'].toString().length > 8 ? ord['orderId'].toString().substring(0, 8) : ord['orderId'] ?? 'New'}', 
                                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)
                                        ),
                                        if (isTodayOrder) ...[
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: Colors.green,
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: const Text('आज (Today)', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                                          ),
                                        ],
                                      ],
                                    ),
                                    Text(
                                      '₹${orderTotal.toString()}', 
                                      style: const TextStyle(color: Color(0xFFF59E0B), fontWeight: FontWeight.bold, fontSize: 16)
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                if (formattedDateTime.isNotEmpty)
                                  Row(
                                    children: [
                                      const Icon(Icons.calendar_today, size: 13, color: Colors.amberAccent),
                                      const SizedBox(width: 4),
                                      Text(formattedDateTime, style: const TextStyle(color: Colors.amberAccent, fontSize: 12, fontWeight: FontWeight.w500)),
                                    ],
                                  ),
                                const SizedBox(height: 6),
                                Text('दुकान: ${ord['shopName'] ?? 'Viziag Mart'}', style: const TextStyle(color: Colors.white70, fontSize: 13)),
                                Text('डिलीवरी पता: ${ord['customerAddress'] ?? ord['deliveryAddress'] ?? 'पता उपलब्ध नहीं'}', 
                                    style: const TextStyle(color: Colors.grey, fontSize: 12)),
                                const Divider(color: Colors.white24, height: 16),
                                ...itemsList.map((it) {
                                  var m = it is Map ? it : {};
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 2.0),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text('• ${m['name'] ?? 'Item'} (x${m['qty'] ?? 1})', style: const TextStyle(color: Colors.white, fontSize: 13)),
                                        Text('₹${(double.tryParse(m['price'].toString()) ?? 0) * (double.tryParse(m['qty'].toString()) ?? 1)}', 
                                            style: const TextStyle(color: Colors.white70, fontSize: 13)),
                                      ],
                                    ),
                                  );
                                }),
                                const SizedBox(height: 12),
                                
                                // 🟢 शानदार लाइव स्टेटस बैनर जो ग्राहक को बताएगा कि आर्डर कहाँ तक पहुँचा है
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: _getStatusColor(status).withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: _getStatusColor(status)),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(_getStatusIcon(status), color: _getStatusColor(status), size: 18),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          _getStatusText(status),
                                          style: TextStyle(color: _getStatusColor(status), fontWeight: FontWeight.bold, fontSize: 13),
                                        ),
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
                  ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    String s = status.toLowerCase();
    if (s.contains('accept')) return Colors.greenAccent;
    if (s.contains('deliver')) return Colors.tealAccent;
    if (s.contains('reject') || s.contains('cancel')) return Colors.redAccent;
    return Colors.amberAccent; // Pending के लिए
  }

  IconData _getStatusIcon(String status) {
    String s = status.toLowerCase();
    if (s.contains('accept')) return Icons.check_circle_outline;
    if (s.contains('deliver')) return Icons.delivery_dining;
    if (s.contains('reject') || s.contains('cancel')) return Icons.cancel_outlined;
    return Icons.hourglass_top_rounded; // Pending
  }

  String _getStatusText(String status) {
    String s = status.toLowerCase();
    if (s.contains('accept')) return '✅ वेंडर द्वारा आर्डर स्वीकार कर लिया गया है!';
    if (s.contains('deliver')) return '🚀 आर्डर डिलीवरी के लिए निकल चुका है!';
    if (s.contains('reject') || s.contains('cancel')) return '❌ यह आर्डर रद्द कर दिया गया है।';
    return '⏳ पेंडिंग: वेंडर के अप्रूवल का इंतज़ार है...';
  }
}
