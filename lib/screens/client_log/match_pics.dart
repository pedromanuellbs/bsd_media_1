// screens/client_log/match_pics.dart
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

class MatchPicsPage extends StatelessWidget {
  // Ambil List of Map dari hasil parsing JSON response backend!
  final List<Map<String, dynamic>> matchedPhotos;

  const MatchPicsPage({
    Key? key,
    required this.matchedPhotos,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hasil Pencocokan'),
      ),
      body: matchedPhotos.isEmpty
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
                crossAxisCount: 2,
                crossAxisSpacing: 8.0,
                mainAxisSpacing: 8.0,
              ),
              itemCount: matchedPhotos.length,
              itemBuilder: (context, index) {
                final photo = matchedPhotos[index];
                final thumbUrl = photo['thumbnailLink'] ?? photo['webViewLink'] ?? '';
                return GestureDetector(
                  onTap: () {
                    // Bisa preview photo lebih besar, atau buka link
                    if (photo['webViewLink'] != null) {
                      // Implementasi open link jika mau
                    }
                  },
                  child: GridTile(
                    child: CachedNetworkImage(
                      imageUrl: thumbUrl,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => const Center(
                        child: CircularProgressIndicator(),
                      ),
                      errorWidget: (context, url, error) => const Icon(Icons.error),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
