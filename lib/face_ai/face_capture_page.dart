// face_ai/face_capture_page.dart
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'dart:io';

class FaceCapturePage extends StatefulWidget {
  final CameraDescription camera;
  const FaceCapturePage({required this.camera, Key? key}) : super(key: key);

  @override
  State<FaceCapturePage> createState() => _FaceCapturePageState();
}

class _FaceCapturePageState extends State<FaceCapturePage> {
  late List<CameraDescription> _cameras;
  late CameraController _controller;
  Future<void>? _initializeControllerFuture;
  int _selectedCameraIndex = 0;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    _cameras = await availableCameras();

    // Set kamera default ke depan jika 
    _selectedCameraIndex = _cameras.indexWhere(
      (cam) => cam.lensDirection == CameraLensDirection.front,
    );
    if (_selectedCameraIndex == -1) _selectedCameraIndex = 0;

    _controller = CameraController(
      _cameras[_selectedCameraIndex],
      ResolutionPreset.medium,
    );
    _initializeControllerFuture = _controller.initialize();
    setState(() {});
  }

  Future<void> _switchCamera() async {
    if (_cameras.length < 2) return;

    _selectedCameraIndex = (_selectedCameraIndex + 1) % _cameras.length;

    await _controller.dispose();
    _controller = CameraController(
      _cameras[_selectedCameraIndex],
      ResolutionPreset.medium,
    );
    _initializeControllerFuture = _controller.initialize();
    setState(() {});
  }

  Future<void> _takePicture() async {
    try {
      if (_initializeControllerFuture == null) return;
      await _initializeControllerFuture!;
      final image = await _controller.takePicture();

      final directory = await getTemporaryDirectory();
      final imagePath = path.join(
        directory.path,
        '${DateTime.now().millisecondsSinceEpoch}.jpg',
      );
      await image.saveTo(imagePath);

      Navigator.pop(context, imagePath);
    } catch (e) {
      print('❌ Error ambil foto: $e');
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
      body: _initializeControllerFuture == null
          ? const Center(child: CircularProgressIndicator())
          : FutureBuilder(
              future: _initializeControllerFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.done) {
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
            heroTag: 'switch_camera',
            onPressed: _switchCamera,
            child: const Icon(Icons.cameraswitch),
            tooltip: 'Ganti Kamera',
          ),
          const SizedBox(height: 16),
          FloatingActionButton(
            heroTag: 'take_picture',
            onPressed: _takePicture,
            child: const Icon(Icons.camera_alt),
            tooltip: 'Ambil Foto',
          ),
        ],
      ),
    );
  }
}
