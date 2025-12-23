import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:cloud_firestore/cloud_firestore.dart' hide Transaction;
import 'package:provider/provider.dart';
import 'package:smart_bites/language_provider.dart';
import 'package:smart_bites/theme_provider.dart';
import 'package:smart_bites/user_role_helper.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _fullNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _auth = FirebaseAuth.instance;
  final _database = FirebaseDatabase.instance.ref();
  final _firestore = FirebaseFirestore.instance;

  bool _isLoginMode = true;
  bool _isLoading = false;
  String _selectedRole = 'Buyer'; // Default role

  static const Map<String, Map<String, String>> _localizations = {
    'ar': {
      'login_title': 'تسجيل الدخول',
      'signup_title': 'إنشاء حساب جديد',
      'email_label': 'البريد الإلكتروني',
      'password_label': 'كلمة المرور',
      'full_name_label': 'الاسم الكامل',
      'phone_label': 'رقم الموبايل',
      'login_button': 'دخول',
      'signup_button': 'إنشاء حساب',
      'switch_to_signup': 'ليس لديك حساب؟ أنشئ واحدًا',
      'switch_to_login': 'لديك حساب بالفعل؟ سجل الدخول',
      'auth_error': 'فشل تسجيل الدخول. تأكد من بياناتك.',
      'profile_error': 'من فضلك املأ كل الحقول',
      'role_label': 'نوع الحساب',
      'buyer': 'مشتري',
      'seller': 'بائع',
      'success_title': 'تم إنشاء حسابك بنجاح!',
      'redirecting': 'جاري توجيهك للصفحة الرئيسية...',
    },
    'en': {
      'login_title': 'Login',
      'signup_title': 'Create a New Account',
      'email_label': 'Email Address',
      'password_label': 'Password',
      'full_name_label': 'Full Name',
      'phone_label': 'Phone Number',
      'login_button': 'Login',
      'signup_button': 'Sign Up',
      'switch_to_signup': "Don't have an account? Sign up",
      'switch_to_login': 'Already have an account? Login',
      'auth_error': 'Authentication failed. Please check your credentials.',
      'profile_error': 'Please fill in all fields',
      'role_label': 'Account Type',
      'buyer': 'Buyer',
      'seller': 'Seller',
      'success_title': 'Account Created Successfully!',
      'redirecting': 'Redirecting to the home page...',
    }
  };

  Future<int> _generateUniqueNumericId() async {
    final counterRef = _database.child('counters/userId');
    final result = await counterRef.runTransaction((Object? currentData) {
      int currentValue = (currentData as int?) ?? 1000000000;
      int newValue = currentValue + 1;
      return Transaction.success(newValue);
    });

    if (result.committed) {
      return result.snapshot.value as int;
    } else {
      throw Exception("Failed to generate numeric ID");
    }
  }

  void _submitAuthForm() async {
    final langCode = Provider.of<LanguageProvider>(context, listen: false).currentLocale.languageCode;
    final loc = _localizations[langCode]!;
    
    setState(() => _isLoading = true);

    try {
      if (_isLoginMode) {
        await _auth.signInWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
        if (mounted) {
          await UserRoleHelper.navigateBasedOnRole(context);
        }
      } else {
        if (_fullNameController.text.isEmpty || _phoneController.text.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(loc['profile_error']!)));
          setState(() => _isLoading = false);
          return;
        }

        final userCredential = await _auth.createUserWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );

        final user = userCredential.user;
        if (user != null) {
          final numericId = await _generateUniqueNumericId();
          
          // Save to Realtime Database (existing logic)
          final Map<String, dynamic> updates = {};
          updates['/users/${user.uid}'] = {
            'name': _fullNameController.text.trim(),
            'email': _emailController.text.trim(),
            'phone': _phoneController.text.trim(),
            'school': 'القوميه بنات',
            'createdAt': ServerValue.timestamp,
            'points': 0,
            'numericId': numericId,
          };
          updates['/numericId_to_uid/$numericId'] = user.uid;
          await _database.update(updates);

          // Save to Firestore with role
          await _firestore.collection('users').doc(user.uid).set({
            'name': _fullNameController.text.trim(),
            'email': _emailController.text.trim(),
            'phone': _phoneController.text.trim(),
            'role': _selectedRole,
            'createdAt': FieldValue.serverTimestamp(),
            'numericId': numericId,
          }, SetOptions(merge: true));

          // --- ✅ تم نقل رسالة النجاح إلى هنا ---
          // لن تظهر إلا بعد التأكد من حفظ البيانات
          if (mounted) {
            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (ctx) => _RegistrationSuccessDialog(loc: loc),
            );
          }
        }
      }
    // --- ✅ تم تعديل هذا الجزء ليتعامل مع كل أنواع الأخطاء ---
    } catch (err) {
      print("An error occurred: ${err.toString()}");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(loc['auth_error']!), backgroundColor: Colors.red),
      );
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);
    final langCode = languageProvider.currentLocale.languageCode;
    final loc = _localizations[langCode]!;

    final themeProvider = Provider.of<ThemeProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Smart Bites', style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.bold)),
        backgroundColor: Colors.deepOrange.shade400,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(themeProvider.isDarkMode ? Icons.light_mode : Icons.dark_mode),
            onPressed: () {
              themeProvider.toggleTheme();
            },
            tooltip: themeProvider.isDarkMode ? 'Light Mode' : 'Dark Mode',
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Card(
            elevation: 8,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset('assets/images/logo.png', height: 80),
                  const SizedBox(height: 20),
                  ToggleButtons(
                    isSelected: [langCode == 'ar', langCode == 'en'],
                    onPressed: (index) {
                      languageProvider.setLocale(Locale(index == 0 ? 'ar' : 'en'));
                    },
                    borderRadius: BorderRadius.circular(30),
                    selectedColor: Colors.white,
                    fillColor: Colors.deepOrange,
                    children: const [
                      Padding(padding: EdgeInsets.symmetric(horizontal: 16.0), child: Text('العربية')),
                      Padding(padding: EdgeInsets.symmetric(horizontal: 16.0), child: Text('English', style: TextStyle(fontFamily: 'Poppins'))),
                    ],
                  ),
                  const SizedBox(height: 20),
                  if (!_isLoginMode) ...[
                    TextField(
                      controller: _fullNameController,
                      decoration: InputDecoration(labelText: loc['full_name_label']!),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(labelText: loc['phone_label']!),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      loc['role_label']!,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: ChoiceChip(
                            label: Text(loc['buyer']!),
                            selected: _selectedRole == 'Buyer',
                            onSelected: (selected) {
                              if (selected) {
                                setState(() => _selectedRole = 'Buyer');
                              }
                            },
                            selectedColor: Colors.deepOrange,
                            labelStyle: TextStyle(
                              color: _selectedRole == 'Buyer' ? Colors.white : Colors.black,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ChoiceChip(
                            label: Text(loc['seller']!),
                            selected: _selectedRole == 'Seller',
                            onSelected: (selected) {
                              if (selected) {
                                setState(() => _selectedRole = 'Seller');
                              }
                            },
                            selectedColor: Colors.deepOrange,
                            labelStyle: TextStyle(
                              color: _selectedRole == 'Seller' ? Colors.white : Colors.black,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                  ],
                  TextField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(labelText: loc['email_label']!),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: InputDecoration(labelText: loc['password_label']!),
                  ),
                  const SizedBox(height: 20),
                  if (_isLoading)
                    const CircularProgressIndicator()
                  else
                    ElevatedButton(
                      onPressed: _submitAuthForm,
                      style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
                      child: Text(_isLoginMode ? loc['login_button']! : loc['signup_button']!, style: const TextStyle(fontSize: 18)),
                    ),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _isLoginMode = !_isLoginMode;
                      });
                    },
                    child: Text(_isLoginMode ? loc['switch_to_signup']! : loc['switch_to_login']!),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RegistrationSuccessDialog extends StatefulWidget {
  final Map<String, String> loc;
  const _RegistrationSuccessDialog({required this.loc});

  @override
  State<_RegistrationSuccessDialog> createState() => __RegistrationSuccessDialogState();
}

class __RegistrationSuccessDialogState extends State<_RegistrationSuccessDialog> {
  @override
  void initState() {
    super.initState();
    Timer(const Duration(seconds: 3), () {
      if (mounted) {
        UserRoleHelper.navigateBasedOnRole(context);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check_circle_outline, color: Colors.green, size: 60),
          const SizedBox(height: 20),
          Text(
            widget.loc['success_title']!,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          Text(
            widget.loc['redirecting']!,
            style: const TextStyle(fontSize: 14, color: Colors.grey),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
