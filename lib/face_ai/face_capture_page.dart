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

// ===== FUNGSI: MEMULAI PENCARIAN =====
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
        return decodedBody['job_id'];
      }
    }
  } catch (e) {
    print("Error saat memulai pencarian: $e");
  }
  return null;
}

// ===== FUNGSI: MENGECEK HASIL (dengan progress) =====
Future<Map<String, dynamic>?> getSearchResult(String jobId) async {
  final url = Uri.parse(
    'https://backendlbphbsdmedia-production.up.railway.app/get_search_status?job_id=$jobId',
  );

  try {
    final response = await http.get(url);
    if (response.statusCode == 200) {
      final decodedBody = jsonDecode(response.body);
      if (decodedBody['success'] == true) {
        return decodedBody['job_data'];
      }
    }
  } catch (e) {
    print("Error saat mengecek hasil: $e");
  }
  return null;
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
  Timer? _pollingTimer;

  // Tambahan state untuk progress bar
  int? _progress;
  int? _total;
  String? _status;

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

  Future<void> _takePicture() async {
    if (!mounted || !_controller.value.isInitialized) return;

    // Tampilkan dialog progress
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (_) => ProgressDialog(
            progress: _progress,
            total: _total,
            status: _status,
          ),
    );

    try {
      final XFile raw = await _controller.takePicture();
      final tmpDir = await getTemporaryDirectory();
      final savePath = p.join(
        tmpDir.path,
        '${DateTime.now().millisecondsSinceEpoch}.jpg',
      );
      await raw.saveTo(savePath);
      final faceFile = File(savePath);

      if (widget.isClient) {
        final jobId = await startPhotoSearch(faceFile);

        if (jobId == null) {
          throw Exception('Gagal memulai tugas pencarian di server.');
        }

        // Reset progress state
        setState(() {
          _progress = null;
          _total = null;
          _status = 'pending';
        });

        _pollingTimer = Timer.periodic(const Duration(seconds: 3), (
          timer,
        ) async {
          if (!mounted) {
            timer.cancel();
            return;
          }

          final jobData = await getSearchResult(jobId);
          if (jobData != null) {
            setState(() {
              _status = jobData['status'];
              _progress = jobData['progress'];
              _total = jobData['total'];
            });

            if (jobData['status'] == 'completed') {
              timer.cancel();
              final List matchedPhotos = jobData['results'] ?? [];
              if (mounted) {
                Navigator.pop(context); // Tutup dialog
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
            } else if (jobData['status'] == 'failed') {
              timer.cancel();
              if (mounted) {
                Navigator.pop(context); // Tutup dialog
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Pencarian gagal: ${jobData['error']}'),
                  ),
                );
              }
            }
          }
        });
      } else {
        if (mounted) {
          Navigator.pop(context); // Tutup dialog
          Navigator.pop(context, faceFile);
        }
      }
    } catch (e) {
      debugPrint('❌ Error proses foto: $e');
      if (mounted) {
        Navigator.pop(context); // Tutup dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Terjadi error: ${e.toString()}')),
        );
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _pollingTimer?.cancel();
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

// Widget progress bar custom
class ProgressDialog extends StatelessWidget {
  final int? progress;
  final int? total;
  final String? status;

  const ProgressDialog({Key? key, this.progress, this.total, this.status})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    bool showProgress =
        status == 'processing' &&
        progress != null &&
        total != null &&
        total! > 0;
    return Dialog(
      backgroundColor: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            showProgress
                ? Column(
                  children: [
                    LinearProgressIndicator(value: progress! / total!),
                    const SizedBox(height: 16),
                    Text('Memproses foto: $progress dari $total'),
                  ],
                )
                : Column(
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    Text(
                      status == 'pending'
                          ? 'Menunggu antrian...'
                          : 'Memulai...',
                    ),
                  ],
                ),
          ],
        ),
      ),
    );
  }
}
