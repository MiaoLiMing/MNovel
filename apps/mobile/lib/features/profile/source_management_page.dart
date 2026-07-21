import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../core/theme/app_theme.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/channel_tabs.dart';
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
  final _client = http.Client();
  List<ContentSource> _sources = const [];
  bool _loading = true;
  ContentChannel _activeChannel = ContentChannel.novel;

  // Connection testing states
  final _latencies = <String, int>{};
  final _testing = <String, bool>{};

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void dispose() {
    _client.close();
    super.dispose();
  }

  Future<void> _reload() async {
    final sources = await _store.list();
    if (!mounted) return;
    setState(() {
      _sources = sources;
      _loading = false;
    });
    // Auto trigger connection test on load
    _testAll();
  }

  Future<void> _testSource(ContentSource source) async {
    setState(() {
      _testing[source.id] = true;
      _latencies.remove(source.id);
    });
    final stopwatch = Stopwatch()..start();
    try {
      final endpoint = source.endpoint.trim();
      if (endpoint.startsWith('{') || endpoint.startsWith('[')) {
        await Future<void>.delayed(const Duration(milliseconds: 60));
        stopwatch.stop();
        if (!mounted) return;
        setState(() {
          _latencies[source.id] = stopwatch.elapsedMilliseconds;
          _testing[source.id] = false;
        });
        return;
      }
      final response = await _client
          .get(Uri.parse(endpoint))
          .timeout(const Duration(seconds: 4));
      stopwatch.stop();
      if (!mounted) return;
      setState(() {
        _latencies[source.id] = response.statusCode == 200 
            ? stopwatch.elapsedMilliseconds 
            : -1;
        _testing[source.id] = false;
      });
    } catch (_) {
      stopwatch.stop();
      if (!mounted) return;
      setState(() {
        _latencies[source.id] = -1; // -1 means offline/error
        _testing[source.id] = false;
      });
    }
  }

  Future<void> _testAll() async {
    final active = _sources.where((s) => s.enabled && s.channels.contains(_activeChannel));
    for (final source in active) {
      unawaited(_testSource(source));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('内容源管理'),
        actions: [
          IconButton(
            tooltip: '添加 JSON 来源',
            onPressed: () => _showAddSourceSheet(),
            icon: const Icon(Icons.add_rounded),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: ChannelTabs(
                    value: _activeChannel,
                    onChanged: (val) => setState(() {
                      _activeChannel = val;
                      _testAll(); // Test again for the new channel
                    }),
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: _sourceList(_activeChannel),
                ),
              ],
            ),
    );
  }

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
              Expanded(child: Text('所有来源均由 App 在设备端直接读取，启停状态、测试延迟和自定义配置只保存在本机。')),
            ],
          ),
        ),
        const SizedBox(height: 16),
        ...sources.map(
          (source) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _SourceCard(
              source: source,
              latencyText: _testing[source.id] == true 
                  ? '检测中...' 
                  : _latencies[source.id] == null 
                  ? '待检测' 
                  : _latencies[source.id] == -1 
                  ? '连接失败' 
                  : '${_latencies[source.id]} ms',
              testing: _testing[source.id] == true,
              onEnabledChanged: (enabled) => _setEnabled(source, enabled),
              onDelete: source.builtIn ? null : () => _delete(source),
              onEdit: source.builtIn ? null : () => _showAddSourceSheet(editingSource: source),
            ),
          ),
        ),
        if (sources.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 40),
            child: EmptyState(
              icon: Icons.dns_outlined,
              title: '暂无${channel.label}内容源',
              description: '此频道目前没有任何内容源。请点击右上角“+”或下方按钮导入自定义的 JSON 数据源。',
              actionLabel: '立即导入内容源',
              onAction: () => _showAddSourceSheet(),
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: OutlinedButton.icon(
              onPressed: _testAll,
              icon: const Icon(Icons.monitor_heart_outlined),
              label: const Text('重新检测当前全部来源'),
            ),
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
    if (enabled) {
      final updatedSource = _sources.firstWhere((s) => s.id == source.id);
      unawaited(_testSource(updatedSource));
    }
  }

  Future<void> _delete(ContentSource source) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: AppColors.danger),
            const SizedBox(width: 10),
            const Text('删除内容源'),
          ],
        ),
        content: Text('您确定要删除内容源“${source.name}”吗？此操作将移除该内容源配置，无法撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.danger,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
            ),
            child: const Text('确定删除'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _store.removeCustom(source.id);
      await _reload();
    }
  }

  Future<void> _showAddSourceSheet({ContentSource? editingSource}) async {
    final nameController = TextEditingController(text: editingSource?.name);
    final endpointController = TextEditingController(text: editingSource?.endpoint);
    var channel = editingSource?.channels.first ?? _activeChannel;
    String? validationError;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.85,
          ),
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              22,
              0,
              22,
              MediaQuery.viewInsetsOf(sheetContext).bottom + 24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  editingSource != null ? '编辑 JSON 来源' : '添加 JSON 来源',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                const Text('接口可返回数组，或包含 items / results 数组的 JSON 对象。'),
                const SizedBox(height: 16),
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: '来源名称', hintText: '例如：星空小说网'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: endpointController,
                  keyboardType: TextInputType.multiline,
                  maxLines: null,
                  decoration: const InputDecoration(
                    labelText: 'HTTPS JSON 地址 或 本地 JSON 文本',
                    prefixIcon: Icon(Icons.link_rounded),
                    hintText: '输入 https://... 或 粘贴 [...] / {...} 文本',
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
                    style: const TextStyle(color: AppColors.danger, fontSize: 13),
                  ),
                ],
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: () async {
                    final name = nameController.text.trim();
                    final endpoint = endpointController.text.trim();
                    if (name.isEmpty || endpoint.isEmpty) {
                      setSheetState(() => validationError = '请填写名称和地址');
                      return;
                    }
                    try {
                      final source = ContentSource(
                        id: editingSource?.id ?? 'custom-${DateTime.now().microsecondsSinceEpoch}',
                        name: name,
                        description: '用户添加的设备端 JSON 来源',
                        channels: {channel},
                        kind: SourceKind.json,
                        endpoint: endpoint,
                        enabled: editingSource?.enabled ?? true,
                      );
                      
                      if (editingSource != null) {
                        await _store.removeCustom(editingSource.id);
                      }
                      await _store.addCustom(source);
                      
                      if (!sheetContext.mounted) return;
                      Navigator.pop(sheetContext);
                    } on FormatException catch (error) {
                      setSheetState(() => validationError = error.message);
                    }
                  },
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                  ),
                  child: const Text('保存到本机', style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ],
            ),
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
    required this.latencyText,
    required this.testing,
    this.onDelete,
    this.onEdit,
  });

  final ContentSource source;
  final ValueChanged<bool> onEnabledChanged;
  final String latencyText;
  final bool testing;
  final VoidCallback? onDelete;
  final VoidCallback? onEdit;

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
                Row(
                  children: [
                    Text(
                      source.enabled ? '已启用' : '已停用',
                      style: TextStyle(
                        color: source.enabled
                            ? AppColors.sage
                            : AppColors.secondaryText,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (source.enabled) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: latencyText == '连接失败'
                              ? AppColors.danger.withValues(alpha: .08)
                              : AppColors.sage.withValues(alpha: .08),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          latencyText,
                          style: TextStyle(
                            color: latencyText == '连接失败' ? AppColors.danger : AppColors.sage,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                if (!source.builtIn) ...[
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (onEdit != null)
                        TextButton.icon(
                          onPressed: onEdit,
                          icon: const Icon(Icons.edit_outlined, size: 16),
                          label: const Text('修改', style: TextStyle(fontSize: 12)),
                        ),
                      if (onDelete != null)
                        TextButton.icon(
                          onPressed: onDelete,
                          icon: const Icon(Icons.delete_outline_rounded, size: 16),
                          style: TextButton.styleFrom(foregroundColor: AppColors.danger),
                          label: const Text('删除', style: TextStyle(fontSize: 12)),
                        ),
                    ],
                  ),
                ],
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
