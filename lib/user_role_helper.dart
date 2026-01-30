// import 'dart:async';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:firebase_database/firebase_database.dart';
// import 'package:flutter/material.dart';
// import 'package:smart_bites/buyer_home.dart';
// import 'package:smart_bites/seller_dashboard.dart';
// import 'package:smart_bites/auth_screen.dart';
//
// class UserRoleHelper {
//   static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
//   static final FirebaseDatabase _database = FirebaseDatabase.instance;
//
//   /// Get user role from Firestore or Realtime Database
//   static Future<String?> getUserRole(String userId) async {
//     // Try Firestore first
//     try {
//       final doc = await _firestore.collection('users').doc(userId).get().timeout(
//         const Duration(seconds: 5),
//         onTimeout: () {
//           print('Firestore timeout - trying Realtime Database');
//           throw TimeoutException('Firestore timeout');
//         },
//       );
//       if (doc.exists) {
//         final role = doc.data()?['role'] as String?;
//         if (role != null) {
//           print('✅ Found role in Firestore: $role');
//           return role;
//         }
//       }
//     } catch (e) {
//       print('⚠️ Firestore error (may not be enabled): $e');
//     }
//
//     // If Firestore fails, try Realtime Database
//     try {
//       final userRef = _database.ref('users/$userId');
//       final snapshot = await userRef.get().timeout(
//         const Duration(seconds: 5),
//         onTimeout: () {
//           print('Realtime Database timeout');
//           throw TimeoutException('Realtime Database timeout');
//         },
//       );
//
//       if (snapshot.exists) {
//         final data = snapshot.value as Map<dynamic, dynamic>;
//         final role = data['role']?.toString();
//         if (role != null) {
//           print('✅ Found role in Realtime Database: $role');
//           return role;
//         }
//       }
//     } catch (e) {
//       print('❌ Realtime Database error: $e');
//     }
//
//     print('⚠️ No role found for user: $userId');
//     return null;
//   }
//
//   /// Navigate user to appropriate screen based on their role
//   static Future<void> navigateBasedOnRole(BuildContext context) async {
//     try {
//       final user = FirebaseAuth.instance.currentUser;
//       if (user == null) {
//         print('❌ No user logged in - navigating to AuthScreen');
//         // User not logged in, navigate to auth screen
//         if (context.mounted) {
//           Navigator.pushAndRemoveUntil(
//             context,
//             MaterialPageRoute(builder: (context) => const AuthScreen()),
//             (route) => false,
//           );
//         }
//         return;
//       }
//
//       print('🔍 Getting role for user: ${user.uid}');
//       final role = await getUserRole(user.uid).timeout(
//         const Duration(seconds: 10),
//         onTimeout: () {
//           print('⚠️ Timeout getting role - defaulting to Buyer');
//           return 'Buyer'; // Default to Buyer on timeout
//         },
//       );
//
//       print('📱 Navigating based on role: $role');
//
//       if (!context.mounted) {
//         print('⚠️ Context not mounted - cannot navigate');
//         return;
//       }
//
//       if (role == 'Seller') {
//         Navigator.pushAndRemoveUntil(
//           context,
//           MaterialPageRoute(builder: (context) => const SellerDashboard()),
//           (route) => false,
//         );
//         print('✅ Navigated to SellerDashboard');
//       } else {
//         // Default to Buyer (or if role is null/not set)
//         Navigator.pushAndRemoveUntil(
//           context,
//           MaterialPageRoute(builder: (context) => const BuyerHome()),
//           (route) => false,
//         );
//         print('✅ Navigated to BuyerHome');
//       }
//     } catch (e) {
//       print('❌ Error in navigateBasedOnRole: $e');
//       // Last resort: navigate to BuyerHome (most common case)
//       if (context.mounted) {
//         try {
//           Navigator.pushAndRemoveUntil(
//             context,
//             MaterialPageRoute(builder: (context) => const BuyerHome()),
//             (route) => false,
//           );
//           print('✅ Navigated to BuyerHome (fallback)');
//         } catch (navError) {
//           print('❌ Navigation error: $navError');
//           // Final fallback: go to auth screen
//           if (context.mounted) {
//             Navigator.pushAndRemoveUntil(
//               context,
//               MaterialPageRoute(builder: (context) => const AuthScreen()),
//               (route) => false,
//             );
//           }
//         }
//       }
//     }
//   }
// }
//



import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:smart_bites/buyer_home.dart';
import 'package:smart_bites/seller_dashboard.dart';
import 'package:smart_bites/auth_screen.dart';
import 'package:smart_bites/verification_pending_screen.dart';
import 'package:smart_bites/seller_verification_page.dart';
import 'package:smart_bites/admin_dashboard.dart';

class UserRoleHelper {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseDatabase _database = FirebaseDatabase.instance;

