import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:cloud_firestore/cloud_firestore.dart' hide Transaction;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_bites/language_provider.dart';
import 'package:smart_bites/theme_provider.dart';
import 'package:smart_bites/user_role_helper.dart';
import 'package:smart_bites/buyer_home.dart';
import 'package:smart_bites/seller_verification_page.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  static const Map<String, Map<String, String>> _localizations = {
    'ar': {
      'login_title': 'تسجيل الدخول',
      'signup_title': 'إنشاء حساب جديد',
      'email_label': 'البريد الإلكتروني',
      'password_label': 'كلمة المرور',
      'confirm_password_label': 'تأكيد كلمة المرور',
      'full_name_label': 'الاسم الكامل',
      'phone_label': 'رقم الموبايل',
      'login_button': 'دخول',
      'signup_button': 'إنشاء حساب',
      'switch_to_signup': 'ليس لديك حساب؟ أنشئ واحدًا',
      'switch_to_login': 'لديك حساب بالفعل؟ سجل الدخول',
      'auth_error': 'فشل تسجيل الدخول. تأكد من بياناتك.',
      'profile_error': 'من فضلك املأ كل الحقول',
      'password_mismatch': 'كلمات المرور غير متطابقة',
      'role_label': 'نوع الحساب',
      'buyer': 'مشتري',
      'seller': 'بائع',
      'school_label': 'المدرسة',
      'select_school': 'اختر المدرسة',
      'school_name_label': 'اسم المدرسة',
      'school_name_hint': 'أدخل اسم المدرسة',
      'school_name_info': 'هذا الاسم سيظهر للطلاب لاختيار مدرستهم',
      'verification_title': 'تحقق من البريد الإلكتروني',
      'verification_message': 'لقد أرسلنا بريد تحقق إلى:',
      'verification_instructions': 'يرجى فتح بريدك الإلكتروني والنقر على رابط التحقق، ثم العودة للتسجيل.',
      'resend_verification': 'إعادة إرسال بريد التحقق',
      'check_verification': 'التحقق من حالة البريد',
      'verification_sent': 'تم إرسال بريد التحقق بنجاح',
      'verification_error': 'فشل إرسال بريد التحقق. حاول مرة أخرى.',
      'email_not_verified': 'بريدك الإلكتروني غير مفعل بعد. يرجى تفعيله أولاً.',
      'email_already_in_use': 'البريد الإلكتروني مستخدم بالفعل',
      'invalid_email': 'بريد إلكتروني غير صالح',
      'weak_password': 'كلمة المرور ضعيفة. يجب أن تحتوي على 6 أحرف على الأقل',
      'verify_email_button': 'تحقق من البريد',
      'back_to_signup': 'العودة للتسجيل',
      'success_title': 'تم إنشاء حسابك بنجاح!',
      'redirecting': 'جاري توجيهك للصفحة الرئيسية...',
    },
    'en': {
      'login_title': 'Login',
      'signup_title': 'Create a New Account',
      'email_label': 'Email Address',
      'password_label': 'Password',
      'confirm_password_label': 'Confirm Password',
      'full_name_label': 'Full Name',
      'phone_label': 'Phone Number',
      'login_button': 'Login',
      'signup_button': 'Sign Up',
      'switch_to_signup': "Don't have an account? Sign up",
      'switch_to_login': 'Already have an account? Login',
      'auth_error': 'Authentication failed. Please check your credentials.',
      'profile_error': 'Please fill in all fields',
      'password_mismatch': 'Passwords do not match',
      'role_label': 'Account Type',
      'buyer': 'Buyer',
      'seller': 'Seller',
      'school_label': 'School',
      'select_school': 'Select School',
      'school_name_label': 'School Name',
      'school_name_hint': 'Enter school name',
      'school_name_info': 'This name will appear in the list for buyers to select their school',
      'verification_title': 'Verify Email Address',
      'verification_message': 'We have sent a verification email to:',
      'verification_instructions': 'Please open your email and click the verification link, then return to complete registration.',
      'resend_verification': 'Resend Verification Email',
      'check_verification': 'Check Verification Status',
      'verification_sent': 'Verification email sent successfully',
      'verification_error': 'Failed to send verification email. Please try again.',
      'email_not_verified': 'Your email is not verified yet. Please verify it first.',
      'email_already_in_use': 'Email already in use',
      'invalid_email': 'Invalid email address',
      'weak_password': 'Weak password. Must be at least 6 characters',
      'verify_email_button': 'Verify Email',
      'back_to_signup': 'Back to Sign Up',
      'success_title': 'Account Created Successfully!',
      'redirecting': 'Redirecting to the home page...',
    }
  };

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _fullNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _auth = FirebaseAuth.instance;
  final _database = FirebaseDatabase.instance.ref();
  final _firestore = FirebaseFirestore.instance;

  bool _isLoginMode = true;
  bool _isLoading = false;
  String _selectedRole = 'Buyer';
  String? _selectedSchool; // Store selected school for buyers
  List<String> _availableSchools = []; // List of available schools (sellers)

  @override
  void initState() {
    super.initState();
    _loadAvailableSchools();
    // Reload schools periodically to catch new sellers (every 10 seconds)
    Timer.periodic(const Duration(seconds: 10), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_selectedRole == 'Buyer') {
        _loadAvailableSchools();
      }
    });
  }

  // Load available schools (sellers) from database
  Future<void> _loadAvailableSchools() async {
    if (!mounted) return;

    print('=== Loading available schools ===');
    final schools = <String>[];

    try {
      // Try Firestore first
      try {
        print('Searching Firestore for sellers...');
        final sellersQuery = await _firestore
            .collection('users')
            .where('role', isEqualTo: 'Seller')
            .get()
            .timeout(const Duration(seconds: 10));

        print('Firestore query returned ${sellersQuery.docs.length} documents');

        for (var doc in sellersQuery.docs) {
          final data = doc.data();
          final role = data['role']?.toString();
          final name = data['name']?.toString() ?? '';
          print('  - Document ID: ${doc.id}, Role: $role, Name: "$name"');

          if (name.isNotEmpty) {
            schools.add(name);
            print('  ✓ Added seller: $name');
          } else {
            print('  ✗ Skipped: name is empty');
          }
        }
      } catch (firestoreError) {
        print('Firestore error: $firestoreError');
        print('Will try Realtime Database...');
      }

      // Also try Realtime Database (may have sellers not in Firestore)
      try {
        print('Searching Realtime Database for sellers...');
        final usersSnapshot = await _database.child('users').get()
            .timeout(const Duration(seconds: 10));

        if (usersSnapshot.exists) {
          final usersMap = usersSnapshot.value as Map<dynamic, dynamic>;
          print('Realtime DB has ${usersMap.length} users');

          for (var entry in usersMap.entries) {
            final userId = entry.key.toString();
            final userData = entry.value as Map<dynamic, dynamic>;
            final role = userData['role']?.toString();
            final name = userData['name']?.toString();

            print('  - User ID: $userId, Role: "$role", Name: "$name"');

            if (role == 'Seller' && name != null && name.isNotEmpty) {
              // Avoid duplicates
              if (!schools.contains(name)) {
                schools.add(name);
                print('  ✓ Added seller from Realtime DB: $name');
              } else {
                print('  ⊗ Duplicate seller skipped: $name');
              }
            } else if (role == 'Seller' && (name == null || name.isEmpty)) {
              print('  ✗ Seller found but name is empty/null');
            }
          }
        } else {
          print('Realtime DB users node does not exist');
        }
      } catch (realtimeError) {
        print('Realtime DB error: $realtimeError');
      }

      // Remove duplicates and sort
      final uniqueSchools = schools.toSet().toList()..sort();

      print('=== Summary ===');
      print('Total unique schools found: ${uniqueSchools.length}');
      if (uniqueSchools.isNotEmpty) {
        print('Schools list: ${uniqueSchools.join(", ")}');
      } else {
        print('⚠️ No schools found! Make sure:');
        print('  1. At least one Seller has registered');
        print('  2. Seller completed email verification');
        print('  3. Seller has role="Seller" in database');
        print('  4. Seller has a non-empty name field');
      }

      if (mounted) {
        setState(() {
          _availableSchools = uniqueSchools;
          // Auto-select first school if none selected and schools available
          if (_selectedSchool == null && uniqueSchools.isNotEmpty) {
            _selectedSchool = uniqueSchools.first;
            print('Auto-selected school: ${_selectedSchool}');
          }
        });
      }
    } catch (e) {
      print('❌ Error loading schools: $e');
      print('Stack trace: ${StackTrace.current}');
      if (mounted) {
        setState(() {
          _availableSchools = [];
          _selectedSchool = null;
        });
      }
    }
  }

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

  // نفس النظام الموجود في المشروع القديم - حفظ البيانات بعد التحقق
  Future<void> _saveUserDataAfterVerification(User user) async {
    try {
      final numericId = await _generateUniqueNumericId();

      // Save to Realtime Database
      final Map<String, dynamic> updates = {};
      updates['/users/${user.uid}'] = {
        'name': _fullNameController.text.trim(),
        'email': _emailController.text.trim(),
        'phone': _phoneController.text.trim(),
        'school': _selectedSchool ?? '',
        'role': _selectedRole, // IMPORTANT: Save role to Realtime DB too
        'createdAt': ServerValue.timestamp,
        'points': 0,
        'numericId': numericId,
        'emailVerified': true,
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
        'emailVerified': true,
      }, SetOptions(merge: true));

      print("User data saved successfully for: ${user.email}");
    } catch (error) {
      print("Error saving user data: $error");
      throw error;
    }
  }

  void _submitAuthForm() async {
    final langCode = Provider.of<LanguageProvider>(context, listen: false).currentLocale.languageCode;
    final loc = AuthScreen._localizations[langCode]!;

    setState(() => _isLoading = true);

    try {
      if (_isLoginMode) {
        final userCredential = await _auth.signInWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );

        final user = userCredential.user;
        if (user != null && !user.emailVerified) {
          setState(() => _isLoading = false);
          if (mounted) {
            Navigator.push(
              context,
              MaterialPageRoute(
                // builder: (context) => EmailVerificationPage(
                //   isFromLogin: true,
                //   email: _emailController.text.trim(), user: null,
                // ),
                builder: (context) => EmailVerificationPage(
                  user: user, // ✅ صحيح
                  isFromLogin: true,
                  email: _emailController.text.trim(),
                  school: null, // From login, school already set
                ),
              ),
            );
          }
          return;
        }

        if (mounted) {
          setState(() => _isLoading = false);
          await UserRoleHelper.navigateBasedOnRole(context);
        }
      } else {
        if (_fullNameController.text.isEmpty ||
            _phoneController.text.isEmpty ||
            _passwordController.text.isEmpty ||
            _confirmPasswordController.text.isEmpty) {
          setState(() => _isLoading = false);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(loc['profile_error']!)),
            );
          }
          return;
        }

        if (_passwordController.text != _confirmPasswordController.text) {
          setState(() => _isLoading = false);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(loc['password_mismatch']!)),
            );
          }
          return;
        }

        if (_passwordController.text.length < 6) {
          setState(() => _isLoading = false);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(loc['weak_password']!)),
            );
          }
          return;
        }

        // Validate school selection for Buyers
        if (_selectedRole == 'Buyer' && (_selectedSchool == null || _selectedSchool!.isEmpty)) {
          setState(() => _isLoading = false);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(loc['select_school'] ?? 'Please select a school'),
                backgroundColor: Colors.red,
              ),
            );
          }
          return;
        }

        // Create user account - نفس المشروع القديم
        final userCredential = await _auth.createUserWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );

        final user = userCredential.user;
        if (user != null) {
          // نفس النظام: انتقل مباشرة لصفحة التحقق
          setState(() => _isLoading = false);
          if (mounted) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => EmailVerificationPage(
                  user: user,
                  isFromLogin: false,
                  email: _emailController.text.trim(),
                  fullName: _fullNameController.text.trim(),
                  phone: _phoneController.text.trim(),
                  role: _selectedRole,
                  school: _selectedSchool, // Pass selected school
                ),
              ),
            );
          }
        }
      }
    } on FirebaseAuthException catch (e) {
      setState(() => _isLoading = false);
      String errorMessage = loc['auth_error']!;

      if (e.code == 'email-already-in-use') {
        errorMessage = loc['email_already_in_use']!;
      } else if (e.code == 'invalid-email') {
        errorMessage = loc['invalid_email']!;
      } else if (e.code == 'weak-password') {
        errorMessage = loc['weak_password']!;
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage), backgroundColor: Colors.red),
        );
      }
    } catch (err) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(loc['auth_error']!), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);
    final langCode = languageProvider.currentLocale.languageCode;
    final loc = AuthScreen._localizations[langCode]!;

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
                      decoration: InputDecoration(
                        labelText: _selectedRole == 'Seller'
                            ? (loc['school_name_label'] ?? loc['full_name_label']!)
                            : loc['full_name_label']!,
                        hintText: _selectedRole == 'Seller'
                            ? (loc['school_name_hint'] ?? 'Enter school name')
                            : null,
                        prefixIcon: _selectedRole == 'Seller'
                            ? const Icon(Icons.school)
                            : const Icon(Icons.person),
                      ),
                    ),
                    if (_selectedRole == 'Seller') ...[
                      const SizedBox(height: 4),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12.0),
                        child: Text(
                          loc['school_name_info'] ?? 'This will be the school name that buyers can select',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    TextField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        labelText: loc['phone_label']!,
                        prefixIcon: const Icon(Icons.phone),
                      ),
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
                                _loadAvailableSchools(); // Reload schools when switching to Buyer
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
                                setState(() {
                                  _selectedRole = 'Seller';
                                  _selectedSchool = null; // Clear school selection when switching to Seller
                                });
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
                    // School selection for Buyers only
                    if (_selectedRole == 'Buyer') ...[
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: _selectedSchool,
                              decoration: InputDecoration(
                                labelText: loc['school_label']!,
                                prefixIcon: const Icon(Icons.school),
                                hintText: _availableSchools.isEmpty
                                    ? 'No schools available'
                                    : 'Select school',
                                suffixIcon: IconButton(
                                  icon: const Icon(Icons.refresh),
                                  onPressed: () {
                                    _loadAvailableSchools();
                                  },
                                  tooltip: 'Refresh schools list',
                                ),
                              ),
                              items: _availableSchools.isEmpty
                                  ? [
                                DropdownMenuItem<String>(
                                  value: null,
                                  enabled: false,
                                  child: Text(
                                    'No schools found. Tap refresh or register as Seller first.',
                                    style: TextStyle(color: Colors.grey[600]),
                                  ),
                                ),
                              ]
                                  : _availableSchools.map((school) {
                                return DropdownMenuItem<String>(
                                  value: school,
                                  child: Text(school),
                                );
                              }).toList(),
                              onChanged: _availableSchools.isEmpty
                                  ? null
                                  : (value) {
                                setState(() {
                                  _selectedSchool = value;
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                      if (_availableSchools.isEmpty) ...[
                        const SizedBox(height: 8),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'No schools available. A Seller (school) must register first.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.orange[700],
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Debug: Check console logs for seller search results.',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ] else ...[
                        const SizedBox(height: 4),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12.0),
                          child: Text(
                            'Found ${_availableSchools.length} school(s)',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.green[700],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ],
                  TextField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      labelText: loc['email_label']!,
                      prefixIcon: const Icon(Icons.email),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: loc['password_label']!,
                      prefixIcon: const Icon(Icons.lock),
                    ),
                  ),
                  if (!_isLoginMode) ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: _confirmPasswordController,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: loc['confirm_password_label']!,
                        prefixIcon: const Icon(Icons.lock_outline),
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  if (_isLoading)
                    const CircularProgressIndicator()
                  else
                    ElevatedButton(
                      onPressed: _isLoading ? null : _submitAuthForm,
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 50),
                        backgroundColor: Colors.deepOrange.shade400,
                      ),
                      child: Text(_isLoginMode ? loc['login_button']! : loc['signup_button']!,
                          style: const TextStyle(fontSize: 18, color: Colors.white)),
                    ),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _isLoginMode = !_isLoginMode;
                        if (_isLoginMode) {
                          _fullNameController.clear();
                          _phoneController.clear();
                          _confirmPasswordController.clear();
                        }
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

