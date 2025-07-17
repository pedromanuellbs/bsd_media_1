// screens/home/search.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:camera/camera.dart';
import '../../face_ai/face_capture_page.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'search.dart';

class PhotographerSearchPage extends StatefulWidget {
  final bool isMember; // <-- TAMBAHKAN INI

  const PhotographerSearchPage({
    Key? key,
    required this.isMember, // <-- TAMBAHKAN INI
  }) : super(key: key);

  @override
  State<PhotographerSearchPage> createState() => _PhotographerSearchPageState();
}

class _PhotographerSearchPageState extends State<PhotographerSearchPage> {
  String _query = '';
  List<Map<String, dynamic>> _results = [];
  List<String> _uids = [];
  bool _loading = false;
  bool? _isClient;

  @override
  void initState() {
    super.initState();
    _checkUserRole();
  }

  Future<void> _checkUserRole() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => _isClient = false);
      return;
    }
    final snap =
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
    setState(() {
      _isClient = (snap.data()?['role'] == 'client');
    });
  }

  Future<void> _searchPhotographer(String keyword) async {
    setState(() {
      _loading = true;
      _results = [];
      _uids = [];
    });

    final res =
        await FirebaseFirestore.instance
            .collection('users')
            .where('role', isEqualTo: 'photographer')
            .get();

    final filtered = <Map<String, dynamic>>[];
    final filteredUids = <String>[];

    for (final doc in res.docs) {
      final nama = doc['nama']?.toString().toLowerCase() ?? '';
      final username = doc['username']?.toString().toLowerCase() ?? '';
      if (nama.contains(keyword.toLowerCase()) ||
          username.contains(keyword.toLowerCase())) {
        filtered.add(doc.data() as Map<String, dynamic>);
        filteredUids.add(doc.id);
      }
    }

    setState(() {
      _results = filtered;
      _uids = filteredUids;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isClient == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_isClient == false) {
      return const Scaffold(
        body: Center(
          child: Text(
            "Fitur pencarian fotografer hanya tersedia untuk klien yang sudah login.",
            style: TextStyle(fontSize: 16),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return Scaffold(
      // appBar: AppBar(title: const Text('Cari Fotografer')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              decoration: InputDecoration(
                hintText: 'Cari nama atau username fotografer',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onChanged: (val) {
                setState(() => _query = val);
                if (val.isNotEmpty) {
                  _searchPhotographer(val);
                } else {
                  setState(() => _results = []);
                }
              },
            ),
            const SizedBox(height: 16),
            if (_loading) const CircularProgressIndicator(),
            if (!_loading)
              Expanded(
                child:
                    _results.isEmpty && _query.isNotEmpty
                        ? const Center(
                          child: Text('Tidak ada fotografer ditemukan.'),
                        )
                        : ListView.builder(
                          itemCount: _results.length,
                          itemBuilder: (ctx, i) {
                            final data = _results[i];
                            final uid = _uids[i];
                            return ListTile(
                              leading: const Icon(Icons.person),
                              title: Text(data['nama'] ?? '-'),
                              subtitle: Text('@${data['username'] ?? ''}'),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder:
                                        (_) => PhotographerProfilePage(
                                          photographerData: data,
                                          photographerUid: uid,
                                          isMember:
                                              widget
                                                  .isMember, // <-- TAMBAHKAN INI
                                        ),
                                  ),
                                );
                              },
                            );
                          },
                        ),
              ),
          ],
        ),
      ),
    );
  }
}

class PhotographerProfilePage extends StatelessWidget {
  final Map<String, dynamic> photographerData;
  final String photographerUid;
  final bool isMember; // <-- TAMBAHKAN INI

  const PhotographerProfilePage({
    Key? key,
    required this.photographerData,
    required this.photographerUid,
    required this.isMember, // <-- TAMBAHKAN INI
  }) : super(key: key);

  Future<void> _showSearchDialog(
    BuildContext context,
    List<QueryDocumentSnapshot> sessionDocs,
    List<String> driveLinks,
  ) async {
    // Buat mapping sessionId ke detail sesi
    final Map<String, dynamic> sessionDetailsMap = {
      for (var doc in sessionDocs) doc.id: doc.data(),
    };

    showDialog(
      context: context,
      builder:
          (dialogContext) => Center(
            child: Card(
              margin: const EdgeInsets.symmetric(horizontal: 32),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      "Kamu mau mencari foto di list ini?",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        ElevatedButton(
                          onPressed: () async {
                            Navigator.of(dialogContext).pop();
                            final cameras = await availableCameras();
                            final frontCamera = cameras.firstWhere(
                              (c) =>
                                  c.lensDirection == CameraLensDirection.front,
                              orElse: () => cameras.first,
                            );
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder:
                                    (_) => FaceCapturePage(
                                      camera: frontCamera,
                                      isClient: true,
                                      isMember:
                                          isMember, // <-- PAKAI isMember DARI KONSTRUKTOR
                                      driveLinks: driveLinks,
                                      sessionDetailsMap: sessionDetailsMap,
                                    ),
                              ),
                            );
                          },
                          child: const Text('Ya'),
                        ),
                        OutlinedButton(
                          onPressed: () {
                            Navigator.of(dialogContext).pop();
                          },
                          child: const Text('Tidak'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profil Fotografer')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.person, size: 50),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      photographerData['nama'] ?? '-',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text('@${photographerData['username'] ?? ''}'),
                    Text(photographerData['email'] ?? ''),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Text(
              'Sesi Foto:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 8),
            StreamBuilder(
              stream:
                  FirebaseFirestore.instance
                      .collection('photo_sessions')
                      .where('photographerId', isEqualTo: photographerUid)
                      .orderBy('createdAt', descending: true)
                      .snapshots(),
              builder: (context, AsyncSnapshot<QuerySnapshot> snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snap.hasData || snap.data!.docs.isEmpty) {
                  return const Text('Belum ada sesi foto.');
                }
                final driveLinks =
                    snap.data!.docs
                        .map((doc) => doc['driveLink'] as String)
                        .where((link) => link.isNotEmpty)
                        .toList();
                final sessionDocs = snap.data!.docs;
                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: sessionDocs.length,
                  itemBuilder: (ctx, i) {
                    final session =
                        sessionDocs[i].data() as Map<String, dynamic>;
                    final title = session['title'] ?? '';
                    final date = session['date'] ?? '';
                    final location = session['location'] ?? '';
                    final link = session['driveLink'] ?? '';
                    return Card(
                      child: ListTile(
                        title: Text(title),
                        subtitle: Text('$date - $location'),
                        onTap:
                            () => _showSearchDialog(
                              context,
                              sessionDocs,
                              driveLinks,
                            ),
                        trailing:
                            link != null && link != ''
                                ? IconButton(
                                  icon: const Icon(Icons.link),
                                  onPressed: () {
                                    // Bisa tambahkan buka link di browser
                                  },
                                )
                                : null,
                      ),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
