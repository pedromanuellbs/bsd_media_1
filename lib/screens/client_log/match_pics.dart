// screens/client_log/match_pics.dart
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
// --- TAMBAHAN: Import halaman payment.dart ---
import './payment.dart';

class MatchPicsPage extends StatefulWidget {
  final List<Map<String, dynamic>> matchedPhotos;

  // --- TAMBAHAN: MAP SESSION ID TO DETAIL (optional, bisa di-pass dari search.dart) ---
  final Map<String, dynamic>? sessionDetailsMap;

  const MatchPicsPage({
    Key? key,
    required this.matchedPhotos,
    this.sessionDetailsMap,
  }) : super(key: key);

  @override
  _MatchPicsPageState createState() => _MatchPicsPageState();
}

class _MatchPicsPageState extends State<MatchPicsPage> {
  Map<String, dynamic>? _selectedPhoto;
  Map<String, dynamic>? _sessionDetails;
  bool _isLoadingDetails = false;

  // === Tambahkan variabel berikut di sini (di dalam _MatchPicsPageState) ===
  bool _showReportCard = false;
  int? _selectedReason;
  final List<String> _reportReasons = [
    "Foto tidak pantas atau mengandung unsur kekerasan",
    "Ini bukan saya",
    "Foto ini melanggar privasi",
  ];

  @override
  void initState() {
    super.initState();
    Intl.defaultLocale = 'id_ID';
  }

  void _showPhoto(Map<String, dynamic> photo) {
    setState(() {
      _selectedPhoto = photo;
      _sessionDetails = null;
      _isLoadingDetails = true;
      _showReportCard = false;
      _selectedReason = null;
    });
    final sessionIdFromPhoto = photo['sessionId'] as String?;
    _fetchSessionDetails(sessionIdFromPhoto);
  }

  Future<void> _fetchSessionDetails(String? sessionId) async {
    // --- Cek mapping session dari widget, jika ada, langsung pakai (lebih cepat) ---
    if (sessionId != null &&
        widget.sessionDetailsMap != null &&
        widget.sessionDetailsMap!.containsKey(sessionId)) {
      setState(() {
        _sessionDetails = widget.sessionDetailsMap![sessionId];
        _isLoadingDetails = false;
      });
      return;
    }
    // --- Jika mapping tidak ada, fallback ke Firestore (cara lama) ---
    if (sessionId == null || sessionId.isEmpty) {
      setState(() => _isLoadingDetails = false);
      return;
    }
    try {
      final sessionDoc =
          await FirebaseFirestore.instance
              .collection('photo_sessions')
              .doc(sessionId)
              .get();

      if (sessionDoc.exists) {
        final details = sessionDoc.data()!;
        final photographerId = details['photographerId'];
        String photographerName = 'Fotografer tidak diketahui';

        if (photographerId != null && photographerId.isNotEmpty) {
          final userDoc =
              await FirebaseFirestore.instance
                  .collection('users')
                  .doc(photographerId)
                  .get();
          if (userDoc.exists) {
            photographerName = userDoc.data()?['nama'] ?? photographerName;
          }
        }
        details['photographerName'] = photographerName;
        setState(() {
          _sessionDetails = details;
          _isLoadingDetails = false;
        });
      } else {
        setState(() {
          _sessionDetails = null;
          _isLoadingDetails = false;
        });
      }
    } catch (e) {
      setState(() {
        _sessionDetails = null;
        _isLoadingDetails = false;
      });
    }
  }

  void _hidePhoto() {
    setState(() {
      _selectedPhoto = null;
      _showReportCard = false;
      _selectedReason = null;
    });
  }

