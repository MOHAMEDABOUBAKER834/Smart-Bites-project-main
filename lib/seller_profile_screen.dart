import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:provider/provider.dart';
import 'package:smart_bites/language_provider.dart';
import 'package:smart_bites/auth_screen.dart';
import 'dart:async';

class SellerProfileScreen extends StatefulWidget {
  const SellerProfileScreen({super.key});

  @override
  State<SellerProfileScreen> createState() => _SellerProfileScreenState();
}

class _SellerProfileScreenState extends State<SellerProfileScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseDatabase _database = FirebaseDatabase.instance;
  String? _sellerName;
  String? _sellerEmail;
  bool _isDeleting = false;

  static const Map<String, Map<String, String>> _localizations = {
    'ar': {
      'title': 'الملف الشخصي',
      'seller_profile': 'ملف البائع',
      'email': 'البريد الإلكتروني',
      'name': 'الاسم',
      'logout': 'تسجيل الخروج',
      'logout_confirmation': 'هل أنت متأكد من تسجيل الخروج؟',
      'delete_account': 'حذف الحساب',
      'delete_account_confirmation': 'هل أنت متأكد من حذف حسابك؟ هذا الإجراء لا يمكن التراجع عنه وسيتم حذف جميع بياناتك ومنتجاتك بشكل دائم.',
      'delete_account_warning': 'تحذير: سيتم حذف جميع بياناتك',
      'account_deleted': 'تم حذف الحساب بنجاح',
      'deleting_account': 'جاري حذف الحساب...',
      'cancel': 'إلغاء',
      'confirm': 'تأكيد',
      'loading': 'جاري التحميل...',
      'error': 'خطأ',
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
      'delete_account': 'Delete Account',
      'delete_account_confirmation': 'Are you sure you want to delete your account? This action cannot be undone and will permanently delete all your data and products.',
      'delete_account_warning': 'Warning: All your data will be deleted',
      'account_deleted': 'Account deleted successfully',
      'deleting_account': 'Deleting account...',
      'cancel': 'Cancel',
      'confirm': 'Confirm',
      'loading': 'Loading...',
      'error': 'Error',
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
        title: Text(loc['logout']!, style: TextStyle(color: Colors.black),),
        content: Text(loc['logout_confirmation']!),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(loc['cancel']!),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text(loc['confirm'] ?? 'Confirm',style: TextStyle(color: Colors.white),),
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
            child: Text(loc['cancel']!),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text(loc['confirm'] ?? 'Confirm',style: TextStyle(color: Colors.white),),
          ),
        ],
      ),
    );

    if (shouldDelete == true) {
      final user = _auth.currentUser;
      if (user == null) return;

      setState(() {
        _isDeleting = true;
      });

      try {
        final userId = user.uid;

        // Get numeric ID from Firestore before deleting
        int? numericId;
        try {
          final userDoc = await _firestore.collection('users').doc(userId).get();
          if (userDoc.exists) {
            numericId = userDoc.data()?['numericId'] as int?;
          }
        } catch (e) {
          print('Error getting numeric ID: $e');
        }

        final dbRef = _database.ref();

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

          // Delete seller's products from Realtime Database
          final productsSnapshot = await dbRef.child('products').orderByChild('sellerId').equalTo(userId).once();
          if (productsSnapshot.snapshot.exists) {
            final productsMap = productsSnapshot.snapshot.value as Map?;
            if (productsMap != null) {
              int deletedProducts = 0;
              for (var key in productsMap.keys) {
                await dbRef.child('products/$key').remove();
                deletedProducts++;
              }
              print('✅ Deleted $deletedProducts products from Realtime DB');
            }
          }

          // Delete seller's cart (if exists)
          await dbRef.child('carts/$userId').remove();
          print('✅ Deleted seller cart');

          // Delete orders by sellerId (orders from this seller)
          final ordersBySellerRef = dbRef.child('orders');
          final ordersBySellerSnapshot = await ordersBySellerRef.orderByChild('sellerId').equalTo(userId).once();
          if (ordersBySellerSnapshot.snapshot.exists) {
            final ordersMap = ordersBySellerSnapshot.snapshot.value as Map?;
            if (ordersMap != null) {
              int deletedOrders = 0;
              for (var key in ordersMap.keys) {
                await ordersBySellerRef.child(key).remove();
                deletedOrders++;
              }
              print('✅ Deleted $deletedOrders orders by sellerId');
            }
          }
          
          // Also delete orders by userId (if seller placed any orders)
          final ordersByUserSnapshot = await ordersBySellerRef.orderByChild('userId').equalTo(userId).once();
          if (ordersByUserSnapshot.snapshot.exists) {
            final ordersMap = ordersByUserSnapshot.snapshot.value as Map?;
            if (ordersMap != null) {
              int deletedOrders = 0;
              for (var key in ordersMap.keys) {
                await ordersBySellerRef.child(key).remove();
                deletedOrders++;
              }
              if (deletedOrders > 0) {
                print('✅ Deleted $deletedOrders orders by userId');
              }
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

        // Delete seller's products from Firestore with timeout
        try {
          print('🗑️ Starting deletion of products from Firestore...');
          final productsQuery = await _firestore
              .collection('products')
              .where('sellerId', isEqualTo: userId)
              .get()
              .timeout(const Duration(seconds: 10));

          int deletedProducts = 0;
          for (var doc in productsQuery.docs) {
            try {
              await doc.reference.delete().timeout(const Duration(seconds: 5));
              deletedProducts++;
            } catch (e) {
              print('⚠️ Error deleting product ${doc.id}: $e');
              // Continue with other products
            }
          }
          print('✅ Deleted $deletedProducts products from Firestore');
        } on TimeoutException {
          print('⚠️ Firestore products delete timed out');
        } catch (productsError) {
          print('❌ Error deleting products from Firestore: $productsError');
        }

        // Delete user from Firestore with timeout
        try {
          print('🗑️ Starting deletion of user from Firestore...');
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
        } on TimeoutException {
          print('⚠️ Firestore user delete timed out - continuing with account deletion');
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
              content: Text('${loc['error']!}: ${e.toString()}'),
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
        backgroundColor: Colors.deepOrange.shade400,
        foregroundColor: Colors.white,
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
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _isDeleting ? null : _logout,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color.fromARGB(255, 241, 46, 46),
                minimumSize: const Size(double.infinity, 50),
              ),
              child: Text(
                loc['logout']!,
                style: const TextStyle(fontSize: 18,color: Colors.white),
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _isDeleting ? null : _deleteAccount,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade700,
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
                  : Text(
                      loc['delete_account']!,
                      style: const TextStyle(fontSize: 18,color: Colors.white),
                    ),
            ),
            const SizedBox(height: 20),
          ],
        ),
        ),
      ),
    );
  }
}

