import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class CakeDatabase {
  static String firebaseRestUrl = "https://viziagmart-default-rtdb.firebaseio.com"; 

  static String currentUserPhone = "9971968060";
  static String currentCustomerName = "Tarun Kumar";
  static String currentDeliveryAddress = "Sector 15A Faridabad";

  static Map<String, dynamic> bakeryShop = {
    'shopId': 'shop_cake_01',
    'shopName': 'Tarun Fruit & Vegetable Shop',
    'ownerName': 'Tarun Kumar',
    'ownerPhone': '9971968060',
    'ownerPhotoPath': '', 
    'bannerPhotoPath': '',
    'shopPhotoPath': '',
    'phone': '9971968060',
    'address': 'Sector 15A Ajronda Sabji Mandi, Faridabad',
    'bio': 'ताज़ा फल, सब्जियां और उत्पाद उपलब्ध।',
    'isOpen': true,
  };

  static List<Map<String, dynamic>> productInventory = [];
  static List<Map<String, dynamic>> cartItems = [];
  static List<Map<String, dynamic>> localOrdersCache = [];

  // ==========================================
  // 1. इन्वेंट्री (Products) के लिए लोकल सेविंग & लोडिंग
  // ==========================================
  static Future<void> saveInventoryLocally() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String encodedData = json.encode(productInventory);
      await prefs.setString('cached_product_inventory', encodedData);
    } catch (e) {
      debugPrint("Error saving inventory locally: $e");
    }
  }

  static Future<List<Map<String, dynamic>>> loadInventoryLocally() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String? cachedData = prefs.getString('cached_product_inventory');
      
      if (cachedData != null && cachedData.isNotEmpty) {
        List<dynamic> decodedList = json.decode(cachedData);
        productInventory = decodedList.map((item) => Map<String, dynamic>.from(item)).toList();
      }
    } catch (e) {
      debugPrint("Error loading inventory locally: $e");
    }
    return productInventory;
  }

  // ==========================================
  // 2. ऑर्डर्स के लिए परमानेंट लोकल मेमोरी सेविंग
  // ==========================================
  static Future<void> saveOrdersLocally() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String encodedData = json.encode(localOrdersCache);
      await prefs.setString('permanent_orders_cache', encodedData);
    } catch (e) {
      debugPrint("Error saving orders locally: $e");
    }
  }

  static Future<void> loadOrdersLocally() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String? cachedData = prefs.getString('permanent_orders_cache');
      
      if (cachedData != null && cachedData.isNotEmpty) {
        List<dynamic> decodedList = json.decode(cachedData);
        localOrdersCache = decodedList.map((item) => Map<String, dynamic>.from(item)).toList();
      }
    } catch (e) {
      debugPrint("Error loading orders locally: $e");
    }
  }

  // ==========================================
  // 3. स्मार्ट फेच: सिर्फ नया 1 ऑर्डर लाना (डेटा की बचत)
  // ==========================================
  static Future<Map<String, dynamic>?> fetchSingleLatestOrderOnly() async {
    try {
      final response = await http.get(
        Uri.parse('$firebaseRestUrl/customer_orders.json?orderBy="\$key"&limitToLast=1'),
      );

      if (response.statusCode == 200 && response.body != 'null' && response.body.isNotEmpty) {
        Map<String, dynamic> data = json.decode(response.body);
        
        String? latestKey;
        Map<String, dynamic>? latestValue;
        
        data.forEach((key, value) {
          latestKey = key;
          if (value != null) {
            latestValue = Map<String, dynamic>.from(value);
          }
        });

        if (latestKey != null && latestValue != null) {
          // 🟢 सुरक्षित तरीके से आर्डर आईडी सेट करना
          latestValue!['orderId'] = latestKey;

          bool alreadyExists = localOrdersCache.any((ord) => ord['orderId'] == latestKey);

          if (!alreadyExists) {
            localOrdersCache.insert(0, latestValue!);
            await saveOrdersLocally();
            return latestValue; 
          }
        }
      }
    } catch (e) {
      debugPrint("Smart fetch single order error: $e");
    }
    return null; 
  }
}