// هنا الكود المطابق للمشروع القديم بالضبط
class EmailVerificationPage extends StatefulWidget {
  final User user;
  final bool isFromLogin;
  final String email;
  final String? fullName;
  final String? phone;
  final String? role;
  final String? school; // Add school parameter

  const EmailVerificationPage({
    super.key,
    required this.user,
    required this.isFromLogin,
    required this.email,
    this.fullName,
    this.phone,
    this.role,
    this.school,
  });

  @override
  _EmailVerificationPageState createState() => _EmailVerificationPageState();
}

class _EmailVerificationPageState extends State<EmailVerificationPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  late Timer _timer;
  bool _emailSent = false;
  bool _isVerified = false;
  int _resendCooldown = 60;
  late Timer _cooldownTimer;
  bool _canResend = false;

  @override
  void initState() {
    super.initState();
    _setVerificationFlag();
    _sendVerificationEmail();
    _startEmailCheckTimer();
    _startResendCooldown();
  }

  Future<void> _setVerificationFlag() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('emailNotVerified', true);
    } catch (e) {
      // If SharedPreferences isn't available/registered for any reason,
      // don't crash the verification flow.
      debugPrint("SharedPreferences not available: $e");
    }
  }

  Future<void> _removeVerificationFlag() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('emailNotVerified');
    } catch (e) {
      debugPrint("SharedPreferences not available: $e");
    }
  }

  Future<void> _sendVerificationEmail() async {
    final user = _auth.currentUser; // نفس المشروع القديم
    if (user != null && !user.emailVerified) {
      try {
        await user.sendEmailVerification();

        if (!mounted) return;
        setState(() {
          _emailSent = true;
          _canResend = false;
          _resendCooldown = 60;
        });

        final langCode = Provider.of<LanguageProvider>(context, listen: false).currentLocale.languageCode;
        final loc = AuthScreen._localizations[langCode]!;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("${loc['verification_sent']!} ${user.email}")),
        );
        _startResendCooldown();
      } on FirebaseAuthException catch (e) {
        if (!mounted) return;
        final langCode = Provider.of<LanguageProvider>(context, listen: false).currentLocale.languageCode;
        final loc = AuthScreen._localizations[langCode]!;

        // Keep the UI-friendly message, but also show the exact Firebase error code for debugging.
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("${loc['verification_error']!} (${e.code})"),
            backgroundColor: Colors.red,
          ),
        );
      } catch (e) {
        if (!mounted) return;
        final langCode = Provider.of<LanguageProvider>(context, listen: false).currentLocale.languageCode;
        final loc = AuthScreen._localizations[langCode]!;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(loc['verification_error']!),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _startResendCooldown() {
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _resendCooldown--;
        if (_resendCooldown <= 0) {
          _canResend = true;
          _cooldownTimer.cancel();
        }
      });
    });
  }

  void _startEmailCheckTimer() {
    _timer = Timer.periodic(const Duration(seconds: 3), (timer) async {
      final user = _auth.currentUser; // نفس المشروع القديم
      await user?.reload();
      if (user != null && user.emailVerified) {
        _timer.cancel();
        _cooldownTimer.cancel();
        setState(() {
          _isVerified = true;
        });

        await _removeVerificationFlag();

        // Small delay to ensure UI updates
        await Future.delayed(const Duration(milliseconds: 500));

        if (!widget.isFromLogin) {
          print('✅ Email verified - Completing registration for new user...');
          if (mounted) {
            await _completeRegistration(user).timeout(
              const Duration(seconds: 30),
              onTimeout: () {
                print('⚠️ Registration completion timeout - forcing navigation');
                if (mounted) {
                  UserRoleHelper.navigateBasedOnRole(context);
                }
              },
            );
          }
        } else {
          print('✅ Email verified - User logged in, navigating to role-based screen...');
          if (mounted) {
            await UserRoleHelper.navigateBasedOnRole(context).timeout(
              const Duration(seconds: 15),
              onTimeout: () {
                print('⚠️ Navigation timeout - forcing navigation to BuyerHome');
                if (mounted) {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (context) => const BuyerHome()),
                        (route) => false,
                  );
                }
              },
            );
          }
        }
      }
    });
  }

  Future<void> _completeRegistration(User user) async {
    try {
      print('Starting registration completion for user: ${user.uid}');
      final _database = FirebaseDatabase.instance.ref();
      final _firestore = FirebaseFirestore.instance;

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

      final numericId = await _generateUniqueNumericId();
      print('Generated numeric ID: $numericId');

      // Save to Realtime Database
      final Map<String, dynamic> updates = {};
      final isSeller = widget.role == 'Seller';
      
      updates['/users/${user.uid}'] = {
        'name': widget.fullName?.trim() ?? '',
        'email': widget.email.trim(),
        'phone': widget.phone?.trim() ?? '',
        'school': widget.school ?? '',
        'role': widget.role ?? 'Buyer', // IMPORTANT: Save role to Realtime DB too
        'createdAt': ServerValue.timestamp,
        'points': 0,
        'numericId': numericId,
        'emailVerified': true,
        // DON'T set verificationStatus here - it should only be set AFTER image upload in SellerVerificationPage
        // If seller, verificationStatus will be null, which means they need to upload image first
      };
      updates['/numericId_to_uid/$numericId'] = user.uid;
      await _database.update(updates);
      print('Saved to Realtime Database');

      // Save to Firestore with role
      await _firestore.collection('users').doc(user.uid).set({
        'name': widget.fullName?.trim() ?? '',
        'email': widget.email.trim(),
        'phone': widget.phone?.trim() ?? '',
        'role': widget.role ?? 'Buyer',
        'createdAt': FieldValue.serverTimestamp(),
        'numericId': numericId,
        'emailVerified': true,
      }, SetOptions(merge: true));
      print('Saved to Firestore');

      // If this is a Seller, the school name (name field) will be available for buyers
      if (isSeller && widget.fullName != null && widget.fullName!.isNotEmpty) {
        print('New seller registered: ${widget.fullName}, this school will appear in buyers list');
      }

      if (mounted) {
        // If seller, redirect to SellerVerificationPage; otherwise, go to RegistrationSuccessScreen
        if (isSeller) {
          print('Seller registered - Navigating to SellerVerificationPage');
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const SellerVerificationPage()),
          );
        } else {
          print('Navigating to RegistrationSuccessScreen');
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const RegistrationSuccessScreen()),
          );
        }
      }
    } catch (error) {
      print('Error in _completeRegistration: $error');
      if (mounted) {
        // Try to navigate anyway
        try {
          await UserRoleHelper.navigateBasedOnRole(context);
        } catch (navError) {
          print('Navigation error: $navError');
          // Last resort: go to auth screen
          if (mounted) {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (context) => const AuthScreen()),
                  (route) => false,
            );
          }
        }
      }
    }
  }

  @override
  void dispose() {
    _timer.cancel();
    _cooldownTimer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);
    final langCode = languageProvider.currentLocale.languageCode;
    final loc = AuthScreen._localizations[langCode]!;

    return Scaffold(
      appBar: AppBar(
        title: Text(loc['verification_title']!),
        backgroundColor: Colors.deepOrange.shade400,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: _isVerified
            ? Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 20),
            Text(
              loc['redirecting']!,
              style: const TextStyle(fontSize: 18),
            ),
          ],
        )
            : Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.email_outlined, size: 100, color: Colors.blue),
            const SizedBox(height: 20),
            Text(
              loc['verification_message']!,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 30),
            ElevatedButton.icon(
              onPressed: _canResend ? _sendVerificationEmail : null,
              icon: const Icon(Icons.refresh),
              label: Text(_canResend
                  ? loc['resend_verification']!
                  : "${loc['resend_verification']!} $_resendCooldown sec"),
            ),
          ],
        ),
      ),
    );
  }
}

