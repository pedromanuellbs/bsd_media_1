// screens/home/home.dart

import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:salomon_bottom_bar/salomon_bottom_bar.dart';
import 'package:video_player/video_player.dart';

import 'settings.dart';

class _ShortData {
  final String assetPath, channelName, title, views, timeAgo, likes, comments;
  _ShortData({
    required this.assetPath,
    required this.channelName,
    required this.title,
    required this.views,
    required this.timeAgo,
    required this.likes,
    required this.comments,
  });
}

final _navBarItems = <SalomonBottomBarItem>[
  SalomonBottomBarItem(icon: const Icon(Icons.home), title: const Text("Home"), selectedColor: Colors.purple),
  SalomonBottomBarItem(icon: const Icon(Icons.favorite_border), title: const Text("Saved"), selectedColor: Colors.pink),
  SalomonBottomBarItem(icon: const Icon(Icons.search), title: const Text("Search"), selectedColor: Colors.orange),
  SalomonBottomBarItem(icon: const Icon(Icons.person), title: const Text("Profile"), selectedColor: Colors.teal),
  SalomonBottomBarItem(icon: const Icon(Icons.settings), title: const Text("Settings"), selectedColor: Colors.grey),
];

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;
  late final PageController _pageController;
  late final List<VideoPlayerController> _controllers;
  List<_ShortData> _shorts = [];
  bool _isLoading = true, _showOverlay = false;
  int _overlayIndex = -1, _currentShortIndex = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _loadShortsAndInit();
  }

  Future<void> _loadShortsAndInit() async {
    Map<String, dynamic> manifestMap = {};
    try {
      manifestMap = json.decode(
          await DefaultAssetBundle.of(context).loadString('AssetManifest.json')
      ) as Map<String, dynamic>;
    } catch (_) {}
    final videoPaths = manifestMap.keys
        .where((k) => k.startsWith('assets/vids/') && k.endsWith('.mp4'))
        .toList()..sort();

    _shorts = videoPaths.map((path) {
      final name = path.split('/').last.replaceAll('.mp4','');
      return _ShortData(
        assetPath: path,
        channelName: 'Channel $name',
        title: 'Short $name',
        views: '100K views',
        timeAgo: '1h ago',
        likes: '10K',
        comments: '5K',
      );
    }).toList();

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

    if (_controllers.isNotEmpty) _controllers[0].play();
    setState(() => _isLoading = false);
  }

  @override
  void dispose() {
    for (var c in _controllers) c.dispose();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isHome = _selectedIndex == 0;
    return Scaffold(
      extendBodyBehindAppBar: isHome,
      appBar: isHome
          // Custom transparent AppBar only on Home
          ? PreferredSize(
              preferredSize: const Size.fromHeight(80),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      const SizedBox(width: 28),
                      Expanded(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text('Mengikuti',
                                style: TextStyle(color: Colors.white70, fontSize: 16)),
                            const SizedBox(width: 24),
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text('Feed',
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold)),
                                Container(
                                  margin: const EdgeInsets.only(top: 4),
                                  height: 2,
                                  width: 24,
                                  color: Colors.white,
                                )
                              ],
                            ),
                          ],
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.send, color: Colors.white, size: 28),
                          const SizedBox(height: 4),
                          const Text('Kirim ke Wajah',
                              style: TextStyle(color: Colors.white70, fontSize: 12)),
                          const SizedBox(height: 16),
                          const Icon(Icons.camera_alt, color: Colors.white, size: 28),
                          const SizedBox(height: 4),
                          const Text('FotoTree',
                              style: TextStyle(color: Colors.white70, fontSize: 12)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            )
          // Regular AppBar on other pages
          : AppBar(
              title: _navBarItems[_selectedIndex].title,
            ),
      body: isHome ? _buildShortsFeed() : _buildPlaceholder(),
      bottomNavigationBar: SalomonBottomBar(
        currentIndex: _selectedIndex,
        selectedItemColor: const Color(0xff6200ee),
        unselectedItemColor: const Color(0xff757575),
        onTap: (i) => setState(() => _selectedIndex = i),
        items: _navBarItems,
      ),
    );
  }

  Widget _buildPlaceholder() {
    switch (_selectedIndex) {
      case 1:
        return const Center(child: Text('Saved'));
      case 2:
        return const Center(child: Text('Search'));
      case 3:
        return const Center(child: Text('Profile'));
      case 4:
        return const SettingsPage2();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildShortsFeed() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    return PageView.builder(
      controller: _pageController,
      scrollDirection: Axis.vertical,
      itemCount: _shorts.length,
      onPageChanged: (idx) {
        _controllers[_currentShortIndex].pause();
        _currentShortIndex = idx;
        if (_controllers[idx].value.isInitialized) _controllers[idx].play();
        setState(() {});
      },
      itemBuilder: (context, idx) {
        final short = _shorts[idx];
        final ctrl = _controllers[idx];
        return Stack(fit: StackFit.expand, children: [
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
          if (!kIsWeb)
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  ctrl.value.isPlaying ? ctrl.pause() : ctrl.play();
                  setState(() {
                    _overlayIndex = idx;
                    _showOverlay = true;
                  });
                  Future.delayed(const Duration(milliseconds: 500), () {
                    if (mounted) setState(() => _showOverlay = false);
                  });
                },
              ),
            ),
          if (_showOverlay && _overlayIndex == idx)
            Center(
              child: AnimatedOpacity(
                opacity: 1,
                duration: const Duration(milliseconds: 200),
                child: Icon(
                  ctrl.value.isPlaying
                      ? Icons.pause_circle_filled
                      : Icons.play_circle_fill,
                  size: 80,
                  color: Colors.white.withOpacity(0.8),
                ),
              ),
            ),
          Positioned(
            left: 16,
            right: 100,
            bottom: 40,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 60,
                  decoration: BoxDecoration(
                    shape: BoxShape.rectangle,
                    borderRadius: BorderRadius.circular(8),
                    image: const DecorationImage(
                      image: AssetImage('assets/img/dum_prof.jpg'),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
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
              ],
            ),
          ),
          Positioned(
            right: 16,
            bottom: 40,
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
}

class _ActionIcon extends StatelessWidget {
  final IconData icon;
  final String label;
  const _ActionIcon({Key? key, required this.icon, required this.label}) : super(key: key);

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Icon(icon, color: Colors.white, size: 32),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 12)),
        ],
      );
}