  String _formatDate(String? dateString) {
    if (dateString == null || dateString.isEmpty) {
      return 'Tanggal tidak diketahui';
    }
    try {
      final DateFormat formatter = DateFormat('d MMMM yyyy', 'id_ID');
      final DateTime dateTime = DateTime.parse(dateString);
      return formatter.format(dateTime);
    } catch (e) {
      return dateString;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Hasil Pencocokan')),
      body: Stack(
        children: [
          widget.matchedPhotos.isEmpty
              ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text(
                    'Tidak ada foto yang cocok ditemukan untuk wajah Anda.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 18),
                  ),
                ),
              )
              : GridView.builder(
                padding: const EdgeInsets.all(8.0),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 8.0,
                  mainAxisSpacing: 8.0,
                ),
                itemCount: widget.matchedPhotos.length,
                itemBuilder: (context, index) {
                  final photo = widget.matchedPhotos[index];
                  final thumbUrl =
                      photo['webContentLink'] ?? photo['thumbnailLink'] ?? '';
                  return GestureDetector(
                    onTap: () {
                      _showPhoto(photo);
                    },
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8.0),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          CachedNetworkImage(
                            imageUrl: thumbUrl,
                            fit: BoxFit.cover,
                            placeholder:
                                (context, url) => const Center(
                                  child: CircularProgressIndicator(),
                                ),
                            errorWidget:
                                (context, url, error) =>
                                    const Icon(Icons.error),
                          ),
                          Center(
                            child: Opacity(
                              opacity: 0.5,
                              child: Image.asset(
                                'assets/logo-bsd-media.png',
                                width: 120,
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
          if (_selectedPhoto != null)
            Container(
              color: Colors.black.withOpacity(0.8),
              child: Stack(
                children: [
                  Center(
                    child: Card(
                      margin: const EdgeInsets.all(24.0),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16.0),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Stack(
                              alignment: Alignment.center,
                              children: [
                                CachedNetworkImage(
                                  imageUrl:
                                      _selectedPhoto!['webContentLink'] ??
                                      _selectedPhoto!['thumbnailLink'] ??
                                      '',
                                  fit: BoxFit.fitWidth,
                                  placeholder:
                                      (context, url) => const Center(
                                        child: CircularProgressIndicator(),
                                      ),
                                  errorWidget:
                                      (context, url, error) => Container(
                                        color: Colors.grey[200],
                                        padding: const EdgeInsets.all(20),
                                        child: const Center(
                                          child: Text(
                                            'Gagal memuat gambar',
                                            textAlign: TextAlign.center,
                                            style: TextStyle(color: Colors.red),
                                          ),
                                        ),
                                      ),
                                ),
                                Opacity(
                                  opacity: 0.5,
                                  child: Image.asset(
                                    'assets/logo-bsd-media.png',
                                    width: 360,
                                    fit: BoxFit.contain,
                                  ),
                                ),
                              ],
                            ),
                            _buildSessionDetails(),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  ElevatedButton(
                                    onPressed:
                                        (_sessionDetails != null &&
                                                !_isLoadingDetails)
                                            ? () {
                                              Navigator.of(context).push(
                                                MaterialPageRoute(
                                                  builder:
                                                      (context) => PaymentPage(
                                                        photoDetails:
                                                            _selectedPhoto!,
                                                        sessionDetails:
                                                            _sessionDetails!,
                                                      ),
                                                ),
                                              );
                                            }
                                            : null,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor:
                                          Theme.of(context).primaryColor,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 12,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(
                                          8.0,
                                        ),
                                      ),
                                    ),
                                    child: const Text('Tebus Foto ini'),
                                  ),
                                  const SizedBox(height: 8),
                                  OutlinedButton(
                                    onPressed: () {
                                      setState(() {
                                        _showReportCard = true;
                                        _selectedReason = null;
                                      });
                                    },
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.red,
                                      side: const BorderSide(color: Colors.red),
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 12,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(
                                          8.0,
                                        ),
                                      ),
                                    ),
                                    child: const Text('Laporkan Foto ini'),
                                  ),
                                  // Card report SUDAH DIPINDAH KE LUAR Card preview!
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 16,
                    right: 16,
                    child: IconButton(
                      icon: const Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 30,
                      ),
                      onPressed: _hidePhoto,
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.black.withOpacity(0.5),
                        shape: const CircleBorder(),
                      ),
                    ),
                  ),
                  // Card report/modal DITAMPILKAN DI LUAR CARD PREVIEW
                  if (_showReportCard)
                    Container(
                      color: Colors.black54,
                      child: Center(
                        child: Card(
                          margin: const EdgeInsets.all(24.0),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16.0),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(20.0),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text(
                                  "Laporkan Foto Ini",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                const Text(
                                  "Silakan pilih alasan laporan Anda:",
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 16),
                                ...List.generate(
                                  _reportReasons.length,
                                  (i) => RadioListTile<int>(
                                    value: i,
                                    groupValue: _selectedReason,
                                    title: Text(_reportReasons[i]),
                                    onChanged: (val) {
                                      setState(() {
                                        _selectedReason = val;
                                      });
                                    },
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceEvenly,
                                  children: [
                                    ElevatedButton(
                                      onPressed:
                                          _selectedReason == null
                                              ? null
                                              : () {
                                                setState(() {
                                                  widget.matchedPhotos.remove(
                                                    _selectedPhoto,
                                                  );
                                                  _selectedPhoto = null;
                                                  _showReportCard = false;
                                                  _selectedReason = null;
                                                });
                                                ScaffoldMessenger.of(
                                                  context,
                                                ).showSnackBar(
                                                  const SnackBar(
                                                    content: Text(
                                                      'Laporan sudah terkirim!',
                                                    ),
                                                  ),
                                                );
                                              },
                                      child: const Text("Kirim Laporan"),
                                    ),
                                    OutlinedButton(
                                      onPressed: () {
                                        setState(() {
                                          _showReportCard = false;
                                          _selectedReason = null;
                                        });
                                      },
                                      child: const Text("Batal"),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSessionDetails() {
    if (_isLoadingDetails) {
      return const Padding(
        padding: EdgeInsets.all(32.0),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_sessionDetails == null) {
      return const Padding(
        padding: EdgeInsets.all(16.0),
        child: Text(
          'Detail sesi tidak ditemukan.',
          textAlign: TextAlign.center,
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _sessionDetails!['title'] ?? 'Tanpa Judul',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.calendar_today, size: 14, color: Colors.black54),
              const SizedBox(width: 8),
              Text(
                _formatDate(_sessionDetails!['date']),
                style: const TextStyle(color: Colors.black54),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.location_on, size: 14, color: Colors.black54),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _sessionDetails!['location'] ?? 'Lokasi tidak diketahui',
                  style: const TextStyle(color: Colors.black54),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.camera_alt, size: 14, color: Colors.black54),
              const SizedBox(width: 8),
              Text(
                _sessionDetails!['photographerName'] ??
                    'Fotografer tidak diketahui',
                style: const TextStyle(color: Colors.black54),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
