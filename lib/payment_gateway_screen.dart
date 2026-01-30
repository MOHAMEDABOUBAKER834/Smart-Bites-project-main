import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:smart_bites/profile_screen.dart'; 

class PaymentGatewayScreen extends StatefulWidget {
  final int pointsToCharge;
  final int amountToPay;

  const PaymentGatewayScreen({
    super.key,
    required this.pointsToCharge,
    required this.amountToPay,
  });

  @override
  State<PaymentGatewayScreen> createState() => _PaymentGatewayScreenState();
}

class _PaymentGatewayScreenState extends State<PaymentGatewayScreen> {
  String _status = "جاري معالجة الدفع...";

  @override
  void initState() {
    super.initState();
    _processPayment();
  }

  void _processPayment() async {
    // محاكاة لعملية الدفع تستغرق 3 ثواني
    await Future.delayed(const Duration(seconds: 3));

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => _status = "خطأ: المستخدم غير مسجل.");
      return;
    }

    final userRef = FirebaseDatabase.instance.ref('users/${user.uid}');
    try {
      final snapshot = await userRef.get();
      if (snapshot.exists) {
        final data = snapshot.value as Map<dynamic, dynamic>;
        int currentPoints = (data['points'] as num?)?.toInt() ?? 0;
        await userRef.update({'points': currentPoints + widget.pointsToCharge});
        
        // الانتقال لشاشة النجاح
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const PaymentSuccessScreen()),
          (route) => route.isFirst,
        );
      }
    } catch (e) {
      setState(() => _status = "فشل شحن النقاط. حاول مرة أخرى.");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 20),
            Text(
              _status,
              style: const TextStyle(fontSize: 18),
            ),
          ],
        ),
      ),
    );
  }
}


class PaymentSuccessScreen extends StatelessWidget {
  const PaymentSuccessScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 100),
            const SizedBox(height: 20),
            const Text('تم شحن النقاط بنجاح!', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('العودة للحساب'),
            )
          ],
        ),
      ),
    );
  }
}