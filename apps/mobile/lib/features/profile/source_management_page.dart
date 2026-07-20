import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../data/source_store.dart';
import '../../domain/content.dart';
import '../../domain/content_source.dart';

class SourceManagementPage extends StatefulWidget {
  const SourceManagementPage({super.key});

  @override
  State<SourceManagementPage> createState() => _SourceManagementPageState();
}

class _SourceManagementPageState extends State<SourceManagementPage> {
  final _store = SourceStore();
  List<ContentSource> _sources = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final sources = await _store.list();
    if (!mounted) return;
    setState(() {
      _sources = sources;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: ContentChannel.values.length,
    child: Scaffold(
      appBar: AppBar(
        title: const Text('内容源管理'),
        bottom: const TabBar(
          tabs: [
            Tab(text: '小说'),
            Tab(text: '短剧'),
            Tab(text: '影视'),
          ],
        ),
        actions: [
          IconButton(
            tooltip: '添加 JSON 来源',
            onPressed: _showAddSourceSheet,
            icon: const Icon(Icons.add_rounded),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              children: ContentChannel.values.map(_sourceList).toList(),
            ),
    ),
  );

  Widget _sourceList(ContentChannel channel) {
    final sources = _sources
        .where((source) => source.channels.contains(channel))
        .toList(growable: false);
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 32),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.sageSoft,
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.phone_android_rounded, color: AppColors.sage),
              SizedBox(width: 12),
              Expanded(child: Text('所有来源均由 App 在设备端读取；启停状态和自定义配置只保存在本机。')),
            ],
          ),
        ),
        const SizedBox(height: 16),
        ...sources.map(
          (source) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _SourceCard(
              source: source,
              onEnabledChanged: (enabled) => _setEnabled(source, enabled),
              onDelete: source.builtIn ? null : () => _delete(source),
            ),
          ),
        ),
        if (sources.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 48),
            child: Center(child: Text('当前频道还没有内容源')),
          ),
      ],
    );
  }

  Future<void> _setEnabled(ContentSource source, bool enabled) async {
    setState(() {
      _sources = _sources
          .map(
            (value) => value.id == source.id
                ? value.copyWith(enabled: enabled)
                : value,
          )
          .toList(growable: false);
    });
    await _store.setEnabled(source.id, enabled);
  }

  Future<void> _delete(ContentSource source) async {
    await _store.removeCustom(source.id);
    await _reload();
  }

  Future<void> _showAddSourceSheet() async {
    final nameController = TextEditingController();
    final endpointController = TextEditingController();
    var channel = ContentChannel.novel;
    String? validationError;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(
            22,
            0,
            22,
            MediaQuery.viewInsetsOf(context).bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('添加 JSON 来源', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              const Text('接口可返回数组，或包含 items / results 数组的 JSON 对象。'),
              const SizedBox(height: 16),
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: '来源名称'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: endpointController,
                keyboardType: TextInputType.url,
                decoration: const InputDecoration(
                  labelText: 'HTTPS JSON 地址',
                  prefixIcon: Icon(Icons.link_rounded),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<ContentChannel>(
                initialValue: channel,
                decoration: const InputDecoration(labelText: '内容频道'),
                items: ContentChannel.values
                    .map(
                      (value) => DropdownMenuItem(
                        value: value,
                        child: Text(value.label),
                      ),
                    )
                    .toList(),
                onChanged: (value) => channel = value ?? channel,
              ),
              if (validationError != null) ...[
                const SizedBox(height: 10),
                Text(
                  validationError!,
                  style: const TextStyle(color: Colors.red),
                ),
              ],
              const SizedBox(height: 18),
              FilledButton(
                onPressed: () async {
                  final name = nameController.text.trim();
                  final endpoint = endpointController.text.trim();
                  if (name.isEmpty || endpoint.isEmpty) {
                    setSheetState(() => validationError = '请填写名称和地址');
                    return;
                  }
                  try {
                    await _store.addCustom(
                      ContentSource(
                        id: 'custom-${DateTime.now().microsecondsSinceEpoch}',
                        name: name,
                        description: '用户添加的设备端 JSON 来源',
                        channels: {channel},
                        kind: SourceKind.json,
                        endpoint: endpoint,
                      ),
                    );
                    if (!sheetContext.mounted) return;
                    Navigator.pop(sheetContext);
                  } on FormatException catch (error) {
                    setSheetState(() => validationError = error.message);
                  }
                },
                child: const Text('保存到本机'),
              ),
            ],
          ),
        ),
      ),
    );
    nameController.dispose();
    endpointController.dispose();
    await _reload();
  }
}

class _SourceCard extends StatelessWidget {
  const _SourceCard({
    required this.source,
    required this.onEnabledChanged,
    this.onDelete,
  });

  final ContentSource source;
  final ValueChanged<bool> onEnabledChanged;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    elevation: 0,
    color: Colors.white,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(18),
      side: const BorderSide(color: AppColors.divider),
    ),
    child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 15, 10, 15),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            backgroundColor: source.enabled
                ? AppColors.sageSoft
                : const Color(0xFFF1F2EF),
            child: Icon(
              source.kind == SourceKind.localCatalog
                  ? Icons.storage_rounded
                  : source.kind == SourceKind.json
                  ? Icons.data_object_rounded
                  : Icons.public_rounded,
              color: source.enabled ? AppColors.sage : AppColors.secondaryText,
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
                    _SourceBadge(label: source.builtIn ? '内置' : '自定义'),
                  ],
                ),
                const SizedBox(height: 5),
                Text(source.description),
                const SizedBox(height: 8),
                Text(
                  source.enabled ? '已启用 · 设备端读取' : '已停用',
                  style: TextStyle(
                    color: source.enabled
                        ? AppColors.sage
                        : AppColors.secondaryText,
                    fontSize: 12,
                  ),
                ),
                if (onDelete != null)
                  TextButton.icon(
                    onPressed: onDelete,
                    icon: const Icon(Icons.delete_outline_rounded, size: 18),
                    label: const Text('删除来源'),
                  ),
              ],
            ),
          ),
          Switch(value: source.enabled, onChanged: onEnabledChanged),
        ],
      ),
    ),
  );
}

class _SourceBadge extends StatelessWidget {
  const _SourceBadge({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: AppColors.sageSoft,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(label, style: const TextStyle(fontSize: 11)),
  );
}
