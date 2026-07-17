import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../domain/content.dart';
import 'web_player_stub.dart'
    if (dart.library.js_util) 'web_player_web.dart';

class MediaPlayerPage extends StatefulWidget {
  const MediaPlayerPage({super.key, required this.item});
  final ContentItem item;

  @override
  State<MediaPlayerPage> createState() => _MediaPlayerPageState();
}

class _MediaPlayerPageState extends State<MediaPlayerPage> {
  bool _playing = true;
  int _episode = 1;
  double _progress = .18;

  @override
  Widget build(BuildContext context) {
    // Determine the video stream based on the content ID
    String videoUrl = 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4';
    if (widget.item.id.contains('earth') || widget.item.id.contains('video-1') || widget.item.id.contains('mountain')) {
      videoUrl = 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/TearsOfSteel.mp4';
    } else if (widget.item.id.contains('chang') || widget.item.id.contains('video-2')) {
      videoUrl = 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/Sintel.mp4';
    } else if (widget.item.id.contains('drama-1') || widget.item.id.contains('fog')) {
      videoUrl = 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ElephantsDream.mp4';
    } else if (widget.item.id.contains('drama-2')) {
      videoUrl = 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4';
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Background Video (Web) or Image (Mobile)
            if (kIsWeb)
              createWebVideoPlayer(videoUrl, widget.item.coverAsset)
            else
              widget.item.coverAsset.startsWith('http')
                  ? Image.network(widget.item.coverAsset, fit: BoxFit.cover)
                  : Image.asset(widget.item.coverAsset, fit: BoxFit.cover),
            
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.black38, Colors.transparent, Colors.black87],
                ),
              ),
            ),
            
            // Top Back Button
            Positioned(
              top: 4,
              left: 4,
              child: IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: Colors.white,
                ),
              ),
            ),
            
            // Controls Layer
            if (!kIsWeb) ...[
              Center(
                child: IconButton(
                  iconSize: 70,
                  onPressed: () => setState(() => _playing = !_playing),
                  icon: Icon(
                    _playing
                        ? Icons.pause_circle_filled_rounded
                        : Icons.play_circle_fill_rounded,
                    color: Colors.white.withValues(alpha: .9),
                  ),
                ),
              ),
              Positioned(
                left: 20,
                right: 20,
                bottom: 24,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.item.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '第 $_episode 集 · ${widget.item.category}',
                      style: const TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 14),
                    Slider(
                      value: _progress,
                      onChanged: (value) => setState(() => _progress = value),
                      activeColor: AppColors.sage,
                      inactiveColor: Colors.white30,
                    ),
                    Row(
                      children: [
                        Text(
                          '${(_progress * 12).toStringAsFixed(1)} 分钟',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                        const Spacer(),
                        TextButton.icon(
                          onPressed: _showEpisodes,
                          icon: const Icon(Icons.video_library_outlined),
                          label: const Text('选集'),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.white,
                          ),
                        ),
                        TextButton.icon(
                          onPressed: _showSources,
                          icon: const Icon(Icons.swap_horiz_rounded),
                          label: const Text('线路'),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ] else ...[
              // On web, display title and info in a corner without overlapping native player controls
              Positioned(
                left: 20,
                bottom: 60,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.item.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        shadows: [Shadow(color: Colors.black, blurRadius: 4)],
                      ),
                    ),
                    Text(
                      '第 $_episode 集 · ${widget.item.category} · 网页原生硬解播放',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        shadows: [Shadow(color: Colors.black, blurRadius: 4)],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showEpisodes() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF20211F),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '选集',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: List.generate(12, (index) {
                  final value = index + 1;
                  return ChoiceChip(
                    label: Text('$value'),
                    selected: value == _episode,
                    selectedColor: AppColors.sage,
                    onSelected: (_) {
                      setState(() {
                        _episode = value;
                        _progress = 0;
                      });
                      Navigator.pop(context);
                    },
                  );
                }),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSources() {
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              ListTile(
                title: Text('线路 A · 1080P'),
                subtitle: Text('当前线路 · 192ms'),
                trailing: Icon(Icons.check_rounded, color: AppColors.sage),
              ),
              ListTile(
                title: Text('线路 B · 720P'),
                subtitle: Text('稳定 · 248ms'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
