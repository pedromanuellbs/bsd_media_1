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
Future<List<String>> findMatchingPhotos(File faceImage) async {
  final uri = Uri.parse('https://backendlbphbsdmedia-production.up.railway.app/find_my_photos');
  try {
    final req = http.MultipartRequest('POST', uri)
      ..files.add(await http.MultipartFile.fromPath('image', faceImage.path));

    final resp = await req.send();
    final body = await resp.stream.bytesToString();

    if (resp.statusCode == 200) {
      final jsonResp = json.decode(body) as Map<String, dynamic>;
      if (jsonResp['success'] == true && jsonResp['photo_urls'] != null) {
        // Konversi list dinamis menjadi list string
        final urls = List<String>.from(jsonResp['photo_urls']);
        return urls;
      }
    }
  } catch (e) {
    debugPrint('Error saat mencari foto: $e');
  }
  // Kembalikan list kosong jika gagal
  return []; 
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
    int camIndex = cameras.indexWhere((c) => c.lensDirection == CameraLensDirection.front);
    if (camIndex < 0) camIndex = 0;

    _controller = CameraController(
      cameras[camIndex],
      ResolutionPreset.medium,
    );
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
      final savePath = p.join(tmpDir.path, '${DateTime.now().millisecondsSinceEpoch}.jpg');
      final faceFile = File(savePath);
      await raw.saveTo(faceFile);

      // 2. Kirim ke Backend untuk dicocokkan (jika role client)
      if (widget.isClient) {
        final List<String> matchedUrls = await findMatchingPhotos(faceFile);

        if (mounted) {
          Navigator.pop(context); // Tutup loading dialog
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => MatchPicsPage(matchedPhotoUrls: matchedUrls),
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
            const SnackBar(content: Text('Terjadi error saat memproses foto.'))
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