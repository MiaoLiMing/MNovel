import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/content_cover.dart';
import '../../data/content_repository.dart';
import '../../domain/content.dart';
import '../detail/content_detail_page.dart';

class CategoryPage extends StatefulWidget {
  const CategoryPage({super.key});

  @override
  State<CategoryPage> createState() => _CategoryPageState();
}

class _CategoryPageState extends State<CategoryPage> {
  ContentChannel _channel = ContentChannel.novel;
  String _selected = '全部';
  final _repository = ContentRepository();
  List<ContentItem> _items = const [];
  bool _loading = true;
  String? _error;
  int _requestId = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final requestId = ++_requestId;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await _repository.discover(_channel, category: _selected);
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _items = items;
        _loading = false;
      });
    } on ContentRepositoryException catch (error) {
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _items = const [];
        _loading = false;
        _error = error.message;
      });
    }
  }

  void _selectChannel(ContentChannel value) {
    setState(() {
      _channel = value;
      _selected = '全部';
    });
    unawaited(_load());
  }

  void _selectCategory(String label) {
    setState(() => _selected = label);
    unawaited(_load());
  }

  List<String> get _categories {
    switch (_channel) {
      case ContentChannel.novel:
        return const ['全部', '都市', '玄幻', '仙侠', '科幻', '历史', '悬疑', '古言', '现实'];
      case ContentChannel.shortDrama:
        return const ['全部', '甜宠', '悬疑', '逆袭', '都市', '古装', '家庭', '喜剧', '职场'];
      case ContentChannel.video:
        return const ['全部', '电影', '剧集', '综艺', '纪录片', '动画', '动作', '剧情', '自然'];
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: ListView(
        key: const PageStorageKey('category-scroll'),
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 30),
        children: [
          Text('分类', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 18),
          SegmentedButton(
            values: ContentChannel.values,
            selected: _channel,
            onChanged: _selectChannel,
          ),
          const SizedBox(height: 26),
          Text('按类型浏览', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _categories
                .map(
                  (label) => ChoiceChip(
                    label: Text(label),
                    selected: label == _selected,
                    selectedColor: AppColors.sageSoft,
                    labelStyle: TextStyle(
                      color: label == _selected
                          ? AppColors.sage
                          : AppColors.text,
                      fontWeight: label == _selected
                          ? FontWeight.w600
                          : FontWeight.w400,
                    ),
                    onSelected: (_) => _selectCategory(label),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 32),
          Text('高级筛选', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          const _FilterRow(label: '状态', value: '全部状态'),
          const _FilterRow(label: '更新时间', value: '最近 30 天'),
          const _FilterRow(label: '排序', value: '热度优先'),
          const SizedBox(height: 28),
          Row(
            children: [
              Expanded(
                child: Text(
                  '真实来源结果',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              Text('${_items.length} 项'),
            ],
          ),
          const SizedBox(height: 12),
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(36),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_items.isEmpty)
            _CategoryEmpty(message: _error ?? '此分类暂无真实来源结果', onRetry: _load)
          else
            ..._items.map(
              (item) => ListTile(
                contentPadding: const EdgeInsets.symmetric(vertical: 7),
                leading: ContentCover(
                  asset: item.coverAsset,
                  width: 54,
                  height: 72,
                  radius: 8,
                ),
                title: Text(
                  item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  '${item.creator}\n${item.sourceName}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                isThreeLine: true,
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => ContentDetailPage(item: item),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _CategoryEmpty extends StatelessWidget {
  const _CategoryEmpty({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(22),
    decoration: BoxDecoration(
      color: AppColors.sageSoft,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Column(
      children: [
        Text(message, textAlign: TextAlign.center),
        const SizedBox(height: 10),
        TextButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('重试'),
        ),
      ],
    ),
  );
}

class SegmentedButton extends StatelessWidget {
  const SegmentedButton({
    super.key,
    required this.values,
    required this.selected,
    required this.onChanged,
  });
  final List<ContentChannel> values;
  final ContentChannel selected;
  final ValueChanged<ContentChannel> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.sageSoft,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: values
            .map(
              (value) => Expanded(
                child: InkWell(
                  onTap: () => onChanged(value),
                  borderRadius: BorderRadius.circular(11),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    alignment: Alignment.center,
                    height: 42,
                    decoration: BoxDecoration(
                      color: value == selected
                          ? Colors.white
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Text(
                      value.label,
                      style: TextStyle(
                        fontWeight: value == selected
                            ? FontWeight.w600
                            : FontWeight.w400,
                      ),
                    ),
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _FilterRow extends StatelessWidget {
  const _FilterRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.divider)),
      ),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(value),
          const SizedBox(width: 6),
          const Icon(Icons.chevron_right_rounded),
        ],
      ),
    );
  }
}
