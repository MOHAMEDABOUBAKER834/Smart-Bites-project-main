import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:provider/provider.dart';
import 'package:smart_bites/language_provider.dart';
import 'package:smart_bites/admin_login_screen.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseDatabase _database = FirebaseDatabase.instance;
  StreamSubscription<DatabaseEvent>? _verificationsSubscription;
  List<Map<String, dynamic>> _pendingVerifications = [];
  bool _isLoading = true;

  static const Map<String, Map<String, String>> _localizations = {
    'en': {
      'title': 'Admin Dashboard',
      'pending_verifications': 'Pending Verifications',
      'no_pending': 'No pending verifications',
      'school_name': 'School Name',
      'email': 'Email',
      'submitted_at': 'Submitted At',
      'approve': 'Approve',
      'reject': 'Reject',
      'approve_confirmation': 'Approve this seller?',
      'reject_confirmation': 'Reject this seller?',
      'approved': 'Approved',
      'rejected': 'Rejected',
      'error': 'Error',
      'logout': 'Logout',
      'view_image': 'View Image',
      'image_title': 'Restaurant Image',
      'close': 'Close',
      'loading': 'Loading...',
    },
    'ar': {
      'title': 'لوحة تحكم المشرف',
      'pending_verifications': 'طلبات التحقق المعلقة',
      'no_pending': 'لا توجد طلبات تحقق معلقة',
      'school_name': 'اسم المدرسة',
      'email': 'البريد الإلكتروني',
      'submitted_at': 'تاريخ التقديم',
      'approve': 'موافقة',
      'reject': 'رفض',
      'approve_confirmation': 'الموافقة على هذا البائع؟',
      'reject_confirmation': 'رفض هذا البائع؟',
      'approved': 'تمت الموافقة',
      'rejected': 'تم الرفض',
      'error': 'خطأ',
      'logout': 'تسجيل الخروج',
      'view_image': 'عرض الصورة',
      'image_title': 'صورة المطعم',
      'close': 'إغلاق',
      'loading': 'جارٍ التحميل...',
    },
  };

  @override
  void initState() {
    super.initState();
    _loadPendingVerifications();
    _listenToVerifications();
  }

  Future<void> _loadPendingVerifications() async {
    try {
      final verificationsRef = _database.ref('sellerVerifications');
      final snapshot = await verificationsRef.get();

      if (snapshot.exists && mounted) {
        final data = snapshot.value as Map<dynamic, dynamic>;
        final List<Map<String, dynamic>> pending = [];

        data.forEach((key, value) {
          final verification = value as Map<dynamic, dynamic>;
          final status = verification['status']?.toString();
          if (status == 'pending') {
            pending.add({
              'userId': key.toString(),
              'schoolName': verification['schoolName']?.toString() ?? '',
              'email': verification['email']?.toString() ?? '',
              'verificationImage': verification['verificationImage']?.toString() ?? '',
              'submittedAt': verification['submittedAt'],
            });
          }
        });

        setState(() {
          _pendingVerifications = pending;
          _isLoading = false;
        });
      } else {
        setState(() {
          _pendingVerifications = [];
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading pending verifications: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _listenToVerifications() {
    _verificationsSubscription = _database
        .ref('sellerVerifications')
        .onValue
        .listen((event) {
      if (event.snapshot.exists && mounted) {
        final data = event.snapshot.value as Map<dynamic, dynamic>;
        final List<Map<String, dynamic>> pending = [];

        data.forEach((key, value) {
          final verification = value as Map<dynamic, dynamic>;
          final status = verification['status']?.toString();
          if (status == 'pending') {
            pending.add({
              'userId': key.toString(),
              'schoolName': verification['schoolName']?.toString() ?? '',
              'email': verification['email']?.toString() ?? '',
              'verificationImage': verification['verificationImage']?.toString() ?? '',
              'submittedAt': verification['submittedAt'],
            });
          }
        });

        setState(() {
          _pendingVerifications = pending;
        });
      } else {
        setState(() {
          _pendingVerifications = [];
        });
      }
    });
  }

  Future<void> _approveSeller(String userId) async {
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
    final langCode = languageProvider.currentLocale.languageCode;
    final loc = _localizations[langCode]!;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(loc['approve']!),
        content: Text(loc['approve_confirmation']!),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(loc['close']!),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: Text(loc['approve']!),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      // Update verification status
      await _database.ref('sellerVerifications/$userId/status').set('approved');
      await _database.ref('users/$userId/verificationStatus').set('approved');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(loc['approved']!),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${loc['error']!}: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _rejectSeller(String userId) async {
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
    final langCode = languageProvider.currentLocale.languageCode;
    final loc = _localizations[langCode]!;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(loc['reject']!),
        content: Text(loc['reject_confirmation']!),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(loc['close']!),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: Text(loc['reject']!),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      // Update verification status
      await _database.ref('sellerVerifications/$userId/status').set('rejected');
      await _database.ref('users/$userId/verificationStatus').set('rejected');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(loc['rejected']!),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${loc['error']!}: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showImageDialog(String base64Image) {
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
    final langCode = languageProvider.currentLocale.languageCode;
    final loc = _localizations[langCode]!;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppBar(
              title: Text(loc['image_title']!),
              backgroundColor: Colors.deepOrange.shade400,
              foregroundColor: Colors.white,
              actions: [
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            Flexible(
              child: Container(
                padding: const EdgeInsets.all(16),
                child: Image.memory(
                  base64Decode(base64Image),
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return 'Unknown';
    try {
      final ts = timestamp is int ? timestamp : timestamp as int;
      final date = DateTime.fromMillisecondsSinceEpoch(ts);
      return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return 'Unknown';
    }
  }

  Future<void> _logout() async {
    await _auth.signOut();
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const AdminLoginScreen()),
        (route) => false,
      );
    }
  }

  @override
  void dispose() {
    _verificationsSubscription?.cancel();
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
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _pendingVerifications.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.check_circle_outline,
                        size: 80,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        loc['no_pending']!,
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: () => _loadPendingVerifications(),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _pendingVerifications.length,
                    itemBuilder: (context, index) {
                      final verification = _pendingVerifications[index];
                      return Card(margin: const EdgeInsets.only(bottom: 16),
                        elevation: 2,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          loc['school_name']!,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                            color: Colors.grey,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          verification['schoolName'] ?? '',
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
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          loc['email']!,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                            color: Colors.grey,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          verification['email'] ?? '',
                                          style: const TextStyle(fontSize: 14),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                '${loc['submitted_at']!}: ${_formatTimestamp(verification['submittedAt'])}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: () {
                                        final image = verification['verificationImage']?.toString();
                                        if (image != null && image.isNotEmpty) {
                                          _showImageDialog(image);
                                        }
                                      },
                                      icon: const Icon(Icons.image),
                                      label: Text(loc['view_image']!),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: () => _rejectSeller(verification['userId']),
                                      icon: const Icon(Icons.close),
                                      label: Text(loc['reject']!),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.red,
                                        foregroundColor: Colors.white,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: () => _approveSeller(verification['userId']),
                                      icon: const Icon(Icons.check),
                                      label: Text(loc['approve']!),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.green,
                                        foregroundColor: Colors.white,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}

