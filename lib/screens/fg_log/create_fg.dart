// screens/fg_log/create_fg.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CreateFGForm extends StatefulWidget {
  const CreateFGForm({Key? key}) : super(key: key);

  @override
  _CreateFGFormState createState() => _CreateFGFormState();
}

class _CreateFGFormState extends State<CreateFGForm> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl    = TextEditingController();
  final _dateCtrl     = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _linkCtrl     = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _dateCtrl.dispose();
    _locationCtrl.dispose();
    _linkCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      _dateCtrl.text = '${picked.year}-${picked.month.toString().padLeft(2,'0')}-${picked.day.toString().padLeft(2,'0')}';
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) throw 'User belum login';

      await FirebaseFirestore.instance
          .collection('photo_sessions')
          .add({
        'activityName'   : _titleCtrl.text.trim(),
        'date'           : _dateCtrl.text,
        'location'       : _locationCtrl.text.trim(),
        'driveLink'      : _linkCtrl.text.trim(),
        'photographerId' : uid,
        'createdAt'      : FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sesi foto berhasil disimpan')),
      );
      Navigator.of(context).pop();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Buat Sesi Foto'),
        backgroundColor: Colors.deepPurple,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Nama Kegiatan
              TextFormField(
                controller: _titleCtrl,
                decoration: InputDecoration(
                  labelText: 'Nama Kegiatan',
                  prefixIcon: const Icon(Icons.title),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                validator: (v) => v == null || v.isEmpty ? 'Isi nama kegiatan' : null,
              ),
              const SizedBox(height: 16),

              // Tanggal
              TextFormField(
                controller: _dateCtrl,
                readOnly: true,
                decoration: InputDecoration(
                  labelText: 'Tanggal Sesi Foto',
                  prefixIcon: const Icon(Icons.calendar_today),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onTap: _pickDate,
                validator: (v) => v == null || v.isEmpty ? 'Pilih tanggal' : null,
              ),
              const SizedBox(height: 16),

              // Lokasi
              TextFormField(
                controller: _locationCtrl,
                decoration: InputDecoration(
                  labelText: 'Lokasi',
                  prefixIcon: const Icon(Icons.location_on),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                validator: (v) => v == null || v.isEmpty ? 'Isi lokasi' : null,
              ),
              const SizedBox(height: 16),

              // Link Google Drive
              TextFormField(
                controller: _linkCtrl,
                decoration: InputDecoration(
                  labelText: 'Link Google Drive',
                  prefixIcon: const Icon(Icons.link),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Isi link Drive';
                  final uri = Uri.tryParse(v);
                  if (uri == null || !uri.isAbsolute) return 'Link tidak valid';
                  return null;
                },
              ),
              const SizedBox(height: 24),

              // Tombol Simpan
              ElevatedButton(
                onPressed: _loading ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: _loading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Simpan Sesi Foto'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
