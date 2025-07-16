// screens/auth/sign_up.dart
import 'dart:io' show File;
import 'dart:math';
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
import 'package:url_launcher/url_launcher.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

enum _SignUpMode { selection, client, photographer }

// Tambahan untuk multiple choice member status
enum MemberStatus { member, nonMember }

Future<bool> registerFaceLBPH(File faceImage, String userId) async {
  print(
    'DEBUG: file path: ${faceImage.path}, exists: ${await faceImage.exists()}, length: ${await faceImage.length()}',
  );

  final uri = Uri.parse(
    'https://backendlbphbsdmedia-production.up.railway.app/register_face',
  );
  final req =
      http.MultipartRequest('POST', uri)
        ..fields['user_id'] = userId
        ..files.add(await http.MultipartFile.fromPath('image', faceImage.path));

  final resp = await req.send();
  final body = await resp.stream.bytesToString();

  print('DEBUG: status=${resp.statusCode}, body=$body');

  if (resp.statusCode == 200) {
    final jsonResp = json.decode(body);
    return jsonResp['success'] == true;
  }
  return false;
}

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
  final _namaC = TextEditingController();
  final _eC = TextEditingController();
  final _pC = TextEditingController();
  final _cC = TextEditingController();
  bool _pwVis = false, _cpwVis = false, _loading = false, _agreedEula = false;
  bool _faceRegistered = false;
  File? _faceFile;

  // Tambahan untuk benefit preview
  bool _showBenefitCard = false;

  // Untuk card kode member
  bool _showMemberCodeCard = false;
  String? _memberCode;

  // Tambahkan untuk member status
  MemberStatus? _memberStatus;

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
      builder:
          (_) => AlertDialog(
            title: const Text('Registrasi Berhasil'),
            content: const Text('Silakan login dengan akun Anda.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
    );
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const SignInPage()),
    );
  }

  void _showError(String msg) {
    showDialog(
      context: context,
      builder:
          (_) => AlertDialog(
            title: const Text('Error'),
            content: Text(msg),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
    );
  }

  Widget _buildModeSelection() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'Kamu adalah?',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: ElevatedButton(
                onPressed:
                    () => setState(() {
                      _mode = _SignUpMode.client;
                      _agreedEula = false;
                    }),
                style: ElevatedButton.styleFrom(minimumSize: const Size(0, 48)),
                child: const Text('Klien'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ElevatedButton(
                onPressed:
                    () => setState(() => _mode = _SignUpMode.photographer),
                style: ElevatedButton.styleFrom(minimumSize: const Size(0, 48)),
                child: const Text('Fotografer'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ElevatedButton(
          onPressed:
              () => Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const SignInPage()),
              ),
          style: ElevatedButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
          ),
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
                validator: (v) => v == null || v.isEmpty ? 'Harus diisi' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _eC,
                decoration: const InputDecoration(labelText: 'Email'),
                validator: (v) => v == null || v.isEmpty ? 'Harus diisi' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _pC,
                obscureText: !_pwVis,
                decoration: InputDecoration(
                  labelText: 'Password',
                  suffixIcon: IconButton(
                    icon: Icon(
                      _pwVis ? Icons.visibility_off : Icons.visibility,
                    ),
                    onPressed: () => setState(() => _pwVis = !_pwVis),
                  ),
                ),
                validator:
                    (v) => v == null || v.length < 6 ? 'Min 6 karakter' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _cC,
                obscureText: !_cpwVis,
                decoration: InputDecoration(
                  labelText: 'Konfirmasi Password',
                  suffixIcon: IconButton(
                    icon: Icon(
                      _cpwVis ? Icons.visibility_off : Icons.visibility,
                    ),
                    onPressed: () => setState(() => _cpwVis = !_cpwVis),
                  ),
                ),
                validator: (v) => v != _pC.text ? 'Tidak cocok' : null,
              ),
              const SizedBox(height: 16),

              // Multiple choice Member BSD Media
              Row(
                children: [
                  Expanded(
                    child: RadioListTile<MemberStatus>(
                      title: const Text('Member BSD Media'),
                      value: MemberStatus.member,
                      groupValue: _memberStatus,
                      onChanged: (MemberStatus? value) {
                        setState(() {
                          _memberStatus = value;
                        });
                      },
                    ),
                  ),
                  Expanded(
                    child: RadioListTile<MemberStatus>(
                      title: const Text('Bukan Member BSD Media'),
                      value: MemberStatus.nonMember,
                      groupValue: _memberStatus,
                      onChanged: (MemberStatus? value) {
                        setState(() {
                          _memberStatus = value;
                        });
                      },
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 4),

              // Teks klik untuk preview benefit member
              GestureDetector(
                onTap: () {
                  showDialog(
                    context: context,
                    builder:
                        (context) => Dialog(
                          backgroundColor: Colors.transparent,
                          child: Container(
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: Colors.deepPurple.shade50,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  "Sebagai Member BSD Media, Anda akan mendapatkan:\n"
                                  "- Harga spesial untuk pemotretan\n"
                                  "- Prioritas booking jadwal\n"
                                  "- Akses ke event eksklusif\n"
                                  "- Support after-sale lebih cepat\n\n"
                                  "Info lebih lanjut hubungi admin BSD Media.",
                                  style: TextStyle(
                                    color: Colors.deepPurple[900],
                                    fontSize: 15,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      TextButton(
                                        onPressed: () async {
                                          // Ganti nomor berikut dengan nomor admin sebenarnya (format internasional tanpa +)
                                          const waUrl =
                                              'https://wa.me/6287818464990';
                                          if (await canLaunch(waUrl)) {
                                            await launch(waUrl);
                                          }
                                        },
                                        child: Row(
                                          children: [
                                            const FaIcon(
                                              FontAwesomeIcons.whatsapp,
                                              color: Colors.green,
                                              size: 20,
                                            ),
                                            const SizedBox(width: 6),
                                            const Text(
                                              "WA Admin",
                                              style: TextStyle(
                                                color: Colors.green,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      TextButton(
                                        onPressed: () => Navigator.pop(context),
                                        child: const Text(
                                          "Tutup",
                                          style: TextStyle(
                                            color: Colors.deepPurple,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                  );
                },
                child: Text(
                  'Lihat info benefit member BSD Media',
                  style: TextStyle(
                    color: Colors.deepPurple,
                    decoration: TextDecoration.underline,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),

              const SizedBox(height: 10),

              // Face Recognition
              ElevatedButton(
                onPressed:
                    _loading
                        ? null
                        : () async {
                          if (_eC.text.trim().isEmpty) {
                            _showError(
                              "Isi email terlebih dahulu sebelum registrasi wajah.",
                            );
                            return;
                          }

                          setState(() => _loading = true);
                          try {
                            final cams = await availableCameras();
                            final File? foto = await Navigator.push<File?>(
                              context,
                              MaterialPageRoute(
                                builder:
                                    (_) => FaceCapturePage(
                                      camera: cams.first,
                                      isClient: false,
                                      username:
                                          _uC.text
                                              .trim(), // <-- Atau pakai _eC.text.trim()
                                    ),
                              ),
                            );

                            if (foto != null) {
                              print(
                                'DEBUG_FLUTTER: File foto diterima dari FaceCapturePage. Path: ${foto.path}, exists: ${await foto.exists()}, length: ${await foto.length()}',
                              );
                            } else {
                              print(
                                'DEBUG_FLUTTER: FaceCapturePage mengembalikan null atau tidak ada foto.',
                              );
                            }

                            if (foto != null && await foto.exists()) {
                              final fileLength = await foto.length();
                              if (fileLength == 0) {
                                setState(() => _loading = false);
                                _showError(
                                  "File foto hasil capture kosong. Silakan ulangi pengambilan foto.",
                                );
                                return;
                              }
                              print(
                                'DEBUG: Siap upload file dengan size: $fileLength bytes',
                              );
                              final userId = _eC.text.trim();
                              final bool success = await registerFaceLBPH(
                                foto,
                                userId,
                              );
                              setState(() {
                                _loading = false;
                                _faceRegistered = success;
                                _faceFile = success ? foto : null;
                              });
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
                              _showError(
                                "Gagal mengambil foto wajah, coba lagi.",
                              );
                            }
                          } catch (e) {
                            setState(() => _loading = false);
                            _showError(
                              "Terjadi error saat proses registrasi wajah: $e",
                            );
                          }
                        },
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
                child:
                    _loading
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
                onPressed:
                    (!_faceRegistered || _loading)
                        ? null
                        : () async {
                          if (!_formKey.currentState!.validate() ||
                              !_agreedEula)
                            return;
                          if (_memberStatus == MemberStatus.member) {
                            // generate kode
                            final random = Random();
                            final code =
                                'BSDMEDIA${random.nextInt(900000) + 100000}';
                            setState(() {
                              _memberCode = code;
                              _showMemberCodeCard = true;
                            });
                            // Tampilkan card kode
                            await showDialog(
                              context: context,
                              barrierDismissible: false,
                              builder:
                                  (context) => Dialog(
                                    backgroundColor: Colors.transparent,
                                    child: Container(
                                      width: double.infinity,
                                      decoration: BoxDecoration(
                                        color: Colors.deepPurple.shade50,
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      padding: const EdgeInsets.all(20),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            "Kode Member BSD Media kamu:",
                                            style: TextStyle(
                                              color: Colors.deepPurple[900],
                                              fontWeight: FontWeight.bold,
                                              fontSize: 17,
                                            ),
                                          ),
                                          const SizedBox(height: 10),
                                          SelectableText(
                                            code,
                                            style: TextStyle(
                                              color: Colors.deepPurple,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 24,
                                              letterSpacing: 2,
                                            ),
                                          ),
                                          const SizedBox(height: 18),
                                          Text(
                                            "Kode ini bisa digunakan untuk verifikasi keanggotaan.",
                                            style: TextStyle(
                                              color: Colors.deepPurple[900],
                                              fontSize: 14,
                                            ),
                                            textAlign: TextAlign.center,
                                          ),
                                          const SizedBox(height: 16),
                                          Align(
                                            alignment: Alignment.centerRight,
                                            child: TextButton(
                                              onPressed:
                                                  () => Navigator.pop(context),
                                              child: const Text(
                                                "Lanjut",
                                                style: TextStyle(
                                                  color: Colors.deepPurple,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                            );
                            // Proses simpan ke firebase setelah kode tampil
                            try {
                              final cred = await FirebaseAuth.instance
                                  .createUserWithEmailAndPassword(
                                    email: _eC.text.trim(),
                                    password: _pC.text.trim(),
                                  );
                              await FirebaseFirestore.instance
                                  .collection('users')
                                  .doc(cred.user!.uid)
                                  .set({
                                    'username': _uC.text.trim(),
                                    'email': _eC.text.trim(),
                                    'role': 'client',
                                    'face_registered': true,
                                    'member_status': 'member',
                                    'member_code': code,
                                    'createdAt': FieldValue.serverTimestamp(),
                                  });
                              await _showSuccessAndGoLogin();
                            } on FirebaseAuthException catch (e) {
                              _showError(e.message ?? 'Gagal registrasi');
                            } finally {
                              if (mounted) setState(() => _loading = false);
                            }
                          } else {
                            // Non-member: langsung simpan tanpa card kode
                            try {
                              final cred = await FirebaseAuth.instance
                                  .createUserWithEmailAndPassword(
                                    email: _eC.text.trim(),
                                    password: _pC.text.trim(),
                                  );
                              await FirebaseFirestore.instance
                                  .collection('users')
                                  .doc(cred.user!.uid)
                                  .set({
                                    'username': _uC.text.trim(),
                                    'email': _eC.text.trim(),
                                    'role': 'client',
                                    'face_registered': true,
                                    'member_status': 'non_member',
                                    'createdAt': FieldValue.serverTimestamp(),
                                  });
                              await _showSuccessAndGoLogin();
                            } on FirebaseAuthException catch (e) {
                              _showError(e.message ?? 'Gagal registrasi');
                            } finally {
                              if (mounted) setState(() => _loading = false);
                            }
                          }
                        },
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
                child:
                    _loading
                        ? const CircularProgressIndicator()
                        : const Text('Register Client'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => setState(() => _mode = _SignUpMode.selection),
                child: const Text('Back'),
              ),
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
                width: 300,
                height: 380,
                child: Card(
                  margin: EdgeInsets.zero,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        const Text(
                          'PERJANJIAN PRIVASI DATA – BSD MEDIA',
                          style: TextStyle(fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        const Expanded(
                          child: SingleChildScrollView(
                            child: Text(
                              '''Dengan menyetujui, Anda memahami dan menerima poin-poin berikut:

1.  **Privasi Anda Terjamin:** Kami berkomitmen untuk melindungi privasi Anda. Data pribadi dan foto Anda tidak akan pernah dijual, disewakan, atau digunakan untuk tujuan periklanan oleh pihak manapun.

2.  **Enkripsi Data Wajah:** Untuk melindungi foto Anda, kami menggunakan teknologi enkripsi canggih pada data biometrik wajah. Hanya Anda yang dapat mengakses foto pribadi Anda setelah verifikasi.

3.  **Kontrol Penuh Atas Data:** Anda memiliki kontrol penuh atas data Anda. Anda dapat mencabut izin akses data dari pihak ketiga kapan saja melalui pengaturan akun Anda.

4.  **Ketentuan & Sanksi Hukum:** Setiap penyalahgunaan platform atau pelanggaran terhadap kebijakan privasi ini akan dikenakan sanksi sesuai dengan hukum dan peraturan yang berlaku di Indonesia. Syarat dan ketentuan lebih lanjut dapat dibaca pada dokumen terpisah.''',
                              textAlign: TextAlign.justify,
                            ),
                          ),
                        ),
                        CheckboxListTile(
                          title: const Text(
                            'Saya telah membaca dan menyetujui Perjanjian Privasi Data',
                          ),
                          value: _agreedEula,
                          onChanged: (v) => setState(() => _agreedEula = v!),
                          controlAffinity: ListTileControlAffinity.leading,
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
          TextFormField(
            controller: _uC,
            decoration: const InputDecoration(labelText: 'Username Fotografer'),
            validator: (v) => v == null || v.isEmpty ? 'Harus diisi' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _namaC,
            decoration: const InputDecoration(labelText: 'Nama Fotografer'),
            validator: (v) => v == null || v.isEmpty ? 'Harus diisi' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _eC,
            decoration: const InputDecoration(labelText: 'Email Fotografer'),
            validator: (v) => v == null || v.isEmpty ? 'Harus diisi' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _pC,
            obscureText: !_pwVis,
            decoration: InputDecoration(
              labelText: 'Password Fotografer',
              suffixIcon: IconButton(
                icon: Icon(_pwVis ? Icons.visibility_off : Icons.visibility),
                onPressed: () => setState(() => _pwVis = !_pwVis),
              ),
            ),
            validator:
                (v) => v == null || v.length < 6 ? 'Min 6 karakter' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _cC,
            obscureText: !_cpwVis,
            decoration: InputDecoration(
              labelText: 'Konfirmasi Password Fotografer',
              suffixIcon: IconButton(
                icon: Icon(_cpwVis ? Icons.visibility_off : Icons.visibility),
                onPressed: () => setState(() => _cpwVis = !_cpwVis),
              ),
            ),
            validator: (v) => v != _pC.text ? 'Tidak cocok' : null,
          ),

          const SizedBox(height: 24),

          ElevatedButton.icon(
            icon: const Icon(Icons.upload_file),
            label: Text(
              _qrisUrl == null ? 'Upload QRIS kamu' : 'QRIS ter-upload',
            ),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
            ),
            onPressed:
                _loading
                    ? null
                    : () async {
                      final result = await FilePicker.platform.pickFiles(
                        withData: kIsWeb,
                      );
                      if (result == null) return;
                      setState(() => _loading = true);
                      try {
                        final f = result.files.first;
                        final ref = FirebaseStorage.instance.ref(
                          'qris/${FirebaseAuth.instance.currentUser?.uid ?? 'temp'}/${f.name}',
                        );
                        if (kIsWeb) {
                          await ref.putData(f.bytes!);
                        } else {
                          await ref.putFile(File(f.path!));
                        }
                        _qrisUrl = await ref.getDownloadURL();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('QRIS berhasil di-upload!'),
                          ),
                        );
                      } catch (e) {
                        _showError('Upload QRIS gagal: $e');
                      } finally {
                        setState(() => _loading = false);
                      }
                    },
          ),

          const SizedBox(height: 16),

          ElevatedButton(
            onPressed:
                (_loading || _qrisUrl == null)
                    ? null
                    : () async {
                      if (!_formKey.currentState!.validate()) return;
                      setState(() => _loading = true);
                      try {
                        final username = _uC.text.trim();
                        final q =
                            await FirebaseFirestore.instance
                                .collection('users')
                                .where('username', isEqualTo: username)
                                .limit(1)
                                .get();

                        if (q.docs.isNotEmpty) {
                          _showError(
                            'Username sudah digunakan. Silakan pilih yang lain.',
                          );
                          setState(() => _loading = false);
                          return;
                        }
                        final cred = await FirebaseAuth.instance
                            .createUserWithEmailAndPassword(
                              email: _eC.text.trim(),
                              password: _pC.text.trim(),
                            );
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
                        setState(() => _loading = false);
                      }
                    },
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
            ),
            child:
                _loading
                    ? const CircularProgressIndicator()
                    : const Text('Daftar Fotografer'),
          ),

          const SizedBox(height: 8),
          TextButton(
            onPressed: () => setState(() => _mode = _SignUpMode.selection),
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
      case _SignUpMode.client:
        body = _clientForm();
        break;
      case _SignUpMode.photographer:
        body = _photogForm();
        break;
      default:
        body = _buildModeSelection();
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: body,
        ),
      ),
    );
  }
}
