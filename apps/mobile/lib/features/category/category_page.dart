import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/novel_widgets.dart';
import '../../data/content_repository.dart';
import '../../domain/content.dart';
import '../bookstore/discover_list_page.dart';

class CategoryPage extends StatefulWidget {
  const CategoryPage({
    super.key,
    this.initialCategory = '全部',
    this.standalone = false,
    this.repository,
  });

  final String initialCategory;
  final bool standalone;
  final ContentRepository? repository;

  @override
  State<CategoryPage> createState() => _CategoryPageState();
}

class _CategoryPageState extends State<CategoryPage> {
  late final ContentRepository _repository;
  List<FilterGroup> _groups = const [];
  Map<String, String> _selected = const {};
  int _resultCount = 0;
  bool _loading = true;
  bool _counting = false;
  String? _error;
  int _requestId = 0;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? ContentRepository();
    unawaited(_initialize());
  }

  Future<void> _initialize() async {
    try {
      final groups = await _repository.taxonomy();
      final selected = <String, String>{
        for (final group in groups) group.id: group.options.first.value,
      };
      if (selected.containsKey('category')) {
        selected['category'] = widget.initialCategory;
      }
      if (!mounted) return;
      setState(() {
        _groups = groups;
        _selected = selected;
        _loading = false;
      });
      await _refreshCount();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '分类信息加载失败';
      });
    }
  }

  Future<void> _refreshCount() async {
    final requestId = ++_requestId;
    setState(() => _counting = true);
    final items = await _repository.discover(
      ContentChannel.novel,
      category: _selected['category'] ?? '',
      status: _selected['status'] ?? '',
      wordCount: _selected['word_count'] ?? '',
      source: _selected['source'] ?? '',
    );
    if (!mounted || requestId != _requestId) return;
    setState(() {
      _resultCount = items.length;
      _counting = false;
    });
  }

  void _select(String groupId, String value) {
    setState(() => _selected = {..._selected, groupId: value});
    unawaited(_refreshCount());
  }

  void _reset() {
    setState(() {
      _selected = {
        for (final group in _groups) group.id: group.options.first.value,
      };
    });
    unawaited(_refreshCount());
  }

  Future<void> _showResults() async {
    final items = await _repository.discover(
      ContentChannel.novel,
      category: _selected['category'] ?? '',
      status: _selected['status'] ?? '',
      wordCount: _selected['word_count'] ?? '',
      source: _selected['source'] ?? '',
    );
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => DiscoverListPage(
          channel: ContentChannel.novel,
          title: '筛选结果',
          listType: 'category',
          repository: _repository,
          initialItems: items,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final content = SafeArea(
      bottom: false,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 4, 10, 0),
            child: SizedBox(
              height: 48,
              child: Row(
                children: [
                  if (widget.standalone)
                    IconButton(
                      tooltip: '返回',
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.chevron_left_rounded, size: 24),
                    )
                  else
                    const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      '分类',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.text,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: _groups.isEmpty ? null : _reset,
                    child: const Text(
                      '重置',
                      style: TextStyle(
                        color: AppColors.secondaryText,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(child: _buildBody()),
          if (!_loading && _error == null)
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                child: FilledButton(
                  onPressed: _counting ? null : _showResults,
                  child: Text(_counting ? '正在统计…' : '查看结果 ($_resultCount)'),
                ),
              ),
            ),
        ],
      ),
    );
    return widget.standalone
        ? Scaffold(backgroundColor: AppColors.canvas, body: content)
        : content;
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded, color: AppColors.tertiaryText),
            const SizedBox(height: 8),
            Text(
              _error!,
              style: const TextStyle(
                color: AppColors.secondaryText,
                fontSize: 12,
              ),
            ),
            TextButton(onPressed: _initialize, child: const Text('重试')),
          ],
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
      itemCount: _groups.length,
      separatorBuilder: (_, _) =>
          const Divider(height: 26, color: AppColors.divider),
      itemBuilder: (context, index) {
        final group = _groups[index];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              group.label,
              style: const TextStyle(
                color: AppColors.text,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: group.options
                  .map(
                    (option) => FilterChipButton(
                      label: option.label,
                      dense: true,
                      selected: _selected[group.id] == option.value,
                      onTap: () => _select(group.id, option.value),
                    ),
                  )
                  .toList(),
            ),
          ],
        );
      },
    );
  }
}
