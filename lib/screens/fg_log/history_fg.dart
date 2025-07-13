// screens/fg_log/history_fg.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

// jadi:
import '../collage_page.dart';

class HistoryFGPage extends StatelessWidget {
  const HistoryFGPage({Key? key}) : super(key: key);

  // API key Drive kamu
  static const _apiKey =
      'AIzaSyC_vPd6yPwYQ60Pn-tuR3Nly_7mgXZcxGk'; // Replace with your actual API key

  /// Ekstrak ID dari link Drive (file atau folder)
  String? _extractDriveId(String link) {
    final m1 = RegExp(r'/d/([^/]+)').firstMatch(link);
    if (m1 != null) return m1.group(1);
    final m2 = RegExp(r'/folders/([^/]+)').firstMatch(link);
    if (m2 != null) return m2.group(1);
    return null;
  }

  /// Tarik semua URL image di folder publik
  Future<List<String>> _fetchAllImageUrls(String folderUrl) async {
    final folderId = _extractDriveId(folderUrl);
    if (folderId == null) throw 'Invalid Drive link';

    final uri = Uri.https('www.googleapis.com', '/drive/v3/files', {
      'q': "'$folderId' in parents and mimeType contains 'image/'",
      'fields': 'files(id)',
      'key': _apiKey,
      'corpora': 'allDrives',
      'supportsAllDrives': 'true',
      'includeItemsFromAllDrives': 'true',
    });

    final resp = await http.get(uri);
    if (resp.statusCode != 200) throw 'Drive API error ${resp.statusCode}';

    final data = json.decode(resp.body) as Map<String, dynamic>;
    final files = (data['files'] as List).cast<Map<String, dynamic>>();
    return files
        .map((f) => 'https://drive.google.com/uc?export=view&id=${f['id']}')
        .toList();
  }

  /// Delete a photo session from Firestore
  Future<void> _deletePhotoSession(String docId) async {
    await FirebaseFirestore.instance
        .collection('photo_sessions')
        .doc(docId)
        .delete();
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      body: StreamBuilder<QuerySnapshot>(
        stream:
            FirebaseFirestore.instance
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
              final docId = docs[i].id; // Get the document ID
              final data = docs[i].data()! as Map<String, dynamic>;
              final title = data['title'] as String? ?? '';
              final location = data['location'] as String? ?? '';
              final date = data['date'] as String? ?? '';
              final link = data['driveLink'] as String? ?? '';
              final ts = data['createdAt'] as Timestamp?;
              final when =
                  ts != null
                      ? DateFormat.yMMMd().add_jm().format(ts.toDate())
                      : '';

              return Dismissible(
                key: ValueKey(docId), // Unique key for each item
                direction:
                    DismissDirection.endToStart, // Swipe from right to left
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  color: Colors.red,
                  child: const Icon(Icons.delete, color: Colors.white),
                ),
                confirmDismiss: (direction) async {
                  return await showDialog(
                    context: context,
                    builder:
                        (context) => AlertDialog(
                          title: const Text('Konfirmasi Hapus'),
                          content: const Text(
                            'Apakah Anda yakin ingin menghapus sesi foto ini?',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(false),
                              child: const Text('Batal'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(true),
                              child: const Text('Hapus'),
                            ),
                          ],
                        ),
                  );
                },
                onDismissed: (direction) {
                  _deletePhotoSession(docId);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Sesi foto "$title" dihapus')),
                  );
                },
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => CollagePage(folderUrl: link),
                      ),
                    );
                  },
                  child: Card(
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          // KIRI: Judul, Lokasi, Tanggal, Link
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
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
                                Text(
                                  location,
                                  style: TextStyle(color: Colors.grey[800]),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '$date • $when',
                                  style: TextStyle(color: Colors.grey[600]),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.link,
                                      size: 20,
                                      color: Colors.blue,
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: GestureDetector(
                                        onTap: () async {
                                          final uri = Uri.parse(link);
                                          if (await canLaunchUrl(uri)) {
                                            await launchUrl(
                                              uri,
                                              mode:
                                                  LaunchMode
                                                      .externalApplication,
                                            );
                                          }
                                        },
                                        child: Text(
                                          link,
                                          style: const TextStyle(
                                            color: Colors.blue,
                                            decoration:
                                                TextDecoration.underline,
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

                          // KANAN: Thumbnail (64×64) atau placeholder
                          SizedBox(
                            width: 64,
                            height: 64,
                            child: FutureBuilder<List<String>>(
                              future: _fetchAllImageUrls(link),
                              builder: (c, snap2) {
                                if (snap2.connectionState ==
                                    ConnectionState.waiting) {
                                  return const Center(
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  );
                                }
                                if (snap2.hasError ||
                                    snap2.data == null ||
                                    snap2.data!.isEmpty) {
                                  return Container(
                                    decoration: BoxDecoration(
                                      color: Colors.grey[200],
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(
                                      Icons.image,
                                      color: Colors.grey,
                                    ),
                                  );
                                }
                                final thumb = snap2.data!.first;
                                return ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.network(
                                    thumb,
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
