// screens/auth/sign_up.dart

import 'dart:io' show File;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:bsd_media/face_ai/face_capture_page.dart';
import 'sign_in.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

enum _SignUpMode { selection, client, photographer }

// 1) Helper untuk register wajah ke LBPH-backend
Future<bool> registerFaceLBPH(File faceImage, String userId) async {
  print('DEBUG: file path: ${faceImage.path}, exists: ${await faceImage.exists()}, length: ${await faceImage.length()}');

  final uri = Uri.parse('https://backendlbphbsdmedia-production.up.railway.app/register_face');
  final req = http.MultipartRequest('POST', uri)
    ..fields['user_id'] = userId
    ..files.add(await http.MultipartFile.fromPath('image', faceImage.path)); // pastikan 'image' sesuai dengan backend

  final resp = await req.send();
  final body = await resp.stream.bytesToString();

  print('DEBUG: status=${resp.statusCode}, body=$body');

  if (resp.statusCode == 200) {
    final jsonResp = json.decode(body);
    return jsonResp['success'] == true;
  }
  return false;
}

// === Tambahkan class Photographer untuk database Firebase ===
class Photographer {
  final String id;
  final String username;
  final String nama;
  final String email;
  final String qrisUrl;
  final String role;
  final Timestamp? createdAt;

  Photographer({
    required this.id,
    required this.username,
    required this.nama,
    required this.email,
    required this.qrisUrl,
    this.role = 'photographer',
    this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'username': username,
        'nama': nama,
        'email': email,
        'qrisUrl': qrisUrl,
        'role': role,
        'createdAt': createdAt ?? FieldValue.serverTimestamp(),
      };

  factory Photographer.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Photographer(
      id: doc.id,
      username: data['username'] ?? '',
      nama: data['nama'] ?? '',
      email: data['email'] ?? '',
      qrisUrl: data['qrisUrl'] ?? '',
      role: data['role'] ?? 'photographer',
      createdAt: data['createdAt'],
    );
  }
}

class SignUpPage extends StatefulWidget {
  const SignUpPage({Key? key}) : super(key: key);
  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  _SignUpMode _mode = _SignUpMode.selection;
  final _formKey = GlobalKey<FormState>();
  final _uC = TextEditingController();
  final _namaC = TextEditingController(); // Controller untuk Nama Fotografer
  final _eC = TextEditingController();
  final _pC = TextEditingController();
  final _cC = TextEditingController();
  bool _pwVis = false, _cpwVis = false, _loading = false, _agreedEula = false;
  bool _faceRegistered = false;
  File? _faceFile; // Simpan file wajah klien untuk referensi jika mau

  @override
  void dispose() {
    _uC.dispose();
    _namaC.dispose();
    _eC.dispose();
    _pC.dispose();
    _cC.dispose();
    super.dispose();
  }

