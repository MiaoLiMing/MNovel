import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_theme.dart';
import '../../data/content_repository.dart';
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
  final _repository = ContentRepository();
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
    final result = await _repository.probeSource(source);
    if (!mounted) return;
    setState(() {
      _healthOverrides[source.id] = result.health;
      _latencyOverrides[source.id] = result.latencyMs;
    });
    if (result.message.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${source.name}：${result.message}')),
      );
    }
  }

  Future<void> _showSourceDetails(ContentSource source) async {
    if (!source.builtIn) {
      await _showEditor(source: source);
      return;
    }
    final (format, catalog, chapter, policy) = switch (source.kind) {
      SourceKind.gutendex => (
        'Gutendex REST JSON + Gutenberg TXT',
        '支持分页搜索公共领域电子书',
        '每本书读取公开纯文本正文',
        '解析由统一后端完成，App 不保存站点规则',
      ),
      SourceKind.wikisource => (
        'MediaWiki Action API JSON',
        '按作品根页面聚合子页目录',
        '每个子页面作为独立章节',
        '解析由统一后端完成，遵循维基媒体公开接口',
      ),
      SourceKind.internetArchive => (
        'Advanced Search JSON + Metadata + DjVu TXT',
        '筛选带全文文件的中文公共馆藏',
        '读取馆藏公开全文文件',
        '解析由统一后端完成，并过滤错误语言标注',
      ),
      _ => ('未知', '未声明', '未声明', '未声明'),
    };
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(source.name),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SourceDetailLine(label: '数据格式', value: format),
            _SourceDetailLine(label: '目录能力', value: catalog),
            _SourceDetailLine(label: '正文能力', value: chapter),
            _SourceDetailLine(label: '处理方式', value: policy),
            _SourceDetailLine(label: '服务地址', value: source.endpoint),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('关闭'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              unawaited(_testSource(source));
            },
            child: const Text('检测可用性'),
          ),
        ],
      ),
    );
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

  Future<void> _showImporter() async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('批量导入书源'),
        content: SizedBox(
          width: 440,
          child: TextField(
            controller: controller,
            minLines: 8,
            maxLines: 14,
            decoration: const InputDecoration(
              hintText:
                  '[{"name":"我的书源","kind":"json","endpoint":"https://example.com/books.json"}]',
              helperText: '支持 MNovel JSON/JS 清单，可粘贴数组或 {"sources": [...]}',
              alignLabelWithHint: true,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              final data = await Clipboard.getData(Clipboard.kTextPlain);
              controller.text = data?.text ?? '';
            },
            child: const Text('从剪贴板粘贴'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text),
            child: const Text('导入'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (result == null || result.trim().isEmpty) return;
    try {
      final count = await _store.importMany(result);
      await _reload();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('已导入 $count 个书源')));
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
        IconButton(
          tooltip: '批量导入',
          onPressed: _showImporter,
          icon: const Icon(Icons.file_download_outlined, size: 19),
        ),
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
                    final startsCustom =
                        !source.builtIn &&
                        (index == 0 || _sources[index - 1].builtIn);
                    return Column(
                      key: ValueKey(source.id),
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (index == 0)
                          const _SourceSectionLabel(
                            title: '内置公共书源',
                            subtitle: '异构格式由统一后端解析',
                          ),
                        if (startsCustom)
                          _SourceSectionLabel(
                            title: '我的书源',
                            subtitle:
                                '仅保存在当前设备 · ${_sources.where((item) => !item.builtIn).length} 个',
                          ),
                        _SourceRow(
                          index: index,
                          source: source,
                          health: health,
                          latencyMs: latency,
                          editing: _editing,
                          onTap: () => _showSourceDetails(source),
                          onTest: () => _testSource(source),
                          onToggle: (value) => _toggle(source, value),
                          onEdit: source.builtIn
                              ? null
                              : () => _showEditor(source: source),
                          onDelete: source.builtIn
                              ? null
                              : () => _remove(source),
                        ),
                      ],
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
    required this.index,
    required this.source,
    required this.health,
    required this.latencyMs,
    required this.editing,
    required this.onTap,
    required this.onTest,
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
  final VoidCallback onTest;
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
            IconButton(
              tooltip: '检测',
              onPressed: onTest,
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.network_check_rounded, size: 16),
            ),
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

class _SourceSectionLabel extends StatelessWidget {
  const _SourceSectionLabel({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(10, 16, 10, 7),
    child: Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              color: AppColors.text,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        Text(
          subtitle,
          style: const TextStyle(color: AppColors.tertiaryText, fontSize: 9),
        ),
      ],
    ),
  );
}

class _SourceDetailLine extends StatelessWidget {
  const _SourceDetailLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: AppColors.tertiaryText, fontSize: 10),
        ),
        const SizedBox(height: 3),
        SelectableText(value, style: const TextStyle(fontSize: 12)),
      ],
    ),
  );
}
