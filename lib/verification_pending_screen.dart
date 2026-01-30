import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:provider/provider.dart';
import 'package:smart_bites/language_provider.dart';
import 'package:smart_bites/seller_dashboard.dart';
import 'package:smart_bites/auth_screen.dart';

class VerificationPendingScreen extends StatefulWidget {
  const VerificationPendingScreen({super.key});

  @override
  State<VerificationPendingScreen> createState() => _VerificationPendingScreenState();
}

class _VerificationPendingScreenState extends State<VerificationPendingScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseDatabase _database = FirebaseDatabase.instance;
  StreamSubscription<DatabaseEvent>? _verificationSubscription;
  String _verificationStatus = 'pending';

  static const Map<String, Map<String, String>> _localizations = {
    'en': {
      'title': 'Verification Pending',
      'message': 'Your restaurant verification is pending approval.',
      'submessage': 'Please wait while we review your submission. You will be notified once your account is verified.',
      'checking': 'Checking status...',
      'approved': 'Verification Approved!',
      'approved_message': 'Your restaurant has been verified. You can now access your dashboard.',
      'go_to_dashboard': 'Go to Dashboard',
      'rejected': 'Verification Rejected',
      'rejected_message': 'Your verification request was rejected. Please contact support for more information.',
      'logout': 'Logout',
      'pending': 'Pending',
    },
    'ar': {
      'title': 'التحقق قيد الانتظار',
      'message': 'طلب التحقق من مطعمك قيد المراجعة.',
      'submessage': 'يرجى الانتظار بينما نراجع طلبك. سيتم إشعارك بمجرد التحقق من حسابك.',
      'checking': 'جارٍ التحقق من الحالة...',
      'approved': 'تم الموافقة على التحقق!',
      'approved_message': 'تم التحقق من مطعمك. يمكنك الآن الوصول إلى لوحة التحكم الخاصة بك.',
      'go_to_dashboard': 'الذهاب إلى لوحة التحكم',
      'rejected': 'تم رفض التحقق',
      'rejected_message': 'تم رفض طلب التحقق الخاص بك. يرجى الاتصال بالدعم لمزيد من المعلومات.',
      'logout': 'تسجيل الخروج',
      'pending': 'قيد الانتظار',
    },
  };

  @override
  void initState() {
    super.initState();
    _checkVerificationStatus();
    _listenToVerificationStatus();
  }

  void _checkVerificationStatus() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final statusRef = _database.ref('users/${user.uid}/verificationStatus');
      final snapshot = await statusRef.get();
      
      if (snapshot.exists && mounted) {
        final status = snapshot.value?.toString();
        if (status != null && status != _verificationStatus) {
          setState(() {
            _verificationStatus = status;
          });
          _handleStatusChange(status);
        }
      }
    } catch (e) {
      print('Error checking verification status: $e');
    }
  }

  void _listenToVerificationStatus() {
    final user = _auth.currentUser;
    if (user == null) return;

    _verificationSubscription = _database
        .ref('users/${user.uid}/verificationStatus')
        .onValue
        .listen((event) {
      if (event.snapshot.exists && mounted) {
        final status = event.snapshot.value?.toString();
        if (status != null && status != _verificationStatus) {
          setState(() {
            _verificationStatus = status;
          });
          _handleStatusChange(status);
        }
      }
    });
  }

  void _handleStatusChange(String status) {
    if (status == 'approved' && mounted) {
      // Navigate to SellerDashboard after a short delay
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const SellerDashboard()),
            (route) => false,
          );
        }
      });
    }
  }

  Future<void> _logout() async {
    await _auth.signOut();
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const AuthScreen()),
        (route) => false,
      );
    }
  }

  @override
  void dispose() {
    _verificationSubscription?.cancel();
    super.dispose();
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
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
            tooltip: loc['logout']!,
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_verificationStatus == 'pending') ...[
                const CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.deepOrange),
                ),
                const SizedBox(height: 32),
                Icon(
                  Icons.pending_actions,
                  size: 80,
                  color: Colors.orange[400],
                ),
                const SizedBox(height: 24),
                Text(
                  loc['message']!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  loc['submessage']!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 32),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.orange[100],
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    loc['pending']!,
                    style: TextStyle(
                      color: Colors.orange[800],
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ] else if (_verificationStatus == 'approved') ...[
                Icon(
                  Icons.check_circle,
                  size: 80,
                  color: Colors.green[400],
                ),
                const SizedBox(height: 24),
                Text(
                  loc['approved']!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  loc['approved_message']!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (context) => const SellerDashboard()),
                      (route) => false,
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  ),
                  child: Text(loc['go_to_dashboard']!),
                ),
              ] else if (_verificationStatus == 'rejected') ...[
                Icon(
                  Icons.cancel,
                  size: 80,
                  color: Colors.red[400],
                ),
                const SizedBox(height: 24),
                Text(
                  loc['rejected']!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  loc['rejected_message']!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: _logout,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  ),
                  child: Text(loc['logout']!),
                ),
              ] else ...[
                Text(
                  loc['checking']!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 18),
                ),
                const SizedBox(height: 16),
                const CircularProgressIndicator(),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

