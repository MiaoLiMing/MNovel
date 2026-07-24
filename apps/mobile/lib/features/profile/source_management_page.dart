import 'dart:async';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

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
  final Map<String, SourceHealth> _healthOverrides = {};
  final Map<String, int> _latencyOverrides = {};
  bool _loading = true;
  bool _editing = false;
  bool _testingAll = false;

  @override
  void initState() {
    super.initState();
    unawaited(_reload());
  }

  Future<void> _reload() async {
    final sources = await _store.list();
    if (!mounted) return;
    setState(() {
      _sources = sources;
      _loading = false;
    });
  }

  Future<void> _toggle(ContentSource source, bool enabled) async {
    await _store.setEnabled(source.id, enabled);
    await _reload();
  }

  Future<void> _testSource(ContentSource source) async {
    setState(() => _healthOverrides[source.id] = SourceHealth.checking);
    final stopwatch = Stopwatch()..start();
    SourceHealth health;
    try {
      final endpoint = source.endpoint.trim();
      if (endpoint.isEmpty || endpoint == '[]') {
        health = SourceHealth.configurationRequired;
      } else if (endpoint.startsWith('[') || endpoint.startsWith('{')) {
        health = SourceHealth.healthy;
      } else {
        final response = await http
            .get(Uri.parse(endpoint))
            .timeout(const Duration(seconds: 6));
        health = response.statusCode < 500
            ? SourceHealth.healthy
            : SourceHealth.error;
      }
    } catch (_) {
      health = SourceHealth.error;
    }
    stopwatch.stop();
    if (!mounted) return;
    setState(() {
      _healthOverrides[source.id] = health;
      _latencyOverrides[source.id] = stopwatch.elapsedMilliseconds;
    });
  }

  Future<void> _testAll() async {
    setState(() => _testingAll = true);
    for (final source in _sources.where((source) => source.enabled)) {
      await _testSource(source);
      if (!mounted) return;
    }
    setState(() => _testingAll = false);
  }

  Future<void> _reorder(int oldIndex, int newIndex) async {
    final values = [..._sources];
    final source = values.removeAt(oldIndex);
    values.insert(newIndex, source);
    setState(() => _sources = values);
    await _store.saveOrder(values.map((item) => item.id).toList());
  }

  Future<void> _remove(ContentSource source) async {
    if (source.builtIn) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('删除书源'),
        content: Text('确定删除“${source.name}”吗？此操作不会删除书架和阅读进度。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _store.removeCustom(source.id);
    await _reload();
  }

  Future<void> _showEditor({ContentSource? source}) async {
    final nameController = TextEditingController(text: source?.name ?? '');
    final endpointController = TextEditingController(
      text: source?.endpoint == '[]' ? '' : source?.endpoint ?? '',
    );
    var kind = source?.kind == SourceKind.js ? SourceKind.js : SourceKind.json;
    final result = await showModalBottomSheet<ContentSource>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: AppColors.surface,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            0,
            16,
            MediaQuery.viewInsetsOf(context).bottom + 18,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                source == null ? '添加书源' : '编辑书源',
                style: const TextStyle(
                  color: AppColors.text,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: '书源名称'),
              ),
              const SizedBox(height: 10),
              SegmentedButton<SourceKind>(
                segments: const [
                  ButtonSegment(
                    value: SourceKind.json,
                    label: Text('JSON'),
                    icon: Icon(Icons.data_object_rounded),
                  ),
                  ButtonSegment(
                    value: SourceKind.js,
                    label: Text('JS 规则'),
                    icon: Icon(Icons.code_rounded),
                  ),
                ],
                selected: {kind},
                onSelectionChanged: (value) =>
                    setSheetState(() => kind = value.first),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: endpointController,
                minLines: 3,
                maxLines: 7,
                decoration: const InputDecoration(
                  labelText: 'HTTPS 地址或 JSON 内容',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    final name = nameController.text.trim();
                    final endpoint = endpointController.text.trim();
                    if (name.isEmpty || endpoint.isEmpty) {
                      ScaffoldMessenger.of(sheetContext).showSnackBar(
                        const SnackBar(content: Text('请填写名称和来源内容')),
                      );
                      return;
                    }
                    Navigator.pop(
                      sheetContext,
                      ContentSource(
                        id:
                            source?.id ??
                            'custom-${DateTime.now().millisecondsSinceEpoch}',
                        name: name,
                        description: endpoint.startsWith('https://')
                            ? endpoint
                            : '本地 JSON 规则',
                        channels: const {ContentChannel.novel},
                        kind: kind,
                        endpoint: endpoint,
                        enabled: source?.enabled ?? true,
                        builtIn: false,
                        priority: source?.priority ?? 20,
                        health: SourceHealth.unknown,
                      ),
                    );
                  },
                  child: const Text('保存书源'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    nameController.dispose();
    endpointController.dispose();
    if (result == null) return;
    try {
      await _store.addCustom(result);
      await _reload();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('书源已保存')));
    } on FormatException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      leading: IconButton(
        tooltip: '返回',
        onPressed: () => Navigator.pop(context),
        icon: const Icon(Icons.chevron_left_rounded, size: 25),
      ),
      title: const Text('书源管理'),
      actions: [
        TextButton(
          onPressed: () => setState(() => _editing = !_editing),
          child: Text(
            _editing ? '完成' : '编辑',
            style: const TextStyle(
              color: AppColors.secondaryText,
              fontSize: 11,
            ),
          ),
        ),
      ],
    ),
    body: _loading
        ? const Center(child: CircularProgressIndicator())
        : Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 2, 16, 8),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        '长按拖动可调整顺序，点击名称检测书源',
                        style: TextStyle(
                          color: AppColors.tertiaryText,
                          fontSize: 9,
                        ),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: _testingAll ? null : _testAll,
                      icon: _testingAll
                          ? const SizedBox(
                              width: 12,
                              height: 12,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.speed_rounded, size: 15),
                      label: const Text('全部检测'),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ReorderableListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  itemCount: _sources.length,
                  onReorderItem: _reorder,
                  buildDefaultDragHandles: false,
                  itemBuilder: (context, index) {
                    final source = _sources[index];
                    final health = _healthOverrides[source.id] ?? source.health;
                    final latency =
                        _latencyOverrides[source.id] ?? source.latencyMs;
                    return _SourceRow(
                      key: ValueKey(source.id),
                      index: index,
                      source: source,
                      health: health,
                      latencyMs: latency,
                      editing: _editing,
                      onTap: () => _testSource(source),
                      onToggle: (value) => _toggle(source, value),
                      onEdit: source.builtIn
                          ? null
                          : () => _showEditor(source: source),
                      onDelete: source.builtIn ? null : () => _remove(source),
                    );
                  },
                ),
              ),
              DecoratedBox(
                decoration: const BoxDecoration(
                  color: AppColors.surface,
                  border: Border(
                    top: BorderSide(color: AppColors.divider, width: .7),
                  ),
                ),
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                    child: SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _showEditor,
                        icon: const Icon(Icons.add_rounded),
                        label: const Text('添加书源'),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
  );
}

