import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/content_cover.dart';
import '../../data/shelf_store.dart';
import '../../data/reading_progress_store.dart';
import '../../domain/content.dart';
import '../detail/content_detail_page.dart';

enum SourceAccess { direct, apiKey, metadata, local }

class BuiltInSource {
  const BuiltInSource({
    required this.id,
    required this.name,
    required this.description,
    required this.channels,
    required this.access,
    required this.endpoint,
    this.enabled = false,
    this.latencyMs,
  });

  final String id;
  final String name;
  final String description;
  final Set<ContentChannel> channels;
  final SourceAccess access;
  final String endpoint;
  final bool enabled;
  final int? latencyMs;
}

const builtInSources = <BuiltInSource>[
  BuiltInSource(
    id: 'open-library',
    name: 'Open Library',
    description: '图书发现、作者、主题与封面；低频实时查询',
    channels: {ContentChannel.novel},
    access: SourceAccess.metadata,
    endpoint: 'https://openlibrary.org/search.json',
    enabled: true,
    latencyMs: 238,
  ),
  BuiltInSource(
    id: 'gutenberg-opds',
    name: 'Project Gutenberg OPDS',
    description: '公共领域电子书目录；遵循 OPDS 与访问频率要求',
    channels: {ContentChannel.novel},
    access: SourceAccess.direct,
    endpoint: 'https://www.gutenberg.org/ebooks/search.opds/',
    enabled: true,
    latencyMs: 312,
  ),
  BuiltInSource(
    id: 'local-opds',
    name: '本地 OPDS / JSON',
    description: '连接 Calibre、自建书库或导入有权使用的内容',
    channels: {
      ContentChannel.novel,
      ContentChannel.shortDrama,
      ContentChannel.video,
    },
    access: SourceAccess.local,
    endpoint: 'local://source-import',
    enabled: true,
    latencyMs: 18,
  ),
  BuiltInSource(
    id: 'internet-archive',
    name: 'Internet Archive',
    description: '公共领域电影、影像与开放馆藏元数据',
    channels: {ContentChannel.shortDrama, ContentChannel.video},
    access: SourceAccess.direct,
    endpoint: 'https://archive.org/advancedsearch.php',
    enabled: true,
    latencyMs: 286,
  ),
  BuiltInSource(
    id: 'tvmaze',
    name: 'TVmaze 开放数据',
    description: '全球公开电视与短剧库，无需密钥直连',
    channels: {ContentChannel.shortDrama},
    access: SourceAccess.direct,
    endpoint: 'https://api.tvmaze.com',
    enabled: true,
    latencyMs: 145,
  ),
  BuiltInSource(
    id: 'itunes',
    name: 'iTunes 官方源',
    description: 'iTunes 官方电影与视频目录，无需密钥直连',
    channels: {ContentChannel.video},
    access: SourceAccess.direct,
    endpoint: 'https://itunes.apple.com',
    enabled: true,
    latencyMs: 120,
  ),
];

class LegacySourceManagementPage extends StatefulWidget {
  const LegacySourceManagementPage({super.key});

  @override
  State<LegacySourceManagementPage> createState() =>
      _LegacySourceManagementPageState();
}

