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
  final _idCtrl = TextEditingController();
  final _pwCtrl = TextEditingController();
  bool _pwVisible = false;
  bool _loading = false;
  bool _isPhotographer = false;
  int _loginAttempts = 0;
  String _lastAttemptedUsername = '';
  String? _lastAttemptedEmail; // <- Tambahkan ini

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

    // Reset counter jika username yang dicoba berbeda
    if (_lastAttemptedUsername != username) {
      setState(() {
        _loginAttempts = 0;
      });
    }
    _lastAttemptedUsername = username;

    setState(() => _loading = true);

    // --- Ambil email dulu, di luar try-catch utama ---
    final roleToFind = _isPhotographer ? 'photographer' : 'client';
    String? emailToUse;
    try {
      final q =
          await FirebaseFirestore.instance
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
      final data = q.docs.first.data();
      emailToUse = data['email'] as String;
      _lastAttemptedEmail = emailToUse;
    } catch (e) {
      _showError('User tidak ditemukan.');
      setState(() => _loading = false);
      return;
    }

    try {
      // Cek jika akun sudah terblokir
      if (_loginAttempts >= 3) {
        throw 'Akun ini terblokir karena terlalu banyak percobaan login. Silakan cek email Anda untuk mereset password.';
      }

      // Sign in with email & password
      final cred = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: emailToUse!,
        password: password,
      );

      // Jika berhasil, reset counter dan lanjutkan
      setState(() => _loginAttempts = 0);

      // Verifikasi role di Firestore jika perlu
      final snap =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(cred.user!.uid)
              .get();
      final actualRole = snap.data()?['role'] as String? ?? '';
      if (actualRole != roleToFind) {
        await FirebaseAuth.instance.signOut();
        throw 'Akun ini bukan ${roleToFind == 'photographer' ? 'Fotografer' : 'Klien'}';
      }

      // Berhasil → ke HomePage
      if (mounted) {
        Navigator.of(
          context,
        ).pushReplacement(MaterialPageRoute(builder: (_) => const HomePage()));
      }
    } on FirebaseAuthException catch (e) {
      if (e.code == 'wrong-password' || e.code == 'INVALID_LOGIN_CREDENTIALS') {
        setState(() {
          _loginAttempts++;
        });
        if (_loginAttempts >= 3) {
          _showError(
            'Akun ini terblokir karena 3x salah password. Silakan tekan "Lupa Password" untuk reset password, atau coba beberapa saat lagi.',
          );
        } else {
          _showError('Password salah. Sisa percobaan: ${3 - _loginAttempts}');
        }
      } else if (e.code == 'too-many-requests') {
        _showError(
          'Terlalu banyak percobaan login. Akun ini diblokir sementara oleh sistem. Silakan tekan "Lupa Password" untuk reset password, atau coba beberapa saat lagi.',
        );
      } else {
        _showError(e.message ?? 'Gagal login');
      }
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showError(String msg) {
    showDialog(
      context: context,
      builder:
          (_) => AlertDialog(
            title: const Text('Error'),
            content: Text(msg),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
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
                  labelText:
                      _isPhotographer
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
                  labelText:
                      _isPhotographer
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
                  onPressed:
                      () => setState(() => _isPhotographer = !_isPhotographer),
                  child: Text(
                    _isPhotographer ? 'Kamu Klien?' : 'Kamu Fotografer?',
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
                child:
                    _loading
                        ? const CircularProgressIndicator()
                        : const Text('Sign In'),
              ),

              const SizedBox(height: 8),
              // Sign Up link
              TextButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple.shade50,
                  foregroundColor: Colors.deepPurple,
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
                onPressed:
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const SignUpPage()),
                    ),
                child: const Text('Sign Up'),
              ),

              const SizedBox(height: 12),

              TextButton(
                onPressed: () async {
                  // Ambil username dan role dari input/field
                  final username = _idCtrl.text.trim();
                  final roleToFind =
                      _isPhotographer ? 'photographer' : 'client';

                  // Query Firestore untuk cari email
                  final q =
                      await FirebaseFirestore.instance
                          .collection('users')
                          .where('role', isEqualTo: roleToFind)
                          .where('username', isEqualTo: username)
                          .limit(1)
                          .get();

                  if (q.docs.isEmpty) {
                    _showError('Username tidak ditemukan.');
                    return;
                  }
                  final email = q.docs.first.data()['email'] as String?;

                  if (email != null) {
                    await FirebaseAuth.instance.sendPasswordResetEmail(
                      email: email,
                    );
                    _showError(
                      'Link reset password sudah dikirim ke email Anda.',
                    );
                  }
                },
                child: const Text('Lupa Password?'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
