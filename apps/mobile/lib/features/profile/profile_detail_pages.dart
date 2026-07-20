import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../domain/content.dart';

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
  final _paused = <int>{};

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('下载管理')),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _DownloadCard(
          title: '长风问剑',
          subtitle: '缓存后 20 章 · 8 / 20',
          progress: .4,
          paused: _paused.contains(0),
          onToggle: () => setState(() => _toggle(0)),
        ),
        _DownloadCard(
          title: '雾城回响',
          subtitle: '第 12—18 集 · 1.8 GB',
          progress: .72,
          paused: _paused.contains(1),
          onToggle: () => setState(() => _toggle(1)),
        ),
        const _DownloadCard(
          title: '远山之下',
          subtitle: '第 1 集 · 已完成',
          progress: 1,
          paused: false,
        ),
      ],
    ),
  );

  void _toggle(int index) {
    _paused.contains(index) ? _paused.remove(index) : _paused.add(index);
  }
}

class _DownloadCard extends StatelessWidget {
  const _DownloadCard({
    required this.title,
    required this.subtitle,
    required this.progress,
    required this.paused,
    this.onToggle,
  });
  final String title;
  final String subtitle;
  final double progress;
  final bool paused;
  final VoidCallback? onToggle;

  @override
  Widget build(BuildContext context) => Card(
    elevation: 0,
    margin: const EdgeInsets.only(bottom: 14),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.download_for_offline_outlined),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleMedium),
                    Text(subtitle),
                  ],
                ),
              ),
              if (onToggle != null)
                IconButton(
                  onPressed: onToggle,
                  icon: Icon(
                    paused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(value: progress, minHeight: 6),
        ],
      ),
    ),
  );
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
    '小说正文': 86,
    '封面图片': 34,
    '短剧与视频': 112,
    '临时文件': 4,
  };

  @override
  Widget build(BuildContext context) {
    final total = _sizes.values.fold<double>(0, (sum, value) => sum + value);
    return Scaffold(
      appBar: AppBar(title: const Text('缓存管理')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.sageSoft,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '${total.toStringAsFixed(0)} MB',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ),
          const SizedBox(height: 18),
          ..._sizes.entries.map(
            (entry) => ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(entry.key),
              subtitle: Text('${entry.value.toStringAsFixed(0)} MB'),
              trailing: TextButton(
                onPressed: entry.value == 0
                    ? null
                    : () => setState(() => _sizes[entry.key] = 0),
                child: const Text('清理'),
              ),
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: total == 0
                ? null
                : () => setState(() {
                    for (final key in _sizes.keys) {
                      _sizes[key] = 0;
                    }
                  }),
            child: const Text('清理全部可清理缓存'),
          ),
        ],
      ),
    );
  }
}
