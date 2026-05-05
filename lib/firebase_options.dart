import 'package:flutter/foundation.dart' show kIsWeb, TargetPlatform, defaultTargetPlatform;
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;

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
      default:
        throw UnsupportedError('Platform not supported');
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyC-jZ7dqgbb28y6uK-RnyHYk9PdD9Ta5D0',
    appId: '1:338888794484:web:a8b4900e45844ffeff0c21',
    messagingSenderId: '338888794484',
    projectId: 'uprise-5eac8',
    authDomain: 'uprise-5eac8.firebaseapp.com',
    storageBucket: 'uprise-5eac8.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyC-jZ7dqgbb28y6uK-RnyHYk9PdD9Ta5D0',
    appId: '1:338888794484:android:YOUR_ANDROID_APP_ID', // You'll need to add Android app in Firebase
    messagingSenderId: '338888794484',
    projectId: 'uprise-5eac8',
    storageBucket: 'uprise-5eac8.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyC-jZ7dqgbb28y6uK-RnyHYk9PdD9Ta5D0',
    appId: '1:338888794484:ios:YOUR_IOS_APP_ID', // You'll need to add iOS app in Firebase
    messagingSenderId: '338888794484',
    projectId: 'uprise-5eac8',
    storageBucket: 'uprise-5eac8.firebasestorage.app',
    iosBundleId: 'com.example.uprise',
  );
}