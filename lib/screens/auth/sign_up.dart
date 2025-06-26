// screens/auth/sign_up.dart

import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../home/home.dart';
import 'sign_in.dart';
import 'package:bsd_media/face_ai/face_capture_page.dart';

/// Roles for sign up
enum _SignUpMode { selection, client, photographer }

class SignUpPage extends StatefulWidget {
  const SignUpPage({Key? key}) : super(key: key);

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  _SignUpMode _mode = _SignUpMode.selection;
  bool _agreedEula = false;

  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _emailController    = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController  = TextEditingController();

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
      body: Center(
        child: ContentBox(
          child: _mode == _SignUpMode.selection
              ? _buildModeSelection()
              : _mode == _SignUpMode.client
                  ? _buildClientForm()
                  : _buildPhotographerForm(),
        ),
      ),
    );
  }

  Widget _buildModeSelection() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('Kamu adalah?',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: () => setState(() {
            _mode = _SignUpMode.client;
            _agreedEula = false;
          }),
          child: const Text('Klien'),
          style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
        ),
        const SizedBox(height: 8),
        ElevatedButton(
          onPressed: () => setState(() {
            _mode = _SignUpMode.photographer;
          }),
          child: const Text('Fotografer'),
          style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
        ),
      ],
    );
  }

  Widget _buildClientForm() {
    return Stack(
      children: [
        Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Username
                TextFormField(
                  controller: _usernameController,
                  decoration: const InputDecoration(labelText: 'Username'),
                  validator: (v) =>
                      v == null || v.isEmpty ? 'Please enter a username' : null,
                ),
                const SizedBox(height: 8),
                // Email
                TextFormField(
                  controller: _emailController,
                  decoration: const InputDecoration(labelText: 'Email'),
                  validator: (v) =>
                      v == null || v.isEmpty ? 'Please enter your email' : null,
                ),
                const SizedBox(height: 8),
                // Password
                TextFormField(
                  controller: _passwordController,
                  obscureText: !_isPasswordVisible,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    suffixIcon: IconButton(
                      icon: Icon(_isPasswordVisible
                          ? Icons.visibility_off
                          : Icons.visibility),
                      onPressed: () =>
                          setState(() => _isPasswordVisible = !_isPasswordVisible),
                    ),
                  ),
                  validator: (v) =>
                      v == null || v.length < 6 ? 'Min 6 characters' : null,
                ),
                const SizedBox(height: 8),
                // Confirm
                TextFormField(
                  controller: _confirmController,
                  obscureText: !_isConfirmVisible,
                  decoration: InputDecoration(
                    labelText: 'Confirm Password',
                    suffixIcon: IconButton(
                      icon: Icon(_isConfirmVisible
                          ? Icons.visibility_off
                          : Icons.visibility),
                      onPressed: () =>
                          setState(() => _isConfirmVisible = !_isConfirmVisible),
                    ),
                  ),
                  validator: (v) =>
                      v != _passwordController.text ? 'Passwords do not match' : null,
                ),
                const SizedBox(height: 16),

                // Face recognition (optional)
                ElevatedButton(
                  onPressed: () async {
                    final cameras = await availableCameras();
                    final camera = cameras.first;
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => FaceCapturePage(camera: camera)),
                    );
                  },
                  child: const Text('Face Recognition'),
                  style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                ),
                const SizedBox(height: 8),

                // Register (Client)
                ElevatedButton(
                  onPressed: () async {
                    if (!(_formKey.currentState?.validate() ?? false) ||
                        !_agreedEula) return;
                    try {
                      final cred = await FirebaseAuth.instance
                          .createUserWithEmailAndPassword(
                              email: _emailController.text.trim(),
                              password: _passwordController.text.trim());
                      await FirebaseFirestore.instance
                          .collection('users')
                          .doc(cred.user!.uid)
                          .set({
                        'username': _usernameController.text.trim(),
                        'email': _emailController.text.trim(),
                        'role': 'client',
                        'createdAt': FieldValue.serverTimestamp(),
                      });
                      if (mounted) {
                        Navigator.pushReplacement(context,
                            MaterialPageRoute(builder: (_) => const HomePage()));
                      }
                    } on FirebaseAuthException catch (e) {
                      showDialog(
                        context: context,
                        builder: (_) => AlertDialog(
                          title: const Text('Registrasi Gagal'),
                          content: Text('${e.code}: ${e.message}'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('OK'),
                            )
                          ],
                        ),
                      );
                    } catch (e) {
                      showDialog(
                        context: context,
                        builder: (_) => AlertDialog(
                          title: const Text('Error'),
                          content: Text(e.toString()),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('OK'),
                            )
                          ],
                        ),
                      );
                    }
                  },
                  child: const Text('Register Client'),
                  style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => setState(() => _mode = _SignUpMode.selection),
                  child: const Text('Back'),
                ),
              ],
            ),
          ),
        ),

        // EULA overlay only on client
        if (!_agreedEula)
          Positioned.fill(
            child: Container(
              color: Colors.black54,
              alignment: Alignment.center,
              child: SizedBox(
                width: 300,
                height: 400,
                child: ContentBox(
                  child: Column(
                    children: [
                      const Text(
                        'PERJANJIAN PRIVASI DATA – BSD MEDIA',
                        style:
                            TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      const Expanded(
                        child: SingleChildScrollView(
                          child: Text(
                            '… EULA text here …',
                            style: TextStyle(fontSize: 14),
                          ),
                        ),
                      ),
                      CheckboxListTile(
                        value: _agreedEula,
                        onChanged: (v) =>
                            setState(() => _agreedEula = v ?? false),
                        title: const Text('Saya menyetujui EULA'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildPhotographerForm() {
    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Username FG
            TextFormField(
              controller: _usernameController,
              decoration: const InputDecoration(labelText: 'Username FG'),
              validator: (v) =>
                  v == null || v.isEmpty ? 'Please enter a username' : null,
            ),
            const SizedBox(height: 8),
            // Email FG
            TextFormField(
              controller: _emailController,
              decoration: const InputDecoration(labelText: 'Email FG'),
              validator: (v) =>
                  v == null || v.isEmpty ? 'Please enter your email' : null,
            ),
            const SizedBox(height: 8),
            // Password FG
            TextFormField(
              controller: _passwordController,
              obscureText: !_isPasswordVisible,
              decoration: InputDecoration(
                labelText: 'Password FG',
                suffixIcon: IconButton(
                  icon: Icon(_isPasswordVisible
                      ? Icons.visibility_off
                      : Icons.visibility),
                  onPressed: () => setState(
                      () => _isPasswordVisible = !_isPasswordVisible),
                ),
              ),
              validator: (v) =>
                  v == null || v.length < 6 ? 'Min 6 characters' : null,
            ),
            const SizedBox(height: 8),
            // Confirm FG
            TextFormField(
              controller: _confirmController,
              obscureText: !_isConfirmVisible,
              decoration: InputDecoration(
                labelText: 'Confirm Password FG',
                suffixIcon: IconButton(
                  icon: Icon(_isConfirmVisible
                      ? Icons.visibility_off
                      : Icons.visibility),
                  onPressed: () => setState(
                      () => _isConfirmVisible = !_isConfirmVisible),
                ),
              ),
              validator: (v) =>
                  v != _passwordController.text ? 'Passwords do not match' : null,
            ),
            const SizedBox(height: 16),

            // QRIS upload button placeholder
            ElevatedButton(
              onPressed: () {
                // TODO: upload QRIS logic here
              },
              child: const Text('Upload QRIS'),
              style:
                  ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
            ),
            const SizedBox(height: 8),

            // Register (Fotografer)
            ElevatedButton(
              onPressed: () async {
                if (!(_formKey.currentState?.validate() ?? false)) return;
                try {
                  final cred = await FirebaseAuth.instance
                      .createUserWithEmailAndPassword(
                          email: _emailController.text.trim(),
                          password: _passwordController.text.trim());
                  await FirebaseFirestore.instance
                      .collection('users')
                      .doc(cred.user!.uid)
                      .set({
                    'username': _usernameController.text.trim(),
                    'email': _emailController.text.trim(),
                    'role': 'photographer',
                    'createdAt': FieldValue.serverTimestamp(),
                  });
                  if (mounted) {
                    Navigator.pushReplacement(context,
                        MaterialPageRoute(builder: (_) => const HomePage()));
                  }
                } on FirebaseAuthException catch (e) {
                  showDialog(
                    context: context,
                    builder: (_) => AlertDialog(
                      title: const Text('Registrasi Gagal'),
                      content: Text('${e.code}: ${e.message}'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('OK'),
                        )
                      ],
                    ),
                  );
                } catch (e) {
                  showDialog(
                    context: context,
                    builder: (_) => AlertDialog(
                      title: const Text('Error'),
                      content: Text(e.toString()),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('OK'),
                        )
                      ],
                    ),
                  );
                }
              },
              child: const Text('Register Fotografer'),
              style:
                  ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => setState(() => _mode = _SignUpMode.selection),
              child: const Text('Back'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Reusable container for forms
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
