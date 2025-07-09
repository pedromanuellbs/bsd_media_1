// screens/client_log/qris.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
// 1️⃣ Storage tidak lagi dipakai, jadi import-nya bisa dihapus.
// import 'package:firebase_storage/firebase_storage.dart';

import '../home/saved.dart'; // --- TAMBAHAN: halaman Saved

class QrisPage extends StatefulWidget {
  final String photographerId;
  final Map<String, dynamic> photoDetails;

  const QrisPage({
    Key? key,
    required this.photographerId,
    required this.photoDetails,
  }) : super(key: key);

  @override
  _QrisPageState createState() => _QrisPageState();
}

class _QrisPageState extends State<QrisPage> {
  String? _qrisImageUrl;
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _fetchQrisImageUrl();
  }

  /// 2️⃣ Mendapatkan URL QRIS langsung dari dokumen `users/{photographerId}`
  Future<void> _fetchQrisImageUrl() async {
    try {
      final userSnap =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(widget.photographerId)
              .get();

      if (userSnap.exists) {
        // Pastikan key persis sama seperti di Firestore
        final url = userSnap.data()?['qrisUrl'] as String?;
        if (url != null && url.isNotEmpty) {
          setState(() => _qrisImageUrl = url);
        }
      }
    } catch (e) {
      debugPrint('Gagal mengambil data QRIS: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _savePhotoAfterPayment() async {
    setState(() => _isSaving = true);

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Gagal: Anda harus login untuk menyimpan foto.'),
        ),
      );
      setState(() => _isSaving = false);
      return;
    }

    try {
      final dataToSave = {
        ...widget.photoDetails,
        'purchasedAt': FieldValue.serverTimestamp(),
      };

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('purchased_photos')
          .add(dataToSave);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pembayaran berhasil! Foto telah disimpan.'),
          backgroundColor: Colors.green,
        ),
      );

      // Navigasi ke halaman Saved
      Navigator.of(context).popUntil((route) => route.isFirst);
      Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const SavedPage()));
    } catch (e) {
      debugPrint('Gagal menyimpan foto: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Terjadi kesalahan saat menyimpan foto.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    const totalPembayaran = 'Rp 16.000';

    return Scaffold(
      appBar: AppBar(title: const Text('Pembayaran QRIS')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Scan QR Code di Bawah Ini',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Total Pembayaran: $totalPembayaran',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.black54),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 250,
              width: 250,
              child:
                  _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : (_qrisImageUrl?.isNotEmpty ?? false)
                      ? Image.network(
                        _qrisImageUrl!,
                        errorBuilder:
                            (_, __, ___) => const Center(
                              child: Text(
                                'Gagal memuat gambar QRIS.',
                                style: TextStyle(color: Colors.red),
                                textAlign: TextAlign.center,
                              ),
                            ),
                      )
                      : const Center(
                        child: Text(
                          'QRIS untuk fotografer ini tidak ditemukan.',
                          style: TextStyle(color: Colors.red),
                          textAlign: TextAlign.center,
                        ),
                      ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Setelah melakukan pembayaran, transaksi Anda akan diverifikasi secara otomatis.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.black54),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ElevatedButton(
          onPressed: _isSaving ? null : _savePhotoAfterPayment,
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            backgroundColor: Theme.of(context).primaryColor,
            foregroundColor: Colors.white,
          ),
          child:
              _isSaving
                  ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 3,
                    ),
                  )
                  : const Text('Saya Sudah Bayar'),
        ),
      ),
    );
  }
}
