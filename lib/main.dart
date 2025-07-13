// main.dart
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:bsd_media/firebase_options.dart';
// import 'package:flutter_prevent_screenshot/disablescreenshot.dart';
import 'load_screen.dart';

// <-- 1. TAMBAHKAN IMPORT UNTUK APP CHECK
import 'package:firebase_app_check/firebase_app_check.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // <-- 2. TAMBAHKAN BLOK INISIALISASI APP CHECK DI SINI
  await FirebaseAppCheck.instance.activate(
    // Gunakan 'debug' untuk pengujian di emulator atau perangkat fisik saat mode debug.
    androidProvider: AndroidProvider.debug,
    // Untuk rilis ke Play Store, ganti dengan:
    // androidProvider: AndroidProvider.playIntegrity,
  );

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  static _MyAppState? of(BuildContext context) =>
      context.findAncestorStateOfType<_MyAppState>();

  @override
  _MyAppState createState() => _MyAppState();
}

// Tidak ada perubahan dari sini ke bawah
class _MyAppState extends State<MyApp> {
  ThemeMode _themeMode = ThemeMode.light;
  // final _flutterPreventScreenshot = FlutterPreventScreenshot.instance;

  void toggleTheme(bool isDark) {
    setState(() {
      _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
    });
  }

  @override
  void initState() {
    super.initState();
    // _enableScreenshotProtection();
  }

  // Future<void> _enableScreenshotProtection() async {
  //   try {
  //     await _flutterPreventScreenshot.screenshotOff();
  //     print("Screenshot protection enabled");
  //   } catch (e) {
  //     print("Failed to enable screenshot protection: $e");
  //   }
  // }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BSD Media',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.light(),
      darkTheme: ThemeData.dark(),
      themeMode: _themeMode,
      home: const LoadScreen(),
    );
  }
}
