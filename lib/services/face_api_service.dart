// services/face_api_service.dart
import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;

Future<bool> registerFaceLBPH(File faceImage, String userId) async {
  final req = http.MultipartRequest(
    'POST',
    Uri.parse('http://your-backend-url/register_face'),
  );
  req.fields['user_id'] = userId;
  req.files.add(await http.MultipartFile.fromPath('image', faceImage.path));
  final resp = await req.send();
  final respStr = await resp.stream.bytesToString();
  final result = json.decode(respStr);
  return result['success'] == true;
}