class RegistrationSuccessScreen extends StatefulWidget {
  const RegistrationSuccessScreen({super.key});

  @override
  State<RegistrationSuccessScreen> createState() => _RegistrationSuccessScreenState();
}

class _RegistrationSuccessScreenState extends State<RegistrationSuccessScreen> {
  @override
  @override
  void initState() {
    super.initState();
    // Navigate immediately after a short delay to ensure data is saved
    Future.delayed(const Duration(seconds: 2), () async {
      if (mounted) {
        print('🔄 RegistrationSuccessScreen: Starting navigation...');
        try {
          await UserRoleHelper.navigateBasedOnRole(context).timeout(
            const Duration(seconds: 15),
            onTimeout: () {
              print('⚠️ Navigation timeout - forcing navigation to BuyerHome');
              if (mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (context) => const BuyerHome()),
                      (route) => false,
                );
              }
            },
          );
        } catch (e) {
          print('❌ Error in RegistrationSuccessScreen navigation: $e');
          if (mounted) {
            // Try to navigate to BuyerHome as fallback
            try {
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (context) => const BuyerHome()),
                    (route) => false,
              );
            } catch (navError) {
              print('❌ Final navigation error: $navError');
              // Last resort: go to auth screen
              if (mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (context) => const AuthScreen()),
                      (route) => false,
                );
              }
            }
          }
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);
    final langCode = languageProvider.currentLocale.languageCode;
    final loc = AuthScreen._localizations[langCode]!;

    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle_outline, color: Colors.green, size: 100),
            const SizedBox(height: 30),
            Text(
              loc['success_title']!,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            const CircularProgressIndicator(),
            const SizedBox(height: 20),
            Text(
              loc['redirecting']!,
              style: const TextStyle(fontSize: 16, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}