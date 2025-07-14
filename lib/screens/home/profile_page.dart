// screens/home/profile_page.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'profile_edit_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({Key? key}) : super(key: key);

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(body: Center(child: Text('Not logged in')));
    }
    return Scaffold(
      // appBar: AppBar(
      //   title: const Text('Profile'),
      //   backgroundColor: Colors.deepPurple,
      // ),
      body: FutureBuilder<DocumentSnapshot>(
        future:
            FirebaseFirestore.instance.collection('users').doc(user.uid).get(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final data = snapshot.data!.data() as Map<String, dynamic>;
          final username = data['username'] ?? user.displayName ?? '';
          final email = user.email ?? '';
          final photoUrl = data['photoUrl'] as String?;
          return Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Center(
                  child: CircleAvatar(
                    radius: 56,
                    backgroundColor: Colors.deepPurple,
                    backgroundImage:
                        (photoUrl != null && photoUrl.isNotEmpty)
                            ? NetworkImage(photoUrl)
                            : null,
                    child:
                        (photoUrl == null || photoUrl.isEmpty)
                            ? Text(
                              username.isNotEmpty
                                  ? username[0].toUpperCase()
                                  : '',
                              style: const TextStyle(
                                fontSize: 40,
                                color: Colors.white,
                              ),
                            )
                            : null,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  username,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 22,
                  ),
                ),
                const SizedBox(height: 8),
                Text(email, style: const TextStyle(fontSize: 16)),
                const SizedBox(height: 32),
                ElevatedButton.icon(
                  onPressed: () async {
                    final updated = await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const EditProfilePage(),
                      ),
                    );
                    if (updated == true) {
                      setState(() {});
                    }
                  },
                  icon: const Icon(Icons.edit),
                  label: const Text("Edit Profil"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color.fromARGB(255, 255, 255, 255),
                    minimumSize: const Size.fromHeight(40),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                // const SizedBox(height: 20),
                // ElevatedButton.icon(
                //   onPressed: () async {
                //     await FirebaseAuth.instance.signOut();
                //     if (!mounted) return;
                //     Navigator.of(context).popUntil((route) => route.isFirst);
                //   },
                //   icon: const Icon(Icons.logout),
                //   label: const Text("Logout"),
                //   style: ElevatedButton.styleFrom(
                //     backgroundColor: Colors.redAccent,
                //     minimumSize: const Size.fromHeight(40),
                //     shape: RoundedRectangleBorder(
                //         borderRadius: BorderRadius.circular(8)),
                //   ),
                // ),
              ],
            ),
          );
        },
      ),
    );
  }
}
