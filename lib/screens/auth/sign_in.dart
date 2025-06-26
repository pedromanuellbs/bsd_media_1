// screens/auth/sign_in.dart
import 'package:flutter/material.dart';
import '../home/home.dart';
import 'sign_up.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BSD Media',
      theme: ThemeData(useMaterial3: true),
      home: const SignInPage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class SignInPage extends StatelessWidget {
  const SignInPage({Key? key}) : super(key: key);
  @override
  Widget build(BuildContext context) {
    final bool isSmall = MediaQuery.of(context).size.width < 600;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: isSmall
            ? Column(mainAxisSize: MainAxisSize.min, children: const [
                _Logo(),
                _FormContent(),
              ])
            : Container(
                padding: const EdgeInsets.all(32),
                constraints: const BoxConstraints(maxWidth: 800),
                child: Row(children: const [
                  Expanded(child: _Logo()),
                  Expanded(child: Center(child: _FormContent())),
                ]),
              ),
      ),
    );
  }
}

class _Logo extends StatelessWidget {
  const _Logo({Key? key}) : super(key: key);
  @override
  Widget build(BuildContext context) {
    final bool isSmall = MediaQuery.of(context).size.width < 600;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset(
          'assets/logo-bsd-media.png',
          width: isSmall ? 100 : 200,
        ),
      ],
    );
  }
}

class _FormContent extends StatefulWidget {
  const _FormContent({Key? key}) : super(key: key);
  @override
  State<_FormContent> createState() => _FormContentState();
}

class _FormContentState extends State<_FormContent> {
  bool _isPasswordVisible = false;
  bool _isFgPasswordVisible = false;     // new FG visibility flag
  bool _rememberMe = false;
  bool _isPhotographer = false;
  final _formKey = GlobalKey<FormState>();

  @override
  Widget build(BuildContext context) {
    return ContentBox(
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ─── Form Klien ──────────────────────────────────────────
            if (!_isPhotographer) ...[
              TextFormField(
                key: const ValueKey('std-username'),
                validator: (v) =>
                    v == null || v.isEmpty ? 'Please enter your username' : null,
                decoration: const InputDecoration(
                  labelText: 'Username',
                  hintText: 'Enter your username',
                  prefixIcon: Icon(Icons.person_outline),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                key: const ValueKey('std-password'),
                validator: (v) {
                  if (v == null || v.isEmpty) {
                    return 'Please enter your password';
                  }
                  if (v.length < 6) {
                    return 'Password must be at least 6 characters';
                  }
                  return null;
                },
                obscureText: !_isPasswordVisible,
                decoration: InputDecoration(
                  labelText: 'Password',
                  hintText: 'Enter your password',
                  prefixIcon: const Icon(Icons.lock_outline_rounded),
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(_isPasswordVisible
                        ? Icons.visibility_off
                        : Icons.visibility),
                    onPressed: () =>
                        setState(() => _isPasswordVisible = !_isPasswordVisible),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // ─── Form Photographer ────────────────────────────────────
            if (_isPhotographer) ...[
              TextFormField(
                key: const ValueKey('fg-username'),
                validator: (v) => v == null || v.isEmpty
                    ? 'Please enter your FG username'
                    : null,
                decoration: const InputDecoration(
                  labelText: 'Username FG',
                  hintText: 'Enter your FG username',
                  prefixIcon: Icon(Icons.person_outline),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              // FG Password with view toggle
              TextFormField(
                key: const ValueKey('fg-password'),
                validator: (v) => v == null || v.isEmpty
                    ? 'Please enter your FG password'
                    : null,
                obscureText: !_isFgPasswordVisible,
                decoration: InputDecoration(
                  labelText: 'Password FG',
                  hintText: 'Enter your FG password',
                  prefixIcon: const Icon(Icons.lock_outline_rounded),
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(_isFgPasswordVisible
                        ? Icons.visibility_off
                        : Icons.visibility),
                    onPressed: () => setState(
                        () => _isFgPasswordVisible = !_isFgPasswordVisible),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // ─── Remember me (selalu di bawah semua form) ─────────────
            CheckboxListTile(
              value: _rememberMe,
              onChanged: (v) => setState(() => _rememberMe = v ?? false),
              title: const Text('Remember me'),
              controlAffinity: ListTileControlAffinity.leading,
              dense: true,
              contentPadding: EdgeInsets.zero,
            ),

            // ─── Toggler link ────────────────────────────────────────
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () =>
                    setState(() => _isPhotographer = !_isPhotographer),
                child: Text(
                  _isPhotographer
                      ? 'Kamu Bukan Fotografer?'
                      : 'Kamu Fotografer?',
                  style: TextStyle(
                    decoration: TextDecoration.underline,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // ─── Sign Up & Sign In Buttons ───────────────────────────
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const SignUpPage())),
                style:
                    ElevatedButton.styleFrom(padding: const EdgeInsets.all(12)),
                child: const Text(
                  'Sign Up',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  if (_formKey.currentState?.validate() ?? false) {
                    Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => const HomePage()));
                  }
                },
                style:
                    ElevatedButton.styleFrom(padding: const EdgeInsets.all(12)),
                child: const Text(
                  'Sign In',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

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

void main() {
  runApp(const MyApp());
}
