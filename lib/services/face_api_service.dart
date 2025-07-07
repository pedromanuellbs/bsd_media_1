// services/face_api_service.dart
import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart'; // Diperlukan untuk Navigator/Snackbar
import '../screens/client_log/match_pics.dart'; // Import ini sesuaikan dengan struktur project-mu

String? _sessionCookie; // Simpan session antar request

// Register
Future<bool> registerFaceLBPH(File faceImage, String userId) async {
  print('[DEBUG] Masuk registerFaceLBPH');
  final req = http.MultipartRequest('POST', Uri.parse('http://127.0.0.1:8000/register_face'));
  req.fields['user_id'] = userId;
  req.files.add(await http.MultipartFile.fromPath('image', faceImage.path));
  try {
    final res = await req.send();
    final respStr = await res.stream.bytesToString();
    print('[DEBUG] Response string registerFaceLBPH: $respStr');
    final result = json.decode(respStr);
    print('[DEBUG] Hasil decode registerFaceLBPH: $result');
    return result['success'] == true;
  } catch (e, s) {
    print('[DEBUG] ERROR registerFaceLBPH: $e\nStack: $s');
    rethrow;
  }
}

// Verifikasi (simpen cookie session)
Future<bool> verifyFaceLBPH(File faceImage, String userId) async {
  print('[DEBUG] Masuk verifyFaceLBPH');
  final req = http.MultipartRequest('POST', Uri.parse('http://127.0.0.1:8000/verify_face'));
  req.fields['user_id'] = userId;
  req.files.add(await http.MultipartFile.fromPath('image', faceImage.path));
  try {
    final res = await req.send();
    print('[DEBUG] Response headers verifyFaceLBPH: ${res.headers}');
    if (res.headers.containsKey('set-cookie')) {
      final cookies = res.headers['set-cookie'];
      final match = RegExp(r'session=([^;]+);').firstMatch(cookies!);
      if (match != null) {
        _sessionCookie = 'session=${match.group(1)}';
        print('[DEBUG] Session cookie setelah verify: $_sessionCookie');
      } else {
        print('[DEBUG] Cookie session tidak ditemukan dari set-cookie!');
      }
    } else {
      print('[DEBUG] Tidak ada set-cookie di response verify!');
    }
    final respStr = await res.stream.bytesToString();
    print('[DEBUG] Response string verifyFaceLBPH: $respStr');
    final result = json.decode(respStr);
    print('[DEBUG] Hasil decode verifyFaceLBPH: $result');
    return result['success'] == true;
  } catch (e, s) {
    print('[DEBUG] ERROR verifyFaceLBPH: $e\nStack: $s');
    rethrow;
  }
}

// Cari foto (harus sudah verified)
Future<Map<String, dynamic>> findMyPhotosLBPH(File faceImage) async {
  print('[DEBUG] Masuk findMyPhotosLBPH');
  final req = http.MultipartRequest('POST', Uri.parse('http://127.0.0.1:8000/find_my_photos'));
  req.files.add(await http.MultipartFile.fromPath('image', faceImage.path));
  try {
    if (_sessionCookie != null) {
      req.headers['cookie'] = _sessionCookie!;
      print('[DEBUG] Session cookie sebelum kirim find_my_photos: $_sessionCookie');
    } else {
      print('[DEBUG] Session cookie sebelum kirim find_my_photos: NULL!');
    }
    final res = await req.send();
    final respStr = await res.stream.bytesToString();
    print('[DEBUG] Response string findMyPhotosLBPH: $respStr');
    final result = json.decode(respStr) as Map<String, dynamic>;
    print('[DEBUG] Hasil decode findMyPhotosLBPH: $result');
    return result;
  } catch (e, s) {
    print('[DEBUG] ERROR di dalam findMyPhotosLBPH: $e\nStack: $s');
    rethrow;
  }
}

// Handler tombol scan (panggil dari page/widget, jangan lupa kirim userId dari sesi login)
Future<void> onScanPressed(BuildContext context, File faceImage, String userId) async {
  try {
    print('[DEBUG] Mulai verifikasi wajah');
    final verified = await verifyFaceLBPH(faceImage, userId);
    print('[DEBUG] Hasil verifikasi: $verified');
    if (verified) {
      print('[DEBUG] Verifikasi cocok! Cari foto...');
      final result = await findMyPhotosLBPH(faceImage);
      print('[DEBUG] Hasil findMyPhotosLBPH: $result');
      final matchedPhotos = (result['matched_photos'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => MatchPicsPage(matchedPhotos: matchedPhotos),
        ),
      );
    } else {
      print('[DEBUG] Verifikasi wajah gagal!');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Verifikasi wajah gagal.')),
      );
    }
  } catch (e, s) {
    print('[DEBUG] ERROR saat proses verifikasi/temukan foto: $e\nStack: $s');
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Terjadi error saat memproses foto.')),
    );
  }
}
