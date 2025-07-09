// screens/home/saved.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';

class SavedPage extends StatelessWidget {
  const SavedPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    // Cek jika user belum login
    if (user == null) {
      return Scaffold(
        body: const Center(
          child: Text("Silakan login untuk melihat foto yang disimpan."),
        ),
      );
    }

    return Scaffold(
      body: StreamBuilder<QuerySnapshot>(
        // Mendengarkan koleksi foto yang dibeli oleh user saat ini
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('purchased_photos')
            .orderBy('purchasedAt', descending: true) // Urutkan dari yang terbaru
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Terjadi kesalahan: ${snapshot.error}'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text(
                'Anda belum memiliki foto yang disimpan.',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            );
          }

          final photos = snapshot.data!.docs;

          // Tampilkan foto dalam Grid
          return GridView.builder(
            padding: const EdgeInsets.all(8.0),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 8.0,
              mainAxisSpacing: 8.0,
            ),
            itemCount: photos.length,
            itemBuilder: (context, index) {
              final photoData = photos[index].data() as Map<String, dynamic>;
              final imageUrl = photoData['webContentLink'] ?? photoData['thumbnailLink'] ?? '';

              return ClipRRect(
                borderRadius: BorderRadius.circular(8.0),
                child: GridTile(
                  child: CachedNetworkImage(
                    imageUrl: imageUrl,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => const Center(
                      child: CircularProgressIndicator(),
                    ),
                    errorWidget: (context, url, error) => const Icon(Icons.error),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
