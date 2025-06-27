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
  final _idCtrl    = TextEditingController(); // Username Klien / Username Fotografer
  final _pwCtrl    = TextEditingController();
  bool _pwVisible  = false;
  bool _loading    = false;
  bool _isPhotographer = false;

  @override
  void dispose() {
    _idCtrl.dispose();
    _pwCtrl.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    final username = _idCtrl.text.trim();
    final password = _pwCtrl.text.trim();
    if (username.isEmpty || password.isEmpty) return;

    setState(() => _loading = true);
    try {
      // 1) Tentukan koleksi & role yang dicari
      final roleToFind = _isPhotographer ? 'photographer' : 'client';

      // 2) Query Firestore by username & role
      final q = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: roleToFind)
          .where('username', isEqualTo: username)
          .limit(1)
          .get();

      if (q.docs.isEmpty) {
        throw _isPhotographer
            ? 'Username Fotografer tidak ditemukan'
            : 'Username Klien tidak ditemukan';
      }

      // 3) Ambil email dari dokumen
      final data    = q.docs.first.data();
      final emailToUse = data['email'] as String;

      // 4) Sign in with email & password
      final cred = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: emailToUse,
        password: password,
      );

      // 5) Verifikasi role di Firestore jika perlu
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .doc(cred.user!.uid)
          .get();
      final actualRole = snap.data()?['role'] as String? ?? '';
      if (actualRole != roleToFind) {
        await FirebaseAuth.instance.signOut();
        throw 'Akun ini bukan ${roleToFind == 'photographer' ? 'Fotografer' : 'Klien'}';
      }

      // 6) Berhasil → ke HomePage
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
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          )
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
              // Username field
              TextFormField(
                controller: _idCtrl,
                decoration: InputDecoration(
                  labelText: _isPhotographer
                      ? 'Username Fotografer'
                      : 'Username Klien',
                  prefixIcon: const Icon(Icons.person_outline),
                ),
              ),
              const SizedBox(height: 12),

              // Password field
              TextFormField(
                controller: _pwCtrl,
                obscureText: !_pwVisible,
                decoration: InputDecoration(
                  labelText: _isPhotographer
                      ? 'Password Fotografer'
                      : 'Password Klien',
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

              // Toggle link (Klien <-> Fotografer)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: () => setState(() => _isPhotographer = !_isPhotographer),
                  child: Text(
                    _isPhotographer
                        ? 'Kamu Klien?'
                        : 'Kamu Fotografer?',
                    style: const TextStyle(
                      color: Colors.deepPurple,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                  style: TextButton.styleFrom(padding: EdgeInsets.zero),
                ),
              ),

              const SizedBox(height: 8),

              // Sign In button
              ElevatedButton(
                onPressed: _loading ? null : _signIn,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple.shade50,
                  foregroundColor: Colors.deepPurple,
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
                child: _loading
                    ? const CircularProgressIndicator()
                    : const Text('Sign In'),
              ),

              const SizedBox(height: 12),

              // Sign Up link
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
