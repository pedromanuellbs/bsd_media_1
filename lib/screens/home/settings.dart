// screens/home/settings.dart
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:bsd_media/main.dart' as root_app;
import 'package:bsd_media/screens/auth/sign_in.dart';
import 'package:line_awesome_flutter/line_awesome_flutter.dart';

class SettingsPage2 extends StatelessWidget {
  const SettingsPage2({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          children: [
            // Section: General
            const _SectionTitle('General'),
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

            const SizedBox(height: 16),
            const Divider(),
            const _SectionTitle('Organization'),
            const _CustomListTile(
              title: 'People',
              icon: Icons.contacts_outlined,
            ),
            _CustomListTile(
              title: 'Cara Kerja',
              icon: LineAwesomeIcons.user_cog_solid,
              onTap: () {},
            ),

            const SizedBox(height: 16),
            const Divider(),
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

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle(this.title, {super.key});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: 8, top: 8, bottom: 8),
    child: Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: Colors.black54,
      ),
    ),
  );
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
      minLeadingWidth: 32, // Biar icon selalu rata kiri
      leading: Icon(icon, size: 26),
      title: Text(title),
      trailing: trailing,
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
    );
  }
}
