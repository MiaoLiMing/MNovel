import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/content_cover.dart';
import '../../data/shelf_store.dart';
import '../../domain/content.dart';
import '../player/media_player_page.dart';
import '../reader/reader_page.dart';

class ContentDetailPage extends StatefulWidget {
  const ContentDetailPage({super.key, required this.item});

  final ContentItem item;

  @override
  State<ContentDetailPage> createState() => _ContentDetailPageState();
}

class _ContentDetailPageState extends State<ContentDetailPage> {
  bool _saved = false;
  final _shelfStore = ShelfStore();

  @override
  void initState() {
    super.initState();
    _restoreSaved();
  }

  Future<void> _restoreSaved() async {
    final saved = await _shelfStore.contains(widget.item.id);
    if (mounted) setState(() => _saved = saved);
  }

  Future<void> _toggleSaved() async {
    if (_saved) {
      await _shelfStore.remove(widget.item.id);
    } else {
      await _shelfStore.add(widget.item);
    }
    if (mounted) setState(() => _saved = !_saved);
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    return Scaffold(
      appBar: AppBar(
        title: Text(item.channel.label),
        actions: [
          IconButton(
            tooltip: '分享',
            onPressed: () => ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('分享链接已准备'))),
            icon: const Icon(Icons.ios_share_rounded),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Hero(
                tag: 'cover-${item.id}',
                child: ContentCover(
                  asset: item.coverAsset,
                  width: 122,
                  height: 174,
                  radius: 14,
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      item.creator,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(item.category),
                    const SizedBox(height: 8),
                    Text(
                      '${item.episodeCount} ${item.unitLabel} · ${item.popularity}',
                    ),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.sageSoft,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${item.sourceName} · 真实来源',
                        style: TextStyle(color: AppColors.sage, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),
          Text('简介', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 10),
          Text(item.summary, style: Theme.of(context).textTheme.bodyLarge),
          const SizedBox(height: 28),
          Row(
            children: [
              Expanded(
                child: Text(
                  item.channel == ContentChannel.novel ? '目录' : '剧集',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              Text('共 ${item.episodeCount} ${item.unitLabel}'),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.divider),
            ),
            child: Column(
              children: List.generate(
                item.episodeCount.clamp(0, 3),
                (index) => Padding(
                  padding: EdgeInsets.only(bottom: index == 2 ? 0 : 14),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.channel == ContentChannel.novel
                              ? item.isLive
                                    ? '第 ${index + 1} 节  ${item.title}'
                                    : '第 ${index + 1} 章  风从远山来'
                              : '第 ${index + 1} 集',
                        ),
                      ),
                      if (index == 0)
                        const Text(
                          '上次看到',
                          style: TextStyle(color: AppColors.sage, fontSize: 12),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 28),
          Text('来源状态', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const CircleAvatar(
              backgroundColor: AppColors.sageSoft,
              child: Icon(Icons.check_rounded, color: AppColors.sage),
            ),
            title: Text('当前来源 · ${item.sourceName}'),
            subtitle: Text(item.isLive ? '实时公开目录 · 已校验来源' : '本地内容'),
            trailing: const Icon(Icons.swap_horiz_rounded),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
          child: Row(
            children: [
              OutlinedButton.icon(
                onPressed: _toggleSaved,
                icon: Icon(
                  _saved
                      ? Icons.bookmark_rounded
                      : Icons.bookmark_border_rounded,
                ),
                label: Text(_saved ? '已收藏' : '收藏'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(112, 52),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _start,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                    backgroundColor: AppColors.sage,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    item.channel == ContentChannel.novel ? '开始阅读' : '开始播放',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _start() {
    final route = widget.item.channel == ContentChannel.novel
        ? MaterialPageRoute(builder: (_) => ReaderPage(item: widget.item))
        : MaterialPageRoute(builder: (_) => MediaPlayerPage(item: widget.item));
    Navigator.of(context).push(route);
  }
}
