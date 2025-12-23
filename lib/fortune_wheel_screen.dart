import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_fortune_wheel/flutter_fortune_wheel.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:provider/provider.dart';
import 'package:smart_bites/language_provider.dart';

class FortuneWheelScreen extends StatefulWidget {
  const FortuneWheelScreen({super.key});

  @override
  State<FortuneWheelScreen> createState() => _FortuneWheelScreenState();
}

class _FortuneWheelScreenState extends State<FortuneWheelScreen> {
  final StreamController<int> _selected = StreamController<int>();
  final _auth = FirebaseAuth.instance;
  final _database = FirebaseDatabase.instance.ref();
  int _userPoints = 0;
  String _userName = '';
  int? _userNumericId;


  static const int SPIN_COST = 5;


  static final Map<String, Map<String, String>> _localizations = {
    'ar': {
      'title': 'عجلة الحظ',
      'spin_button': 'لف العجلة ($SPIN_COST نقاط)',
      'not_enough_points': 'نقاطك غير كافية!',
      'congrats': 'مبروك!',
      'won': 'لقد فزت بـ',
      'better_luck': 'حظ أفضل المرة القادمة!',
      'ok': 'حسنًا',
      'confirm_spin_title': 'تأكيد',
      'confirm_spin_content': 'سيتم خصم $SPIN_COST نقاط من رصيدك. هل أنت متأكد؟',
      'yes': 'نعم',
      'no': 'لا',
      'screenshot_prompt': 'خذ لقطة شاشة لهذه الرسالة واذهب لاستلام جائزتك من الكانتين!',
    },
    'en': {
      'title': 'Fortune Wheel',
      'spin_button': 'Spin the Wheel ($SPIN_COST Points)',
      'not_enough_points': 'Not enough points!',
      'congrats': 'Congratulations!',
      'won': 'You won',
      'better_luck': 'Better luck next time!',
      'ok': 'OK',
      'confirm_spin_title': 'Confirm',
      'confirm_spin_content': '$SPIN_COST points will be deducted from your balance. Are you sure?',
      'yes': 'Yes',
      'no': 'No',
      'screenshot_prompt': 'Take a screenshot of this message and go collect your prize from the canteen!',
    }
  };

