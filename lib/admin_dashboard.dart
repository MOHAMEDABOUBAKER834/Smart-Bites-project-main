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
  StreamSubscription<DatabaseEvent>? _usersSubscription;
  List<Map<String, dynamic>> _pendingVerifications = [];
  List<Map<String, dynamic>> _users = [];
  bool _isLoadingVerifications = true;
  bool _isLoadingUsers = true;

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
      'manage_users': 'Manage Users',
      'users': 'Users',
      'role': 'Role',
      'points': 'Points',
      'ban': 'Ban',
      'unban': 'Unban',
      'delete_user': 'Delete User',
      'add_points': 'Add Points',
      'ban_confirmation': 'Ban this account? The user will not be able to log in.',
      'unban_confirmation': 'Unban this account and allow login again?',
      'delete_user_confirmation': 'Delete this account and all related data? This cannot be undone.',
      'user_banned': 'User has been banned',
      'user_unbanned': 'User has been unbanned',
      'user_deleted': 'User account deleted',
      'points_updated': 'Points updated successfully',
      'no_users': 'No users found',
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
      'manage_users': 'إدارة المستخدمين',
      'users': 'المستخدمون',
      'role': 'الدور',
      'points': 'النقاط',
      'ban': 'حظر',
      'unban': 'إلغاء الحظر',
      'delete_user': 'حذف المستخدم',
      'add_points': 'إضافة نقاط',
      'ban_confirmation': 'هل تريد حظر هذا الحساب؟ لن يتمكن المستخدم من تسجيل الدخول.',
      'unban_confirmation': 'هل تريد إلغاء حظر هذا الحساب والسماح له بتسجيل الدخول مرة أخرى؟',
      'delete_user_confirmation': 'هل تريد حذف هذا الحساب وكل البيانات المرتبطة به؟ هذا الإجراء لا يمكن التراجع عنه.',
      'user_banned': 'تم حظر المستخدم',
      'user_unbanned': 'تم إلغاء حظر المستخدم',
      'user_deleted': 'تم حذف حساب المستخدم',
      'points_updated': 'تم تحديث النقاط بنجاح',
      'no_users': 'لا يوجد مستخدمون',
    },
  };

  @override
  void initState() {
    super.initState();
    _loadPendingVerifications();
    _listenToVerifications();
    _loadUsers();
    _listenToUsers();
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
          _isLoadingVerifications = false;
        });
      } else {
        setState(() {
          _pendingVerifications = [];
          _isLoadingVerifications = false;
        });
      }
    } catch (e) {
      print('Error loading pending verifications: $e');
      if (mounted) {
        setState(() {
          _isLoadingVerifications = false;
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

  Future<void> _loadUsers() async {
    try {
      final usersRef = _database.ref('users');
      final snapshot = await usersRef.get();

      if (snapshot.exists && mounted) {
        final data = snapshot.value as Map<dynamic, dynamic>;
        final List<Map<String, dynamic>> users = [];

        data.forEach((key, value) {
          final user = value as Map<dynamic, dynamic>;
          users.add({
            'userId': key.toString(),
            'name': user['name']?.toString() ?? '',
            'email': user['email']?.toString() ?? '',
            'role': user['role']?.toString() ?? '',
            'school': user['school']?.toString() ?? '',
            'points': (user['points'] as num?)?.toInt() ?? 0,
            'banned': user['banned'] == true || user['banned']?.toString() == 'true',
          });
        });

        setState(() {
          _users = users;
          _isLoadingUsers = false;
        });
      } else {
        setState(() {
          _users = [];
          _isLoadingUsers = false;
        });
      }
    } catch (e) {
      print('Error loading users: $e');
      if (mounted) {
        setState(() {
          _isLoadingUsers = false;
        });
      }
    }
  }

  void _listenToUsers() {
    _usersSubscription = _database
        .ref('users')
        .onValue
        .listen((event) {
      if (event.snapshot.exists && mounted) {
        final data = event.snapshot.value as Map<dynamic, dynamic>;
        final List<Map<String, dynamic>> users = [];

        data.forEach((key, value) {
          final user = value as Map<dynamic, dynamic>;
          users.add({
            'userId': key.toString(),
            'name': user['name']?.toString() ?? '',
            'email': user['email']?.toString() ?? '',
            'role': user['role']?.toString() ?? '',
            'school': user['school']?.toString() ?? '',
            'points': (user['points'] as num?)?.toInt() ?? 0,
            'banned': user['banned'] == true || user['banned']?.toString() == 'true',
          });
        });

        setState(() {
          _users = users;
        });
      } else {
        setState(() {
          _users = [];
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
    _usersSubscription?.cancel();
    super.dispose();
  }

  Future<void> _addPointsToUser(String userId, String userName) async {
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
    final langCode = languageProvider.currentLocale.languageCode;
    final loc = _localizations[langCode]!;

    final controller = TextEditingController();
    final result = await showDialog<int?>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${loc['add_points']!} - $userName'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Points to add',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: Text(loc['close']!),
          ),
          ElevatedButton(
            onPressed: () {
              final value = int.tryParse(controller.text.trim());
              Navigator.pop(context, value);
            },
            child: Text(loc['add_points']!),
          ),
        ],
      ),
    );

    if (result == null || result == 0) return;

    try {
      await _database.ref('users/$userId/points').set(ServerValue.increment(result));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(loc['points_updated']!),
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

  Future<void> _toggleBanUser(String userId, String userName, bool isBanned) async {
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
    final langCode = languageProvider.currentLocale.languageCode;
    final loc = _localizations[langCode]!;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isBanned ? loc['unban']! : loc['ban']!),
        content: Text(isBanned ? loc['unban_confirmation']! : loc['ban_confirmation']!),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(loc['close']!),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: isBanned ? Colors.green : Colors.red,
              foregroundColor: Colors.white,
            ),
            child: Text(isBanned ? loc['unban']! : loc['ban']!),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _database.ref('users/$userId/banned').set(!isBanned);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(!isBanned ? loc['user_banned']! : loc['user_unbanned']!),
            backgroundColor: !isBanned ? Colors.red : Colors.green,
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

  Future<void> _deleteUser(String userId, String userName) async {
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
    final langCode = languageProvider.currentLocale.languageCode;
    final loc = _localizations[langCode]!;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(loc['delete_user']!),
        content: Text(loc['delete_user_confirmation']!),
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
            child: Text(loc['delete_user']!),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      // Note: Client apps cannot delete OTHER users from Firebase Auth.
      // We delete all user-related data from Realtime Database.
      // Then the app will block the user from using the account because users/{uid} is missing.

      final dbRef = _database.ref();
      final updates = <String, Object?>{};

      // Read basic info before delete (role, numericId)
      String? role;
      int? numericId;
      try {
        final userSnapshot = await dbRef.child('users/$userId').get();
        if (userSnapshot.exists) {
          final data = userSnapshot.value as Map<dynamic, dynamic>;
          role = data['role']?.toString();
          final n = data['numericId'];
          if (n is num) numericId = n.toInt();
        }
      } catch (e) {
        print('⚠️ Could not read user info before delete: $e');
      }

      // Core deletes
      updates['users/$userId'] = null;
      updates['carts/$userId'] = null;
      updates['sellerVerifications/$userId'] = null;
      updates['coupons/$userId'] = null;
      if (numericId != null) {
        updates['numericId_to_uid/$numericId'] = null;
      }

      // Delete orders created by this user (buyer orders)
      // IMPORTANT:
      // We DO NOT delete orders when a buyer account is deleted.
      // Orders are needed for the seller's history and the points they collected from those orders.
      // Instead, we mark the orders as buyerDeleted to indicate the buyer account was removed.
      try {
        final ordersEvent = await dbRef
            .child('orders')
            .orderByChild('userId')
            .equalTo(userId)
            .once();
        if (ordersEvent.snapshot.exists) {
          final map = ordersEvent.snapshot.value as Map<dynamic, dynamic>?;
          if (map != null) {
            for (final key in map.keys) {
              updates['orders/$key/buyerDeleted'] = true;
              updates['orders/$key/buyerDeletedAt'] = ServerValue.timestamp;
            }
          }
        }
      } catch (e) {
        print('⚠️ Could not mark orders as buyerDeleted: $e');
      }

      // If seller, delete products & coupons & verification data (already covered for coupons/verifications)
      if (role == 'Seller') {
        try {
          final productsEvent = await dbRef
              .child('products')
              .orderByChild('sellerId')
              .equalTo(userId)
              .once();
          if (productsEvent.snapshot.exists) {
            final map = productsEvent.snapshot.value as Map<dynamic, dynamic>?;
            if (map != null) {
              for (final key in map.keys) {
                updates['products/$key'] = null;
              }
            }
          }
        } catch (e) {
          print('⚠️ Could not delete seller products: $e');
        }
      }

      // Delete point transfer logs where user is sender or receiver
      try {
        final transfersSnapshot = await dbRef.child('points_transfers').get();
        if (transfersSnapshot.exists) {
          final transfersMap = transfersSnapshot.value as Map<dynamic, dynamic>?;
          if (transfersMap != null) {
            for (final entry in transfersMap.entries) {
              final key = entry.key.toString();
              final t = (entry.value as Map?)?.cast<dynamic, dynamic>();
              if (t == null) continue;
              final senderId = t['senderId']?.toString();
              final receiverId = t['receiverId']?.toString();
              if (senderId == userId || receiverId == userId) {
                updates['points_transfers/$key'] = null;
              }
            }
          }
        }
      } catch (e) {
        print('⚠️ Could not delete points_transfers logs: $e');
      }

      // Apply all deletes in one update (faster + more consistent)
      await dbRef.update(updates);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(loc['user_deleted']!),
            backgroundColor: Colors.red,
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

  Widget _buildVerificationsTab(Map<String, String> loc) {
    if (_isLoadingVerifications) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_pendingVerifications.isEmpty) {
      return Center(
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
      );
    }

    return RefreshIndicator(
      onRefresh: () => _loadPendingVerifications(),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _pendingVerifications.length,
        itemBuilder: (context, index) {
          final verification = _pendingVerifications[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 16),
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
    );
  }

  Widget _buildUsersTab(Map<String, String> loc) {
    if (_isLoadingUsers) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_users.isEmpty) {
      return Center(
        child: Text(
          loc['no_users']!,
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey[600],
          ),
        ),
      );
    }

    // Sort users by role then name for better readability
    final sortedUsers = List<Map<String, dynamic>>.from(_users)
      ..sort((a, b) {
        final roleA = a['role']?.toString() ?? '';
        final roleB = b['role']?.toString() ?? '';
        final cmpRole = roleA.compareTo(roleB);
        if (cmpRole != 0) return cmpRole;
        return (a['name']?.toString() ?? '').compareTo(b['name']?.toString() ?? '');
      });

    return RefreshIndicator(
      onRefresh: () => _loadUsers(),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: sortedUsers.length,
        itemBuilder: (context, index) {
          final user = sortedUsers[index];
          final bool isBanned = user['banned'] == true;

          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            elevation: 2,
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: isBanned ? Colors.red.shade100 : Colors.deepOrange.shade100,
                child: Icon(
                  Icons.person,
                  color: isBanned ? Colors.red.shade700 : Colors.deepOrange,
                ),
              ),
              title: Text(
                user['name']?.toString().isNotEmpty == true ? user['name'] as String : user['email'] as String? ?? '',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isBanned ? Colors.red.shade700 : null,
                ),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if ((user['email'] as String?)?.isNotEmpty == true)
                    Text(user['email'] as String),
                  Row(
                    children: [
                      Text('${loc['role']!}: ${user['role'] ?? ''}'),
                      const SizedBox(width: 12),
                      Text('${loc['points']!}: ${user['points'] ?? 0}'),
                    ],
                  ),
                  if ((user['school'] as String?)?.isNotEmpty == true)
                    Text(user['school'] as String),
                  if (isBanned)
                    Text(
                      loc['ban']!,
                      style: TextStyle(color: Colors.red.shade700, fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                ],
              ),
              trailing: PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'add_points') {
                    _addPointsToUser(user['userId'] as String, user['name']?.toString() ?? user['email']?.toString() ?? '');
                  } else if (value == 'ban') {
                    _toggleBanUser(user['userId'] as String, user['name']?.toString() ?? '', isBanned);
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'add_points',
                    child: Text(loc['add_points']!),
                  ),
                  PopupMenuItem(
                    value: 'ban',
                    child: Text(isBanned ? loc['unban']! : loc['ban']!),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);
    final langCode = languageProvider.currentLocale.languageCode;
    final loc = _localizations[langCode]!;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
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
          bottom: TabBar(
            tabs: [
              Tab(text: loc['pending_verifications']!),
              Tab(text: loc['manage_users']!),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildVerificationsTab(loc),
            _buildUsersTab(loc),
          ],
        ),
      ),
    );
  }
}

