import 'package:flutter/material.dart';
import 'database_models.dart';

class CartAndOrdersView extends StatefulWidget {
  const CartAndOrdersView({super.key});

  @override
  State<CartAndOrdersView> createState() => _CartAndOrdersViewState();
}

class _CartAndOrdersViewState extends State<CartAndOrdersView> {
  @override
  void initState() {
    super.initState();
    // यहाँ से पुराना डेटा लोड करने वाला फंक्शन हटा दिया है, 
    // ताकि पुराने 97 ऑर्डर्स स्क्रीन पर लोड होकर न आएं।
    if (CakeDatabase.localOrdersCache == null) {
      CakeDatabase.localOrdersCache = [];
    }
  }

  // यह चेक करने के लिए कि आर्डर आज का है या नहीं (आज की तारीख: 22 सितंबर 2026)
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
      if (_isToday(ord['orderTime'])) {
        todayOrdersCount++;
        todayOrdersTotal += double.tryParse((ord['grandTotal'] ?? ord['totalAmount'] ?? 0).toString()) ?? 0.0;
      }
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('📦 मेरी आर्डर हिस्ट्री', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
      ),
      body: Column(
        children: [
          // 📊 आज के ऑर्डर्स का समरी कार्ड
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

          // 📜 केवल नए/लोकल ऑर्डर्स दिखाने के लिए लिस्ट व्यू
          Expanded(
            child: CakeDatabase.localOrdersCache.isEmpty
                ? const Center(
                    child: Text('आपने अभी तक कोई नया आर्डर नहीं दिया है', style: TextStyle(color: Colors.grey, fontSize: 15)),
                  )
                : ListView.builder(
                    itemCount: CakeDatabase.localOrdersCache.length,
                    itemBuilder: (context, index) {
                      var ord = CakeDatabase.localOrdersCache[index];
                      String status = ord['orderStatus'] ?? ord['status'] ?? 'Pending';
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
                                    padding: const:_buildStatusDecoration(status),
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
        ],
      ),
    );
  }

  Decoration _buildStatusDecoration(String status) {
    return BoxDecoration(
      color: status.toLowerCase().contains('delivered') ? Colors.green.withOpacity(0.2) : Colors.amber.withOpacity(0.2),
      borderRadius: BorderRadius.circular(4),
    );
  }
}
