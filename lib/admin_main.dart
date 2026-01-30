import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:smart_bites/language_provider.dart';
import 'package:smart_bites/theme_provider.dart';
import 'package:smart_bites/admin_dashboard.dart';
import 'package:smart_bites/admin_login_screen.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // App Check:
  // - Debug builds: allow requests using the Debug provider (shows debug token in logs).
  // - Release builds: use Play Integrity (requires enabling App Check in Firebase Console).
  await FirebaseAppCheck.instance.activate(
    androidProvider: kReleaseMode ? AndroidProvider.playIntegrity : AndroidProvider.debug,
  );

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => LanguageProvider()),
        ChangeNotifierProvider(create: (context) => ThemeProvider()),
      ],
      child: const AdminApp(),
    ),
  );
}

class AdminApp extends StatelessWidget {
  const AdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);
    final themeProvider = Provider.of<ThemeProvider>(context);

    return MaterialApp(
      title: 'Smart Bites Admin',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.deepOrange,
        fontFamily: 'Cairo',
        brightness: Brightness.light,
        scaffoldBackgroundColor: Colors.orange.shade50,
        cardColor: Colors.white,
      ),
      darkTheme: ThemeData(
        primarySwatch: Colors.deepOrange,
        fontFamily: 'Cairo',
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Colors.grey.shade900,
        cardColor: Colors.grey.shade800,
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.deepOrange.shade700,
          foregroundColor: Colors.white,
        ),
      ),
      themeMode: themeProvider.themeMode,
      locale: languageProvider.currentLocale,
      home: const AdminLoginScreen(),
    );
  }
}

