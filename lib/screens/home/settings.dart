// screens/home/settings.dart

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

// Alias import main.dart supaya toggleTheme dikenali
import 'package:bsd_media/main.dart' as root_app;
// Import halaman SignIn untuk tombol Sign out
import 'package:bsd_media/screens/auth/sign_in.dart';
// Import Line Awesome Flutter icon set
import 'package:line_awesome_flutter/line_awesome_flutter.dart';

class SettingsPage2 extends StatelessWidget {
  const SettingsPage2({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const leftPadding = 72.0; // Sejajar dengan judul AppBar

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(
            left: leftPadding,
            right: 16,
            top: 16,
            bottom: 16,
          ),
          children: [
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text(
                'General',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            _CustomListTile(
              title: 'Dark Mode',
              icon: Icons.dark_mode_outlined,
              trailing: Switch(
                value: isDark,
                onChanged: (v) => root_app.MyApp.of(context)?.toggleTheme(v),
              ),
            ),
            const _CustomListTile(
              title: 'Notifications',
              icon: Icons.notifications_none_rounded,
            ),
            const _CustomListTile(
              title: 'Security Status',
              icon: CupertinoIcons.lock_shield,
            ),

            const Divider(height: 32),
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text(
                'Organization',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            const _CustomListTile(
              title: 'People',
              icon: Icons.contacts_outlined,
            ),

            // Tile “Cara Kerja” pakai icon user-cog dari Line Awesome
            _CustomListTile(
              title: 'Cara Kerja',
              icon: LineAwesomeIcons.user_cog_solid,
              onTap: () {},
            ),

            const Divider(height: 32),
            _CustomListTile(
              title: 'Bahasa',
              icon: LineAwesomeIcons.language_solid,
              onTap: () {
                showDialog(
                  context: context,
                  builder: (BuildContext context) {
                    return AlertDialog(
                      title: const Text('Pilih Bahasa'),
                      content: const Text('Fitur ini belum tersedia.'),
                      actions: <Widget>[
                        TextButton(
                          child: const Text('OK'),
                          onPressed: () {
                            Navigator.of(context).pop();
                          },
                        ),
                      ],
                    );
                  },
                );
              },
            ),
            const _CustomListTile(
              title: 'Bantuan',
              icon: Icons.help_outline_rounded,
            ),
            _CustomListTile(
              title: 'Tentang Aplikasi Ini',
              icon: Icons.info_outline_rounded,
              onTap: () {
                showDialog(
                  context: context,
                  builder: (BuildContext context) {
                    return AlertDialog(
                      title: const Text('Tentang Aplikasi Ini'),
                      content: const Text(
                        'Aplikasi ini dibuat untuk memenuhi Tugas Akhir tentang Penerapan Face Recognition untuk memenuhi Data Privacy Fotografer. Aplikasi ini masih dalam tahap pengembangan, diharapkan kedepannya bisa berkembang dengan sempurna.',
                      ),
                      actions: <Widget>[
                        TextButton(
                          child: const Text('OK'),
                          onPressed: () {
                            // This closes the dialog
                            Navigator.of(context).pop();
                          },
                        ),
                      ],
                    );
                  },
                );
              },
            ),
            _CustomListTile(
              title: 'Sign out',
              icon: Icons.exit_to_app_rounded,
              onTap: () {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const SignInPage()),
                  (route) => false,
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _CustomListTile extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _CustomListTile({
    Key? key,
    required this.title,
    required this.icon,
    this.trailing,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon),
      title: Text(title),
      trailing: trailing,
      onTap: onTap,
    );
  }
}