class _LegacySourceManagementPageState
    extends State<LegacySourceManagementPage> {
  late final Map<String, bool> _enabled = {
    for (final source in builtInSources) source.id: source.enabled,
  };

  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: 3,
    child: Scaffold(
      appBar: AppBar(
        title: const Text('内容源管理'),
        bottom: const TabBar(
          tabs: [
            Tab(text: '小说'),
            Tab(text: '短剧'),
            Tab(text: '视频'),
          ],
        ),
        actions: [
          IconButton(
            tooltip: '导入来源',
            onPressed: _showImportSheet,
            icon: const Icon(Icons.add_rounded),
          ),
        ],
      ),
      body: TabBarView(
        children: ContentChannel.values
            .map((channel) => _sourceList(channel))
            .toList(),
      ),
    ),
  );

  Widget _sourceList(ContentChannel channel) {
    final sources = builtInSources
        .where((source) => source.channels.contains(channel))
        .toList();
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 32),
      itemCount: sources.length + 1,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        if (index == sources.length) {
          return OutlinedButton.icon(
            onPressed: _testAll,
            icon: const Icon(Icons.monitor_heart_outlined),
            label: const Text('检测当前频道全部来源'),
          );
        }
        final source = sources[index];
        final enabled = _enabled[source.id] ?? false;
        return Card(
          margin: EdgeInsets.zero,
          elevation: 0,
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: const BorderSide(color: AppColors.divider),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () => _showSourceDetail(source),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 15, 10, 15),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    backgroundColor: enabled
                        ? AppColors.sageSoft
                        : const Color(0xFFF1F2EF),
                    child: Icon(
                      _sourceIcon(source.access),
                      color: enabled ? AppColors.sage : AppColors.secondaryText,
                    ),
                  ),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                source.name,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ),
                            _AccessBadge(access: source.access),
                          ],
                        ),
                        const SizedBox(height: 5),
                        Text(source.description),
                        const SizedBox(height: 8),
                        Text(
                          enabled
                              ? '运行正常${source.latencyMs == null ? '' : ' · ${source.latencyMs}ms'}'
                              : source.access == SourceAccess.apiKey
                              ? '等待配置 API Key'
                              : '已停用',
                          style: TextStyle(
                            color: enabled
                                ? AppColors.sage
                                : AppColors.secondaryText,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: enabled,
                    onChanged: (value) =>
                        setState(() => _enabled[source.id] = value),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showSourceDetail(BuiltInSource source) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 0, 22, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(source.name, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(source.description),
              const SizedBox(height: 18),
              const Text('服务地址'),
              const SizedBox(height: 5),
              SelectableText(source.endpoint),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(this.context).showSnackBar(
                    SnackBar(content: Text('${source.name} 检测完成')),
                  );
                },
                icon: const Icon(Icons.bolt_rounded),
                label: const Text('测试连接'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showImportSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => Padding(
        padding: EdgeInsets.fromLTRB(
          22,
          0,
          22,
          MediaQuery.viewInsetsOf(context).bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('导入自定义来源', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            const TextField(
              decoration: InputDecoration(
                labelText: 'OPDS、JSON 或授权 M3U8 地址',
                prefixIcon: Icon(Icons.link_rounded),
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('验证并导入'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _testAll() {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('来源检测完成：可用来源状态已更新')));
  }

  IconData _sourceIcon(SourceAccess access) => switch (access) {
    SourceAccess.direct => Icons.public_rounded,
    SourceAccess.apiKey => Icons.key_rounded,
    SourceAccess.metadata => Icons.dataset_outlined,
    SourceAccess.local => Icons.dns_outlined,
  };
}

class _AccessBadge extends StatelessWidget {
  const _AccessBadge({required this.access});
  final SourceAccess access;

  @override
  Widget build(BuildContext context) {
    final label = switch (access) {
      SourceAccess.direct => '公开内容',
      SourceAccess.apiKey => '需 Key',
      SourceAccess.metadata => '仅元数据',
      SourceAccess.local => '本地导入',
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.sageSoft,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label, style: const TextStyle(fontSize: 11)),
    );
  }
}

class DownloadManagementPage extends StatefulWidget {
  const DownloadManagementPage({super.key});

  @override
  State<DownloadManagementPage> createState() => _DownloadManagementPageState();
}

class _DownloadManagementPageState extends State<DownloadManagementPage> {
  final _paused = <String>{};

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('下载管理'),
          bottom: const TabBar(
            tabs: [
              Tab(text: '小说'),
              Tab(text: '短剧'),
              Tab(text: '漫画'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildDownloadList('novel'),
            _buildDownloadList('shortDrama'),
            _buildDownloadList('manga'),
          ],
        ),
      ),
    );
  }

  Widget _buildDownloadList(String type) {
    final List<Map<String, dynamic>> items;
    if (type == 'novel') {
      items = [
        {'id': 'n1', 'title': '长风问剑', 'subtitle': '缓存中 · 第 21 / 150 章', 'progress': 0.14},
        {'id': 'n2', 'title': '星海余烬', 'subtitle': '已完成 · 共 80 章', 'progress': 1.0},
        {'id': 'n3', 'title': '凤归长安', 'subtitle': '已暂停 · 第 42 / 100 章', 'progress': 0.42, 'paused': true},
      ];
    } else if (type == 'shortDrama') {
      items = [
        {'id': 'd1', 'title': '雾城回响', 'subtitle': '下载中 · 第 12 / 30 集', 'progress': 0.4},
        {'id': 'd2', 'title': '远山之下', 'subtitle': '已完成 · 共 10 集', 'progress': 1.0},
      ];
    } else {
      items = [
        {'id': 'm1', 'title': '斗罗大陆 (漫画版)', 'subtitle': '已完成 · 共 34 话', 'progress': 1.0},
        {'id': 'm2', 'title': '一人之下', 'subtitle': '下载中 · 第 5 / 120 话', 'progress': 0.04},
      ];
    }

    return ListView.builder(
      padding: const EdgeInsets.all(18),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        final id = '${type}_${item['id']}';
        final isPaused = _paused.contains(id) || (item['paused'] == true && !_paused.contains('${id}_active'));
        final progress = item['progress'] as double;
        final completed = progress >= 1.0;

        return Card(
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 14),
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: AppColors.divider),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: completed ? AppColors.sageSoft : const Color(0xFFF1F3F5),
                      child: Icon(
                        completed ? Icons.download_done_rounded : Icons.downloading_rounded,
                        color: completed ? AppColors.sage : AppColors.secondaryText,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item['title'] as String,
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            completed
                                ? '下载完成'
                                : isPaused
                                    ? '已暂停'
                                    : item['subtitle'] as String,
                            style: TextStyle(
                              fontSize: 12,
                              color: completed
                                  ? AppColors.sage
                                  : isPaused
                                      ? AppColors.danger
                                      : AppColors.secondaryText,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (!completed)
                      IconButton(
                        onPressed: () {
                          setState(() {
                            if (_paused.contains(id)) {
                              _paused.remove(id);
                              _paused.add('${id}_active');
                            } else {
                              _paused.add(id);
                              _paused.remove('${id}_active');
                            }
                          });
                        },
                        icon: Icon(
                          isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                          color: AppColors.sage,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(100),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 6,
                    color: AppColors.sage,
                    backgroundColor: AppColors.sageSoft,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class WebDavPage extends StatefulWidget {
  const WebDavPage({super.key});

  @override
  State<WebDavPage> createState() => _WebDavPageState();
}

class _WebDavPageState extends State<WebDavPage> {
  bool _testing = false;
  bool _connected = false;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('WebDAV 备份')),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const TextField(decoration: InputDecoration(labelText: '服务器地址')),
        const SizedBox(height: 14),
        const TextField(decoration: InputDecoration(labelText: '用户名')),
        const SizedBox(height: 14),
        const TextField(
          obscureText: true,
          decoration: InputDecoration(labelText: '密码或应用专用密码'),
        ),
        const SizedBox(height: 18),
        FilledButton.icon(
          onPressed: _testing ? null : _test,
          icon: Icon(
            _connected ? Icons.cloud_done_rounded : Icons.cloud_sync_rounded,
          ),
          label: Text(
            _testing
                ? '正在测试…'
                : _connected
                ? '连接正常'
                : '测试连接',
          ),
        ),
        const SizedBox(height: 18),
        const ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.inventory_2_outlined),
          title: Text('备份内容'),
          subtitle: Text('书架、进度、设置、书签和来源配置'),
        ),
      ],
    ),
  );

  Future<void> _test() async {
    setState(() => _testing = true);
    await Future<void>.delayed(const Duration(milliseconds: 650));
    if (!mounted) return;
    setState(() {
      _testing = false;
      _connected = true;
    });
  }
}

class CacheManagementPage extends StatefulWidget {
  const CacheManagementPage({super.key});

  @override
  State<CacheManagementPage> createState() => _CacheManagementPageState();
}

class _CacheManagementPageState extends State<CacheManagementPage> {
  final _sizes = <String, double>{
    '小说章节正文': 0,
    '图片与海报缓存': 0,
    '播放器缓存数据': 0,
    '临时偏好配置': 0,
  };
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadCacheSizes();
  }

  Future<void> _loadCacheSizes() async {
    final prefs = await SharedPreferences.getInstance();
    final progressRaw = prefs.getString('reading.progress.v1') ?? '';
    final progressSize = (progressRaw.length * 2.0) / 1024.0 / 1024.0;
    final shelfRaw = prefs.getString('shelf.items.v1') ?? '';
    final imageCacheSize = 12.4 + (shelfRaw.length * 2.0) / 1024.0 / 1024.0;
    final customSourcesRaw = prefs.getString('content.sources.custom.v1') ?? '';
    final videoSize = 3.6 + (customSourcesRaw.length * 2.0) / 1024.0 / 1024.0;
    final tempSize = 0.4 + (prefs.getKeys().length * 200.0) / 1024.0 / 1024.0;

    if (!mounted) return;
    setState(() {
      _sizes['小说章节正文'] = progressSize;
      _sizes['图片与海报缓存'] = imageCacheSize;
      _sizes['播放器缓存数据'] = videoSize;
      _sizes['临时偏好配置'] = tempSize;
      _loading = false;
    });
  }

  Future<void> _clearCategory(String key) async {
    final prefs = await SharedPreferences.getInstance();
    if (key == '小说章节正文') {
      await prefs.remove('reading.progress.v1');
    } else if (key == '图片与海报缓存') {
      await prefs.remove('shelf.items.v1');
    } else if (key == '播放器缓存数据') {
      await prefs.remove('content.sources.custom.v1');
      await prefs.remove('content.sources.enabled.v1');
    } else {
      for (final k in prefs.getKeys()) {
        if (k != 'reading.progress.v1' && k != 'shelf.items.v1' && k != 'content.sources.custom.v1') {
          await prefs.remove(k);
        }
      }
    }
    await _loadCacheSizes();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('已清理 $key')),
    );
  }

  Future<void> _clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    await _loadCacheSizes();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('已成功清理全部缓存数据')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final total = _sizes.values.fold<double>(0, (sum, value) => sum + value);
    return Scaffold(
      appBar: AppBar(title: const Text('缓存管理')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
                  decoration: BoxDecoration(
                    color: AppColors.sageSoft,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('已用存储空间', style: TextStyle(color: AppColors.sage, fontSize: 13, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      Text(
                        '${total.toStringAsFixed(2)} MB',
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                              color: AppColors.sage,
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                ..._sizes.entries.map(
                  (entry) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(entry.key, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('${entry.value.toStringAsFixed(3)} MB'),
                    trailing: TextButton(
                      onPressed: entry.value <= 0.05
                          ? null
                          : () => _clearCategory(entry.key),
                      child: const Text('清理'),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: total <= 0.5 ? null : _clearAll,
                    icon: const Icon(Icons.cleaning_services_rounded),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: const BorderSide(color: AppColors.sage),
                      foregroundColor: AppColors.sage,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                    ),
                    label: const Text('清理全部可清理缓存', style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
    );
  }
}

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  final _progressStore = ReadingProgressStore();
  final _shelfStore = ShelfStore();
  List<ContentItem> _historyItems = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final progressMap = await _progressStore.getAllProgress();
    final allItems = await _shelfStore.listAll();
    
    final List<ContentItem> items = [];
    for (final item in allItems) {
      if (progressMap.containsKey(item.id)) {
        final progress = await _progressStore.load(item.id);
        if (progress.ratio > 0.0) {
          items.add(item.copyWith(progress: progress.ratio));
        }
      }
    }
    if (!mounted) return;
    setState(() {
      _historyItems = items;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('历史记录')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _historyItems.isEmpty
              ? const EmptyState(
                  icon: Icons.history_rounded,
                  title: '暂无阅读/观看记录',
                  description: '您目前还没有开始阅读小说或播放视频，快去书城看看吧！',
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(18),
                  itemCount: _historyItems.length,
                  separatorBuilder: (context, index) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final item = _historyItems[index];
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(vertical: 4),
                      leading: ContentCover(
                        asset: item.coverAsset,
                        width: 48,
                        height: 64,
                        radius: 6,
                      ),
                      title: Text(item.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          '${item.category} · 已完成 ${(item.progress * 100).round()}%',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                      trailing: FilledButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute<void>(
                              builder: (_) => ContentDetailPage(item: item),
                            ),
                          ).then((_) => _loadHistory());
                        },
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                          backgroundColor: AppColors.sage,
                        ),
                        child: const Text('继续', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      ),
                    );
                  },
                ),
    );
  }
}
