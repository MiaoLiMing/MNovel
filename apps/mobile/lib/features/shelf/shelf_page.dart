import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/app_shell.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/content_cover.dart';
import '../../core/widgets/novel_widgets.dart';
import '../../data/shelf_store.dart';
import '../../domain/content.dart';
import '../detail/content_detail_page.dart';
import '../search/search_page.dart';

class ShelfPage extends StatefulWidget {
  const ShelfPage({super.key});

  @override
  State<ShelfPage> createState() => _ShelfPageState();
}

class _ShelfPageState extends State<ShelfPage> {
  final _store = ShelfStore();
  bool _loading = true;
  bool _refreshing = false;
  List<ContentItem> _items = const [];

  @override
  void initState() {
    super.initState();
    unawaited(_loadShelf());
  }

  Future<void> _loadShelf({bool refresh = false}) async {
    if (refresh) setState(() => _refreshing = true);
    final items = await _store.list(ContentChannel.novel);
    if (!mounted) return;
    setState(() {
      _items = items;
      _loading = false;
      _refreshing = false;
    });
  }

  void _open(ContentItem item) {
    Navigator.of(context)
        .push(
          MaterialPageRoute<void>(
            builder: (_) => ContentDetailPage(item: item),
          ),
        )
        .then((_) => _loadShelf());
  }

  void _openSearch() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const SearchPage()));
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    bottom: false,
    child: RefreshIndicator(
      color: AppColors.coral,
      onRefresh: () => _loadShelf(refresh: true),
      child: CustomScrollView(
        key: const PageStorageKey('shelf-scroll'),
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            sliver: SliverList.list(
              children: [
                PageTitleBar(
                  title: '书架',
                  actions: [
                    IconButton(
                      tooltip: '搜索',
                      onPressed: _openSearch,
                      icon: const Icon(Icons.search_rounded, size: 20),
                    ),
                    IconButton(
                      tooltip: '同步书架',
                      onPressed: _refreshing
                          ? null
                          : () => _loadShelf(refresh: true),
                      icon: AnimatedRotation(
                        duration: const Duration(milliseconds: 450),
                        turns: _refreshing ? 1 : 0,
                        child: const Icon(Icons.sync_rounded, size: 19),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const SectionTitle(title: '最近阅读'),
                const SizedBox(height: 8),
                if (_loading)
                  const SizedBox(
                    height: 142,
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (_items.isEmpty)
                  _EmptyShelf(
                    onExplore: () => context
                        .findAncestorStateOfType<AppShellState>()
                        ?.setIndex(1),
                  )
                else
                  _RecentReadingCard(
                    item: _items.first,
                    onTap: () => _open(_items.first),
                    onMore: () => _showShelfActions(_items.first),
                  ),
                const SizedBox(height: 22),
                SectionTitle(
                  title: '阅读进度',
                  action: '更新',
                  onAction: () => _loadShelf(refresh: true),
                ),
                const SizedBox(height: 2),
              ],
            ),
          ),
          if (!_loading && _items.isNotEmpty)
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverList.separated(
                itemCount: _items.skip(1).take(3).length,
                itemBuilder: (context, index) {
                  final item = _items[index + 1];
                  return NovelListRow(
                    item: item,
                    progress: item.progress,
                    onTap: () => _open(item),
                    trailing: _UnreadBadge(
                      count: index == 0
                          ? 9
                          : index == 1
                          ? 3
                          : 0,
                    ),
                  );
                },
                separatorBuilder: (_, _) =>
                    const Divider(height: 1, color: AppColors.divider),
              ),
            ),
          if (!_loading && _items.isNotEmpty)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 30),
              sliver: SliverList.list(
                children: [
                  const SectionTitle(title: '最近更新'),
                  const SizedBox(height: 8),
                  ..._items.reversed
                      .take(2)
                      .map(
                        (item) => NovelListRow(
                          item: item,
                          compact: true,
                          onTap: () => _open(item),
                          trailing: const Text(
                            '2天前',
                            style: TextStyle(
                              color: AppColors.tertiaryText,
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ),
                ],
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 10)),
        ],
      ),
    ),
  );

  Future<void> _showShelfActions(ContentItem item) async {
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
                leading: const Icon(Icons.play_arrow_rounded),
                title: const Text('继续阅读'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _open(item);
                },
              ),
              ListTile(
                leading: const Icon(Icons.push_pin_outlined),
                title: const Text('置顶到书架'),
                onTap: () async {
                  await _store.add(item);
                  if (!sheetContext.mounted) return;
                  Navigator.pop(sheetContext);
                  await _loadShelf();
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.delete_outline_rounded,
                  color: AppColors.danger,
                ),
                title: const Text(
                  '移出书架',
                  style: TextStyle(color: AppColors.danger),
                ),
                onTap: () async {
                  await _store.remove(item.id);
                  if (!sheetContext.mounted) return;
                  Navigator.pop(sheetContext);
                  await _loadShelf();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecentReadingCard extends StatelessWidget {
  const _RecentReadingCard({
    required this.item,
    required this.onTap,
    required this.onMore,
  });

  final ContentItem item;
  final VoidCallback onTap;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) => Material(
    color: AppColors.surface,
    borderRadius: BorderRadius.circular(AppRadii.medium),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadii.medium),
      child: Container(
        height: 142,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadii.medium),
          border: Border.all(color: AppColors.divider, width: .7),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ContentCover(
              asset: item.coverAsset,
              width: 72,
              height: 104,
              radius: 6,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.title,
                          style: const TextStyle(
                            color: AppColors.text,
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: '更多',
                        onPressed: onMore,
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(Icons.more_horiz_rounded, size: 18),
                      ),
                    ],
                  ),
                  Text(
                    item.creator,
                    style: const TextStyle(
                      color: AppColors.secondaryText,
                      fontSize: 11,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '读至 第${(item.episodeCount * item.progress).round()}章',
                    style: const TextStyle(
                      color: AppColors.secondaryText,
                      fontSize: 10,
                    ),
                  ),
                  const SizedBox(height: 7),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: LinearProgressIndicator(
                      minHeight: 3,
                      value: item.progress,
                      color: AppColors.coral,
                      backgroundColor: AppColors.divider,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      '${(item.progress * 100).round()}%',
                      style: const TextStyle(
                        color: AppColors.tertiaryText,
                        fontSize: 9,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _UnreadBadge extends StatelessWidget {
  const _UnreadBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    if (count <= 0) {
      return const SizedBox(width: 20);
    }
    return Container(
      width: 20,
      height: 20,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: AppColors.coral,
        shape: BoxShape.circle,
      ),
      child: Text(
        '$count',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 9,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _EmptyShelf extends StatelessWidget {
  const _EmptyShelf({required this.onExplore});

  final VoidCallback onExplore;

  @override
  Widget build(BuildContext context) => Container(
    height: 142,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadii.medium),
      border: Border.all(color: AppColors.divider),
    ),
    child: Row(
      children: [
        const Icon(
          Icons.bookmark_add_outlined,
          color: AppColors.coral,
          size: 34,
        ),
        const SizedBox(width: 14),
        const Expanded(
          child: Text(
            '书架还是空的\n去书城收藏喜欢的小说吧',
            style: TextStyle(
              color: AppColors.secondaryText,
              height: 1.6,
              fontSize: 12,
            ),
          ),
        ),
        TextButton(onPressed: onExplore, child: const Text('去书城')),
      ],
    ),
  );
}
