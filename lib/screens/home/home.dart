// screens/home/home.dart
import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:salomon_bottom_bar/salomon_bottom_bar.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:camera/camera.dart';

import 'search.dart';
import '../fg_log/create_fg.dart';
import '../fg_log/history_fg.dart';
import 'profile_page.dart';
import 'saved.dart';
import 'settings.dart';
import '../../face_ai/face_capture_page.dart';
import '../fg_log/history_pay.dart';

// Data class untuk sesi foto
class _PhotoSessionFeedData {
  final String photographerUsername;
  final String driveFolderUrl;
  final String photoSessionDate;
  final List<String> photoUrls;
  final String sessionTitle;
  _PhotoSessionFeedData({
    required this.photographerUsername,
    required this.driveFolderUrl,
    required this.photoSessionDate,
    required this.photoUrls,
    required this.sessionTitle,
  });
}

class HomePage extends StatefulWidget {
  final bool isMember;
  const HomePage({Key? key, required this.isMember}) : super(key: key);

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  int _selectedIndex = 0;
  bool _showEmptyFollowing = false;
  bool _isPhotographer = false;
  bool _isClient = false;
  late final PageController _pageController;
  bool _isLoading = true;
  List<_PhotoSessionFeedData> _feeds = [];
  String? photoUrl;

