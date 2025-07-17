// face_ai/face_login.dart
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:http/http.dart' as http;
import 'dart:io';
import 'dart:convert'; // <--- TAMBAHKAN BARIS INI

class FaceLoginPage extends StatefulWidget {
  final CameraDescription camera;
  final bool isClient;
  final String username;
  final List<String>? driveLinks;
  final Map<String, dynamic>? sessionDetailsMap;

  const FaceLoginPage({
    required this.camera,
    required this.isClient,
    required this.username,
    this.driveLinks,
    this.sessionDetailsMap,
    Key? key,
  }) : super(key: key);

  @override
  State<FaceLoginPage> createState() => _FaceLoginPageState();
}

class _FaceLoginPageState extends State<FaceLoginPage> {
  late CameraController _controller;
  Future<void>? _initFuture;
  bool _isLoading = false;
  XFile? _capturedFile; // Untuk preview image sebelum upload

  @override
  void initState() {
    super.initState();
    _controller = CameraController(widget.camera, ResolutionPreset.high);
    _initFuture = _controller.initialize();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onCapture() async {
    try {
      final XFile file = await _controller.takePicture();
      setState(() {
        _capturedFile = file;
      });
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Gagal mengambil gambar: $e')));
    }
  }

  // face_ai/face_login.dart

  Future<void> _onUpload() async {
    if (_capturedFile == null) return;
    setState(() => _isLoading = true);

    try {
      final uri = Uri.parse(
        'https://backendlbphbsdmedia-production.up.railway.app/face_login',
      );
      var request = http.MultipartRequest('POST', uri);
      // 'username' di sini berisi UID dari Firebase, sesuai kiriman dari sign_in.dart
      request.fields['username'] =
          widget.username; // isikan 'dummy9' atau yang diinput user
      request.files.add(
        await http.MultipartFile.fromPath('image', _capturedFile!.path),
      );

      final response = await request.send();
      final responseBody = await response.stream.bytesToString();

      // Pengecekan status code 200 untuk sukses
      if (response.statusCode == 200) {
        // Jika sukses, kembali ke halaman sign_in dengan nilai 'true'
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Verifikasi Wajah Berhasil!')),
          );
          Navigator.pop(context, true); // <--- PENTING
        }
      } else {
        // Jika gagal, tampilkan pesan error dan kembali dengan nilai 'false'
        if (mounted) {
          // Ambil pesan error dari JSON jika ada
          final errorMsg =
              json.decode(responseBody)['error'] ?? 'Verifikasi wajah gagal';
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Gagal: $errorMsg')));
          Navigator.pop(context, false); // <--- PENTING
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Terjadi error: $e')));
        Navigator.pop(context, false); // <--- PENTING
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _resetCapture() {
    setState(() {
      _capturedFile = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan Wajah Kamu')),
      body: Stack(
        children: [
          if (_capturedFile == null)
            FutureBuilder(
              future: _initFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.done) {
                  return CameraPreview(_controller);
                } else {
                  return const Center(child: CircularProgressIndicator());
                }
              },
            )
          else
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Preview Foto', style: TextStyle(fontSize: 18)),
                  const SizedBox(height: 16),
                  Image.file(
                    File(_capturedFile!.path),
                    width: 250,
                    height: 350,
                    fit: BoxFit.cover,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton.icon(
                        icon: Icon(Icons.check),
                        label: Text('Pakai Foto Ini'),
                        onPressed: _isLoading ? null : _onUpload,
                      ),
                      const SizedBox(width: 16),
                      ElevatedButton.icon(
                        icon: Icon(Icons.refresh),
                        label: Text('Ulangi'),
                        onPressed: _isLoading ? null : _resetCapture,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          if (_isLoading)
            Container(
              color: Colors.black45,
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
      floatingActionButton:
          _capturedFile == null
              ? FloatingActionButton(
                onPressed: _isLoading ? null : _onCapture,
                tooltip: 'Ambil Foto',
                child: const Icon(Icons.camera_alt),
              )
              : null,
    );
  }
}
