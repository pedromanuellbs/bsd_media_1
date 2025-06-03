// screens/home/home.dart
import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:salomon_bottom_bar/salomon_bottom_bar.dart';
import 'package:video_player/video_player.dart';

/// Data class untuk satu short
class _ShortData {
  final String assetPath;
  final String channelName;
  final String? channelAvatarUrl;
  final String title;
  final String views;
  final String timeAgo;
  final String likes;
  final String comments;

  _ShortData({
    required this.assetPath,
    required this.channelName,
    this.channelAvatarUrl,
    required this.title,
    required this.views,
    required this.timeAgo,
    required this.likes,
    required this.comments,
  });
}

/// Item bottom navigation
final _navBarItems = <SalomonBottomBarItem>[
  SalomonBottomBarItem(
    icon: const Icon(Icons.home),
    title: const Text("Home"),
    selectedColor: Colors.purple,
  ),
  SalomonBottomBarItem(
    icon: const Icon(Icons.favorite_border),
    title: const Text("Saved"),
    selectedColor: Colors.pink,
  ),
  SalomonBottomBarItem(
    icon: const Icon(Icons.search),
    title: const Text("Search"),
    selectedColor: Colors.orange,
  ),
  SalomonBottomBarItem(
    icon: const Icon(Icons.person),
    title: const Text("Profile"),
    selectedColor: Colors.teal,
  ),
  SalomonBottomBarItem(
    icon: const Icon(Icons.settings),
    title: const Text("Settings"),
    selectedColor: Colors.grey,
  ),
];

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;
  late final PageController _pageController;
  late final List<VideoPlayerController> _controllers;

  List<_ShortData> _shorts = [];
  bool _isLoading = true;

  // Untuk overlay ikon play/pause
  bool _showOverlay = false;
  int _overlayIndex = -1;

  int _currentShortIndex = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _loadShortsAndInit();
  }

  Future<void> _loadShortsAndInit() async {
    // 1) Baca AssetManifest.json
    final manifestJson = await rootBundle.loadString('AssetManifest.json');
    final Map<String, dynamic> manifestMap = json.decode(manifestJson);

    // 2) Filter hanya .mp4 di assets/vids/
    final videoPaths = manifestMap.keys
        .where((k) => k.startsWith('assets/vids/') && k.endsWith('.mp4'))
        .toList()
      ..sort();

    // 3) Buat list _ShortData dari path
    _shorts = videoPaths.map((path) {
      final name = path.split('/').last.replaceAll('.mp4', '');
      return _ShortData(
        assetPath: path,
        channelName: 'Channel $name',
        channelAvatarUrl: null,
        title: 'Short $name',
        views: '100K views',
        timeAgo: '1h ago',
        likes: '10K',
        comments: '5K',
      );
    }).toList();

    // 4) Inisialisasi VideoPlayerController untuk tiap video
    _controllers = _shorts.map((short) {
      final ctrl = kIsWeb
          ? VideoPlayerController.network(short.assetPath)
          : VideoPlayerController.asset(short.assetPath);
      ctrl.initialize().then((_) {
        ctrl.setLooping(true);
        setState(() {});
      });
      return ctrl;
    }).toList();

    // 5) Play hanya video pertama
    if (_controllers.isNotEmpty) {
      _controllers[0].play();
    }

    setState(() {
      _isLoading = false;
    });
  }

  @override
  void dispose() {
    for (var c in _controllers) {
      c.dispose();
    }
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Sembunyikan AppBar di tab Home
      appBar: _selectedIndex == 0
          ? null
          : AppBar(title: _navBarItems[_selectedIndex].title),
      body: _selectedIndex == 0
          ? _buildShortsFeed()
          : _buildPlaceholderContent(),
      bottomNavigationBar: SalomonBottomBar(
        currentIndex: _selectedIndex,
        selectedItemColor: const Color(0xff6200ee),
        unselectedItemColor: const Color(0xff757575),
        onTap: (i) => setState(() => _selectedIndex = i),
        items: _navBarItems,
      ),
    );
  }

  Widget _buildShortsFeed() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    return PageView.builder(
      controller: _pageController,
      scrollDirection: Axis.vertical,
      itemCount: _shorts.length,
      onPageChanged: (idx) {
        // pause video lama, play video baru
        _controllers[_currentShortIndex].pause();
        _currentShortIndex = idx;
        if (_controllers[idx].value.isInitialized) {
          _controllers[idx].play();
        }
      },
      itemBuilder: (context, idx) {
        final short = _shorts[idx];
        final ctrl = _controllers[idx];

        return Stack(fit: StackFit.expand, children: [
          // Video full-screen
          if (ctrl.value.isInitialized)
            FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: ctrl.value.size.width,
                height: ctrl.value.size.height,
                child: VideoPlayer(ctrl),
              ),
            )
          else
            const Center(child: CircularProgressIndicator()),

          // Overlay transparent untuk menangkap tap di mobile
          if (!kIsWeb)
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  // Toggle play/pause
                  if (ctrl.value.isPlaying) {
                    ctrl.pause();
                  } else {
                    ctrl.play();
                  }
                  // Tampilkan ikon
                  setState(() {
                    _overlayIndex = idx;
                    _showOverlay = true;
                  });
                  Future.delayed(const Duration(milliseconds: 500), () {
                    if (mounted) {
                      setState(() => _showOverlay = false);
                    }
                  });
                },
                child: Container(color: Colors.transparent),
              ),
            ),

          // Ikon overlay play/pause
          if (_showOverlay && _overlayIndex == idx)
            Center(
              child: AnimatedOpacity(
                opacity: 1.0,
                duration: const Duration(milliseconds: 200),
                child: Icon(
                  ctrl.value.isPlaying
                      ? Icons.pause_circle_filled
                      : Icons.play_circle_fill,
                  color: Colors.white.withOpacity(0.8),
                  size: 80,
                ),
              ),
            ),

          // Overlay channel + tombol Follow
          Positioned(
            top: 40,
            left: 16,
            child: Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundImage: short.channelAvatarUrl != null
                      ? NetworkImage(short.channelAvatarUrl!)
                      : null,
                  child: short.channelAvatarUrl == null
                      ? const Icon(Icons.person, color: Colors.white)
                      : null,
                ),
                const SizedBox(width: 8),
                Text(
                  short.channelName,
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 8),
                TextButton(
                  style: TextButton.styleFrom(
                    side: const BorderSide(color: Colors.white),
                    minimumSize: const Size(0, 0),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  ),
                  onPressed: () {},
                  child: const Text('Follow',
                      style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          ),

          // Judul + views di bawah
          Positioned(
            left: 16,
            bottom: 100,
            right: 100,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(short.title,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text('${short.views} • ${short.timeAgo}',
                    style: const TextStyle(
                        color: Colors.white70, fontSize: 14)),
              ],
            ),
          ),

          // Action icons di kanan
          Positioned(
            right: 16,
            bottom: 100,
            child: Column(
              children: [
                _ActionIcon(icon: Icons.thumb_up, label: short.likes),
                const SizedBox(height: 24),
                _ActionIcon(icon: Icons.comment, label: short.comments),
                const SizedBox(height: 24),
                _ActionIcon(icon: Icons.share, label: 'Share'),
                const SizedBox(height: 24),
                const Icon(Icons.more_vert, color: Colors.white, size: 32),
              ],
            ),
          ),
        ]);
      },
    );
  }

  Widget _buildPlaceholderContent() {
    switch (_selectedIndex) {
      case 1:
        return const Center(child: Text('Saved'));
      case 2:
        return const Center(child: Text('Search'));
      case 3:
        return const Center(child: Text('Profile'));
      case 4:
        return const Center(child: Text('Settings'));
      default:
        return const SizedBox.shrink();
    }
  }
}

/// Widget kecil untuk icon + label pada action column
class _ActionIcon extends StatelessWidget {
  final IconData icon;
  final String label;
  const _ActionIcon({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 32),
        const SizedBox(height: 4),
        Text(label,
            style: const TextStyle(color: Colors.white, fontSize: 12)),
      ],
    );
  }
}
