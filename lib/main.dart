import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:bsd_media/firebase_options.dart';
import 'package:flutter_prevent_screenshot/disablescreenshot.dart'; // Add this
import 'load_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
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

class _MyAppState extends State<MyApp> {
  ThemeMode _themeMode = ThemeMode.light;
  final _flutterPreventScreenshot = FlutterPreventScreenshot.instance; // Controller

  void toggleTheme(bool isDark) {
    setState(() {
      _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
    });
  }

  @override
  void initState() {
    super.initState();
    _enableScreenshotProtection(); // Enable protection when app starts
  }

  Future<void> _enableScreenshotProtection() async {
    try {
      await _flutterPreventScreenshot.screenshotOff(); // Block screenshots
      print("Screenshot protection enabled");
    } catch (e) {
      print("Failed to enable screenshot protection: $e");
    }
  }

  @override
  void dispose() {
    // Optionally re-enable screenshots when app closes
    // _flutterPreventScreenshot.screenshotOn(); 
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
      home: const LoadScreen(), // Your existing screen
    );
  }
}