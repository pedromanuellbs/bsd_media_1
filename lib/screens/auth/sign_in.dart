// screens/auth/sign_in.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../home/home.dart';
import 'sign_up.dart';

class SignInPage extends StatefulWidget {
  const SignInPage({Key? key}) : super(key: key);

  @override
  State<SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends State<SignInPage> {
  final _emailCtrl = TextEditingController();
  final _pwCtrl = TextEditingController();
  bool _pwVisible = false;
  bool _loading = false;
  bool _isPhotographer = false; // <-- Tambah state

  @override
  void dispose() {
    _emailCtrl.dispose();
    _pwCtrl.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (_emailCtrl.text.isEmpty || _pwCtrl.text.isEmpty) return;
    setState(() => _loading = true);

    try {
      final cred = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailCtrl.text.trim(),
        password: _pwCtrl.text.trim(),
      );

      // Jika photographer, bisa tambah pengecekan role di Firestore jika dibutuhkan
      // Tapi sesuai permintaan sekarang, cukup sign in saja.

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const HomePage()),
        );
      }
    } on FirebaseAuthException catch (e) {
      _showError(e.message ?? 'Gagal login');
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showError(String msg) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Error'),
        content: Text(msg),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 32),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Username (Klien/Fotografer)
              TextFormField(
                controller: _emailCtrl,
                decoration: InputDecoration(
                  labelText: _isPhotographer ? 'Username Fotografer' : 'Username Klien',
                  prefixIcon: const Icon(Icons.email_outlined),
                ),
              ),
              const SizedBox(height: 12),

              // Password (Klien/Fotografer)
              TextFormField(
                controller: _pwCtrl,
                obscureText: !_pwVisible,
                decoration: InputDecoration(
                  labelText: _isPhotographer ? 'Password Fotografer' : 'Password Klien',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _pwVisible ? Icons.visibility_off : Icons.visibility,
                    ),
                    onPressed: () => setState(() => _pwVisible = !_pwVisible),
                  ),
                ),
              ),
              const SizedBox(height: 8),

              // Toggle link: di atas tombol Sign In
              if (!_isPhotographer) // Kalau belum photographer
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: () => setState(() => _isPhotographer = true),
                    child: const Text(
                      'Kamu Fotografer?',
                      style: TextStyle(
                        color: Colors.deepPurple,
                        fontSize: 14,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(0, 0),
                    ),
                  ),
                ),

              // Toggle link: Kembali ke klien
              if (_isPhotographer) // Jika sudah photographer, ganti link
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: () => setState(() => _isPhotographer = false),
                    child: const Text(
                      'Kamu Bukan Fotografer?',
                      style: TextStyle(
                        color: Colors.deepPurple,
                        fontSize: 14,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(0, 0),
                    ),
                  ),
                ),

              const SizedBox(height: 8),

              // Tombol Sign In
              ElevatedButton(
                onPressed: _loading ? null : _signIn,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple.shade50,
                  foregroundColor: Colors.deepPurple,
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  textStyle: const TextStyle(fontSize: 16),
                ),
                child: _loading
                    ? const CircularProgressIndicator()
                    : const Text('Sign In'),
              ),
              const SizedBox(height: 12),

              // Tombol Sign Up (untuk daftar user baru)
              TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SignUpPage()),
                ),
                child: const Text('Sign Up'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}