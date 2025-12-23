import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:smart_bites/auth_screen.dart';
import 'package:smart_bites/user_role_helper.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    // مؤقت للانتقال بعد 3 ثوانٍ
    Timer(const Duration(seconds: 3), () async {
      // --- التحقق من حالة تسجيل الدخول هنا ---
      final user = FirebaseAuth.instance.currentUser;

      if (user != null) {
        // إذا كان المستخدم مسجل دخوله، اذهب للصفحة المناسبة حسب الدور
        await UserRoleHelper.navigateBasedOnRole(context);
      } else {
        // إذا لم يكن مسجل دخوله، اذهب لشاشة التسجيل
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const AuthScreen()),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      // 1. الخلفية أصبحت بيضاء
      backgroundColor: Colors.white,
      body: Column(
        children: [
          // 2. اللوجو في المنتصف وحجمه كبير
          Expanded(
            child: Center(
              child: Image(
                image: AssetImage('assets/images/logo.png'), // تأكد من وجود الشعار بهذا المسار
                height: 200, // تم تكبير حجم اللوجو
              ),
            ),
          ),
          // 3. مؤشر التحميل في الأسفل
          Padding(
            padding: EdgeInsets.only(bottom: 50.0),
            child: SpinKitFadingCircle(
              color: Colors.orangeAccent,
              size: 50.0,
            ),
          ),
        ],
      ),
    );
  }
}
