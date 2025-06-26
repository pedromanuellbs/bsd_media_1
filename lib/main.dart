// main.dart

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';    // file yang kita buat di lib/firebase_options.dart
import 'load_screen.dart';         // sesuaikan path jika berbeda

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Inisialisasi core Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  /// Agar child widget bisa akses state ini
  static _MyAppState? of(BuildContext context) =>
      context.findAncestorStateOfType<_MyAppState>();

  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  ThemeMode _themeMode = ThemeMode.light;

  /// 2. (Langkah nomor 2) — setelah init Firebase,
  ///    Anda bisa langsung menggunakan FirebaseAuth dan Firestore
  ///
  /// Contoh: mengecek apakah user sudah login
  /// di LoadScreen nanti, Anda bisa ambil:
  /// final user = FirebaseAuth.instance.currentUser;

  void toggleTheme(bool isDark) {
    setState(() {
      _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BSD Media',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.light(),
      darkTheme: ThemeData.dark(),
      themeMode: _themeMode,
      home: const LoadScreen(),  // Tentukan widget pertama setelah Firebase ready
    );
  }
}
