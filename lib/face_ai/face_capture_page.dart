// face_ai/face_capture_page.dart
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class FaceCapturePage extends StatefulWidget {
  final CameraDescription camera;
  const FaceCapturePage({ required this.camera, Key? key }) : super(key: key);

  @override
  State<FaceCapturePage> createState() => _FaceCapturePageState();
}

class _FaceCapturePageState extends State<FaceCapturePage> {
  late List<CameraDescription> _cameras;
  late CameraController _controller;
  Future<void>? _initFuture;
  int _camIndex = 0;

  @override
  void initState() {
    super.initState();
    _setupCamera();
  }

  Future<void> _setupCamera() async {
    _cameras = await availableCameras();
    // Cari kamera depan
    _camIndex = _cameras.indexWhere((c) => c.lensDirection == CameraLensDirection.front);
    if (_camIndex < 0) _camIndex = 0;

    _controller = CameraController(
      _cameras[_camIndex],
      ResolutionPreset.medium,
    );
    _initFuture = _controller.initialize();
    setState(() {});
  }

  Future<void> _switchCamera() async {
    if (_cameras.length < 2) return;
    _camIndex = (_camIndex + 1) % _cameras.length;
    await _controller.dispose();
    _controller = CameraController(
      _cameras[_camIndex],
      ResolutionPreset.medium,
    );
    _initFuture = _controller.initialize();
    setState(() {});
  }

  Future<void> _takePicture() async {
    try {
      await _initFuture;
      // ambil gambar
      final XFile raw = await _controller.takePicture();
      // simpan ke temp dir
      final tmpDir = await getTemporaryDirectory();
      final savePath = p.join(tmpDir.path, '${DateTime.now().millisecondsSinceEpoch}.jpg');
      await raw.saveTo(savePath);
      // kembaliin File, bukan String
      Navigator.pop(context, File(savePath));
    } catch (e) {
      debugPrint('❌ Error ambil foto: $e');
      Navigator.pop(context, null);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext ctx) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan Wajah')),
      body: _initFuture == null
          ? const Center(child: CircularProgressIndicator())
          : FutureBuilder(
              future: _initFuture,
              builder: (c, snap) {
                if (snap.connectionState == ConnectionState.done) {
                  return CameraPreview(_controller);
                } else {
                  return const Center(child: CircularProgressIndicator());
                }
              },
            ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            heroTag: 'switch_cam',
            onPressed: _switchCamera,
            tooltip: 'Ganti Kamera',
            child: const Icon(Icons.cameraswitch),
          ),
          const SizedBox(height: 16),
          FloatingActionButton(
            heroTag: 'take_pic',
            onPressed: _takePicture,
            tooltip: 'Ambil Foto',
            child: const Icon(Icons.camera_alt),
          ),
        ],
      ),
    );
  }
}
