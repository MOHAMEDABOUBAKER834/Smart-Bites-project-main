import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:smart_bites/home_screen.dart';
import 'package:smart_bites/language_provider.dart';

import 'buyer_home.dart';

class OrderSuccessScreen extends StatelessWidget {
  final String orderId;

  const OrderSuccessScreen({super.key, required this.orderId});

  static const Map<String, Map<String, String>> _localizations = {
    'ar': {
      'success_title': 'تم إرسال طلبك بنجاح!',
      'success_subtitle': 'يمكنك استلام طلبك من الكانتين باستخدام هذا الرقم:',
      'back_home': 'العودة للرئيسية',
      'copied': 'تم نسخ الرقم!',
    },
    'en': {
      'success_title': 'Your order has been placed!',
      'success_subtitle': 'You can pick it up from the canteen using this number:',
      'back_home': 'Back to Home',
      'copied': 'ID Copied!',
    }
  };

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
    final langCode = languageProvider.currentLocale.languageCode;
    final loc = _localizations[langCode]!;
    final shortOrderId = '#${orderId.substring(orderId.length - 6).toUpperCase()}';

    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.check_circle_outline, color: Colors.green, size: 100),
              const SizedBox(height: 24),
              Text(
                loc['success_title']!,
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                loc['success_subtitle']!,
                style: const TextStyle(fontSize: 16, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              Card(
                color: Colors.deepOrange.shade50,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Colors.deepOrange.shade100)
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        shortOrderId,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Poppins',
                          letterSpacing: 2,
                          color: Colors.deepOrange
                        ),
                      ),
                      const SizedBox(width: 10),
                      IconButton(
                        icon: Icon(Icons.copy_outlined, color: Colors.deepOrange.shade200),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: shortOrderId));
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(loc['copied']!)),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (context) => const BuyerHome()),
                      (route) => false,
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Colors.deepOrange,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                  ),
                  child: Text(
                    loc['back_home']!,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
