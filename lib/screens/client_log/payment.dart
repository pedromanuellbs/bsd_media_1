// screens/client_log/payment.dart
import 'dart:io';
import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
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
    final imageUrl =
        photoDetails['webContentLink'] ?? photoDetails['thumbnailLink'] ?? '';
    final photographerName =
        sessionDetails['photographerName'] ?? 'Fotografer tidak diketahui';
    final photographerId = sessionDetails['photographerId'];

    return Scaffold(
      appBar: AppBar(title: const Text('Konfirmasi Pembelian')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // --- GAMBAR SEKARANG MENGGUNAKAN WIDGET BARU ---
            Card(
              clipBehavior: Clip.antiAlias,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.0),
              ),
              elevation: 4,
              child: AspectRatio(
                aspectRatio: 1,
                child: FaceBlurredImage(
                  imageUrl: imageUrl,
                  // isMember: false -> agar gambar ditampilkan DENGAN BLUR
                  isMember: false,
                  borderRadius: 12.0,
                ),
              ),
            ),

            // --- BATAS PERUBAHAN ---
            const SizedBox(height: 24),
            const Text(
              'DETAIL ITEM',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
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
                        const Text(
                          'Item',
                          style: TextStyle(color: Colors.black54),
                        ),
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
                        const Text(
                          'Fotografer',
                          style: TextStyle(color: Colors.black54),
                        ),
                        Text(photographerName),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'RINCIAN HARGA',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [Text('Harga Foto'), Text('Rp 15.000')],
                    ),
                    const SizedBox(height: 8),
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [Text('Biaya Layanan'), Text('Rp 1.000')],
                    ),
                    const Divider(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Total Pembayaran',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'Rp 16.000',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).primaryColor,
                            fontSize: 16,
                          ),
                        ),
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
                  builder:
                      (context) => QrisPage(
                        photographerId: photographerId as String,
                        photoDetails: photoDetails,
                      ),
                ),
              );
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Error: ID Fotografer tidak ditemukan.'),
                ),
              );
            }
          },
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            backgroundColor: Theme.of(context).primaryColor,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12.0),
            ),
          ),
          child: const Text('Bayar Sekarang', style: TextStyle(fontSize: 16)),
        ),
      ),
    );
  }
}

// =========================================================================
// WIDGET UNTUK BLUR DAN WATERMARK DITAMBAHKAN DI BAWAH SINI
// =========================================================================

class FaceBlurredImage extends StatefulWidget {
  final String imageUrl;
  final bool isMember;
  final double aspect;
  final double borderRadius;

  const FaceBlurredImage({
    Key? key,
    required this.imageUrl,
    required this.isMember,
    this.aspect = 1.0,
    this.borderRadius = 8.0,
  }) : super(key: key);

  @override
  _FaceBlurredImageState createState() => _FaceBlurredImageState();
}

class _FaceBlurredImageState extends State<FaceBlurredImage> {
  List<Rect> _faceRects = [];
  bool _isLoading = true;
  late final FaceDetector _faceDetector;

  @override
  void initState() {
    super.initState();
    _faceDetector = FaceDetector(
      options: FaceDetectorOptions(performanceMode: FaceDetectorMode.fast),
    );
    if (!widget.isMember) {
      _processImage();
    } else {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _faceDetector.close();
    super.dispose();
  }

  Future<void> _processImage() async {
    if (widget.imageUrl.isEmpty) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }
    setState(() {
      _isLoading = true;
      _faceRects = [];
    });
    try {
      final response = await http.get(Uri.parse(widget.imageUrl));
      final imageBytes = response.bodyBytes;
      final tempDir = await getTemporaryDirectory();
      final file = await File(
        '${tempDir.path}/temp_image.jpg',
      ).writeAsBytes(imageBytes);
      final inputImage = InputImage.fromFilePath(file.path);
      final faces = await _faceDetector.processImage(inputImage);
      final rects = faces.map((face) => face.boundingBox).toList();
      if (mounted) {
        setState(() {
          _faceRects = rects;
          _isLoading = false;
        });
      }
      await file.delete();
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.imageUrl.isEmpty) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.grey[300],
          borderRadius: BorderRadius.circular(widget.borderRadius),
        ),
        child: Icon(Icons.image_not_supported, color: Colors.grey[600]),
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;
        return ClipRRect(
          borderRadius: BorderRadius.circular(widget.borderRadius),
          child: Stack(
            fit: StackFit.expand,
            children: [
              CachedNetworkImage(
                imageUrl: widget.imageUrl,
                fit: BoxFit.cover,
                width: w,
                height: h,
                placeholder:
                    (context, url) =>
                        const Center(child: CircularProgressIndicator()),
                errorWidget: (context, url, error) => const Icon(Icons.error),
              ),
              if (!widget.isMember && _faceRects.isNotEmpty)
                ..._faceRects.map((rect) {
                  return Positioned.fromRect(
                    rect: rect,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(rect.width / 4),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                        child: Container(color: Colors.transparent),
                      ),
                    ),
                  );
                }).toList(),
              Center(
                child: Opacity(
                  opacity: 0.5,
                  child: Image.asset(
                    'assets/logo-bsd-media.png',
                    width: w * 0.6,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              if (!widget.isMember && _isLoading)
                Container(
                  color: Colors.black.withOpacity(0.3),
                  child: const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
