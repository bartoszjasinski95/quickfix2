import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart';
import 'dart:io' show Platform; // DODANE

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    } else if (Platform.isAndroid) {
      return android;
    } else if (Platform.isIOS) {
      return ios;
    }
    throw UnsupportedError('Unsupported platform');
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyDpfPi1iSU5n5hXme9PhGcjT0r95jXXazQ',
    appId: '1:773535626217:web:c5c8173a89ac4c26061178',
    messagingSenderId: '773535626217',
    projectId: 'quickfix-bournemouth',
    authDomain: 'quickfix-bournemouth.firebaseapp.com',
    storageBucket: 'quickfix-bournemouth.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDpfPi1iSU5n5hXme9PhGcjT0r95jXXazQ',
    appId: '1:773535626217:android:YOUR_ANDROID_APP_ID',
    messagingSenderId: '773535626217',
    projectId: 'quickfix-bournemouth',
    storageBucket: 'quickfix-bournemouth.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyDpfPi1iSU5n5xHme9PhGcjT0r95jXXazQ',
    appId: '1:773535626217:ios:YOUR_IOS_APP_ID',
    messagingSenderId: '773535626217',
    projectId: 'quickfix-bournemouth',
    storageBucket: 'quickfix-bournemouth.firebasestorage.app',
    iosBundleId: 'com.example.quickfix2',
  );
}