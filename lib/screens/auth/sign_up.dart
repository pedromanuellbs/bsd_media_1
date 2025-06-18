// screens/auth/sign_up.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../home/home.dart';
import 'sign_in.dart';

import 'package:camera/camera.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'dart:convert';
import 'dart:io';
import 'package:bsd_media/face_ai/face_capture_page.dart';



class SignUpPage extends StatefulWidget {
  const SignUpPage({Key? key}) : super(key: key);

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final _signUpFormKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _emailController    = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController  = TextEditingController();

  // Visibility toggles
  bool _isPasswordVisible = false;
  bool _isConfirmVisible  = false;

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      // appBar: AppBar(
      //   title: const Text('Sign Up'),
      //   backgroundColor: Colors.black,
      // ),
      body: Center(
        child: ContentBox(
          child: Form(
            key: _signUpFormKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Username field
                TextFormField(
                  controller: _usernameController,
                  validator: (v) => v == null || v.isEmpty
                      ? 'Please enter a username'
                      : null,
                  decoration: const InputDecoration(
                    labelText: 'Username',
                    prefixIcon: Icon(Icons.person_outline),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),

                // Email field
                TextFormField(
                  controller: _emailController,
                  validator: (v) => v == null || v.isEmpty
                      ? 'Please enter your email'
                      : null,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(Icons.email_outlined),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),

                // Password field with visibility toggle
                TextFormField(
                  controller: _passwordController,
                  obscureText: !_isPasswordVisible,
                  validator: (v) => v == null || v.length < 6
                      ? 'Min 6 characters'
                      : null,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    prefixIcon: const Icon(Icons.lock_outline_rounded),
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(_isPasswordVisible
                          ? Icons.visibility_off
                          : Icons.visibility),
                      onPressed: () => setState(
                          () => _isPasswordVisible = !_isPasswordVisible),
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                // Confirm Password field with visibility toggle
                TextFormField(
                  controller: _confirmController,
                  obscureText: !_isConfirmVisible,
                  validator: (v) => v != _passwordController.text
                      ? 'Passwords do not match'
                      : null,
                  decoration: InputDecoration(
                    labelText: 'Confirm Password',
                    prefixIcon: const Icon(Icons.lock_outline_rounded),
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(_isConfirmVisible
                          ? Icons.visibility_off
                          : Icons.visibility),
                      onPressed: () => setState(
                          () => _isConfirmVisible = !_isConfirmVisible),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Face Recognition button (placeholder)
                SizedBox(
  width: double.infinity,
  child: ElevatedButton(
    onPressed: () async {
      try {
        final cameras = await availableCameras();
        final camera = cameras.first;

        final result = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => FaceCapturePage(camera: camera),
          ),
        );

        if (result != null) {
          final filePath = result as String;

          final request = http.MultipartRequest(
            'POST',
           Uri.parse('http://192.168.100.13:5000/recognize')
          );
          request.files.add(await http.MultipartFile.fromPath('face', filePath));

          final response = await request.send();
          final respStr = await response.stream.bytesToString();
          final jsonResponse = json.decode(respStr);

          if (jsonResponse['results'].isNotEmpty) {
            final user = jsonResponse['results'][0]['user'];
            final confidence = jsonResponse['results'][0]['confidence'];

            showDialog(
              context: context,
              builder: (_) => AlertDialog(
                title: const Text('Wajah Dikenali'),
                content: Text('User: $user\nConfidence: ${confidence.toStringAsFixed(2)}'),
                actions: [
                  TextButton(
                    child: const Text('OK'),
                    onPressed: () => Navigator.pop(context),
                  )
                ],
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Tidak ada wajah terdeteksi.')),
            );
          }
        }
      } catch (e) {
        print('❌ Error Face Recognition: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Terjadi kesalahan saat face recognition')),
        );
      }
    },
    style: ElevatedButton.styleFrom(
      padding: const EdgeInsets.all(12),
    ),
    child: const Text(
      'Face Recognition',
      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
    ),
  ),
),

                const SizedBox(height: 8),

                // Register button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      if (_signUpFormKey.currentState?.validate() ?? false) {
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute(
                            builder: (_) => const HomePage(),
                          ),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.all(12),
                    ),
                    child: const Text(
                      'Register',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                // Back to Login button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(
                            builder: (_) => const SignInPage()),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.all(12),
                    ),
                    child: const Text(
                      'Back to Login',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Reuse your existing ContentBox widget from sign_in.dart
class ContentBox extends StatelessWidget {
  final Widget child;
  const ContentBox({Key? key, required this.child}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
            blurRadius: 10,
            offset: Offset(0, 4),
            spreadRadius: 1,
            color: Colors.black12,
          ),
        ],
      ),
      child: child,
    );
  }
}
