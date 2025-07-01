// screens/fg_log/history_fg.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

class HistoryFGPage extends StatelessWidget {
  const HistoryFGPage({Key? key}) : super(key: key);

  // Ganti dengan API key Drive-mu & pastikan folder-mu share→“Anyone with link”→Viewer
  static const _apiKey = 'AIzaSyC_vPd6yPwYQ60Pn-tuR3Nly_7mgXZcxGk';

  /// Ekstrak ID dari share link (file atau folder)
  String? _extractDriveId(String link) {
    final m1 = RegExp(r'/d/([^/]+)').firstMatch(link);
    if (m1 != null) return m1.group(1);
    final m2 = RegExp(r'/folders/([^/]+)').firstMatch(link);
    if (m2 != null) return m2.group(1);
    return null;
  }

  /// Tarik thumbnail pertama di folder
  Future<String?> _fetchThumbnail(String driveLink) async {
  try {
    final folderId = _extractDriveId(driveLink);
    if (folderId == null) return null;

    final uri = Uri.https(
      'www.googleapis.com',
      '/drive/v3/files',
      {
        'q': "'$folderId' in parents and mimeType contains 'image/'",
        'orderBy': 'createdTime desc',
        'pageSize': '1',

        // ← tambahan corpus agar API key bisa akses item publik:
        'corpora'                 : 'allDrives',
        'supportsAllDrives'       : 'true',
        'includeItemsFromAllDrives': 'true',

        'fields': 'files(thumbnailLink)',
        'key'   : _apiKey,
      },
    );

    final resp = await http.get(uri);
    if (resp.statusCode != 200) {
      debugPrint('Thumbnail fetch gagal: ${resp.statusCode}');
      return null;
    }
    final data = json.decode(resp.body) as Map<String, dynamic>;
    final files = data['files'] as List<dynamic>? ?? [];
    if (files.isEmpty) return null;
    return (files.first as Map<String, dynamic>)['thumbnailLink'] as String?;
  } catch (e) {
    debugPrint('Thumbnail exception: $e');
    return null;
  }
}


  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text('History Sesi Foto'),
        backgroundColor: Colors.deepPurple,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('photo_sessions')
            .where('photographerId', isEqualTo: uid)
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (ctx, snap) {
          if (snap.hasError) {
            return Center(child: Text('Error: ${snap.error}'));
          }
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snap.data!.docs;
          if (docs.isEmpty) {
            return const Center(child: Text('Belum ada sesi foto'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: docs.length,
            itemBuilder: (ctx, i) {
              final data     = docs[i].data()! as Map<String, dynamic>;
              final title    = data['title']      as String? ?? '';
              final location = data['location']   as String? ?? '';
              final date     = data['date']       as String? ?? '';
              final link     = data['driveLink']  as String? ?? '';
              final ts       = data['createdAt']  as Timestamp?;
              final when = ts != null
                  ? DateFormat.yMMMd().add_jm().format(ts.toDate())
                  : '';

              return Card(
                margin: const EdgeInsets.symmetric(vertical: 6),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      // ── KIRI: Judul, Lokasi, Tanggal, Link ───────────────
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Judul
                            if (title.isNotEmpty) ...[
                              Text(
                                title,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                            ],

                            // Lokasi
                            Text(
                              location,
                              style: TextStyle(color: Colors.grey[800]),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),

                            // Tanggal + waktu dibuat
                            Text(
                              '$date • $when',
                              style: TextStyle(color: Colors.grey[600]),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 8),

                            // Link Google Drive
                            Row(
                              children: [
                                const Icon(Icons.link, size: 20, color: Colors.blue),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () async {
                                      final uri = Uri.parse(link);
                                      if (await canLaunchUrl(uri)) {
                                        await launchUrl(
                                          uri,
                                          mode: LaunchMode.externalApplication,
                                        );
                                      }
                                    },
                                    child: Text(
                                      link,
                                      style: const TextStyle(
                                        color: Colors.blue,
                                        decoration: TextDecoration.underline,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(width: 12),

                      // ── KANAN: Thumbnail (64×64) atau placeholder ────────
                      SizedBox(
                        width: 64,
                        height: 64,
                        child: FutureBuilder<String?>(
                          future: _fetchThumbnail(link),
                          builder: (c, snap2) {
                            if (snap2.connectionState == ConnectionState.waiting) {
                              return const Center(
                                  child: CircularProgressIndicator(strokeWidth: 2));
                            }
                            if (snap2.hasError || snap2.data == null) {
                              return Container(
                                decoration: BoxDecoration(
                                  color: Colors.grey[200],
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.image, color: Colors.grey),
                              );
                            }
                            return ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                snap2.data!,
                                width: 64,
                                height: 64,
                                fit: BoxFit.cover,
                              ),
                            );
                          },
                        ),
                      ),
                    ],
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
