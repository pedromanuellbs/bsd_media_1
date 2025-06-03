// sign_in.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../home/home.dart'; // import HomePage dari file terpisah

/// Entry point widget so tests and runApp work without errors.
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BSD Media',
      theme: ThemeData(useMaterial3: true),
      home: const SignInPage2(),
      debugShowCheckedModeBanner: false,
    );
  }
}

/// Sign-in page with responsive layout and Material 3 text styles.
class SignInPage2 extends StatelessWidget {
  const SignInPage2({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final bool isSmallScreen = MediaQuery.of(context).size.width < 600;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: isSmallScreen
            ? Column(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  _Logo(),
                  _FormContent(),
                ],
              )
            : Container(
                padding: const EdgeInsets.all(32.0),
                constraints: const BoxConstraints(maxWidth: 800),
                child: Row(
                  children: const [
                    Expanded(child: _Logo()),
                    Expanded(child: Center(child: _FormContent())),
                  ],
                ),
              ),
      ),
    );
  }
}

class _Logo extends StatelessWidget {
  const _Logo({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final bool isSmallScreen = MediaQuery.of(context).size.width < 600;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset(
          'assets/logo-bsd-media.png',
          width: isSmallScreen ? 100 : 200,
        ),
      ],
    );
  }
}

class _FormContent extends StatefulWidget {
  const _FormContent({Key? key}) : super(key: key);

  @override
  State<_FormContent> createState() => __FormContentState();
}

class __FormContentState extends State<_FormContent> {
  bool _isPasswordVisible = false;
  bool _rememberMe = false;
  bool _showSignUp = false;
  final _loginFormKey = GlobalKey<FormState>();
  final _signUpFormKey = GlobalKey<FormState>();

  // Controllers for sign-up fields (optional)
  final _usernameController = TextEditingController();
  final _emailController   = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController  = TextEditingController();

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
    return AnimatedCrossFade(
      firstChild: _buildLoginForm(context),
      secondChild: _buildSignUpForm(context),
      crossFadeState: _showSignUp
          ? CrossFadeState.showSecond
          : CrossFadeState.showFirst,
      duration: const Duration(milliseconds: 300),
      layoutBuilder:
          (topChild, topKey, bottomChild, bottomKey) => Stack(
        alignment: Alignment.center,
        children: [
          Positioned(key: bottomKey, child: bottomChild),
          Positioned(key: topKey, child: topChild),
        ],
      ),
    );
  }

  Widget _buildLoginForm(BuildContext context) {
    return ContentBox(
      child: Form(
        key: _loginFormKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Email field
            TextFormField(
              validator: (v) =>
                  v == null || v.isEmpty ? 'Please enter your email' : null,
              decoration: const InputDecoration(
                labelText: 'Email',
                hintText: 'Enter your email',
                prefixIcon: Icon(Icons.email_outlined),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            // Password field
            TextFormField(
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

            // Remember-me checkbox
            CheckboxListTile(
              value: _rememberMe,
              onChanged: (v) => setState(() => _rememberMe = v ?? false),
              title: const Text('Remember me'),
              controlAffinity: ListTileControlAffinity.leading,
              dense: true,
              contentPadding: EdgeInsets.zero,
            ),
            const SizedBox(height: 16),

            // Sign Up button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () =>
                    setState(() => _showSignUp = true), // switch to sign-up
                child: const Text('Sign Up'),
              ),
            ),
            const SizedBox(height: 8),

            // Sign in button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  if (_loginFormKey.currentState?.validate() ?? false) {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                          builder: (_) => const HomePage()),
                    );
                  }
                },
                child: const Padding(
                  padding: EdgeInsets.all(12),
                  child: Text('Sign In',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSignUpForm(BuildContext context) {
    return ContentBox(
      child: Form(
        key: _signUpFormKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Username
            TextFormField(
              controller: _usernameController,
              validator: (v) =>
                  v == null || v.isEmpty ? 'Please enter a username' : null,
              decoration: const InputDecoration(
                labelText: 'Username',
                prefixIcon: Icon(Icons.person_outline),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            // Email
            TextFormField(
              controller: _emailController,
              validator: (v) =>
                  v == null || v.isEmpty ? 'Please enter your email' : null,
              decoration: const InputDecoration(
                labelText: 'Email',
                prefixIcon: Icon(Icons.email_outlined),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            // Password
            TextFormField(
              controller: _passwordController,
              obscureText: true,
              validator: (v) =>
                  v == null || v.length < 6 ? 'Min 6 characters' : null,
              decoration: const InputDecoration(
                labelText: 'Password',
                prefixIcon: Icon(Icons.lock_outline_rounded),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            // Confirm Password
            TextFormField(
              controller: _confirmController,
              obscureText: true,
              validator: (v) => v != _passwordController.text
                  ? 'Passwords do not match'
                  : null,
              decoration: const InputDecoration(
                labelText: 'Confirm Password',
                prefixIcon: Icon(Icons.lock_outline_rounded),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            // Back to Sign In
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () =>
                    setState(() => _showSignUp = false), // back to login
                child: const Text('Back to Sign In'),
              ),
            ),
            const SizedBox(height: 8),

            // Register button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  if (_signUpFormKey.currentState?.validate() ?? false) {
                    // handle registration logic here...
                    setState(() => _showSignUp = false); // go back to login
                  }
                },
                child: const Padding(
                  padding: EdgeInsets.all(12),
                  child: Text('Register',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Box content wrapper with padding, radius, and subtle shadow.
class ContentBox extends StatelessWidget {
  final Widget child;
  const ContentBox({super.key, required this.child});

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