  final Map<String, Map<String, dynamic>> _prizes = {
    'try_again': {'ar': 'حاول مرة أخرى', 'en': 'Try Again', 'color': Colors.grey.shade400},
    'chips': {'ar': 'كيس شيبسي', 'en': 'Chips', 'color': Colors.blue.shade400},
    'fries': {'ar': 'باكت بطاطس', 'en': 'Fries', 'color': Colors.red.shade400},
    'discount': {'ar': 'خصم 10%', 'en': '10% Discount', 'color': Colors.green.shade400},
    'strips_sandwich': {'ar': 'ساندوتش استربس', 'en': 'Strips Sandwich', 'color': Colors.amber.shade600},
  };

  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }

  void _fetchUserData() {
    final user = _auth.currentUser;
    if (user != null) {
      _database.child('users/${user.uid}').onValue.listen((event) {
        if (mounted && event.snapshot.exists) {
          final data = event.snapshot.value as Map<dynamic, dynamic>;
          setState(() {
            _userPoints = (data['points'] as num?)?.toInt() ?? 0;
            _userName = data['name'] ?? '';
            _userNumericId = (data['numericId'] as num?)?.toInt();
          });
        }
      });
    }
  }

  // --- ✅ تعديل: دمج الخطوط المخصصة في الديالوج ---
  TextStyle _getTextStyle(String langCode, {FontWeight? weight, double? size, Color? color}) {
    return TextStyle(
      fontFamily: langCode == 'ar' ? 'Cairo' : 'Poppins',
      fontWeight: weight ?? (langCode == 'ar' ? FontWeight.w700 : FontWeight.normal),
      fontSize: size,
      color: color,
    );
  }

  Future<void> _showConfirmationDialog(String langCode) async {
    final loc = _localizations[langCode]!;
    // --- ✅ تعديل: التحقق من 5 نقاط ---
    if (_userPoints < SPIN_COST) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(loc['not_enough_points']!, style: _getTextStyle(langCode)), backgroundColor: Colors.red),
      );
      return;
    }
    
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(loc['confirm_spin_title']!, style: _getTextStyle(langCode, size: 20)),
          content: Text(loc['confirm_spin_content']!, style: _getTextStyle(langCode)),
          actions: <Widget>[
            TextButton(
              child: Text(loc['no']!, style: _getTextStyle(langCode)),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: Text(loc['yes']!, style: _getTextStyle(langCode)),
              onPressed: () {
                Navigator.of(context).pop();
                _handleSpin(langCode);
              },
            ),
          ],
        );
      },
    );
  }

  void _handleSpin(String langCode) async {
    final loc = _localizations[langCode]!;
    final user = _auth.currentUser;
    if (user == null) return;

 
    await _database.child('users/${user.uid}/points').set(ServerValue.increment(-SPIN_COST));
    

    final spinCountRef = _database.child('users/${user.uid}/spinCount');
    final transactionResult = await spinCountRef.runTransaction((currentData) {
      int count = (currentData as int?) ?? 0;
      return Transaction.success(count + 1);
    });
    final newSpinCount = transactionResult.snapshot.value as int;
    
    int resultIndex;
    String prizeKey;

    if (newSpinCount % 30 == 0) {
      prizeKey = 'strips_sandwich';
    } else if (newSpinCount % 15 == 0) {
      prizeKey = 'discount';
    } else {
      final random = Random().nextDouble() * 100;
      if (random < 60) {
        prizeKey = 'try_again';
      } else if (random < 85) {
        prizeKey = 'chips';
      } else {
        prizeKey = 'fries';
      }
    }
    
    resultIndex = _prizes.keys.toList().indexOf(prizeKey);
    _selected.add(resultIndex);

    Future.delayed(const Duration(seconds: 5), () {
      _recordWinInFirebase(prizeKey, langCode);
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(prizeKey == 'try_again' ? loc['better_luck']! : loc['congrats']!, style: _getTextStyle(langCode, size: 20)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                prizeKey == 'try_again' ? '' : '${loc['won']} ${_prizes[prizeKey]![langCode]}',
                style: _getTextStyle(langCode),
              ),
              if (prizeKey != 'try_again') ...[
                const SizedBox(height: 15),
                Text(
                  loc['screenshot_prompt']!,
                  style: _getTextStyle(langCode, size: 12, color: Colors.grey, weight: FontWeight.normal),
                  textAlign: TextAlign.center,
                ),
              ]
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(loc['ok']!, style: _getTextStyle(langCode)),
            ),
          ],
        ),
      );
    });
  }

  void _recordWinInFirebase(String prizeKey, String langCode) {
    if (prizeKey == 'try_again' || _auth.currentUser == null) return;

    final winRef = _database.child('fortune_wheel_wins').push();
    winRef.set({
      'userId': _auth.currentUser!.uid,
      'userNumericId': _userNumericId,
      'userName': _userName,
      'prize': _prizes[prizeKey]![langCode],
      'timestamp': ServerValue.timestamp,
    });
  }

  @override
  void dispose() {
    _selected.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);
    final langCode = languageProvider.currentLocale.languageCode;
    final loc = _localizations[langCode]!;

    final items = _prizes.entries.map((entry) {
      return FortuneItem(
        // --- ✅ تعديل: تطبيق الخطوط المخصصة على نصوص العجلة ---
        child: Text(
          entry.value[langCode]!,
          style: _getTextStyle(langCode, color: Colors.white, size: 16),
        ),
        style: FortuneItemStyle(
          color: entry.value['color'] as Color,
          borderColor: Colors.white,
          borderWidth: 2,
        ),
      );
    }).toList();

    return Scaffold(
      appBar: AppBar(
        // --- ✅ تعديل: تطبيق الخطوط المخصصة على عنوان الصفحة ---
        title: Text(loc['title']!, style: _getTextStyle(langCode)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.black, // لجعل لون سهم الرجوع أسود
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.orange.shade100, Colors.blue.shade100],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Expanded(
                child: FortuneWheel(
                  selected: _selected.stream,
                  animateFirst: false,
                  items: items,
                  styleStrategy: const UniformStyleStrategy(),
                  indicators: const <FortuneIndicator>[
                    FortuneIndicator(
                      alignment: Alignment.topCenter,
                      child: TriangleIndicator(color: Colors.black54),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),
              ElevatedButton(
                onPressed: () => _showConfirmationDialog(langCode),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepOrange,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  elevation: 5,
                ),

                child: Text(
                  loc['spin_button']!,
                  style: _getTextStyle(langCode, size: 18, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}