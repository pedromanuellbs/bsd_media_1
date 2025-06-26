// firebase_options.dart

import 'package:firebase_core/firebase_core.dart'
    show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform, kIsWeb;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    // 1) Tangani Web lebih dulu
    if (kIsWeb) {
      return web;
    }

    // 2) Lalu platform lain
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      // jangan sertakan TargetPlatform.web di sini
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

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyD-0C4SRIR60ZxC-9Hl6z2IhfInT-yWj_Q',
    appId: '1:869680622559:ios:YOUR_IOS_APP_ID',
    messagingSenderId: '869680622559',
    projectId: 'db-ta-bsd-media',
    storageBucket: 'db-ta-bsd-media.firebasestorage.app',
    // Jika Anda tidak target iOS, field ini boleh dilewati atau diisi placeholder:
    iosClientId: 'YOUR_IOS_CLIENT_ID',    // Optional
    iosBundleId: 'com.bsdmedia.dbmedia',   // Sesuai Info.plist
  );

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyD-0C4SRIR60ZxC-9Hl6z2IhfInT-yWj_Q',
    authDomain: 'db-ta-bsd-media.firebaseapp.com',
    projectId: 'db-ta-bsd-media',
    storageBucket: 'db-ta-bsd-media.firebasestorage.app',
    messagingSenderId: '869680622559',
    appId: '1:869680622559:web:YOUR_WEB_APP_ID',
    measurementId: 'G-MEASUREMENT_ID',     // Optional
  );
}
