// screens/home/profile_edit_page.dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({Key? key}) : super(key: key);

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _aboutCtrl = TextEditingController();

  bool isLoading = true;
  String? email;
  String? photoUrl;
  File? _newImageFile;
  late String uid;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => isLoading = false);
      return;
    }
    uid = user.uid;
    final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    setState(() {
      _nameCtrl.text = doc.data()?['username'] ?? user.displayName ?? '';
      _aboutCtrl.text = doc.data()?['about'] ?? '';
      email = user.email;
      photoUrl = doc.data()?['photoUrl'];
      isLoading = false;
    });
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    setState(() => isLoading = true);

    String? uploadedUrl = photoUrl;
    if (_newImageFile != null) {
      final fileName = 'profile_${user.uid}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final ref = FirebaseStorage.instance.ref().child('profile_images').child(fileName);
      await ref.putFile(_newImageFile!);
      uploadedUrl = await ref.getDownloadURL();
    }

    await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
      'username': _nameCtrl.text.trim(),
      'about': _aboutCtrl.text.trim(),
      'photoUrl': uploadedUrl,
    });

    setState(() => isLoading = false);

    if (mounted) {
      Navigator.of(context).pop(true);
    }
  }

  Future<void> _pickImage() async {
    try {
      final ImagePicker _picker = ImagePicker();
      final picked = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );
      if (picked != null) {
        setState(() {
          _newImageFile = File(picked.path);
          photoUrl = null; // Untuk preview
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal membuka galeri: $e')),
      );
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _aboutCtrl.dispose();
    super.dispose();
  }

  Widget _buildProfileImage() {
    Widget imageWidget;
    if (_newImageFile != null) {
      imageWidget = CircleAvatar(
        radius: 48,
        backgroundImage: FileImage(_newImageFile!),
      );
    } else if (photoUrl != null && photoUrl!.isNotEmpty) {
      imageWidget = CircleAvatar(
        radius: 48,
        backgroundImage: NetworkImage(photoUrl!),
      );
    } else {
      imageWidget = const CircleAvatar(
        radius: 48,
        backgroundColor: Colors.deepPurple,
        child: Icon(Icons.person, size: 48, color: Colors.white),
      );
    }
    return Stack(
      alignment: Alignment.bottomRight,
      children: [
        imageWidget,
        Positioned(
          bottom: 0,
          right: 6,
          child: InkWell(
            onTap: _pickImage,
            child: CircleAvatar(
              radius: 18,
              backgroundColor: Colors.white,
              child: Icon(Icons.camera_alt, color: Colors.deepPurple.shade700),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profile'),
        backgroundColor: Colors.deepPurple,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(24.0),
              child: Form(
                key: _formKey,
                child: ListView(
                  children: [
                    const SizedBox(height: 20),
                    Center(child: _buildProfileImage()),
                    const SizedBox(height: 30),
                    TextFormField(
                      controller: _nameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Full Name',
                        prefixIcon: Icon(Icons.person),
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? 'Nama wajib diisi' : null,
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      enabled: false,
                      initialValue: email ?? '',
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        prefixIcon: Icon(Icons.email),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _aboutCtrl,
                      decoration: const InputDecoration(
                        labelText: 'About',
                        prefixIcon: Icon(Icons.info_outline),
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 4,
                    ),
                    const SizedBox(height: 30),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.save),
                      label: const Text('Simpan'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepPurple,
                        minimumSize: const Size.fromHeight(48),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: isLoading ? null : _saveProfile,
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}