  /// Get user role from Firestore or Realtime Database
  static Future<String?> getUserRole(String userId) async {
    // Try Firestore first
    try {
      final doc = await _firestore.collection('users').doc(userId).get().timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          print('Firestore timeout - trying Realtime Database');
          throw TimeoutException('Firestore timeout');
        },
      );
      if (doc.exists) {
        final role = doc.data()?['role'] as String?;
        if (role != null) {
          print('✅ Found role in Firestore: $role');
          return role;
        }
      }
    } catch (e) {
      print('⚠️ Firestore error (may not be enabled): $e');
    }

    // If Firestore fails, try Realtime Database
    try {
      final userRef = _database.ref('users/$userId');
      final snapshot = await userRef.get().timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          print('Realtime Database timeout');
          throw TimeoutException('Realtime Database timeout');
        },
      );

      if (snapshot.exists) {
        final data = snapshot.value as Map<dynamic, dynamic>;
        final role = data['role']?.toString();
        if (role != null) {
          print('✅ Found role in Realtime Database: $role');
          return role;
        }
      }
    } catch (e) {
      print('❌ Realtime Database error: $e');
    }

    print('⚠️ No role found for user: $userId');
    return null;
  }


  /// Get seller verification status from Realtime Database
  static Future<String?> _getVerificationStatus(String userId) async {
    try {
      final userRef = _database.ref('users/$userId/verificationStatus');
      final snapshot = await userRef.get().timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          print('Realtime Database timeout getting verification status');
          throw TimeoutException('Realtime Database timeout');
        },
      );

      if (snapshot.exists) {
        final status = snapshot.value?.toString();
        print('✅ Found verification status: $status');
        
        // CRITICAL: If status is 'pending', check if verification image actually exists
        // If no image exists, seller needs to upload first
        if (status == 'pending') {
          final verificationRef = _database.ref('sellerVerifications/$userId');
          final verificationSnapshot = await verificationRef.get().timeout(
            const Duration(seconds: 3),
            // onTimeout: () {
            //   print('Timeout checking verification image');
            //     // Return null to force upload page
            // },
          );
          
          if (!verificationSnapshot.exists || 
              (verificationSnapshot.value as Map<dynamic, dynamic>?)?['verificationImage'] == null) {
            print('⚠️ Status is pending but no verification image found - redirecting to upload page');
            return null; // Force redirect to SellerVerificationPage
          }
        }
        
        return status;
      }
    } catch (e) {
      print('❌ Realtime Database error getting verification status: $e');
    }

    print('⚠️ No verification status found for user: $userId');
    return null;
  }

  /// Navigate user to appropriate screen based on their role
  static Future<void> navigateBasedOnRole(BuildContext context) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        print('❌ No user logged in - navigating to AuthScreen');
        // User not logged in, navigate to auth screen
        if (context.mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const AuthScreen()),
                (route) => false,
          );
        }
        return;
      }

      print('🔍 Getting role for user: ${user.uid}');
      final role = await getUserRole(user.uid).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          print('⚠️ Timeout getting role - defaulting to Buyer');
          return 'Buyer'; // Default to Buyer on timeout
        },
      );

      print('📱 Navigating based on role: $role');

      if (!context.mounted) {
        print('⚠️ Context not mounted - cannot navigate');
        return;
      }

      if (role == 'Admin') {
        // Admin users go directly to AdminDashboard
        print('👑 Admin user - navigating to AdminDashboard');
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const AdminDashboard()),
          (route) => false,
        );
        print('✅ Navigated to AdminDashboard');
        return;
      }

      if (role == 'Seller') {
        // Check verification status for sellers
        final verificationStatus = await _getVerificationStatus(user.uid);
        print('📋 Seller verification status: $verificationStatus');
        
        if (verificationStatus == null || verificationStatus.isEmpty) {
          // No verification status - redirect to verification page
          print('📝 No verification status - redirecting to SellerVerificationPage');
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const SellerVerificationPage()),
            (route) => false,
          );
        } else if (verificationStatus == 'approved') {
          // Verified - go to dashboard
          print('✅ Seller verified - navigating to SellerDashboard');
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const SellerDashboard()),
            (route) => false,
          );
        } else {
          // Pending or rejected - show pending screen
          print('⏳ Seller verification status: $verificationStatus - navigating to VerificationPendingScreen');
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const VerificationPendingScreen()),
            (route) => false,
          );
        }
      } else {
        // Default to Buyer (or if role is null/not set)
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const BuyerHome()),
              (route) => false,
        );
        print('✅ Navigated to BuyerHome');
      }
    } catch (e) {
      print('❌ Error in navigateBasedOnRole: $e');
      // Last resort: navigate to BuyerHome (most common case)
      if (context.mounted) {
        try {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const BuyerHome()),
                (route) => false,
          );
          print('✅ Navigated to BuyerHome (fallback)');
        } catch (navError) {
          print('❌ Navigation error: $navError');
          // Final fallback: go to auth screen
          if (context.mounted) {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (context) => const AuthScreen()),
                  (route) => false,
            );
          }
        }
      }
    }
  }
}