  Future<void> _showSuccessAndGoLogin() async {
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Registrasi Berhasil'),
        content: const Text('Silakan login dengan akun Anda.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK')),
        ],
      ),
    );
    if (!mounted) return;
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const SignInPage()));
  }

  void _showError(String msg) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Error'),
        content: Text(msg),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))
        ],
      ),
    );
  }

  Widget _buildModeSelection() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('Kamu adalah?', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: () => setState(() { _mode = _SignUpMode.client; _agreedEula = false; }),
          style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
          child: const Text('Klien'),
        ),
        const SizedBox(height: 8),
        ElevatedButton(
          onPressed: () => setState(() => _mode = _SignUpMode.photographer),
          style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
          child: const Text('Fotografer'),
        ),
        const SizedBox(height: 8),
        ElevatedButton(
          onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const SignInPage())),
          style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
          child: const Text('Kembali'),
        ),
      ],
    );
  }
  String? _qrisUrl;  

  Widget _clientForm() {
    return Stack(
      children: [
        Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(24),
            shrinkWrap: true,
            children: [
              TextFormField(
                controller: _uC,
                decoration: const InputDecoration(labelText: 'Username'),
                validator: (v) => v==null||v.isEmpty?'Harus diisi':null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _eC,
                decoration: const InputDecoration(labelText: 'Email'),
                validator: (v) => v==null||v.isEmpty?'Harus diisi':null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _pC,
                obscureText: !_pwVis,
                decoration: InputDecoration(
                  labelText: 'Password',
                  suffixIcon: IconButton(
                    icon: Icon(_pwVis?Icons.visibility_off:Icons.visibility),
                    onPressed: ()=> setState(()=>_pwVis=!_pwVis),
                  ),
                ),
                validator: (v)=> v==null||v.length<6?'Min 6 karakter':null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _cC,
                obscureText: !_cpwVis,
                decoration: InputDecoration(
                  labelText: 'Konfirmasi Password',
                  suffixIcon: IconButton(
                    icon: Icon(_cpwVis?Icons.visibility_off:Icons.visibility),
                    onPressed: ()=>setState(()=>_cpwVis=!_cpwVis),
                  ),
                ),
                validator: (v)=> v!=_pC.text?'Tidak cocok':null,
              ),
              const SizedBox(height: 16),

              // Face Recognition
              ElevatedButton(
                onPressed: _loading
                    ? null
                    : () async {
                        // SARAN: Pastikan email sudah diisi sebelum registrasi wajah
                        if (_eC.text.trim().isEmpty) {
                          _showError("Isi email terlebih dahulu sebelum registrasi wajah.");
                          return;
                        }

                        setState(() => _loading = true);
                        final cams = await availableCameras();
                        final File? foto = await Navigator.push<File?>(
  context,
  MaterialPageRoute(builder: (_) => FaceCapturePage(camera: cams.first, isClient: false)),
);
                        if (foto != null && await foto.exists() && await foto.length() > 0) {
  final userId = _eC.text.trim();
  final bool success = await registerFaceLBPH(foto, userId);
                          setState(() {
                            _loading = false;
                            _faceRegistered = success;
                            _faceFile = success ? foto : null;
                          });
                          // SARAN: Tampilkan hasil log ke user jika gagal
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                success
                                    ? 'Registrasi wajah berhasil!'
                                    : 'Registrasi wajah gagal! (lihat log untuk detail)',
                              ),
                            ),
                          );
                        } else {
  setState(() => _loading = false);
  _showError("Gagal mengambil foto wajah, coba lagi.");
}
                      },
                style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                child: _loading
                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(
                        _faceRegistered
                            ? 'Wajah sudah teregistrasi'
                            : 'Face Recognition',
                      ),
              ),

              const SizedBox(height: 8),

              // Register Client
              ElevatedButton(
                onPressed: (!_faceRegistered || _loading) ? null : () async {
                  if (!_formKey.currentState!.validate()||!_agreedEula) return;
                  setState(()=>_loading=true);
                  try {
                    final cred = await FirebaseAuth.instance
                      .createUserWithEmailAndPassword(email:_eC.text.trim(),password:_pC.text.trim());
                    await FirebaseFirestore.instance.collection('users').doc(cred.user!.uid).set({
                      'username':_uC.text.trim(),
                      'email':_eC.text.trim(),
                      'role':'client',
                      'face_registered': true, // Status face recognition
                      'createdAt':FieldValue.serverTimestamp(),
                    });
                    await _showSuccessAndGoLogin();
                  } on FirebaseAuthException catch(e) {
                    _showError(e.message??'Gagal registrasi');
                  } finally {
                    if(mounted) setState(()=>_loading=false);
                  }
                },
                style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                child: _loading?const CircularProgressIndicator():const Text('Register Client'),
              ),
              const SizedBox(height: 8),
              TextButton(onPressed: ()=>setState(()=>_mode=_SignUpMode.selection), child: const Text('Back')),
            ],
          ),
        ),

        // EULA overlay
        if (!_agreedEula)
          Positioned.fill(
            child: Container(
              color: Colors.black54,
              alignment: Alignment.center,
              child: SizedBox(
                width: 300, height: 380,
                child: Card(
                  margin: EdgeInsets.zero,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        const Text('PERJANJIAN PRIVASI DATA – BSD MEDIA',
                          style: TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                        const SizedBox(height: 8),
                        const Expanded(child: SingleChildScrollView(
                          child: Text('… isi EULA singkat di sini …'),
                        )),
                        CheckboxListTile(
                          title: const Text('Saya setuju'),
                          value: _agreedEula,
                          onChanged: (v)=> setState(()=>_agreedEula=v!),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _photogForm() {
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(24),
        shrinkWrap: true,
        children: [
          // Username Fotografer
          TextFormField(
            controller: _uC,
            decoration: const InputDecoration(labelText: 'Username Fotografer'),
            validator: (v)=>v==null||v.isEmpty?'Harus diisi':null,
          ),
          const SizedBox(height: 12),
          // === Tambahkan Nama Fotografer ===
          TextFormField(
            controller: _namaC,
            decoration: const InputDecoration(labelText: 'Nama Fotografer'),
            validator: (v)=>v==null||v.isEmpty?'Harus diisi':null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _eC,
            decoration: const InputDecoration(labelText: 'Email Fotografer'),
            validator: (v)=>v==null||v.isEmpty?'Harus diisi':null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _pC,
            obscureText: !_pwVis,
            decoration: InputDecoration(
              labelText: 'Password Fotografer',
              suffixIcon: IconButton(
                icon: Icon(_pwVis?Icons.visibility_off:Icons.visibility),
                onPressed: ()=>setState(()=>_pwVis=!_pwVis),
              ),
            ),
            validator: (v)=>v==null||v.length<6?'Min 6 karakter':null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _cC,
            obscureText: !_cpwVis,
            decoration: InputDecoration(
              labelText: 'Konfirmasi Password Fotografer',
              suffixIcon: IconButton(
                icon: Icon(_cpwVis?Icons.visibility_off:Icons.visibility),
                onPressed: ()=>setState(()=>_cpwVis=!_cpwVis),
              ),
            ),
            validator: (v)=>v!=_pC.text?'Tidak cocok':null,
          ),

          const SizedBox(height: 24),

          // == NEW: Upload QRIS Button ==
          ElevatedButton.icon(
            icon: const Icon(Icons.upload_file),
            label: Text(_qrisUrl == null ? 'Upload QRIS kamu' : 'QRIS ter-upload'),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
            ),
            onPressed: _loading ? null : () async {
              // pilih file
              final result = await FilePicker.platform.pickFiles(withData: kIsWeb);
              if (result == null) return; // batal
              setState(() => _loading = true);
              try {
                final f = result.files.first;
                final ref = FirebaseStorage.instance
                    .ref('qris/${FirebaseAuth.instance.currentUser?.uid ?? 'temp'}/${f.name}');
                if (kIsWeb) {
                  await ref.putData(f.bytes!);
                } else {
                  await ref.putFile(File(f.path!));
                }
                _qrisUrl = await ref.getDownloadURL();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('QRIS berhasil di-upload!')),
                );
              } catch (e) {
                _showError('Upload QRIS gagal: $e');
              } finally {
                setState(() => _loading = false);
              }
            },
          ),

          const SizedBox(height: 16),

          // Daftar Fotografer (only enabled if QRIS sudah di-upload)
          ElevatedButton(
            onPressed: (_loading || _qrisUrl == null) ? null : () async {
              if (!_formKey.currentState!.validate()) return;
              setState(()=>_loading=true);
              try {
                // 1) Auth
                final cred = await FirebaseAuth.instance
                  .createUserWithEmailAndPassword(
                    email: _eC.text.trim(),
                    password: _pC.text.trim(),
                  );
                // 2) Simpan di Firestore
                final photographer = Photographer(
                  id: cred.user!.uid,
                  username: _uC.text.trim(),
                  nama: _namaC.text.trim(),
                  email: _eC.text.trim(),
                  qrisUrl: _qrisUrl!,
                );
                await FirebaseFirestore.instance
                  .collection('users')
                  .doc(cred.user!.uid)
                  .set(photographer.toMap());
                await _showSuccessAndGoLogin();
              } on FirebaseAuthException catch (e) {
                _showError(e.message ?? 'Gagal registrasi');
              } finally {
                setState(()=>_loading=false);
              }
            },
            style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
            child: _loading
                ? const CircularProgressIndicator()
                : const Text('Daftar Fotografer'),
          ),

          const SizedBox(height: 8),
          TextButton(
            onPressed: ()=>setState(()=>_mode=_SignUpMode.selection),
            child: const Text('Back'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget body;
    switch (_mode) {
      case _SignUpMode.client:      body = _clientForm(); break;
      case _SignUpMode.photographer: body = _photogForm(); break;
      default:                       body = _buildModeSelection();
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 32),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
          child: body,
        ),
      ),
    );
  }
}