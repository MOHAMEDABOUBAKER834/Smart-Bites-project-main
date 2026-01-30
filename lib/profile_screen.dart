import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:smart_bites/language_provider.dart';
import 'package:smart_bites/auth_screen.dart';
import 'package:smart_bites/order_history_screen.dart';
import 'package:smart_bites/charge_points_screen.dart';
import 'package:smart_bites/transfer_points_screen.dart'; 
import 'package:smart_bites/recent_transfers_screen.dart';
import 'dart:async';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final User? currentUser = FirebaseAuth.instance.currentUser;
  final dbRef = FirebaseDatabase.instance.ref();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String userName = '...';
  int userPoints = 0;
  int? userNumericId;
  bool _isDeleting = false;

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
      'cancel': 'إلغاء',
      'confirm': 'تأكيد',
      'error': 'خطأ',
      'logout': 'تسجيل الخروج',
      'delete_account': 'حذف الحساب',
      'delete_account_confirmation': 'هل أنت متأكد من حذف حسابك؟ هذا الإجراء لا يمكن التراجع عنه وسيتم حذف جميع بياناتك بشكل دائم.',
      'delete_account_warning': 'تحذير: سيتم حذف جميع بياناتك',
      'account_deleted': 'تم حذف الحساب بنجاح',
      'deleting_account': 'جاري حذف الحساب...',
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
      'cancel': 'Cancel',
      'confirm': 'Confirm',
      'error': 'Error',
      'logout': 'Logout',
      'delete_account': 'Delete Account',
      'delete_account_confirmation': 'Are you sure you want to delete your account? This action cannot be undone and will permanently delete all your data.',
      'delete_account_warning': 'Warning: All your data will be deleted',
      'account_deleted': 'Account deleted successfully',
      'deleting_account': 'Deleting account...',
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

  void _deleteAccount() async {
    final langCode = Provider.of<LanguageProvider>(context, listen: false).currentLocale.languageCode;
    final loc = _localizations[langCode]!;

    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(loc['delete_account_warning']!, style: const TextStyle(color: Colors.red)),
        content: Text(loc['delete_account_confirmation']!),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(loc['cancel'] ?? 'Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text(loc['confirm'] ?? 'Confirm',style: TextStyle(color: Colors.white),),
          ),
        ],
      ),
    );

    if (shouldDelete == true && currentUser != null) {
      setState(() {
        _isDeleting = true;
      });

      try {
        final user = currentUser!;
        final userId = user.uid;

        // Get numeric ID before deleting
        final numericId = userNumericId;

        // Delete from Realtime Database
        try {
          print('🗑️ Starting deletion from Realtime Database...');
          
          // Delete user data
          await dbRef.child('users/$userId').remove();
          print('✅ Deleted user data');
          
          // Delete from numericId_to_uid mapping if numericId exists
          if (numericId != null) {
            await dbRef.child('numericId_to_uid/$numericId').remove();
            print('✅ Deleted numericId mapping');
          }

          // Delete user's cart
          await dbRef.child('carts/$userId').remove();
          print('✅ Deleted user cart');
          
          // Delete user's orders (by userId)
          final ordersRef = dbRef.child('orders');
          final ordersSnapshot = await ordersRef.orderByChild('userId').equalTo(userId).once();
          if (ordersSnapshot.snapshot.exists) {
            final ordersMap = ordersSnapshot.snapshot.value as Map?;
            if (ordersMap != null) {
              int deletedOrders = 0;
              for (var key in ordersMap.keys) {
                await ordersRef.child(key).remove();
                deletedOrders++;
              }
              print('✅ Deleted $deletedOrders orders');
            }
          }
          
          // Delete point transfers where user is sender or receiver
          try {
            final transfersRef = dbRef.child('points_transfers');
            final transfersSnapshot = await transfersRef.get();
            if (transfersSnapshot.exists) {
              final transfersMap = transfersSnapshot.value as Map?;
              if (transfersMap != null) {
                int deletedTransfers = 0;
                for (var key in transfersMap.keys) {
                  final transfer = transfersMap[key] as Map?;
                  if (transfer != null) {
                    final senderId = transfer['senderId']?.toString();
                    final receiverId = transfer['receiverId']?.toString();
                    if (senderId == userId || receiverId == userId) {
                      await transfersRef.child(key).remove();
                      deletedTransfers++;
                    }
                  }
                }
                if (deletedTransfers > 0) {
                  print('✅ Deleted $deletedTransfers transfers');
                }
              }
            }
          } catch (transferError) {
            print('⚠️ Error deleting transfers: $transferError');
          }
          
          print('✅ Completed Realtime Database deletion');
        } catch (dbError) {
          print('❌ Error deleting from Realtime Database: $dbError');
          // Continue even if Realtime DB deletion fails
        }

        // Delete from Firestore with timeout
        try {
          print('🗑️ Starting deletion from Firestore...');
          
          // Delete user document
          await _firestore.collection('users').doc(userId).delete().timeout(
            const Duration(seconds: 5),
            onTimeout: () {
              print('⚠️ Firestore user delete timed out');
              throw TimeoutException('Firestore operation timed out');
            },
          );
          print('✅ Deleted user from Firestore');
          
          // Delete transfers from Firestore
          try {
            final transfersQuery = await _firestore
                .collection('transfers')
                .where('senderId', isEqualTo: userId)
                .get()
                .timeout(const Duration(seconds: 5));
            for (var doc in transfersQuery.docs) {
              await doc.reference.delete();
            }
            
            final receivedTransfersQuery = await _firestore
                .collection('transfers')
                .where('receiverId', isEqualTo: userId)
                .get()
                .timeout(const Duration(seconds: 5));
            for (var doc in receivedTransfersQuery.docs) {
              await doc.reference.delete();
            }
            print('✅ Deleted transfers from Firestore');
          } catch (transferError) {
            print('⚠️ Error deleting transfers from Firestore: $transferError');
          }
          
          print('✅ Completed Firestore deletion');
        } on TimeoutException {
          print('⚠️ Firestore delete timed out - continuing with account deletion');
        } catch (firestoreError) {
          print('❌ Error deleting from Firestore: $firestoreError');
          // Continue even if Firestore deletion fails
        }

        // Delete Firebase Auth account
        await user.delete();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(loc['account_deleted']!)),
          );
          
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const AuthScreen()),
            (route) => false,
          );
        }
      } catch (e) {
        print('Error deleting account: $e');
        if (mounted) {
          setState(() {
            _isDeleting = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${loc['error'] ?? 'Error'}: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
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
      ),
      body: SingleChildScrollView(
        child: Padding(
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
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _isDeleting ? null : _logout,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color.fromARGB(255, 241, 46, 46),
                minimumSize: const Size(double.infinity, 50),
              ),
              child: Text(loc['logout']!, style: const TextStyle(fontSize: 18,color: Colors.white)),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _isDeleting ? null : _deleteAccount,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color.fromARGB(255, 241, 46, 46),
                minimumSize: const Size(double.infinity, 50),
              ),
              child: _isDeleting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(loc['delete_account']!, style: const TextStyle(fontSize: 18,color: Colors.white)),
            ),
            const SizedBox(height: 20),
          ],
        ),
        ),
      ),
    );
  }
}