class _SourceRow extends StatelessWidget {
  const _SourceRow({
    super.key,
    required this.index,
    required this.source,
    required this.health,
    required this.latencyMs,
    required this.editing,
    required this.onTap,
    required this.onToggle,
    this.onEdit,
    this.onDelete,
  });

  final int index;
  final ContentSource source;
  final SourceHealth health;
  final int latencyMs;
  final bool editing;
  final VoidCallback onTap;
  final ValueChanged<bool> onToggle;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  Color get _healthColor => switch (health) {
    SourceHealth.healthy => AppColors.success,
    SourceHealth.checking => AppColors.warning,
    SourceHealth.error => AppColors.danger,
    SourceHealth.configurationRequired => AppColors.warning,
    SourceHealth.unknown => AppColors.tertiaryText,
  };

  @override
  Widget build(BuildContext context) => Material(
    color: AppColors.canvas,
    child: InkWell(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 68),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: const BoxDecoration(
          border: Border(
            bottom: BorderSide(color: AppColors.divider, width: .7),
          ),
        ),
        child: Row(
          children: [
            ReorderableDragStartListener(
              index: index,
              child: const Padding(
                padding: EdgeInsets.all(6),
                child: Icon(
                  Icons.drag_handle_rounded,
                  color: AppColors.tertiaryText,
                  size: 18,
                ),
              ),
            ),
            const SizedBox(width: 3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    source.name,
                    style: const TextStyle(
                      color: AppColors.text,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    source.description,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.tertiaryText,
                      fontSize: 9,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            Text(
              latencyMs > 0 ? '${health.label} ${latencyMs}ms' : health.label,
              style: TextStyle(
                color: _healthColor,
                fontSize: 9,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 6),
            if (editing && onEdit != null)
              IconButton(
                tooltip: '编辑',
                onPressed: onEdit,
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.edit_outlined, size: 16),
              ),
            if (editing && onDelete != null)
              IconButton(
                tooltip: '删除',
                onPressed: onDelete,
                visualDensity: VisualDensity.compact,
                icon: const Icon(
                  Icons.delete_outline_rounded,
                  color: AppColors.danger,
                  size: 16,
                ),
              ),
            Switch(
              value: source.enabled,
              onChanged: onToggle,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ],
        ),
      ),
    ),
  );
}
