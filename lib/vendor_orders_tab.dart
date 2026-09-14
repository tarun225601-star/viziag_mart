import 'package:flutter/material.dart';
import 'database_models.dart';
import 'image_picker_helper.dart';

class VendorOrdersTab extends StatefulWidget {
  const VendorOrdersTab({super.key});

  @override
  State<VendorOrdersTab> createState() => _VendorOrdersTabState();
}

class _VendorOrdersTabState extends State<VendorOrdersTab> {
  void _refreshOrders() {
    setState(() {
      // ऑर्डर्स लिस्ट को रीफ्रेश करने के लिए स्टेट अपडेट कर रहे हैं
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('🔄 ऑर्डर्स रिफ्रेश हो गए हैं!'), backgroundColor: Colors.blue, duration: Duration(milliseconds: 800)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // रिफ्रेश बटन बार
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('📦 ग्राहक ऑर्डर्स लिस्ट', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ElevatedButton.icon(
                onPressed: _refreshOrders,
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('रिफ्रेश करें'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade700, foregroundColor: Colors.white),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: CakeDatabase.cartItems.isEmpty
              ? const Center(
                  child: Text(
                    '📭 अभी कोई नया आर्डर नहीं आया है!',
                    style: TextStyle(fontSize: 16, color: Colors.grey, fontWeight: FontWeight.bold),
                  ),
                )
              : ListView.builder(
                  itemCount: CakeDatabase.cartItems.length,
                  itemBuilder: (context, index) {
                    var ord = CakeDatabase.cartItems[index];
                    var orderItems = (ord['items'] ?? ord['cartItems'] ?? []) as List<dynamic>;

                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                      color: Colors.white,
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      child: ExpansionTile(
                        title: Text('ग्राहक: ${ord['customerName'] ?? ord['name'] ?? 'Tarun Kumar'}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 3),
                            Text('📞 ${ord['phone'] ?? ord['customerPhone'] ?? '9971968060'}', style: TextStyle(color: Colors.green.shade800, fontWeight: FontWeight.w600, fontSize: 12)),
                            Text('पता: ${ord['address'] ?? 'Sector 15A Faridabad'}', style: const TextStyle(fontSize: 11)),
                            Text('कुल राशि: ₹${ord['totalAmount'] ?? ord['total'] ?? '200'}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.black87)),
                            Text('स्टेटस: ${ord['status'] ?? 'Pending'}', style: const TextStyle(fontSize: 11, color: Colors.orange, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        trailing: PopupMenuButton<String>(
                          onSelected: (val) {
                            setState(() {
                              ord['status'] = val;
                            });
                          },
                          itemBuilder: (context) => const [
                            PopupMenuItem(value: 'Accepted', child: Text('Accept')),
                            PopupMenuItem(value: 'Delivered', child: Text('Deliver')),
                          ],
                        ),
                        children: orderItems.map<Widget>((item) {
                          var itemImg = item['image'] ?? item['img'] ?? '';
                          var itemName = item['name'] ?? item['title'] ?? 'Product Item';
                          var itemQty = item['qty'] ?? item['quantity'] ?? 1;
                          var itemPrice = item['price'] ?? item['rate'] ?? '0';

                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            child: ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: buildShopOrProdImage(itemImg, 45, 45, Icons.fastfood),
                              ),
                              title: Text(itemName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              subtitle: Text('मात्रा (Qty): $itemQty | दाम: ₹$itemPrice', style: const TextStyle(fontSize: 11, color: Colors.black54)),
                            ),
                          );
                        }).toList(),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
