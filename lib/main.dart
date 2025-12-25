import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:smart_bites/language_provider.dart';
import 'package:smart_bites/theme_provider.dart';
import 'firebase_options.dart';
import 'package:smart_bites/splash_screen.dart'; // استدعاء شاشة السبلاش

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => LanguageProvider()),
        ChangeNotifierProvider(create: (context) => ThemeProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);
    final themeProvider = Provider.of<ThemeProvider>(context);

    return MaterialApp(
      title: 'Smart Bites',
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
      // --- تم إرجاع شاشة السبلاش كنقطة بداية ---
      home: const SplashScreen(),
    );
  }
}
