import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/content_cover.dart';
import '../../data/content_repository.dart';
import '../../data/shelf_store.dart';
import '../../domain/content.dart';
import '../profile/source_management_page.dart';
import '../reader/chapter_catalog_page.dart';
import '../reader/reader_page.dart';

class ContentDetailPage extends StatefulWidget {
  const ContentDetailPage({super.key, required this.item, this.repository});

  final ContentItem item;
  final ContentRepository? repository;

  @override
  State<ContentDetailPage> createState() => _ContentDetailPageState();
}

class _ContentDetailPageState extends State<ContentDetailPage> {
  late final ContentRepository _repository;
  final _shelfStore = ShelfStore();
  late ContentItem _item = widget.item;
  bool _loading = true;
  bool _saved = false;
  bool _summaryExpanded = false;
  bool _showAllSources = false;
  String? _error;
  late String _selectedSource =
      widget.item.sourceLabels.firstOrNull ?? widget.item.sourceName;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? ContentRepository();
    unawaited(_initialize());
  }

  Future<void> _initialize() async {
    await Future.wait([_loadDetail(), _restoreSaved()]);
  }

  Future<void> _loadDetail() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final detail = await _repository.detail(_item);
      if (!mounted) return;
      setState(() {
        _item = detail;
        _selectedSource = detail.sourceLabels.contains(_selectedSource)
            ? _selectedSource
            : detail.sourceLabels.firstOrNull ?? detail.sourceName;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '详情加载失败，当前展示书架缓存';
      });
    }
  }

  Future<void> _restoreSaved() async {
    final saved = await _shelfStore.contains(_item.id);
    if (!mounted) return;
    setState(() => _saved = saved);
  }

  Future<void> _toggleSaved() async {
    if (_saved) {
      await _shelfStore.remove(_item.id);
    } else {
      await _shelfStore.add(
        _item.copyWith(sourceId: _selectedSource, sourceName: _selectedSource),
      );
    }
    if (!mounted) return;
    setState(() => _saved = !_saved);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(_saved ? '已加入书架' : '已移出书架')));
  }

  void _start({int chapterIndex = 0}) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ReaderPage(
          item: _item.copyWith(
            sourceId: _selectedSource,
            sourceName: _selectedSource,
          ),
          initialChapterIndex: chapterIndex,
          repository: _repository,
        ),
      ),
    );
  }

  Future<void> _share() async {
    final text =
        '《${_item.title}》\n作者：${_item.creator}\n'
        '${_item.summary}\n来源：$_selectedSource';
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('书籍信息已复制，可粘贴分享')));
  }

  Future<void> _openCatalog() async {
    final selected = await Navigator.of(context).push<int>(
      MaterialPageRoute<int>(
        builder: (_) => ChapterCatalogPage(
          item: _item,
          selectedSource: _selectedSource,
          repository: _repository,
        ),
      ),
    );
    if (selected != null && mounted) _start(chapterIndex: selected);
  }

  Future<void> _showMoreMenu() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: AppColors.surface,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.format_list_numbered_rounded),
                title: const Text('查看章节目录'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _openCatalog();
                },
              ),
              ListTile(
                leading: const Icon(Icons.hub_outlined),
                title: const Text('管理书源'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const SourceManagementPage(),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.copy_rounded),
                title: const Text('复制书名'),
                onTap: () async {
                  await Clipboard.setData(ClipboardData(text: _item.title));
                  if (!sheetContext.mounted) return;
                  Navigator.pop(sheetContext);
                  if (!mounted) return;
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(const SnackBar(content: Text('书名已复制')));
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final item = _item;
    final sources = item.sourceLabels.isEmpty
        ? [item.sourceName]
        : item.sourceLabels;
    final visibleSources = _showAllSources ? sources : sources.take(3);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: '返回',
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.chevron_left_rounded, size: 25),
        ),
        title: const SizedBox.shrink(),
        actions: [
          IconButton(
            tooltip: '分享',
            onPressed: _share,
            icon: const Icon(Icons.ios_share_rounded, size: 19),
          ),
          IconButton(
            tooltip: '更多',
            onPressed: _showMoreMenu,
            icon: const Icon(Icons.more_vert_rounded, size: 20),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 116),
        children: [
          if (_loading)
            const Padding(
              padding: EdgeInsets.only(bottom: 10),
              child: LinearProgressIndicator(minHeight: 2),
            ),
          if (_error != null)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: AppColors.coralSoft,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.info_outline_rounded,
                    size: 16,
                    color: AppColors.coral,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _error!,
                      style: const TextStyle(
                        color: AppColors.secondaryText,
                        fontSize: 10,
                      ),
                    ),
                  ),
                  TextButton(onPressed: _loadDetail, child: const Text('重试')),
                ],
              ),
            ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Hero(
                tag: 'cover-${item.id}',
                child: ContentCover(
                  asset: item.coverAsset,
                  width: 84,
                  height: 116,
                  radius: 6,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: const TextStyle(
                        color: AppColors.text,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      item.creator,
                      style: const TextStyle(
                        color: AppColors.secondaryText,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${item.category} · ${item.status.label}',
                      style: const TextStyle(
                        color: AppColors.tertiaryText,
                        fontSize: 10,
                      ),
                    ),
                    const SizedBox(height: 9),
                    Row(
                      children: [
                        Text(
                          item.score.toStringAsFixed(1),
                          style: const TextStyle(
                            color: AppColors.coral,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(width: 5),
                        ...List.generate(
                          5,
                          (index) => Icon(
                            index < (item.score / 2).round()
                                ? Icons.star_rounded
                                : Icons.star_border_rounded,
                            size: 13,
                            color: AppColors.coral,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      item.popularity,
                      style: const TextStyle(
                        color: AppColors.tertiaryText,
                        fontSize: 9,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _StatRow(item: item),
          const Divider(height: 27, color: AppColors.divider),
          const Text(
            '简介',
            style: TextStyle(
              color: AppColors.text,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            item.summary,
            maxLines: _summaryExpanded ? null : 4,
            overflow: _summaryExpanded
                ? TextOverflow.visible
                : TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.text,
              fontSize: 11,
              height: 1.75,
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () =>
                  setState(() => _summaryExpanded = !_summaryExpanded),
              child: Text(
                _summaryExpanded ? '收起' : '展开',
                style: const TextStyle(
                  color: AppColors.secondaryText,
                  fontSize: 9,
                ),
              ),
            ),
          ),
          const Divider(height: 12, color: AppColors.divider),
          Row(
            children: [
              const Expanded(
                child: Text(
                  '来源',
                  style: TextStyle(
                    color: AppColors.text,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                '共 ${sources.length} 个',
                style: const TextStyle(
                  color: AppColors.tertiaryText,
                  fontSize: 9,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ...visibleSources.toList().asMap().entries.map(
            (entry) => _SourceTile(
              source: entry.value,
              subtitle:
                  '${entry.key == 0 ? '最新' : '备用'} · '
                  '${item.latestChapter.isEmpty ? '${item.episodeCount}章' : item.latestChapter}',
              selected: entry.value == _selectedSource,
              onTap: () => setState(() => _selectedSource = entry.value),
            ),
          ),
          if (sources.length > 3)
            TextButton(
              onPressed: () =>
                  setState(() => _showAllSources = !_showAllSources),
              child: Text(_showAllSources ? '收起来源' : '更多来源 >'),
            ),
        ],
      ),
      bottomNavigationBar: DecoratedBox(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(top: BorderSide(color: AppColors.divider, width: .7)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
            child: Row(
              children: [
                OutlinedButton(
                  onPressed: _toggleSaved,
                  child: Text(_saved ? '已在书架' : '加入书架'),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: _loading ? null : _start,
                    child: Text(item.progress > 0 ? '继续阅读' : '开始阅读'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({required this.item});

  final ContentItem item;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 11),
    decoration: const BoxDecoration(
      border: Border(
        top: BorderSide(color: AppColors.divider, width: .7),
        bottom: BorderSide(color: AppColors.divider, width: .7),
      ),
    ),
    child: Row(
      children: [
        _Stat(value: item.wordCountLabel, label: '总字数'),
        _Stat(value: '${item.episodeCount}章', label: '更新至'),
        _Stat(value: '${item.sourceLabels.length}', label: '可切换'),
      ],
    ),
  );
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: AppColors.text,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          style: const TextStyle(color: AppColors.tertiaryText, fontSize: 9),
        ),
      ],
    ),
  );
}

class _SourceTile extends StatelessWidget {
  const _SourceTile({
    required this.source,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final String source;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        children: [
          SizedBox(
            width: 22,
            child: Text(
              '${source.hashCode.abs() % 9 + 1}',
              style: const TextStyle(
                color: AppColors.coral,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  source,
                  style: const TextStyle(
                    color: AppColors.text,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
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
          Icon(
            selected
                ? Icons.check_circle_rounded
                : Icons.radio_button_unchecked_rounded,
            color: selected ? AppColors.coral : AppColors.divider,
            size: 17,
          ),
        ],
      ),
    ),
  );
}
