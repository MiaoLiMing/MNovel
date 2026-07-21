import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/channel_tabs.dart';
import '../../core/widgets/content_cover.dart';
import '../../core/widgets/empty_state.dart';
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

  // Interactive filter states
  String _status = '全部状态';
  String _time = '全部时间';
  String _sort = '热度优先';

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
      _status = '全部状态';
      _time = '全部时间';
      _sort = '热度优先';
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

  void _showFilterOptions(
    String title,
    String currentValue,
    List<String> options,
    ValueChanged<String> onChanged,
  ) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Text(
                '选择$title',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                textAlign: TextAlign.center,
              ),
            ),
            const Divider(height: 1),
            ...options.map((option) {
              final isSelected = option == currentValue;
              return ListTile(
                title: Text(
                  option,
                  style: TextStyle(
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected ? AppColors.sage : AppColors.text,
                  ),
                ),
                trailing: isSelected ? const Icon(Icons.check, color: AppColors.sage, size: 20) : null,
                onTap: () {
                  onChanged(option);
                  Navigator.pop(context);
                  unawaited(_load());
                },
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterTab({
    required String label,
    required String value,
    required List<String> options,
    required ValueChanged<String> onChanged,
  }) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: InkWell(
          onTap: () => _showFilterOptions(label, value, options, onChanged),
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFEAECF0),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.text,
                    ),
                  ),
                ),
                const SizedBox(width: 2),
                const Icon(Icons.arrow_drop_down, size: 16, color: AppColors.secondaryText),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          // Top tabs matching Bookstore style
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ChannelTabs(value: _channel, onChanged: _selectChannel),
          ),
          const Divider(height: 1),
          
          // Side-by-side split columns
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Left Column: Category Sidebar
                SizedBox(
                  width: 96,
                  child: Container(
                    color: const Color(0xFFF1F3F5),
                    child: ListView.builder(
                      itemCount: _categories.length,
                      itemBuilder: (context, index) {
                        final label = _categories[index];
                        final isSelected = label == _selected;
                        return InkWell(
                          onTap: () => _selectCategory(label),
                          child: Container(
                            height: 54,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: isSelected ? Colors.white : Colors.transparent,
                              border: isSelected
                                  ? const Border(
                                      left: BorderSide(color: AppColors.sage, width: 4),
                                    )
                                  : null,
                            ),
                            child: Text(
                              label,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                color: isSelected ? AppColors.sage : AppColors.text,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                
                const VerticalDivider(width: 1, thickness: 1),
                
                // Right Column: Advanced Sub-filters (Top) and Content List (Bottom)
                Expanded(
                  child: Container(
                    color: Colors.white,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Advanced Filters Row
                        Padding(
                          padding: const EdgeInsets.fromLTRB(8, 12, 8, 12),
                          child: Row(
                            children: [
                              _buildFilterTab(
                                label: '状态',
                                value: _status,
                                options: const ['全部状态', '连载中', '已完结'],
                                onChanged: (val) => setState(() => _status = val),
                              ),
                              _buildFilterTab(
                                label: '更新时间',
                                value: _time,
                                options: const ['全部时间', '最近 7 天', '最近 30 天', '三月前'],
                                onChanged: (val) => setState(() => _time = val),
                              ),
                              _buildFilterTab(
                                label: '排序',
                                value: _sort,
                                options: const ['热度优先', '评分优先', '更新优先'],
                                onChanged: (val) => setState(() => _sort = val),
                              ),
                            ],
                          ),
                        ),
                        const Divider(height: 1),
                        
                        // Content List Panel
                        Expanded(
                          child: _loading
                              ? const Center(child: CircularProgressIndicator())
                              : RefreshIndicator(
                                  onRefresh: _load,
                                  child: _items.isEmpty
                                      ? ListView(
                                          children: [
                                            Padding(
                                              padding: const EdgeInsets.only(top: 80),
                                              child: EmptyState(
                                                icon: Icons.category_outlined,
                                                title: '此分类暂无内容',
                                                description: _error ?? '在此筛选条件下未能加载到有效内容，请重试或配置其他源。',
                                                actionLabel: '重新加载',
                                                onAction: _load,
                                              ),
                                            ),
                                          ],
                                        )
                                      : ListView.separated(
                                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                                          itemCount: _items.length,
                                          separatorBuilder: (context, index) => const Divider(height: 1),
                                          itemBuilder: (context, index) {
                                            final item = _items[index];
                                            return ListTile(
                                              contentPadding: const EdgeInsets.symmetric(vertical: 6),
                                              leading: ContentCover(
                                                asset: item.coverAsset,
                                                width: 50,
                                                height: 68,
                                                radius: 6,
                                              ),
                                              title: Text(
                                                item.title,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                                              ),
                                              subtitle: Padding(
                                                padding: const EdgeInsets.only(top: 4),
                                                child: Text(
                                                  '${item.creator} · ${item.sourceName}',
                                                  maxLines: 2,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: const TextStyle(fontSize: 12),
                                                ),
                                              ),
                                              trailing: const Icon(Icons.chevron_right_rounded, size: 20),
                                              onTap: () => Navigator.of(context).push(
                                                MaterialPageRoute<void>(
                                                  builder: (_) => ContentDetailPage(item: item),
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
