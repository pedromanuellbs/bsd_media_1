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
  
  final _attemptsRef = FirebaseFirestore.instance.collection('login_attempts');
  final _lockedAccountsRef = FirebaseFirestore.instance.collection('locked_accounts');

  Future<void> _signIn() async {
    final username = _idCtrl.text.trim();
    final password = _pwCtrl.text.trim();
    print('[DEBUG] Attempting login for: $username');

    try {
      // 1. Find user by username
      final userQuery = await FirebaseFirestore.instance
          .collection('users')
          .where('username', isEqualTo: username)
          .limit(1)
          .get();

      if (userQuery.docs.isEmpty) {
        print('[DEBUG] User not found');
        throw 'Username tidak ditemukan';
      }

      final userDoc = userQuery.docs.first;
      final email = userDoc['email'] as String;
      final role = userDoc['role'] as String;
      print('[DEBUG] Found user: $email | Role: $role');

      // 2. Verify role
      if ((_isPhotographer && role != 'photographer') || 
          (!_isPhotographer && role != 'client')) {
        throw 'Akun ini bukan ${_isPhotographer ? 'Fotografer' : 'Klien'}';
      }

      // 3. Check if locked
      final locked = await _lockedAccountsRef.doc(email).get();
      if (locked.exists) throw 'Akun terkunci. Silakan reset password.';

      // 4. Authenticate
      final cred = await FirebaseAuth.instance
          .signInWithEmailAndPassword(email: email, password: password);
      print('[DEBUG] Login success! UID: ${cred.user?.uid}');

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomePage()),
      );

    } on FirebaseAuthException catch (e) {
      print('[ERROR] Auth failed: ${e.code}');
      if (e.code == 'wrong-password') await _handleFailedAttempt(username);
      _showError(e.message ?? 'Gagal login');
    } catch (e) {
      print('[ERROR] $e');
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _handleFailedAttempt(String username) async {
    print('[DEBUG] Handling failed attempt for: $username');
    await _attemptsRef.doc(username).set({
      'count': FieldValue.increment(1),
      'timestamp': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    final attempts = (await _attemptsRef.doc(username).get()).data()?['count'] ?? 1;
    if (attempts >= 3) {
      final user = await FirebaseFirestore.instance
          .collection('users')
          .where('username', isEqualTo: username)
          .limit(1)
          .get();
      await _lockedAccountsRef.doc(user.docs.first['email']).set({
        'lockedAt': FieldValue.serverTimestamp(),
      });
    }
  }

  Future<void> _resetPassword() async {
    print('\n[AUTH] === PASSWORD RESET INITIATED ===');
    final username = _idCtrl.text.trim();
    print('[AUTH] Username for reset: $username');

    try {
      // 1. Find user
      final roleToFind = _isPhotographer ? 'photographer' : 'client';
      print('[AUTH] Searching for $roleToFind: $username');

      final q = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: roleToFind)
          .where('username', isEqualTo: username)
          .limit(1)
          .get();

      if (q.docs.isEmpty) {
        print('[AUTH] User not found for password reset');
        throw 'Username tidak ditemukan';
      }

      final email = q.docs.first.data()['email'] as String;
      print('[AUTH] Found email for reset: $email');

      // 2. Send reset email
      print('[AUTH] Sending password reset email...');
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      print('[AUTH] Reset email sent to $email');

      // 3. Unlock account
      print('[AUTH] Unlocking account and clearing attempts...');
      await Future.wait([
        _lockedAccountsRef.doc(email).delete(),
        _attemptsRef.doc(username).delete(),
      ]);
      print('[AUTH] Account unlocked and attempts reset');

      _showSuccess('Link reset telah dikirim. Akun telah dibuka kembali.');
    } catch (e) {
      print('[AUTH ERROR] Password reset failed: $e');
      _showError(e.toString());
    }
    print('[AUTH] Password reset flow completed\n');
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
          ),
        ],
      ),
    );
  }

  void _showSuccess(String msg) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Sukses'),
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
                  labelText: _isPhotographer ? 'Username Fotografer' : 'Username Klien',
                  prefixIcon: const Icon(Icons.person_outline),
                ),
              ),
              const SizedBox(height: 12),

              // Password field
              TextFormField(
                controller: _pwCtrl,
                obscureText: !_pwVisible,
                decoration: InputDecoration(
                  labelText: _isPhotographer ? 'Password Fotografer' : 'Password Klien',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(_pwVisible ? Icons.visibility_off : Icons.visibility),
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
                child: _loading
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
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SignUpPage()),
                ),
                child: const Text('Sign Up'),
              ),

              const SizedBox(height: 12),

              TextButton(
                onPressed: _resetPassword,
                child: const Text('Lupa Password?'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}