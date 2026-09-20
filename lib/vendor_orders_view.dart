import 'package:flutter/material.dart';
import 'database_models.dart';

class VendorOrdersView extends StatefulWidget {
  const VendorOrdersView({super.key});

  @override
  State<VendorOrdersView> createState() => _VendorOrdersViewState();
}

class _VendorOrdersViewState extends State<VendorOrdersView> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🛒 वेंडर लाइव ऑर्डर्स', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 1,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.green),
            onPressed: () => setState(() {}),
            tooltip: 'রিফ্রেশ (Refresh)',
          ),
        ],
      ),
      body: CakeDatabase.cartItems.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.inbox_outlined, size: 65, color: Colors.grey),
                  SizedBox(height: 12),
                  Text(
                    'अभी कोई नया आर्डर नहीं है!',
                    style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: CakeDatabase.cartItems.length,
              itemBuilder: (context, index) {
                final order = CakeDatabase.cartItems[index];
                return Card(
                  elevation: 2,
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const CircleAvatar(
                              backgroundColor: Colors.green,
                              radius: 18,
                              child: Icon(Icons.shopping_bag, color: Colors.white, size: 18),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                order['title'] ?? 'ऑर्डर #${index + 1}',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                              ),
                            ),
                            Text(
                              '₹${order['price'] ?? 0}',
                              style: const TextStyle(color: Colors.green, fontWeight: FontWeight.w900, fontSize: 16),
                            ),
                          ],
                        ),
                        const Divider(height: 20),
                        Row(
                          children: [
                            const Icon(Icons.person, size: 14, color: Colors.grey),
                            const SizedBox(width: 6),
                            Text('ग्राहक: ${CakeDatabase.currentCustomerName}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.phone, size: 14, color: Colors.grey),
                            const SizedBox(width: 6),
                            Text('फोन: ${CakeDatabase.currentUserPhone}', style: const TextStyle(fontSize: 12)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.location_on, size: 14, color: Colors.grey),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'पता: ${CakeDatabase.currentDeliveryAddress}',
                                style: const TextStyle(fontSize: 12, color: Colors.black54),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Chip(
                              label: Text('मात्रा (Qty): ${order['qty'] ?? 1}', style: const TextStyle(fontSize: 10)),
                              backgroundColor: Colors.green.shade50,
                              labelStyle: TextStyle(color: Colors.green.shade800, fontWeight: FontWeight.bold),
                              padding: EdgeInsets.zero,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