  static const _apiKey = 'AIzaSyC_vPd6yPwYQ60Pn-tuR3Nly_7mgXZcxGk';

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _fetchUserRoleAndData();
  }

  Future<void> _fetchUserRoleAndData() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      final snap =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final role = snap.data()?['role'] as String?;
      setState(() {
        _isPhotographer = (role == 'photographer');
        _isClient = (role == 'client');
      });
      if (_isClient) {
        await _loadPhotoSessionsFeed();
      }
      setState(() {
        _isLoading = false;
      });
    } else {
      setState(() {
        _isLoading = false;
        _isClient = false;
        _isPhotographer = false;
      });
    }
  }

  Future<void> _loadPhotoSessionsFeed() async {
    setState(() => _isLoading = true);
    final sessions =
        await FirebaseFirestore.instance
            .collection('photo_sessions')
            .orderBy('createdAt', descending: true)
            .get();
    List<_PhotoSessionFeedData> feeds = [];
    for (var doc in sessions.docs) {
      final data = doc.data();
      final driveLink = data['driveLink'] as String? ?? '';
      final photographerId = data['photographerId'] as String? ?? '';
      final date = data['date'] as String? ?? '';
      final sessionTitle = data['title'] as String? ?? '';
      if (driveLink.isEmpty || photographerId.isEmpty) {
        continue;
      }

      String photographerUsername = 'Fotografer';
      if (photographerId.isNotEmpty) {
        final userDoc =
            await FirebaseFirestore.instance
                .collection('users')
                .doc(photographerId)
                .get();
        photographerUsername = userDoc.data()?['username'] ?? 'Fotografer';
      }

      List<String> photoUrls = [];
      try {
        if (driveLink.isNotEmpty) {
          photoUrls = await _fetchImageUrls(driveLink);
        }
      } catch (e) {
        debugPrint('[ERROR] Gagal load foto dari Google Drive: $e');
      }

      if (photoUrls.isNotEmpty) {
        feeds.add(
          _PhotoSessionFeedData(
            photographerUsername: photographerUsername,
            driveFolderUrl: driveLink,
            photoSessionDate: date,
            photoUrls: photoUrls.take(5).toList(),
            sessionTitle: sessionTitle,
          ),
        );
      }
    }
    setState(() {
      _feeds = feeds;
      _isLoading = false;
    });
  }

  Future<List<String>> _fetchImageUrls(String folderUrl) async {
    final match =
        RegExp(r'/d/([^/]+)').firstMatch(folderUrl) ??
        RegExp(r'[?&]id=([^&]+)').firstMatch(folderUrl) ??
        RegExp(r'/folders/([^/?]+)').firstMatch(folderUrl);
    final folderId = match?.group(1);
    if (folderId == null) {
      throw 'Link Drive tidak valid';
    }

    final uri = Uri.https('www.googleapis.com', '/drive/v3/files', {
      'q': "'$folderId' in parents and mimeType contains 'image/'",
      'fields': 'files(id,name,thumbnailLink)',
      'key': _apiKey,
      'pageSize': '5',
      'orderBy': 'createdTime desc',
    });
    final resp = await http.get(uri);
    if (resp.statusCode != 200) {
      throw 'Drive API error ${resp.statusCode}';
    }
    final data = json.decode(resp.body) as Map<String, dynamic>;
    final files = (data['files'] as List).cast<Map<String, dynamic>>();
    return files.map<String>((f) {
      if (f['thumbnailLink'] != null) {
        return f['thumbnailLink'] as String;
      }
      return 'https://drive.google.com/uc?export=download&id=${f['id']}';
    }).toList();
  }

  Future<void> _navigateToFaceCapture() async {
    try {
      final cameras = await availableCameras();
      final frontCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      final result = await Navigator.push<File>(
        context,
        MaterialPageRoute(
          builder:
              (_) => FaceCapturePage(
                camera: frontCamera,
                isClient: _isClient,
                isMember: widget.isMember,
              ),
        ),
      );

      if (result != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Foto berhasil diambil: ${result.path}')),
        );
      }
    } catch (e) {
      debugPrint('Error navigasi ke face capture: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Gagal membuka kamera: $e')));
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isHome = _selectedIndex == 0;
    return Scaffold(
      extendBodyBehindAppBar: isHome,
      appBar:
          isHome
              ? (_isClient ? _buildHomeAppBar() : null)
              : AppBar(title: Text(_navTitle(_selectedIndex))),
      body: _buildPageBody(_selectedIndex),
      bottomNavigationBar: SalomonBottomBar(
        currentIndex: _selectedIndex,
        selectedItemColor: const Color(0xff6200ee),
        unselectedItemColor: const Color(0xff757575),
        onTap: (i) {
          setState(() {
            _selectedIndex = i;
            if (i != 0) _showEmptyFollowing = false;
          });
        },
        items: _navItems(),
      ),
    );
  }

  Widget _buildPageBody(int idx) {
    if (_isPhotographer && idx == 0) {
      return const HistoryPayPage();
    }
    if (_isClient && idx == 0) {
      // Kirim status member ke dalam feed
      return _buildPhotoSessionFeed(isMember: widget.isMember);
    }
    return _buildPlaceholder(idx);
  }

  PreferredSizeWidget _buildHomeAppBar() => PreferredSize(
    preferredSize: const Size.fromHeight(130),
    child: SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(width: 28),
            _buildFollowFeedToggle(),
            _buildActionIcons(),
          ],
        ),
      ),
    ),
  );

  Widget _buildFollowFeedToggle() => Expanded(
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        GestureDetector(
          onTap: () => setState(() => _showEmptyFollowing = true),
          child: Text(
            'Mengikuti',
            style: TextStyle(
              color: _showEmptyFollowing ? Colors.white70 : Colors.white,
              fontSize: 16,
            ),
          ),
        ),
        const SizedBox(width: 24),
        GestureDetector(
          onTap: () => setState(() => _showEmptyFollowing = false),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Feed',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Container(
                margin: const EdgeInsets.only(top: 4),
                height: 2,
                width: 24,
                color: Colors.white,
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _buildActionIcons() => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      const Icon(Icons.send, color: Colors.white, size: 28),
      const SizedBox(height: 4),
      const Text(
        'Kirim ke Wajah',
        style: TextStyle(color: Colors.white70, fontSize: 12),
      ),
      const SizedBox(height: 16),
      GestureDetector(
        onTap: _navigateToFaceCapture,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.camera_alt, color: Colors.white, size: 28),
            SizedBox(height: 4),
            Text(
              'Cari Foto Kamu',
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        ),
      ),
    ],
  );

  String _navTitle(int idx) {
    switch (idx) {
      case 1:
        return _isPhotographer ? 'History' : 'Saved';
      case 2:
        return _isPhotographer ? 'Buat Sesi Foto' : 'Cari Fotografer';
      case 3:
        return _isPhotographer ? 'Profile' : 'Profile';
      case 4:
        return 'Settings';
      default:
        return '';
    }
  }

  List<SalomonBottomBarItem> _navItems() {
    final localPhotoUrl = photoUrl;

    return [
      if (_isPhotographer)
        SalomonBottomBarItem(
          icon: const Icon(Icons.money_off_csred_rounded),
          title: const Text("History Pembelian"),
          selectedColor: Colors.purple,
        )
      else
        SalomonBottomBarItem(
          icon: const Icon(Icons.home),
          title: const Text("Home"),
          selectedColor: Colors.purple,
        ),
      if (_isPhotographer)
        SalomonBottomBarItem(
          icon: const Icon(Icons.history),
          title: const Text('History'),
          selectedColor: Colors.teal,
        )
      else if (_isClient)
        SalomonBottomBarItem(
          icon: const Icon(Icons.bookmark),
          title: const Text('Saved'),
          selectedColor: Colors.teal,
        ),
      SalomonBottomBarItem(
        icon: Icon(_isPhotographer ? Icons.add_circle : Icons.search),
        title: Text(_isPhotographer ? "Create" : "Search"),
        selectedColor: _isPhotographer ? Colors.green : Colors.orange,
      ),
      SalomonBottomBarItem(
        icon:
            (localPhotoUrl != null && localPhotoUrl.isNotEmpty)
                ? ClipRRect(
                  borderRadius: BorderRadius.circular(6.0),
                  child: Image.network(
                    localPhotoUrl,
                    width: 28,
                    height: 28,
                    fit: BoxFit.cover,
                  ),
                )
                : const Icon(Icons.person),
        title: Text(_isPhotographer ? "Fotografer" : "Profile"),
        selectedColor: Colors.teal,
      ),
      SalomonBottomBarItem(
        icon: const Icon(Icons.settings),
        title: const Text("Settings"),
        selectedColor: Colors.grey,
      ),
    ];
  }

  Widget _buildEmptyFollowing() => const Center(
    child: Text(
      'Kamu belum follow fotografer siapapun.',
      style: TextStyle(color: Colors.black, fontSize: 18),
      textAlign: TextAlign.center,
    ),
  );

  // Feed untuk klien: daftar sesi foto dengan slideshow animasi black fade
  Widget _buildPhotoSessionFeed({required bool isMember}) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_feeds.isEmpty) {
      return const Center(child: Text('Belum ada sesi foto dari fotografer.'));
    }
    return PageView.builder(
      controller: _pageController,
      scrollDirection: Axis.vertical,
      itemCount: _feeds.length,
      itemBuilder: (context, idx) {
        final feed = _feeds[idx];
        // isMember dikirim ke PhotoSessionSlide
        return PhotoSessionSlide(feed: feed, isMember: isMember);
      },
    );
  }

  Widget _buildPlaceholder(int idx) {
    switch (idx) {
      case 1:
        if (_isPhotographer) {
          return const HistoryFGPage();
        } else if (_isClient) {
          return const SavedPage();
        } else {
          return const SizedBox.shrink();
        }
      case 2:
        if (_isPhotographer) {
          return const CreateFGForm();
        } else if (_isClient) {
          return PhotographerSearchPage(isMember: widget.isMember);
        } else {
          return const SizedBox.shrink();
        }
      case 3:
        return Builder(
          builder: (context) {
            try {
              return const ProfilePage();
            } catch (e) {
              return const Center(child: Text('Profile'));
            }
          },
        );
      case 4:
        return const SettingsPage2();
      default:
        return const SizedBox.shrink();
    }
  }
}

