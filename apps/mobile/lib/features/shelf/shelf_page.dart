import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/app_shell.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/channel_tabs.dart';
import '../../core/widgets/content_cover.dart';
import '../../core/widgets/empty_state.dart';
import '../../data/shelf_store.dart';
import '../../domain/content.dart';
import '../detail/content_detail_page.dart';

class ShelfPage extends StatefulWidget {
  const ShelfPage({super.key});

  @override
  State<ShelfPage> createState() => _ShelfPageState();
}

class _ShelfPageState extends State<ShelfPage> {
  final _store = ShelfStore();
  ContentChannel _channel = ContentChannel.novel;
  bool _grid = true;
  bool _loading = true;
  List<ContentItem> _items = const [];

  @override
  void initState() {
    super.initState();
    unawaited(_loadShelf());
  }

  Future<void> _loadShelf() async {
    final items = await _store.list(_channel);
    if (!mounted) return;
    setState(() {
      _items = items;
      _loading = false;
    });
  }

  void _changeChannel(ContentChannel value) {
    setState(() {
      _channel = value;
      _loading = true;
    });
    unawaited(_loadShelf());
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;
    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        onRefresh: _loadShelf,
        child: CustomScrollView(
          key: const PageStorageKey('shelf-scroll'),
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
              sliver: SliverList(
                delegate: SliverChildListDelegate.fixed([
                  Row(
                    children: [
                      Expanded(
                        child: ChannelTabs(value: _channel, onChanged: _changeChannel),
                      ),
                      IconButton(
                        tooltip: '切换布局',
                        onPressed: () => setState(() => _grid = !_grid),
                        icon: Icon(
                          _grid
                              ? Icons.view_list_outlined
                              : Icons.grid_view_outlined,
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 1),
                  const SizedBox(height: 22),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _channel == ContentChannel.novel ? '最近阅读' : '继续观看',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                      Text(
                        '${items.length} 项',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ]),
              ),
            ),
            if (_loading)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: CircularProgressIndicator()),
              )
            else if (items.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: _EmptyShelf(),
              )
            else if (_grid)
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    childAspectRatio: .56,
                    crossAxisSpacing: 14,
                    mainAxisSpacing: 18,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => _ShelfGridItem(
                      item: items[index],
                      onTap: () => _open(items[index]),
                    ),
                    childCount: items.length,
                  ),
                ),
              )
            else
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) => _ShelfListItem(
                    item: items[index],
                    onTap: () => _open(items[index]),
                  ),
                  childCount: items.length,
                ),
              ),
          const SliverToBoxAdapter(child: SizedBox(height: 30)),
        ],
      ),
    ),
  );
}

  Future<void> _open(ContentItem item) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => ContentDetailPage(item: item)),
    );
    await _loadShelf();
  }
}

class _EmptyShelf extends StatelessWidget {
  const _EmptyShelf();

  @override
  Widget build(BuildContext context) => EmptyState(
    icon: Icons.bookmark_add_outlined,
    title: '书架空空如也',
    description: '您可以去书城浏览并收藏喜爱的小说、短剧或影视内容，它们会自动同步在这里。',
    actionLabel: '去书城逛逛',
    onAction: () {
      context.findAncestorStateOfType<AppShellState>()?.setIndex(1);
    },
  );
}

class _ShelfGridItem extends StatelessWidget {
  const _ShelfGridItem({required this.item, required this.onTap});
  final ContentItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ContentCover(
              asset: item.coverAsset,
              width: double.infinity,
              height: double.infinity,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            item.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 5),
          LinearProgressIndicator(
            value: item.progress,
            minHeight: 3,
            color: AppColors.sage,
            backgroundColor: AppColors.sageSoft,
          ),
          const SizedBox(height: 4),
          Text(
            '已完成 ${(item.progress * 100).round()}%',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _ShelfListItem extends StatelessWidget {
  const _ShelfListItem({required this.item, required this.onTap});
  final ContentItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      onTap: onTap,
      leading: ContentCover(
        asset: item.coverAsset,
        width: 58,
        height: 76,
        radius: 8,
      ),
      title: Text(item.title, style: Theme.of(context).textTheme.titleMedium),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Text('${item.category}\n已完成 ${(item.progress * 100).round()}%'),
      ),
      isThreeLine: true,
      trailing: const Icon(Icons.chevron_right_rounded),
    );
  }
}
