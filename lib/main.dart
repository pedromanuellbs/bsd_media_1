// main.dart
import 'package:flutter/material.dart';
import 'load_screen.dart';  // sesuaikan jika LoadScreen berada di folder lain

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  /// Agar child widget (SettingsPage2) bisa akses state ini
  static _MyAppState? of(BuildContext context) =>
  context.findAncestorStateOfType<_MyAppState>();


  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  ThemeMode _themeMode = ThemeMode.light;

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
      home: const LoadScreen(),
    );
  }
}
