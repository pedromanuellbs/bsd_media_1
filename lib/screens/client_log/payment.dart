// screens/client_log/payment.dart
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import './qris.dart';

class PaymentPage extends StatelessWidget {
  final Map<String, dynamic> photoDetails;
  final Map<String, dynamic> sessionDetails;

  const PaymentPage({
    Key? key,
    required this.photoDetails,
    required this.sessionDetails,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final imageUrl = photoDetails['webContentLink'] ?? photoDetails['thumbnailLink'] ?? '';
    final photographerName = sessionDetails['photographerName'] ?? 'Fotografer tidak diketahui';
    final photographerId = sessionDetails['photographerId'];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Konfirmasi Pembelian'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Konten halaman (Card gambar, detail, harga, dll) tetap sama
            Card(
              clipBehavior: Clip.antiAlias,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.0),
              ),
              elevation: 4,
              child: CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.cover,
                placeholder: (context, url) => const AspectRatio(
                  aspectRatio: 1,
                  child: Center(child: CircularProgressIndicator()),
                ),
                errorWidget: (context, url, error) => const AspectRatio(
                  aspectRatio: 1,
                  child: Center(child: Icon(Icons.broken_image, size: 40)),
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text('DETAIL ITEM', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Item', style: TextStyle(color: Colors.black54)),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            '1x Foto Digital (${photoDetails['name']})',
                            textAlign: TextAlign.end,
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Fotografer', style: TextStyle(color: Colors.black54)),
                        Text(photographerName),
                      ],
                    ),
                  ],
                ),
              ),
            ),
             const SizedBox(height: 24),
            const Text('RINCIAN HARGA', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    const Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('Harga Foto'), Text('Rp 15.000')]),
                    const SizedBox(height: 8),
                    const Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('Biaya Layanan'), Text('Rp 1.000')]),
                    const Divider(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Total Pembayaran', style: TextStyle(fontWeight: FontWeight.bold)),
                        Text('Rp 16.000', style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor, fontSize: 16)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ElevatedButton(
          onPressed: () {
            if (photographerId != null) {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => QrisPage(
                    // --- PERBAIKAN: Pastikan tipe data adalah String ---
                    photographerId: photographerId as String,
                    photoDetails: photoDetails,
                  ),
                ),
              );
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Error: ID Fotografer tidak ditemukan.')),
              );
            }
          },
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            backgroundColor: Theme.of(context).primaryColor,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
          ),
          child: const Text('Bayar Sekarang', style: TextStyle(fontSize: 16)),
        ),
      ),
    );
  }
}
