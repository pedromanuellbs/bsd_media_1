// services/face_api_service.dart
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

Future<bool> verifyFace(File faceImageFile) async {
  final req = http.MultipartRequest(
    'POST',
    Uri.parse('http://your-backend-url/verify_face'),
  );
  req.files.add(await http.MultipartFile.fromPath('image', faceImageFile.path));
  final resp = await req.send();
  final respStr = await resp.stream.bytesToString();
  final result = json.decode(respStr);
  return result['success'] == true;
}
