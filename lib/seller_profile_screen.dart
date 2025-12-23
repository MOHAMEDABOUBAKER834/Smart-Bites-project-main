import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:smart_bites/language_provider.dart';
import 'package:smart_bites/auth_screen.dart';

class SellerProfileScreen extends StatefulWidget {
  const SellerProfileScreen({super.key});

  @override
  State<SellerProfileScreen> createState() => _SellerProfileScreenState();
}

class _SellerProfileScreenState extends State<SellerProfileScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String? _sellerName;
  String? _sellerEmail;

  static const Map<String, Map<String, String>> _localizations = {
    'ar': {
      'title': 'الملف الشخصي',
      'seller_profile': 'ملف البائع',
      'email': 'البريد الإلكتروني',
      'name': 'الاسم',
      'logout': 'تسجيل الخروج',
      'logout_confirmation': 'هل أنت متأكد من تسجيل الخروج؟',
      'cancel': 'إلغاء',
      'confirm': 'تأكيد',
      'loading': 'جاري التحميل...',
      'language': 'اللغة',
      'arabic': 'العربية',
      'english': 'English',
    },
    'en': {
      'title': 'Profile',
      'seller_profile': 'Seller Profile',
      'email': 'Email',
      'name': 'Name',
      'logout': 'Logout',
      'logout_confirmation': 'Are you sure you want to logout?',
      'cancel': 'Cancel',
      'confirm': 'Confirm',
      'loading': 'Loading...',
      'language': 'Language',
      'arabic': 'العربية',
      'english': 'English',
    }
  };

  @override
  void initState() {
    super.initState();
    _fetchSellerData();
  }

  void _fetchSellerData() async {
    final user = _auth.currentUser;
    if (user != null) {
      setState(() {
        _sellerEmail = user.email;
      });

      try {
        final doc = await _firestore.collection('users').doc(user.uid).get();
        if (doc.exists && mounted) {
          setState(() {
            _sellerName = doc.data()?['name'] as String?;
          });
        }
      } catch (e) {
        print('Error fetching seller data: $e');
      }
    }
  }

  void _logout() async {
    final langCode = Provider.of<LanguageProvider>(context, listen: false).currentLocale.languageCode;
    final loc = _localizations[langCode]!;

    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(loc['logout']!),
        content: Text(loc['logout_confirmation']!),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(loc['cancel']!),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text(loc['confirm']!),
          ),
        ],
      ),
    );

    if (shouldLogout == true) {
      await _auth.signOut();
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const AuthScreen()),
          (route) => false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);
    final langCode = languageProvider.currentLocale.languageCode;
    final loc = _localizations[langCode]!;

    return Scaffold(
      appBar: AppBar(
        title: Text(loc['title']!),
        backgroundColor: Colors.deepOrange.shade400,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            const CircleAvatar(
              radius: 50,
              backgroundColor: Colors.deepOrange,
              child: Icon(Icons.person, size: 50, color: Colors.white),
            ),
            const SizedBox(height: 20),
            Text(
              loc['seller_profile']!,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 30),
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_sellerName != null) ...[
                      Row(
                        children: [
                          const Icon(Icons.person, color: Colors.deepOrange),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  loc['name']!,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _sellerName!,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 30),
                    ],
                    Row(
                      children: [
                        const Icon(Icons.email, color: Colors.deepOrange),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                loc['email']!,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _sellerEmail ?? 'N/A',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              elevation: 2,
              child: ListTile(
                leading: const Icon(Icons.language, color: Colors.blue),
                title: Text(loc['language']!),
                trailing: ToggleButtons(
                  isSelected: [langCode == 'ar', langCode == 'en'],
                  onPressed: (index) {
                    languageProvider.setLocale(Locale(index == 0 ? 'ar' : 'en'));
                  },
                  borderRadius: BorderRadius.circular(20),
                  selectedColor: Colors.white,
                  fillColor: Colors.deepOrange,
                  constraints: const BoxConstraints(
                    minHeight: 32,
                    minWidth: 60,
                  ),
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12.0),
                      child: Text(
                        loc['arabic']!,
                        style: TextStyle(
                          fontSize: 12,
                          fontFamily: 'Cairo',
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12.0),
                      child: Text(
                        loc['english']!,
                        style: const TextStyle(
                          fontSize: 12,
                          fontFamily: 'Poppins',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const Spacer(),
            ElevatedButton(
              onPressed: _logout,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color.fromARGB(255, 241, 46, 46),
                minimumSize: const Size(double.infinity, 50),
              ),
              child: Text(
                loc['logout']!,
                style: const TextStyle(fontSize: 18),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

