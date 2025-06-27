// firebase_options.dart

import 'package:firebase_core/firebase_core.dart'
    show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform, kIsWeb;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      default:
        throw UnsupportedError('This platform is not supported');
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyD-0C4SRIR60ZxC-9Hl6z2IhfInT-yWj_Q',
    appId: '1:869680622559:android:cc94134dd493081685726a',
    messagingSenderId: '869680622559',
    projectId: 'db-ta-bsd-media',
    storageBucket: 'db-ta-bsd-media.firebasestorage.app',
  );

  static const FirebaseOptions web = FirebaseOptions(
  apiKey: "AIzaSyCblWOO-uIq3WsfB-BqUHD8YRSPBHZB-xg",
  authDomain: "db-ta-bsd-media.firebaseapp.com",
  projectId: "db-ta-bsd-media",
  storageBucket: "db-ta-bsd-media.firebasestorage.app",
  messagingSenderId: "869680622559",
  appId: "1:869680622559:web:00a2a1b70f46c57185726a",
  measurementId: "G-6HX5VE24NQ"
);


}