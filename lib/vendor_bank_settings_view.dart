import 'package:flutter/material.dart';
import 'database_models.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

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

  bool _isLoading = false;
  bool _isFetchingIfsc = false;
  String? bankDetailsInfo; // 🟢 IFSC से मिलने वाले बैंक/ब्रांच की जानकारी दिखाने के लिए

  @override
  void initState() {
    super.initState();
    _loadExistingBankDetails();
  }

  void _loadExistingBankDetails() {
    setState(() {
      accountNameController.text = CakeDatabase.bakeryShop['accountHolderName'] ?? '';
      accountNumberController.text = CakeDatabase.bakeryShop['accountNumber'] ?? '';
      confirmAccountNumberController.text = CakeDatabase.bakeryShop['accountNumber'] ?? '';
      ifscController.text = CakeDatabase.bakeryShop['ifscCode'] ?? '';
      confirmIfscController.text = CakeDatabase.bakeryShop['ifscCode'] ?? '';
      
      if (ifscController.text.length == 11) {
        _fetchBankDetails(ifscController.text);
      }
    });
  }

  // 🌐 1. IFSC कोड से बैंक और शाखा (Branch) का नाम ऑटोमेटिक पता करना
  Future<void> _fetchBankDetails(String ifscCode) async {
    if (ifscCode.length != 11) {
      setState(() => bankDetailsInfo = null);
      return;
    }

    setState(() => _isFetchingIfsc = true);

    try {
      final response = await http.get(Uri.parse('https://ifsc.razorpay.com/$ifscCode'));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        String bankName = data['BANK'] ?? '';
        String branch = data['BRANCH'] ?? '';
        String city = data['CITY'] ?? '';

        setState(() {
          bankDetailsInfo = '🏦 बैंक: $bankName\n📍 शाखा (Branch): $branch, $city';
        });
      } else {
        setState(() {
          bankDetailsInfo = '❌ अमान्य (Invalid) IFSC कोड!';
        });
      }
    } catch (e) {
      setState(() {
        bankDetailsInfo = '⚠️ बैंक डिटेल्स लाने में विफल नेटवर्क एरर';
      });
    } finally {
      setState(() => _isFetchingIfsc = false);
    }
  }

  // 2. फायरबेस पर बैंक डिटेल्स परमानेंट सेव करना
  Future<void> _saveBankDetailsToFirebase() async {
    String name = accountNameController.text.trim();
    String accNum = accountNumberController.text.trim();
    String confirmAccNum = confirmAccountNumberController.text.trim();
    String ifsc = ifscController.text.trim().toUpperCase();
    String confirmIfsc = confirmIfscController.text.trim().toUpperCase();

    if (name.isEmpty || accNum.isEmpty || confirmAccNum.isEmpty || ifsc.isEmpty || confirmIfsc.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('⚠️ कृपया सभी बैंक डिटेल्स भरें!'), backgroundColor: Colors.red),
      );
      return;
    }

    if (accNum != confirmAccNum) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('❌ बैंक अकाउंट नंबर आपस में मेल नहीं खा रहे हैं!'), backgroundColor: Colors.red),
      );
      return;
    }

    if (ifsc != confirmIfsc) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('❌ IFSC कोड आपस में मेल नहीं खा रहा है!'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      CakeDatabase.bakeryShop['accountHolderName'] = name;
      CakeDatabase.bakeryShop['accountNumber'] = accNum;
      CakeDatabase.bakeryShop['ifscCode'] = ifsc;

      await http.put(
        Uri.parse('${CakeDatabase.firebaseRestUrl}/bakery_shop.json'),
        body: json.encode(CakeDatabase.bakeryShop),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ बैंक डिटेल्स फायरबेस पर सुरक्षित सेव हो गई हैं!'), backgroundColor: Colors.green),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ एरर: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('बैंक खाता सेटिंग्स (Bank Details)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            const Text(
              'सुरक्षित भुगतान के लिए अपनी बैंक डिटेल्स दर्ज करें। सही IFSC कोड डालते ही बैंक और शाखा का नाम ऑटोमेटिक आ जाएगा।',
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
              onChanged: (value) {
                // जैसे ही पूरे 11 अक्षर होंगे, ऑटोमैटिक बैंक डिटेल फेच होगी
                if (value.trim().length == 11) {
                  _fetchBankDetails(value.trim().toUpperCase());
                } else {
                  setState(() => bankDetailsInfo = null);
                }
              },
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
            const SizedBox(height: 15),

            // 🟢 ऑटोमैटिक बैंक और ब्रांच नाम दिखने वाला बॉक्स
            if (_isFetchingIfsc)
              const Center(child: Padding(padding: EdgeInsets.all(8.0), child: CircularProgressIndicator()))
            else if (bankDetailsInfo != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  border: Border.all(color: Colors.green.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  bankDetailsInfo!,
                  style: TextStyle(color: Colors.green.shade900, fontWeight: FontWeight.bold, fontSize: 13),
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
                onPressed: _isLoading ? null : _saveBankDetailsToFirebase,
                child: _isLoading
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
