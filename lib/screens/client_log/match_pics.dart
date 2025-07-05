// screens/client_log/match_pics.dart
// Ganti seluruh file match_pics.dart dengan ini

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

class MatchPicsPage extends StatelessWidget {
  final List<String> matchedPhotoUrls;

  const MatchPicsPage({
    Key? key,
    required this.matchedPhotoUrls,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hasil Pencocokan'),
      ),
      body: matchedPhotoUrls.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  'Tidak ada foto yang cocok ditemukan untuk wajah Anda.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 18),
                ),
              ),
            )
          : GridView.builder(
              padding: const EdgeInsets.all(8.0),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2, // 2 kolom
                crossAxisSpacing: 8.0,
                mainAxisSpacing: 8.0,
              ),
              itemCount: matchedPhotoUrls.length,
              itemBuilder: (context, index) {
                final url = matchedPhotoUrls[index];
                return GridTile(
                  child: CachedNetworkImage(
                    imageUrl: url,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => const Center(
                      child: CircularProgressIndicator(),
                    ),
                    errorWidget: (context, url, error) => const Icon(Icons.error),
                  ),

                );
              },
            ),
    );
  }
}