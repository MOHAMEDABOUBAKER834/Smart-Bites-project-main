import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:smart_bites/buyer_home.dart';
import 'package:smart_bites/seller_dashboard.dart';
import 'package:smart_bites/auth_screen.dart';

class UserRoleHelper {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Get user role from Firestore
  static Future<String?> getUserRole(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (doc.exists) {
        return doc.data()?['role'] as String?;
      }
      return null;
    } catch (e) {
      print('Error fetching user role: $e');
      return null;
    }
  }

  /// Navigate user to appropriate screen based on their role
  static Future<void> navigateBasedOnRole(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      // User not logged in, navigate to auth screen
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const AuthScreen()),
        (route) => false,
      );
      return;
    }

    final role = await getUserRole(user.uid);
    
    if (role == 'Seller') {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const SellerDashboard()),
        (route) => false,
      );
    } else {
      // Default to Buyer (or if role is null/not set)
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const BuyerHome()),
        (route) => false,
      );
    }
  }
}

