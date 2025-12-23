// File generated based on your google-services.json
// ignore_for_file: type=lint
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        throw UnsupportedError(
          'DefaultFirebaseOptions not configured for macOS.',
        );
      case TargetPlatform.windows:
        throw UnsupportedError(
          'DefaultFirebaseOptions not configured for Windows.',
        );
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions not configured for Linux.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  /// ---- WEB (EMPTY – fill if needed) ----
  static const FirebaseOptions web = FirebaseOptions(
    apiKey: '',
    appId: '',
    messagingSenderId: '',
    projectId: 'smart-bites-2',
    databaseURL: 'https://smart-bites-2-default-rtdb.firebaseio.com/',
    storageBucket: 'smart-bites-2.firebasestorage.app',
  );

  /// ---- ANDROID (FROM google-services.json) ----
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDDLkI57bJ-AOzKh9PBExTpgAbU8IE9pvU',
    appId: '1:1013932323860:android:3bf535f0ead01d1d99a301',
    messagingSenderId: '1013932323860',
    projectId: 'smart-bites-2',
    storageBucket: 'smart-bites-2.firebasestorage.app',
  );

  /// ---- iOS (EMPTY – fill if needed) ----
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: '',
    appId: '',
    messagingSenderId: '',
    projectId: 'smart-bites-2',
    databaseURL: 'https://smart-bites-2-default-rtdb.firebaseio.com/',
    storageBucket: 'smart-bites-2.firebasestorage.app',
    iosBundleId:'',
  );
}