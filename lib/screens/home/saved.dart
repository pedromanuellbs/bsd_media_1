// screens/home/saved.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';

class SavedPage extends StatefulWidget {
  const SavedPage({Key? key}) : super(key: key);

  @override
  _SavedPageState createState() => _SavedPageState();
}

class _SavedPageState extends State<SavedPage> {
  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    // Jika belum login
    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Saved')),
        body: const Center(
          child: Text("Silakan login untuk melihat foto yang disimpan."),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Saved')),
      body: StreamBuilder<QuerySnapshot>(
        // Koleksi foto yang dibeli user
        stream:
            FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .collection('purchased_photos')
                .orderBy('purchasedAt', descending: true)
                .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Terjadi kesalahan: ${snapshot.error}'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data!.docs;
          if (docs.isEmpty) {
            return const Center(
              child: Text(
                'Anda belum memiliki foto yang disimpan.',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            );
          }

          return GridView.builder(
            padding: const EdgeInsets.all(8.0),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 8.0,
              mainAxisSpacing: 8.0,
            ),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              final imageUrl =
                  data['webContentLink'] ?? data['thumbnailLink'] ?? '';

              return ClipRRect(
                borderRadius: BorderRadius.circular(8.0),
                child: CachedNetworkImage(
                  imageUrl: imageUrl,
                  fit: BoxFit.cover,
                  placeholder:
                      (c, u) =>
                          const Center(child: CircularProgressIndicator()),
                  errorWidget: (c, u, e) => const Icon(Icons.error),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
