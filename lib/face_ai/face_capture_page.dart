// face_ai/face_capture_page.dart

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../screens/client_log/match_pics.dart';

// ===== FUNGSI BARU (BAGIAN 1): MEMULAI PENCARIAN =====
// Fungsi ini hanya mengirim gambar dan mendapatkan job_id
Future<String?> startPhotoSearch(File faceFile) async {
  final url = Uri.parse(
    'https://backendlbphbsdmedia-production.up.railway.app/start_photo_search',
  );

  var request = http.MultipartRequest('POST', url);
  request.files.add(await http.MultipartFile.fromPath('image', faceFile.path));

  try {
    final response = await request.send();
    if (response.statusCode == 200) {
      final responseBody = await response.stream.bytesToString();
      final decodedBody = jsonDecode(responseBody);
      if (decodedBody['success'] == true) {
        return decodedBody['job_id']; // Mengembalikan job_id
      }
    }
  } catch (e) {
    print("Error saat memulai pencarian: $e");
  }
  return null; // Kembalikan null jika gagal
}

// ===== FUNGSI BARU (BAGIAN 2): MENGECEK HASIL =====
// Fungsi ini digunakan untuk mengecek status pekerjaan secara berkala
Future<Map<String, dynamic>?> getSearchResult(String jobId) async {
  final url = Uri.parse(
    'https://backendlbphbsdmedia-production.up.railway.app/get_search_status?job_id=$jobId',
  );

  try {
    final response = await http.get(url);
    if (response.statusCode == 200) {
      final decodedBody = jsonDecode(response.body);
      if (decodedBody['success'] == true) {
        return decodedBody['job_data']; // Mengembalikan seluruh data job
      }
    }
  } catch (e) {
    print("Error saat mengecek hasil: $e");
  }
  return null; // Kembalikan null jika gagal
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
  Timer? _pollingTimer; // Tambahkan variabel untuk timer

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

  // ===== UBAHAN UTAMA DI FUNGSI INI =====
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
      await raw.saveTo(savePath);
      final faceFile = File(savePath);

      // 2. Jika role adalah client, jalankan alur asinkron
      if (widget.isClient) {
        // Mulai pencarian dan dapatkan job ID
        final jobId = await startPhotoSearch(faceFile);

        if (jobId == null) {
          throw Exception('Gagal memulai tugas pencarian di server.');
        }

        // Mulai polling setiap 5 detik
        _pollingTimer = Timer.periodic(const Duration(seconds: 5), (
          timer,
        ) async {
          if (!mounted) {
            timer.cancel();
            return;
          }

          print("Polling untuk job_id: $jobId");
          final jobData = await getSearchResult(jobId);

          if (jobData != null && jobData['status'] == 'completed') {
            timer.cancel(); // Hentikan polling
            final List matchedPhotos = jobData['results'] ?? [];

            if (mounted) {
              Navigator.pop(context); // Tutup loading dialog
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder:
                      (_) => MatchPicsPage(
                        matchedPhotos:
                            matchedPhotos.cast<Map<String, dynamic>>(),
                      ),
                ),
              );
            }
          } else if (jobData != null && jobData['status'] == 'failed') {
            timer.cancel(); // Hentikan polling
            if (mounted) {
              Navigator.pop(context); // Tutup loading dialog
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Pencarian gagal: ${jobData['error']}')),
              );
            }
          }
          // Jika status masih 'pending' atau 'processing', biarkan timer berjalan
        });
      }
      // 3. Jika bukan client (logika registrasi lama)
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
          SnackBar(content: Text('Terjadi error: ${e.toString()}')),
        );
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _pollingTimer?.cancel(); // Pastikan timer dibatalkan saat page ditutup
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
