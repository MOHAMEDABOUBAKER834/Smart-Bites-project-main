import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:provider/provider.dart';
import 'package:smart_bites/language_provider.dart';
import 'package:smart_bites/admin_dashboard.dart';

class AdminLoginScreen extends StatefulWidget {
  const AdminLoginScreen({super.key});

  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseDatabase _database = FirebaseDatabase.instance;
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  static const Map<String, Map<String, String>> _localizations = {
    'en': {
      'title': 'Admin Login',
      'subtitle': 'Smart Bites Admin Panel',
      'email_label': 'Email',
      'password_label': 'Password',
      'login_button': 'Login',
      'logging_in': 'Logging in...',
      'error': 'Error',
      'invalid_credentials': 'Invalid email or password',
      'not_admin': 'This account is not an admin',
      'checking': 'Checking admin status...',
    },
    'ar': {
      'title': 'تسجيل دخول المشرف',
      'subtitle': 'لوحة تحكم Smart Bites',
      'email_label': 'البريد الإلكتروني',
      'password_label': 'كلمة المرور',
      'login_button': 'تسجيل الدخول',
      'logging_in': 'جارٍ تسجيل الدخول...',
      'error': 'خطأ',
      'invalid_credentials': 'البريد الإلكتروني أو كلمة المرور غير صحيحة',
      'not_admin': 'هذا الحساب ليس مشرفاً',
      'checking': 'جارٍ التحقق من حالة المشرف...',
    },
  };

  Future<void> _checkAdminStatus(String userId) async {
    try {
      final userRef = _database.ref('users/$userId/role');
      final snapshot = await userRef.get();
      
      if (snapshot.exists) {
        final role = snapshot.value?.toString();
        if (role == 'Admin') {
          if (mounted) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (context) => const AdminDashboard()),
            );
          }
        } else {
          await _auth.signOut();
          if (mounted) {
            setState(() {
              _isLoading = false;
              _errorMessage = _localizations[Provider.of<LanguageProvider>(context, listen: false).currentLocale.languageCode]!['not_admin'];
            });
          }
        }
      } else {
        await _auth.signOut();
        if (mounted) {
          setState(() {
            _isLoading = false;
            _errorMessage = _localizations[Provider.of<LanguageProvider>(context, listen: false).currentLocale.languageCode]!['not_admin'];
          });
        }
      }
    } catch (e) {
      await _auth.signOut();
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Error checking admin status: $e';
        });
      }
    }
  }

  Future<void> _login() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      setState(() {
        _errorMessage = _localizations[Provider.of<LanguageProvider>(context, listen: false).currentLocale.languageCode]!['invalid_credentials'];
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      if (userCredential.user != null) {
        // Check if user is admin
        await _checkAdminStatus(userCredential.user!.uid);
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        final langCode = Provider.of<LanguageProvider>(context, listen: false).currentLocale.languageCode;
        final loc = _localizations[langCode]!;
        
        setState(() {
          _isLoading = false;
          _errorMessage = loc['invalid_credentials'];
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Error: $e';
        });
      }
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);
    final langCode = languageProvider.currentLocale.languageCode;
    final loc = _localizations[langCode]!;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.admin_panel_settings,
                  size: 80,
                  color: Colors.deepOrange.shade400,
                ),
                const SizedBox(height: 24),
                Text(
                  loc['title']!,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  loc['subtitle']!,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 48),
                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: loc['email_label']!,
                    prefixIcon: const Icon(Icons.email),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: loc['password_label']!,
                    prefixIcon: const Icon(Icons.lock),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                if (_errorMessage != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red[300]!),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline, color: Colors.red[700]),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: TextStyle(color: Colors.red[700]),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _login,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepOrange.shade400,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isLoading
                        ? Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(loc['logging_in']!),
                            ],
                          )
                        : Text(
                            loc['login_button']!,
                            style: const TextStyle(fontSize: 18),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

