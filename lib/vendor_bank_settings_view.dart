import 'package:flutter/material.dart';
import 'database_models.dart';

class VendorBankSettingsView extends StatefulWidget {
  const VendorBankSettingsView({super.key});

  @override
  State<VendorBankSettingsView> createState() => _VendorBankSettingsViewState();
}

class _VendorBankSettingsViewState extends State<VendorBankSettingsView> {
  final TextEditingController accountNameController = TextEditingController();
  final TextEditingController accountNumberController = TextEditingController();
  final TextEditingController confirmAccountNumberController = TextEditingController();
  final TextEditingController ifscController = TextEditingController();
  final TextEditingController confirmIfscController = TextEditingController();

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    // अगर पहले से कोई डेटा सेव है तो उसे यहाँ लोड कर सकते हैं
  }

  void _saveBankDetails() {
    String name = accountNameController.text.trim();
    String accNum = accountNumberController.text.trim();
    String confirmAccNum = confirmAccountNumberController.text.trim();
    String ifsc = ifscController.text.trim().toUpperCase();
    String confirmIfsc = confirmIfscController.text.trim().toUpperCase();

    // 1. वैलिडेट करें कि खाली तो नहीं है
    if (name.isEmpty || accNum.isEmpty || confirmAccNum.isEmpty || ifsc.isEmpty || confirmIfsc.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('⚠️ कृपया सभी बैंक डिटेल्स भरें!'), backgroundColor: Colors.red),
      );
      return;
    }

    // 2. अकाउंट नंबर मैच चेक करें
    if (accNum != confirmAccNum) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('❌ बैंक अकाउंट नंबर आपस में मेल नहीं खा रहे हैं!'), backgroundColor: Colors.red),
      );
      return;
    }

    // 3. IFSC कोड मैच चेक करें
    if (ifsc != confirmIfsc) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('❌ IFSC कोड आपस में मेल नहीं खा रहा है!'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isSaving = true);

    // यहाँ डेटा सेव करने का लॉजिक (जैसे CakeDatabase या SharedPreferences में स्टोर करना)
    try {
      CakeDatabase.bakeryShop['accountHolderName'] = name;
      CakeDatabase.bakeryShop['accountNumber'] = accNum;
      CakeDatabase.bakeryShop['ifscCode'] = ifsc;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ बैंक डिटेल्स सफलतापूर्वक सेव हो गई हैं!'), backgroundColor: Colors.green),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ एरर: $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('बैंक खाता सेटिंग्स (Bank Settings)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            const Text(
              'सुरक्षित भुगतान के लिए अपनी बैंक डिटेल्स दर्ज करें। खाता नंबर और IFSC कोड दो बार भरना अनिवार्य है।',
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
            const SizedBox(height: 20),

            // 1. खाता धारक का नाम
            TextField(
              controller: accountNameController,
              decoration: const InputDecoration(
                labelText: 'खाता धारक का नाम (Account Holder Name)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person),
              ),
            ),
            const SizedBox(height: 15),

            // 2. बैंक अकाउंट नंबर
            TextField(
              controller: accountNumberController,
              keyboardType: TextInputType.number,
              obscureText: true, // सुरक्षा के लिए छिपाकर रखना चाहें तो रख सकते हैं
              decoration: const InputDecoration(
                labelText: 'बैंक अकाउंट नंबर (Account Number)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.account_balance),
              ),
            ),
            const SizedBox(height: 15),

            // 3. अकाउंट नंबर दोबारा दर्ज करें
            TextField(
              controller: confirmAccountNumberController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'अकाउंट नंबर कन्फर्म करें (Confirm Account Number)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.check_circle_outline),
              ),
            ),
            const SizedBox(height: 15),

            // 4. IFSC कोड
            TextField(
              controller: ifscController,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                labelText: 'IFSC कोड (जैसे: SBIN0001234)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.code),
              ),
            ),
            const SizedBox(height: 15),

            // 5. IFSC कोड दोबारा दर्ज करें
            TextField(
              controller: confirmIfscController,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                labelText: 'IFSC कोड कन्फर्म करें (Confirm IFSC)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.verified_outlined),
              ),
            ),
            const SizedBox(height: 30),

            // सेव बटन
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade700,
                  foregroundColor: Colors.white,
                ),
                onPressed: _isSaving ? null : _saveBankDetails,
                child: _isSaving
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('बैंक डिटेल्स सेव करें', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
