// screens/auth/sign_in.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../home/home.dart';
import 'sign_up.dart';
import '../../face_ai/face_capture_page.dart';
import 'package:camera/camera.dart';

class SignInPage extends StatefulWidget {
  const SignInPage({Key? key}) : super(key: key);
  @override
  State<SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends State<SignInPage> {
  // Controller untuk masing-masing field
  final TextEditingController _usernameCtrl = TextEditingController();
  final TextEditingController _idMemberCtrl = TextEditingController();
  final TextEditingController _pwCtrl = TextEditingController();

  // Variabel state
  bool _pwVisible = false;
  bool _loading = false;
  bool _isPhotographer = false;

  final _attemptsRef = FirebaseFirestore.instance.collection('login_attempts');
  final _lockedAccountsRef = FirebaseFirestore.instance.collection(
    'locked_accounts',
  );

  int _remainingAttempts = 3;

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _idMemberCtrl.dispose();
    _pwCtrl.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (_loading) return;
    setState(() => _loading = true);

    final username = _usernameCtrl.text.trim();
    final password = _pwCtrl.text.trim();
    print('[DEBUG] Attempting login for: $username');

    try {
      // 1. Find user by username & role
      final userQuery =
          await FirebaseFirestore.instance
              .collection('users')
              .where('username', isEqualTo: username)
              .where(
                'role',
                isEqualTo: _isPhotographer ? 'photographer' : 'client',
              )
              .limit(1)
              .get();

      if (userQuery.docs.isEmpty) {
        print('[DEBUG] User not found or role mismatch');
        throw 'Username tidak ditemukan atau role tidak sesuai';
      }

      final userDoc = userQuery.docs.first;
      final email = userDoc['email'] as String;
      final role = userDoc['role'] as String;
      print('[DEBUG] Found user: $email | Role: $role');

      // 2. Check if locked
      final locked = await _lockedAccountsRef.doc(email).get();
      if (locked.exists) throw 'Akun terkunci. Silakan reset password.';

      // 3. Jika klien dan mengisi ID Member, validasi
      if (!_isPhotographer && _idMemberCtrl.text.trim().isNotEmpty) {
        final String inputCode = _idMemberCtrl.text.trim();
        final String? dbMemberCode =
            userDoc.data().containsKey('member_code')
                ? userDoc['member_code']
                : null;
        if (dbMemberCode != null && dbMemberCode != inputCode) {
          throw 'ID Member BSD MEDIA salah.';
        }
        if (dbMemberCode == null) {
          throw 'Akun ini bukan member BSD MEDIA.';
        }
      }

      // 4. Authenticate
      final cred = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      print('[DEBUG] Login success! UID: ${cred.user?.uid}');

      // 5. Ambil UID user login
      final user = FirebaseAuth.instance.currentUser;
      final uid = user?.uid;
      print('[DEBUG] Firebase UID user login: $uid');

      // 6. Ambil data user dari Firestore berdasarkan UID (opsional)
      final userDocByUid =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final facePhotoUrl = userDocByUid.data()?['facePhotoUrl'];
      print('[DEBUG] facePhotoUrl: $facePhotoUrl');

      // 7. Reset login attempts jika berhasil
      await _attemptsRef.doc(username).delete();

      // === Tambahan: Face Verification untuk klien ===
      if (!_isPhotographer) {
        // 1. Ambil kamera depan (non-nullable)
        final cameras = await availableCameras();
        final CameraDescription frontCamera = cameras.firstWhere(
          (cam) => cam.lensDirection == CameraLensDirection.front,
          orElse: () => cameras.first,
        );

        // 2. Pindah ke FaceCapturePage dan tunggu hasilnya
        final bool? faceVerified = await Navigator.push<bool>(
          context,
          MaterialPageRoute(
            builder:
                (_) => FaceCapturePage(
                  camera: frontCamera,
                  isClient: true,
                  username:
                      username, // Kirim username user yang login ke FaceCapturePage
                ),
          ),
        );

        if (faceVerified == true) {
          // Lanjut ke Home jika verifikasi wajah berhasil
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const HomePage()),
          );
        } else {
          // Jika gagal, tampilkan alert dan logout
          await FirebaseAuth.instance.signOut();
          _showError('Deteksi Wajah Tidak Sama, harap daftar!');
        }
        setState(() => _loading = false);
        return;
      }

      // === Fotografer langsung ke Home ===
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomePage()),
      );
    } on FirebaseAuthException catch (e) {
      print('[ERROR] Auth failed: ${e.code}');
      if (e.code == 'wrong-password') await _handleFailedAttempt(username);
      await _fetchRemainingAttempts(username);
      _showError(
        (e.message ?? 'Gagal login') +
            (_remainingAttempts < 3
                ? '\nPercobaan tersisa: $_remainingAttempts'
                : ''),
      );
    } catch (e) {
      print('[ERROR] $e');
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _fetchRemainingAttempts(String username) async {
    final doc = await _attemptsRef.doc(username).get();
    final count = doc.data()?['count'] ?? 0;
    setState(() {
      _remainingAttempts = 3 - (count as int);
      if (_remainingAttempts < 0) _remainingAttempts = 0;
    });
  }

  Future<void> _handleFailedAttempt(String username) async {
    print('[DEBUG] Handling failed attempt for: $username');
    await _attemptsRef.doc(username).set({
      'count': FieldValue.increment(1),
      'timestamp': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    final attempts =
        (await _attemptsRef.doc(username).get()).data()?['count'] ?? 1;
    if (attempts >= 3) {
      final user =
          await FirebaseFirestore.instance
              .collection('users')
              .where('username', isEqualTo: username)
              .limit(1)
              .get();
      if (user.docs.isNotEmpty) {
        await _lockedAccountsRef.doc(user.docs.first['email']).set({
          'lockedAt': FieldValue.serverTimestamp(),
        });
      }
    }
  }

  Future<void> _resetPassword() async {
    print('\n[AUTH] === PASSWORD RESET INITIATED ===');
    final username = _usernameCtrl.text.trim();
    print('[AUTH] Username for reset: $username');

    try {
      final roleToFind = _isPhotographer ? 'photographer' : 'client';
      print('[AUTH] Searching for $roleToFind: $username');

      final q =
          await FirebaseFirestore.instance
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

      print('[AUTH] Sending password reset email...');
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      print('[AUTH] Reset email sent to $email');

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

  void _showSuccess(String msg) {
    showDialog(
      context: context,
      builder:
          (_) => AlertDialog(
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
              // Username form (always shown)
              TextFormField(
                controller: _usernameCtrl,
                decoration: InputDecoration(
                  labelText:
                      _isPhotographer
                          ? 'Username Fotografer'
                          : 'Username Klien',
                  prefixIcon: const Icon(Icons.person_outline),
                ),
              ),
              const SizedBox(height: 12),

              // ID Member BSD MEDIA (only for client, optional)
              if (!_isPhotographer)
                Column(
                  children: [
                    TextFormField(
                      controller: _idMemberCtrl,
                      decoration: const InputDecoration(
                        labelText: 'ID Member BSD MEDIA (Opsional)',
                        prefixIcon: Icon(Icons.card_membership),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),

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

              // Info attempts jika gagal
              if (_remainingAttempts < 3)
                Text(
                  'Percobaan login tersisa: $_remainingAttempts',
                  style: const TextStyle(color: Colors.red, fontSize: 13),
                ),

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
