// screens/home/saved.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';

class SavedPage extends StatefulWidget {
  const SavedPage({Key? key}) : super(key: key);

  @override
  State<SavedPage> createState() => _SavedPageState();
}

class _SavedPageState extends State<SavedPage> {
  late Future<void> _localeInitFuture;

  @override
  void initState() {
    super.initState();
    _localeInitFuture = initializeDateFormatting('id', null);
    FlutterDownloader.initialize(debug: true, ignoreSsl: true);
  }

  Future<void> deleteImage(
    DocumentReference docRef,
    BuildContext context,
  ) async {
    try {
      await docRef.delete();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Foto berhasil dihapus')));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Gagal menghapus foto: $e')));
    }
  }

  Future<void> showDeleteConfirmationDialog(
    BuildContext context,
    DocumentReference docRef,
  ) async {
    final result = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text("Konfirmasi Hapus"),
            content: const Text("Apakah Anda yakin ingin menghapus foto ini?"),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text("Batal"),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text("Ya, Hapus"),
              ),
            ],
          ),
    );
    if (result == true) {
      await deleteImage(docRef, context);
    }
  }

  Future<void> downloadImage(BuildContext context, String imageUrl) async {
    try {
      final status = await Permission.storage.request();
      if (!status.isGranted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Izin penyimpanan ditolak')),
        );
        return;
      }

      Directory? externalDir = await getExternalStorageDirectory();
      if (externalDir == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Gagal mendapatkan direktori penyimpanan'),
          ),
        );
        return;
      }

      // Coba simpan ke folder Download jika ada
      String downloadPath = "/storage/emulated/0/Download";
      if (await Directory(downloadPath).exists()) {
        externalDir = Directory(downloadPath);
      }

      await FlutterDownloader.enqueue(
        url: imageUrl,
        savedDir: externalDir.path,
        showNotification: true,
        openFileFromNotification: true,
      );
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Download dimulai...')));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Gagal mengunduh gambar: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    // Tunggu sampai inisialisasi locale selesai sebelum render
    return FutureBuilder(
      future: _localeInitFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return _buildContent(context);
      },
    );
  }

  Widget _buildContent(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Saved')),
        body: const Center(
          child: Text("Silakan login untuk melihat foto yang disimpan."),
        ),
      );
    }

    return Scaffold(
      body: StreamBuilder<QuerySnapshot>(
        stream:
            FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .collection('purchased_photos')
                .orderBy('redeemedAt', descending: true)
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
              final title = data['name'] ?? 'Foto';
              final docRef = docs[index].reference;

              // Ambil tanggal penebusan & kadaluarsa langsung dari Firestore
              final Timestamp? redeemedAtTs = data['redeemedAt'];
              final Timestamp? expiredAtTs = data['expiredAt'];
              DateTime? redeemedAt;
              DateTime? expiredAt;

              if (redeemedAtTs != null) redeemedAt = redeemedAtTs.toDate();
              if (expiredAtTs != null) expiredAt = expiredAtTs.toDate();

              // Cek kadaluarsa
              final now = DateTime.now();
              if (expiredAt != null && now.isAfter(expiredAt)) {
                Future.microtask(() async {
                  await docRef.delete();
                });
                return const SizedBox.shrink();
              }

              return GestureDetector(
                onTap: () {
                  showDialog(
                    context: context,
                    builder:
                        (context) => Center(
                          child: Card(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16.0),
                            ),
                            margin: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 64,
                            ),
                            color: Colors.white,
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: SingleChildScrollView(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(12.0),
                                      child: CachedNetworkImage(
                                        imageUrl: imageUrl,
                                        fit: BoxFit.cover,
                                        width: double.infinity,
                                        height: 220,
                                        placeholder:
                                            (c, u) => const Center(
                                              child:
                                                  CircularProgressIndicator(),
                                            ),
                                        errorWidget:
                                            (c, u, e) =>
                                                const Icon(Icons.error),
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      title,
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    // Tanggal tebus dan kadaluarsa dari Firestore
                                    if (redeemedAt != null &&
                                        expiredAt != null) ...[
                                      const SizedBox(height: 12),
                                      Text(
                                        "Kamu menebus foto ini pada: ${DateFormat('d MMMM yyyy', 'id').format(redeemedAt)}",
                                        style: const TextStyle(fontSize: 14),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        "Kadaluarsa: ${DateFormat('d MMMM yyyy', 'id').format(expiredAt)}",
                                        style: const TextStyle(
                                          fontSize: 14,
                                          color: Colors.redAccent,
                                        ),
                                      ),
                                    ],
                                    const SizedBox(height: 16),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceEvenly,
                                      children: [
                                        ElevatedButton.icon(
                                          onPressed: () async {
                                            await downloadImage(
                                              context,
                                              imageUrl,
                                            );
                                          },
                                          icon: const Icon(Icons.download),
                                          label: const Text("Download"),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.blue,
                                            foregroundColor: Colors.white,
                                          ),
                                        ),
                                        ElevatedButton.icon(
                                          onPressed: () async {
                                            Navigator.of(context).pop();
                                            await showDeleteConfirmationDialog(
                                              context,
                                              docRef,
                                            );
                                          },
                                          icon: const Icon(Icons.delete),
                                          label: const Text("Hapus"),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.red,
                                            foregroundColor: Colors.white,
                                          ),
                                        ),
                                        TextButton(
                                          onPressed:
                                              () => Navigator.of(context).pop(),
                                          child: const Text("Tutup"),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                  );
                },
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8.0),
                  child: CachedNetworkImage(
                    imageUrl: imageUrl,
                    fit: BoxFit.cover,
                    placeholder:
                        (c, u) =>
                            const Center(child: CircularProgressIndicator()),
                    errorWidget: (c, u, e) => const Icon(Icons.error),
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

// CONTOH: Tambahkan kode penebusan foto yang otomatis menulis redeemedAt & expiredAt
// Panggil fungsi ini saat user menebus/membeli foto

Future<void> redeemPhoto({
  required String imageUrl,
  required String title,
  String? thumbnailUrl,
}) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return;

  final now = DateTime.now();
  final expiredAt = now.add(const Duration(days: 30));

  await FirebaseFirestore.instance
      .collection('users')
      .doc(user.uid)
      .collection('purchased_photos')
      .add({
        'webContentLink': imageUrl,
        if (thumbnailUrl != null) 'thumbnailLink': thumbnailUrl,
        'name': title,
        'redeemedAt': Timestamp.fromDate(now),
        'expiredAt': Timestamp.fromDate(expiredAt),
        // field lain sesuai kebutuhan
      });
}
