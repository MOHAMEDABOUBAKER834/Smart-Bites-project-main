import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:provider/provider.dart';
import 'package:smart_bites/language_provider.dart';
import 'package:smart_bites/auth_screen.dart';
import 'package:smart_bites/order_history_screen.dart';
import 'package:smart_bites/charge_points_screen.dart';
import 'package:smart_bites/transfer_points_screen.dart'; 
import 'package:smart_bites/recent_transfers_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final User? currentUser = FirebaseAuth.instance.currentUser;
  final dbRef = FirebaseDatabase.instance.ref();
  String userName = '...';
  int userPoints = 0;
  int? userNumericId;

  static const Map<String, Map<String, String>> _localizations = {
    'ar': {
      'title': 'حسابي',
      'my_orders': 'سجل طلباتي',
      'my_points': 'رصيد نقاطي',
      'charge_points': 'شحن نقاط',
      'transfer_points': 'تحويل نقاط',
      'transfer_history': 'سجل التحويلات',
      'user_id': 'معرف المستخدم (ID)',
      'copied': 'تم نسخ المعرف!',
      'logout': 'تسجيل الخروج',
      'language': 'اللغة',
      'arabic': 'العربية',
      'english': 'English',
    },
    'en': {
      'title': 'My Profile',
      'my_orders': 'Order History',
      'my_points': 'My Points Balance',
      'charge_points': 'Top-up Points',
      'transfer_points': 'Transfer Points',
      'transfer_history': 'Transfer History',
      'user_id': 'User ID',
      'copied': 'ID Copied!',
      'logout': 'Logout',
      'language': 'Language',
      'arabic': 'العربية',
      'english': 'English',
    }
  };

  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }

  void _fetchUserData() async {
    if (currentUser != null) {
      final userRef = dbRef.child('users/${currentUser!.uid}');
      userRef.onValue.listen((event) {
        if (event.snapshot.exists && mounted) {
          final data = event.snapshot.value as Map<dynamic, dynamic>;
          setState(() {
            userName = data['name'] ?? 'User';
            userPoints = (data['points'] as num?)?.toInt() ?? 0;
            userNumericId = (data['numericId'] as num?)?.toInt();
          });
        }
      });
    }
  }

  void _logout() async {
    await FirebaseAuth.instance.signOut();
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const AuthScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);
    final langCode = languageProvider.currentLocale.languageCode;
    final loc = _localizations[langCode]!;

    return Scaffold(
      appBar: AppBar(
        title: Text(loc['title']!),
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
            Text(userName, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Text(loc['user_id']!, style: const TextStyle(color: Colors.grey)),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(userNumericId?.toString() ?? 'N/A', style: const TextStyle(fontFamily: 'Poppins', color: Colors.grey, fontSize: 12)),
                IconButton(
                  icon: const Icon(Icons.copy, size: 16),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: userNumericId?.toString() ?? ''));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(loc['copied']!)),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 30),
            ListTile(
              leading: const Icon(Icons.history),
              title: Text(loc['my_orders']!),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const OrderHistoryScreen())),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.star, color: Colors.amber),
              title: Text(loc['my_points']!),
              trailing: Text('$userPoints', style: const TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.bold, fontSize: 18)),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.add_card, color: Colors.green),
              title: Text(loc['charge_points']!),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ChargePointsScreen())),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.swap_horiz, color: Colors.blue),
              title: Text(loc['transfer_points']!),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const TransferPointsScreen())),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.receipt_long, color: Colors.purple),
              title: Text(loc['transfer_history']!),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const RecentTransfersScreen())),
            ),
            const Divider(),
            ListTile(
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
            const Divider(),
            const Spacer(),
            ElevatedButton(
              onPressed: _logout,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color.fromARGB(255, 241, 46, 46),
                minimumSize: const Size(double.infinity, 50),
              ),
              child: Text(loc['logout']!, style: const TextStyle(fontSize: 18)),
            ),
          ],
        ),
      ),
    );
  }
}
