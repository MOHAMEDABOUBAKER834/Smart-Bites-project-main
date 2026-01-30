import 'package:flutter/material.dart';

// هذا الكلاس هو "ذاكرة" التطبيق للغة الحالية
class LanguageProvider with ChangeNotifier {
  Locale _currentLocale = const Locale('ar'); // اللغة الافتراضية هي العربية

  Locale get currentLocale => _currentLocale;

  // دالة لتغيير اللغة وإعلام باقي التطبيق بالتغيير
  void setLocale(Locale locale) {
    _currentLocale = locale;
    notifyListeners();
  }
}
