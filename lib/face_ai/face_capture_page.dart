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

Future<Map<String, dynamic>?> findMyPhotos(
  File faceFile, {
  List<String>? driveLinks,
}) async {
  final url = Uri.parse(
    'https://backendlbphbsdmedia-production.up.railway.app/find_my_photos',
  );

  var request = http.MultipartRequest('POST', url);
  request.files.add(await http.MultipartFile.fromPath('image', faceFile.path));

  if (driveLinks != null && driveLinks.isNotEmpty) {
    request.fields['drive_links'] = jsonEncode(driveLinks);
  }

  try {
    final response = await request.send().timeout(
      const Duration(seconds: 350),
      onTimeout: () => throw TimeoutException('Request timeout'),
    );

    final responseBody = await response.stream.bytesToString();
    debugPrint(
      'DEBUG_FLUTTER: findMyPhotos - HTTP Status Code: ${response.statusCode}',
    );
    debugPrint(
      'DEBUG_FLUTTER: findMyPhotos - Raw Response Body: $responseBody',
    );

    if (response.statusCode == 200) {
      try {
        final decodedBody = jsonDecode(responseBody);
        debugPrint('DEBUG_FLUTTER: findMyPhotos - Decoded Body: $decodedBody');

        if (decodedBody['success'] == true) {
          return decodedBody;
        } else {
          print("Server error: ${decodedBody['error']}");
          return decodedBody;
        }
      } catch (e) {
        debugPrint('ERROR_FLUTTER: findMyPhotos - Error decoding JSON: $e');
        debugPrint(
          'ERROR_FLUTTER: findMyPhotos - Raw body that caused error: $responseBody',
        );
        return {
          'success': false,
          'error': 'Gagal memproses respons dari server (JSON error)',
        };
      }
    } else {
      print("HTTP error: ${response.statusCode}");
      debugPrint("HTTP error body: $responseBody");
      return {'success': false, 'error': 'HTTP Error ${response.statusCode}'};
    }
  } on TimeoutException catch (e) {
    print("Timeout error: $e");
    return {'success': false, 'error': 'Request timeout'};
  } catch (e) {
    print("General error: $e");
    return {
      'success': false,
      'error': 'Terjadi kesalahan umum: ${e.toString()}',
    };
  }
}

class FaceCapturePage extends StatefulWidget {
  final CameraDescription camera;
  final bool isClient;
  final List<String>? driveLinks;
  final Map<String, dynamic>? sessionDetailsMap;

  const FaceCapturePage({
    required this.camera,
    required this.isClient,
    this.driveLinks,
    this.sessionDetailsMap,
    Key? key,
  }) : super(key: key);

  @override
  State<FaceCapturePage> createState() => _FaceCapturePageState();
}

class _FaceCapturePageState extends State<FaceCapturePage> {
  late CameraController _controller;
  Future<void>? _initFuture;
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

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => ProgressDialog(status: _status),
    );

    try {
      final XFile raw = await _controller.takePicture();
      debugPrint(
        'DEBUG_FLUTTER: XFile dari kamera. Path: ${raw.path}, bytes: ${await raw.readAsBytes().then((b) => b.length)}',
      );

      final tmpDir = await getTemporaryDirectory();
      final savePath = p.join(
        tmpDir.path,
        '${DateTime.now().millisecondsSinceEpoch}.jpg',
      );
      await raw.saveTo(savePath);
      final faceFile = File(savePath);
      debugPrint(
        'DEBUG_FLUTTER: File foto disimpan. Path: $savePath, exists: ${await faceFile.exists()}, length: ${await faceFile.length()}',
      );

      if (widget.isClient) {
        setState(() {
          _status = 'Memproses...';
        });

        final searchResult = await findMyPhotos(
          faceFile,
          driveLinks: widget.driveLinks,
        );

        if (mounted) {
          Navigator.pop(context);

          if (searchResult != null && searchResult['success'] == true) {
            final List matchedPhotos = searchResult['matched_photos'] ?? [];

            debugPrint(
              'DEBUG_FLUTTER: findMyPhotos returned success: ${searchResult['success']}',
            );
            debugPrint(
              'DEBUG_FLUTTER: Matched photos count: ${matchedPhotos.length}',
            );
            debugPrint('DEBUG_FLUTTER: Matched photos content: $matchedPhotos');
            debugPrint(
              'DEBUG_FLUTTER: Full searchResult from backend: $searchResult',
            );

            print(
              "DEBUG sessionDetailsMap keys: ${widget.sessionDetailsMap?.keys}",
            );
            print(
              "DEBUG matchedPhotos sessionIds: ${matchedPhotos.map((p) => p['sessionId']).toList()}",
            );

            Navigator.push(
              context,
              MaterialPageRoute(
                builder:
                    (_) => MatchPicsPage(
                      matchedPhotos: matchedPhotos.cast<Map<String, dynamic>>(),
                      sessionDetailsMap: widget.sessionDetailsMap,
                    ),
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Pencarian gagal: ${searchResult?['error'] ?? 'Terjadi kesalahan tidak dikenal'}',
                ),
              ),
            );
          }
        }
      } else {
        if (mounted) {
          Navigator.pop(context);
          Navigator.pop(context, faceFile);
        }
      }
    } catch (e) {
      debugPrint('❌ Error proses foto: $e');
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Terjadi error: ${e.toString()}')),
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

class ProgressDialog extends StatelessWidget {
  final int? progress;
  final int? total;
  final String? status;

  const ProgressDialog({Key? key, this.progress, this.total, this.status})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(status ?? 'Memulai...'),
          ],
        ),
      ),
    );
  }
}
