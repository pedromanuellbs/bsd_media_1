// face_ai/face_capture_page.dart

import 'dart:convert';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../screens/client_log/match_pics.dart';

// Helper function untuk memanggil backend pencari foto
// Contoh fungsi yang benar:
Future<List<Map<String, dynamic>>> findMatchingPhotos(File faceFile) async {
  final url = Uri.parse(
    'https://backendlbphbsdmedia-production.up.railway.app/find_my_photos',
  );
  var request = http.MultipartRequest('POST', url);
  request.files.add(await http.MultipartFile.fromPath('image', faceFile.path));

  final streamedResponse = await request.send();
  final response = await http.Response.fromStream(streamedResponse);

  if (response.statusCode != 200) {
    throw Exception('Failed to get matched photos');
  }

  final Map<String, dynamic> data = jsonDecode(response.body);
  final List matchedPhotos = data['matched_photos'] ?? [];
  return matchedPhotos.cast<Map<String, dynamic>>();
}

class FaceCapturePage extends StatefulWidget {
  final CameraDescription camera;
  final bool isClient;

  const FaceCapturePage({
    required this.camera,
    required this.isClient,
    Key? key,
  }) : super(key: key);

  @override
  State<FaceCapturePage> createState() => _FaceCapturePageState();
}

class _FaceCapturePageState extends State<FaceCapturePage> {
  late CameraController _controller;
  Future<void>? _initFuture;

  @override
  void initState() {
    super.initState();
    _setupCamera();
  }

  Future<void> _setupCamera() async {
    final cameras = await availableCameras();
    int camIndex = cameras.indexWhere(
      (c) => c.lensDirection == CameraLensDirection.front,
    );
    if (camIndex < 0) camIndex = 0;

    _controller = CameraController(cameras[camIndex], ResolutionPreset.medium);
    _initFuture = _controller.initialize();
    if (mounted) setState(() {});
  }

  // UBAHAN UTAMA DI FUNGSI INI
  Future<void> _takePicture() async {
    if (!mounted || !_controller.value.isInitialized) return;

    // Tampilkan loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      // 1. Ambil foto
      final XFile raw = await _controller.takePicture();
      final tmpDir = await getTemporaryDirectory();
      final savePath = p.join(
        tmpDir.path,
        '${DateTime.now().millisecondsSinceEpoch}.jpg',
      );
      await raw.saveTo(savePath); // ini benar

      // Tambahkan delay agar file system sempat flush (100ms biasanya cukup)
      await Future.delayed(const Duration(milliseconds: 100));

      final faceFile = File(savePath);
      final fileLength = await faceFile.length();
      if (fileLength == 0) {
        if (mounted) {
          Navigator.pop(context); // Tutup loading dialog
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Foto gagal disimpan (file kosong)! Silakan ulangi.',
              ),
            ),
          );
        }
        return;
      }
      print('DEBUG FOTO: simpan ke $savePath, size: $fileLength');

      // 2. Kirim ke Backend untuk dicocokkan (jika role client)
      if (widget.isClient) {
        final List<Map<String, dynamic>> matchedPhotos =
            await findMatchingPhotos(faceFile);

        if (mounted) {
          Navigator.pop(context); // Tutup loading dialog
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => MatchPicsPage(matchedPhotos: matchedPhotos),
            ),
          );
        }
      }
      // Logika lama untuk registrasi
      else {
        if (mounted) {
          Navigator.pop(context); // Tutup loading dialog
          Navigator.pop(context, faceFile); // Kembalikan file
        }
      }
    } catch (e) {
      debugPrint('❌ Error proses foto: $e');
      if (mounted) {
        Navigator.pop(context); // Tutup loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Terjadi error saat memproses foto.')),
        );
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan Wajah')),
      body: FutureBuilder(
        future: _initFuture,
        builder: (c, snap) {
          if (snap.connectionState == ConnectionState.done) {
            return CameraPreview(_controller);
          } else {
            return const Center(child: CircularProgressIndicator());
          }
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _takePicture,
        tooltip: 'Ambil Foto',
        child: const Icon(Icons.camera_alt),
      ),
    );
  }
}
