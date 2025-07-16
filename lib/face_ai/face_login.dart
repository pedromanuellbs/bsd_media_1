// face_ai/face_login.dart
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class FaceLoginPage extends StatefulWidget {
  final CameraDescription camera;
  final bool isClient;
  final String username;

  const FaceLoginPage({
    Key? key,
    required this.camera,
    required this.isClient,
    required this.username,
  }) : super(key: key);

  @override
  State<FaceLoginPage> createState() => _FaceLoginPageState();
}

class _FaceLoginPageState extends State<FaceLoginPage> {
  CameraController? _controller;
  bool _processing = false;
  String? _resultMessage;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    _controller = CameraController(
      widget.camera,
      ResolutionPreset.medium,
      enableAudio: false,
    );
    await _controller!.initialize();
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _captureAndVerify() async {
    if (_controller == null || !_controller!.value.isInitialized) return;

    setState(() {
      _processing = true;
      _resultMessage = null;
    });

    try {
      final tmpDir = await getTemporaryDirectory();
      final filePath =
          '${tmpDir.path}/${DateTime.now().millisecondsSinceEpoch}.jpg';
      await _controller!.takePicture().then(
        (file) => File(file.path).copySync(filePath),
      );

      // Kirim foto ke backend untuk face verification (find-face-users)
      final request = http.MultipartRequest(
        'POST',
        Uri.parse(
          'https://backendlbphbsdmedia-production.up.railway.app/find-face-users',
        ), // GANTI DENGAN URL BACKEND KAMU
      );
      request.fields['user_id'] =
          widget
              .username; // Pastikan isinya UID, bukan username jika backend butuh UID

      request.files.add(await http.MultipartFile.fromPath('image', filePath));

      final response = await request.send();

      if (response.statusCode == 200) {
        final responseStr = await response.stream.bytesToString();
        final jsonResp = json.decode(responseStr);

        if (jsonResp['success'] == true &&
            (jsonResp['matched_photos'] as List).isNotEmpty) {
          setState(() {
            _resultMessage = "Autentikasi wajah berhasil. Selamat datang!";
          });
          Navigator.pop(
            context,
            true,
          ); // Sukses, kembali ke sign_in dan lanjut ke Home
        } else {
          setState(() {
            _resultMessage = "Autentikasi wajah gagal. Silakan coba lagi.";
          });
        }
      } else {
        setState(() {
          _resultMessage = "Terjadi error pada server. Coba lagi nanti.";
        });
      }
    } catch (e) {
      setState(() {
        _resultMessage = "Gagal mengambil gambar atau memproses wajah.";
      });
    } finally {
      setState(() {
        _processing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Wajah Kamu'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_controller != null && _controller!.value.isInitialized)
              SizedBox(
                width: 220,
                height: 220,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: CameraPreview(_controller!),
                ),
              )
            else
              const CircularProgressIndicator(),
            const SizedBox(height: 24),
            const Text(
              'Scan Wajah Kamu',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              icon: const Icon(Icons.camera_alt),
              label: Text(_processing ? 'Memproses...' : 'Capture'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 36,
                  vertical: 16,
                ),
                backgroundColor: Colors.deepPurple,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                textStyle: const TextStyle(fontSize: 18),
              ),
              onPressed: _processing ? null : _captureAndVerify,
            ),
            if (_resultMessage != null) ...[
              const SizedBox(height: 24),
              Text(
                _resultMessage!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color:
                      _resultMessage!.contains("berhasil")
                          ? Colors.greenAccent
                          : Colors.redAccent,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
