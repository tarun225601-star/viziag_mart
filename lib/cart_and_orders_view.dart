import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'database_models.dart';
import 'image_picker_helper.dart';

class CartAndOrdersView extends StatefulWidget {
  const CartAndOrdersView({super.key});

  @override
  State<CartAndOrdersView> createState() => _CartAndOrdersViewState();
}

class _CartAndOrdersViewState extends State<CartAndOrdersView> {
  bool _isLoadingOrders = false;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    await CakeDatabase.loadOrdersLocally();
    if (mounted) setState(() {});
    // बैकग्राउंड में नए ऑर्डर्स सिंक करने के लिए
    _fetchLatestOrdersFromCloud();
  }

  // REST API के जरिए आर्डर फेच करना
  Future<void> _fetchLatestOrdersFromCloud() async {
    if (_isLoadingOrders) return;
    setState(() => _isLoadingOrders = true);

    try {
      final response = await http.get(
        Uri.parse('${CakeDatabase.firebaseRestUrl}/orders.json'),
      );

      if (response.statusCode == 200 && response.body != 'null' && response.body.isNotEmpty) {
        Map<String, dynamic> data = json.decode(response.body);
        List<Map<String, dynamic>> loadedOrders = [];

        data.forEach((key, val) {
          if (val is Map) {
            var ord = Map<String, dynamic>.from(val);
            ord['orderId'] = key;

            String custPhone = ord['customerPhone'] ?? '';
            if (custPhone == CakeDatabase.currentUserPhone && CakeDatabase.currentUserPhone.isNotEmpty) {
              loadedOrders.add(ord);
            }
          }
        });

        // नए ऑर्डर्स को ऊपर दिखाने के लिए सॉर्ट करना (तारीख के हिसाब से लेटेस्ट पहले)
        loadedOrders.sort((a, b) {
          String timeA = a['orderTime'] ?? '';
          String timeB = b['orderTime'] ?? '';
          return timeB.compareTo(timeA);
        });

        if (mounted) {
          setState(() {
            CakeDatabase.localOrdersCache = loadedOrders;
          });
          await CakeDatabase.saveOrdersLocally();
        }
      }
    } catch (e) {
      debugPrint("Fetch orders error: $e");
    } finally {
      if (mounted) setState(() => _isLoadingOrders = false);
    }
  }

  // यह चेक करने के लिए कि आर्डर आज का है या नहीं
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
    // आज के ऑर्डर्स की गिनती और टोटल निकालने के लिए
    int todayOrdersCount = 0;
    double todayOrdersTotal = 0.0;

    for (var ord in CakeDatabase.localOrdersCache) {
      if (_isToday(ord['orderTime'])) {
        todayOrdersCount++;
        todayOrdersTotal += double.tryParse((ord['grandTotal'] ?? ord['totalAmount'] ?? 0).toString()) ?? 0.0;
      }
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('📦 मेरी आर्डर हिस्ट्री', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Color(0xFFF59E0B)),
            onPressed: _fetchLatestOrdersFromCloud,
            tooltip: 'Refresh Orders',
          ),
        ],
      ),
      body: Column(
        children: [
          // 📊 आज के ऑर्डर्स का समरी कार्ड (Today's Summary Widget)
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

          // 📜 आर्डर लिस्ट व्यू
          Expanded(
            child: CakeDatabase.localOrdersCache.isEmpty
                ? Center(
                    child: _isLoadingOrders
                        ? const CircularProgressIndicator()
                        : const Text('कोई पिछला आर्डर नहीं है', style: TextStyle(color: Colors.grey, fontSize: 15)),
                  )
                : RefreshIndicator(
                    onRefresh: _fetchLatestOrdersFromCloud,
                    child: ListView.builder(
                      itemCount: CakeDatabase.localOrdersCache.length,
                      itemBuilder: (context, index) {
                        var ord = CakeDatabase.localOrdersCache[index];
                        String status = ord['orderStatus'] ?? ord['status'] ?? 'Pending';
                        var orderTotal = ord['grandTotal'] ?? ord['totalAmount'] ?? 0;
                        var itemsList = ord['items'] as List<dynamic>? ?? [];
                        
                        // तारीख और समय को सही फॉर्मेट में दिखाने के लिए
                        String rawTime = ord['orderTime'] ?? '';
                        String formattedDateTime = '';
                        if (rawTime.isNotEmpty) {
                          try {
                            DateTime dt = DateTime.parse(rawTime);
                            formattedDateTime = "${dt.day.toString().padLeft(2, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.year} | ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";
                          } catch (e) {
                            formattedDateTime = rawTime.length >= 16 ? rawTime.substring(0, 16).replaceAll('T', ' ') : rawTime;
                          }
                        }

                        bool isTodayOrder = _isToday(rawTime);

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
                                          'आर्डर #${ord['orderId'] != null && ord['orderId'].toString().length > 8 ? ord['orderId'].toString().substring(0, 8) : ord['orderId'] ?? ''}', 
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
                                // 📅 तारीख और समय दिखाने वाली लाइन
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
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: status.toLowerCase().contains('delivered') ? Colors.green.withOpacity(0.2) : Colors.amber.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text('स्टेटस: $status', style: TextStyle(color: status.toLowerCase().contains('delivered') ? Colors.greenAccent : Colors.amberAccent, fontWeight: FontWeight.bold, fontSize: 12)),
                                    ),
                                  ],
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
}