// Widget slideshow animasi black fade per sesi foto
class PhotoSessionSlide extends StatefulWidget {
  final _PhotoSessionFeedData feed;
  final bool isMember;
  const PhotoSessionSlide({
    Key? key,
    required this.feed,
    required this.isMember,
  }) : super(key: key);

  @override
  State<PhotoSessionSlide> createState() => _PhotoSessionSlideState();
}

class _PhotoSessionSlideState extends State<PhotoSessionSlide>
    with SingleTickerProviderStateMixin {
  int _currentIdx = 0;
  late AnimationController _controller;
  late Animation<double> _fadeAnim;
  Timer? _timer;
  ImageStream? _watermarkStream;
  ui.Image? _watermarkImage;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeAnim = Tween(begin: 1.0, end: 0.0).animate(_controller);
    _startSlideshow();
    if (!widget.isMember) {
      _loadWatermark();
    }
  }

  void _startSlideshow() {
    _timer = Timer.periodic(const Duration(seconds: 6), (timer) async {
      await _controller.forward(from: 0);
      if (!mounted) return;
      setState(() {
        _currentIdx = (_currentIdx + 1) % widget.feed.photoUrls.length;
      });
      _controller.reset();
    });
  }

  void _loadWatermark() async {
    final provider = AssetImage('assets/logo-bsd-media.png');
    _watermarkStream = provider.resolve(const ImageConfiguration());
    _watermarkStream!.addListener(
      ImageStreamListener((imageInfo, _) {
        setState(() {
          _watermarkImage = imageInfo.image;
        });
      }),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    _watermarkStream?.removeListener(ImageStreamListener((_, __) {}));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final url = widget.feed.photoUrls[_currentIdx];
    final photographerName = widget.feed.photographerUsername;
    final uploadDate = widget.feed.photoSessionDate;

    return Stack(
      fit: StackFit.expand,
      children: [
        Container(color: Colors.black),
        FadeTransition(
          opacity: _fadeAnim,
          child:
              (widget.isMember)
                  // Jika member, tampilkan gambar tanpa watermark
                  ? CachedNetworkImage(
                    imageUrl: url,
                    fit: BoxFit.cover,
                    placeholder:
                        (ctx, _) =>
                            const Center(child: CircularProgressIndicator()),
                    errorWidget: (ctx, url, error) {
                      debugPrint('[ERROR] Failed to load image: $url\n$error');
                      return Container(
                        color: Colors.grey[200],
                        child: const Icon(
                          Icons.broken_image,
                          color: Colors.grey,
                        ),
                      );
                    },
                  )
                  // Jika non-member, tampilkan gambar dengan watermark
                  : WatermarkedImage(
                    imageUrl: url,
                    watermarkImage: _watermarkImage,
                  ),
        ),
        Positioned(
          left: 16,
          bottom: 40,
          right: 24,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 60,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.grey[400],
                ),
                child: const Icon(Icons.person, color: Colors.white, size: 30),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    photographerName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    uploadDate,
                    style: const TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class WatermarkedImage extends StatelessWidget {
  final String imageUrl;
  final ui.Image? watermarkImage;

  const WatermarkedImage({
    Key? key,
    required this.imageUrl,
    required this.watermarkImage,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        return Stack(
          fit: StackFit.expand,
          children: [
            CachedNetworkImage(
              imageUrl: imageUrl,
              fit: BoxFit.cover,
              placeholder:
                  (ctx, _) => const Center(child: CircularProgressIndicator()),
              errorWidget: (ctx, url, error) {
                debugPrint('[ERROR] Failed to load image: $url\n$error');
                return Container(
                  color: Colors.grey[200],
                  child: const Icon(Icons.broken_image, color: Colors.grey),
                );
              },
            ),
            if (watermarkImage != null)
              IgnorePointer(
                child: CustomPaint(
                  size: Size(box.maxWidth, box.maxHeight),
                  painter: WatermarkPainter(watermarkImage!, opacity: 0.65),
                ),
              ),
          ],
        );
      },
    );
  }
}

class WatermarkPainter extends CustomPainter {
  final ui.Image watermark;
  final double opacity;

  WatermarkPainter(this.watermark, {this.opacity = 0.65});

  @override
  void paint(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..color = Color.fromARGB((255 * opacity).toInt(), 255, 255, 255)
          ..filterQuality = FilterQuality.high
          ..isAntiAlias = true;

    final double watermarkWidth = size.width * 0.85;
    final double scale = watermarkWidth / watermark.width;
    final double watermarkHeight = watermark.height * scale;

    final Offset center = Offset(
      (size.width - watermarkWidth) / 2,
      (size.height - watermarkHeight) / 2,
    );

    paint.color = paint.color.withOpacity(opacity);

    canvas.saveLayer(Rect.fromLTWH(0, 0, size.width, size.height), Paint());
    canvas.drawImageRect(
      watermark,
      Rect.fromLTWH(
        0,
        0,
        watermark.width.toDouble(),
        watermark.height.toDouble(),
      ),
      Rect.fromLTWH(center.dx, center.dy, watermarkWidth, watermarkHeight),
      paint,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant WatermarkPainter oldDelegate) =>
      watermark != oldDelegate.watermark || opacity != oldDelegate.opacity;
}
