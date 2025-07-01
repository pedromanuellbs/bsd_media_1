// screens/collage_page.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class CollagePage extends StatelessWidget {
  final String folderUrl;
  const CollagePage({Key? key, required this.folderUrl}) : super(key: key);

  // API key (sama seperti di history_fg.dart)
  static const _apiKey = 'AIzaSyC_vPd6yPwYQ60Pn-tuR3Nly_7mgXZcxGk';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Collage Photos')),
      body: FutureBuilder<List<String>>(
        future: _fetchImageUrls(folderUrl),
        builder: (ctx, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('Error: ${snap.error}'));
          }
          final urls = snap.data!;
          if (urls.isEmpty) {
            return const Center(child: Text('Folder kosong'));
          }
          return GridView.builder(
            padding: const EdgeInsets.all(8),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: urls.length,
            itemBuilder: (_, i) => ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                urls[i],
                fit: BoxFit.cover,
                loadingBuilder: (ctx, child, progress) {
                  if (progress == null) return child;
                  return const Center(child: CircularProgressIndicator());
                },
                errorBuilder: (ctx, _, __) {
                  return Container(
                    color: Colors.grey[200],
                    child: const Icon(Icons.broken_image, color: Colors.grey),
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }

  Future<List<String>> _fetchImageUrls(String folderUrl) async {
    // 1) Ekstrak folderId dari berbagai format link Drive
    final match = RegExp(r'/d/([^/]+)').firstMatch(folderUrl)
               ?? RegExp(r'[?&]id=([^&]+)').firstMatch(folderUrl)
               ?? RegExp(r'/folders/([^/?]+)').firstMatch(folderUrl);
    final folderId = match?.group(1);
    if (folderId == null) throw 'Link Drive tidak valid';

    // 2) Panggil Drive API untuk dapat id + thumbnailLink
    final uri = Uri.https(
      'www.googleapis.com',
      '/drive/v3/files',
      {
        'q': "'$folderId' in parents and mimeType contains 'image/'",
        'fields': 'files(id,thumbnailLink)',
        'key': _apiKey,
        'pageSize': '100',
        'orderBy': 'createdTime desc',
      },
    );
    debugPrint('⏳ Fetching Drive files: $uri');
    final resp = await http.get(uri);
    debugPrint('🔔 Drive responded (${resp.statusCode}): ${resp.body}');
    if (resp.statusCode != 200) {
      throw 'Drive API error ${resp.statusCode}';
    }

    final data = json.decode(resp.body) as Map<String, dynamic>;
    final files = (data['files'] as List).cast<Map<String, dynamic>>();

    // 3) Keluarkan semua thumbnailLink yang support CORS
    return files
      .map((f) => f['thumbnailLink'] as String)
      .toList();
  }
}
