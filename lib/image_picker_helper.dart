import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class ImagePickerHelper {
  // 🚀 वह मेथड जिसकी main.dart को तलाश है
  static Future<String?> pickAndUploadImage(BuildContext context) async {
    return await pickAndConvertToBase64();
  }

  // 🚀 गैलरी से इमेज पिक करके Base64 में बदलने का मेथड
  static Future<String?> pickAndConvertToBase64() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 50,
        maxWidth: 800,
        maxHeight: 800,
      );

      if (pickedFile == null) return null;
      final Uint8List bytes = await pickedFile.readAsBytes();
      if (bytes.isEmpty) return null;

      return 'data:image/jpeg;base64,${base64Encode(bytes)}';
    } catch (e) {
      debugPrint('❌ एरर: $e');
      return null;
    }
  }

  // 📸 कैमरे से फोटो खींचकर Base64 में बदलने के लिए
  static Future<String?> captureAndConvertToBase64() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? capturedFile = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 50,
        maxWidth: 800,
        maxHeight: 800,
      );

      if (capturedFile == null) return null;
      final Uint8List bytes = await capturedFile.readAsBytes();
      if (bytes.isEmpty) return null;

      return 'data:image/jpeg;base64,${base64Encode(bytes)}';
    } catch (e) {
      debugPrint('❌ कैमरा एरर: $e');
      return null;
    }
  }

  // 🖼️ UI पर इमेज रेंडर करने का लॉजिक
  static Widget renderImage(String? path, double height, double width, IconData fallbackIcon) {
    if (path != null && path.isNotEmpty) {
      if (path.startsWith('http')) {
        return Image.network(
          path,
          height: height,
          width: width,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => Container(
            height: height,
            width: width,
            color: const Color(0xFF334155),
            child: Icon(fallbackIcon, size: height * 0.4, color: const Color(0xFFF59E0B)),
          ),
        );
      } else if (path.startsWith('data:image')) {
        try {
          final base64String = path.contains(',') ? path.split(',').last : path;
          return Image.memory(
            base64Decode(base64String),
            height: height,
            width: width,
            fit: BoxFit.cover,
          );
        } catch (e) {
          debugPrint('Base64 Error: $e');
        }
      } else if (!kIsWeb && File(path).existsSync()) {
        return Image.file(
          File(path),
          height: height,
          width: width,
          fit: BoxFit.cover,
        );
      }
    }
    
    return Container(
      height: height,
      width: width,
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF334155), Color(0xFF1E293B)]),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(fallbackIcon, size: height * 0.4, color: const Color(0xFFF59E0B)),
    );
  }
}

// 🛠️ एक्सटेंशन ताकि main.dart की स्टेट क्लास में सीधे कॉल हो सके
extension ImageHelperExtension on State {
  Future<String?> pickAndConvertToBase64() async {
    return await ImagePickerHelper.pickAndConvertToBase64();
  }

  Widget buildShopOrProdImage(String? path, double height, double width, IconData fallbackIcon) {
    return ImagePickerHelper.renderImage(path, height, width, fallbackIcon);
  }
}
