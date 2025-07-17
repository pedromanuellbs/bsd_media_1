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

enum MemberStatus { member, nonMember }

// Fungsi untuk memanggil endpoint register_face di backend
Future<bool> registerFaceLBPH(File faceImage, String userId) async {
  print(
    'DEBUG: Mengirim data ke backend. UserID: $userId, Path: ${faceImage.path}',
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

  print('DEBUG: Backend Response -> status=${resp.statusCode}, body=$body');

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

  // PERUBAHAN: Variabel untuk menyimpan file foto yang diambil
  File? _faceFile;

  bool _showBenefitCard = false;
  bool _showMemberCodeCard = false;
  String? _memberCode;
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
    if (!mounted) return;
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

  // Fungsi untuk menangani keseluruhan proses registrasi klien
  Future<void> _handleClientRegistration() async {
    // Validasi awal
    if (!_formKey.currentState!.validate() || !_agreedEula) {
      _showError("Harap isi semua data dan setujui perjanjian privasi.");
      return;
    }
    if (_faceFile == null) {
      _showError("Harap lakukan pengambilan foto wajah terlebih dahulu.");
      return;
    }
    if (_memberStatus == null) {
      _showError("Harap pilih status keanggotaan Anda.");
      return;
    }

    setState(() => _loading = true);

    UserCredential? cred; // Simpan kredensial untuk potensi rollback

    try {
      // LANGKAH 1: Buat user di Firebase Authentication
      print("Mencoba membuat user di Firebase Auth...");
      cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _eC.text.trim(),
        password: _pC.text.trim(),
      );
      final uid = cred.user?.uid;

      if (uid == null) {
        throw 'Gagal mendapatkan UID setelah membuat akun.';
      }
      print("User berhasil dibuat di Auth. UID: $uid");

      // LANGKAH 2: Kirim foto dan UID ke backend untuk registrasi wajah
      print("Mengirim data wajah ke backend...");
      final bool faceSuccess = await registerFaceLBPH(_faceFile!, uid);

      if (!faceSuccess) {
        throw 'Registrasi wajah di backend gagal. Silakan coba lagi.';
      }
      print("Registrasi wajah di backend berhasil.");

      // LANGKAH 3: Simpan data user ke Firestore
      print("Menyimpan data user ke Firestore...");
      String? newMemberCode;
      if (_memberStatus == MemberStatus.member) {
        final random = Random();
        newMemberCode = 'BSDMEDIA${random.nextInt(900000) + 100000}';
      }

      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'username': _uC.text.trim(),
        'email': _eC.text.trim(),
        'role': 'client',
        'face_registered': true,
        'member_status':
            _memberStatus == MemberStatus.member ? 'member' : 'non_member',
        'member_code': newMemberCode,
        'createdAt': FieldValue.serverTimestamp(),
      });
      print("Data user berhasil disimpan di Firestore.");

      // LANGKAH 4: Tampilkan dialog sukses
      if (_memberStatus == MemberStatus.member) {
        await _showMemberCodeDialog(newMemberCode!);
      }
      await _showSuccessAndGoLogin();
    } on FirebaseAuthException catch (e) {
      _showError(e.message ?? 'Gagal registrasi akun Firebase.');
    } catch (e) {
      // Rollback: Hapus user dari Auth jika langkah setelahnya gagal
      if (cred?.user != null) {
        print(
          "Terjadi error, melakukan rollback dengan menghapus user dari Auth...",
        );
        await cred!.user!.delete();
        print("User berhasil dihapus dari Auth.");
      }
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // Fungsi untuk menampilkan dialog kode member
  Future<void> _showMemberCodeDialog(String code) async {
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
                      onPressed: () => Navigator.pop(context),
                      child: const Text(
                        "Lanjut",
                        style: TextStyle(color: Colors.deepPurple),
                      ),
                    ),
                  ),
                ],
              ),
            ),
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
              Row(
                children: [
                  Expanded(
                    child: RadioListTile<MemberStatus>(
                      title: const Text('Member'),
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
                      title: const Text('Bukan Member'),
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
                                          const waUrl =
                                              'https://wa.me/6287818464990';
                                          if (await canLaunch(waUrl)) {
                                            await launch(waUrl);
                                          }
                                        },
                                        child: const Row(
                                          children: [
                                            FaIcon(
                                              FontAwesomeIcons.whatsapp,
                                              color: Colors.green,
                                              size: 20,
                                            ),
                                            SizedBox(width: 6),
                                            Text(
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
                child: const Text(
                  'Lihat info benefit member BSD Media',
                  style: TextStyle(
                    color: Colors.deepPurple,
                    decoration: TextDecoration.underline,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // PERUBAHAN: Tombol ini hanya untuk mengambil foto
              ElevatedButton(
                onPressed:
                    _loading
                        ? null
                        : () async {
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
                                    ),
                              ),
                            );
                            if (foto != null && await foto.exists()) {
                              setState(() {
                                _faceFile = foto; // Simpan file foto ke state
                              });
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Foto wajah berhasil diambil!'),
                                ),
                              );
                            } else {
                              _showError(
                                "Gagal mengambil foto wajah, coba lagi.",
                              );
                            }
                          } catch (e) {
                            _showError("Terjadi error saat membuka kamera: $e");
                          } finally {
                            setState(() => _loading = false);
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
                          _faceFile != null
                              ? 'Wajah sudah diambil (Ulangi)'
                              : 'Ambil Foto Wajah',
                        ),
              ),
              const SizedBox(height: 8),

              // PERUBAHAN: Tombol ini sekarang menjadi satu-satunya pemicu registrasi
              ElevatedButton(
                onPressed: _loading ? null : _handleClientRegistration,
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
    // ... (Kode form fotografer tidak diubah, tetap sama)
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
