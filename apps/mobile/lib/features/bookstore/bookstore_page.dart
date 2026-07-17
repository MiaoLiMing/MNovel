import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/channel_tabs.dart';
import '../../core/widgets/content_cover.dart';
import '../../data/content_api_repository.dart';
import '../../domain/content.dart';
import '../detail/content_detail_page.dart';

class BookstorePage extends StatefulWidget {
  const BookstorePage({super.key});

  @override
  State<BookstorePage> createState() => _BookstorePageState();
}

class _BookstorePageState extends State<BookstorePage> {
  final _repository = ContentApiRepository();
  final _searchController = TextEditingController();
  ContentChannel _channel = ContentChannel.novel;
  String _query = '';
  List<ContentItem> _items = const [];
  Timer? _searchDebounce;
  bool _loading = true;
  String? _error;
  int _requestId = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final requestId = ++_requestId;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await _repository.discover(_channel, query: _query);
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _items = items;
        _loading = false;
      });
    } on ContentApiException catch (error) {
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _items = const [];
        _loading = false;
        _error = error.message;
      });
    }
  }

  void _onQueryChanged(String value) {
    setState(() => _query = value);
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 420), _load);
  }

  void _changeChannel(ContentChannel value) {
    setState(() {
      _channel = value;
      _query = '';
      _searchController.clear();
    });
    unawaited(_load());
  }

  void _open(ContentItem item) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => ContentDetailPage(item: item)));
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;

    return SafeArea(
      bottom: false,
      child: CustomScrollView(
        key: const PageStorageKey('bookstore-scroll'),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
            sliver: SliverList(
              delegate: SliverChildListDelegate.fixed([
                Text('书城', style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 16),
                TextField(
                  controller: _searchController,
                  onChanged: _onQueryChanged,
                  onSubmitted: (_) => unawaited(_load()),
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: _channel == ContentChannel.novel
                        ? '搜索书名或作者'
                        : '搜索片名或主创',
                    prefixIcon: const Icon(Icons.search_rounded, size: 25),
                    suffixIcon: _query.isEmpty
                        ? null
                        : IconButton(
                            tooltip: '清空搜索',
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _query = '');
                              unawaited(_load());
                            },
                            icon: const Icon(Icons.close_rounded),
                          ),
                  ),
                ),
                const SizedBox(height: 10),
                ChannelTabs(value: _channel, onChanged: _changeChannel),
                const Divider(height: 1),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(
                      Icons.cloud_done_outlined,
                      color: AppColors.sage,
                      size: 17,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '实时公开目录 · 非演示数据',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ]),
            ),
          ),
          if (_loading)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(child: CircularProgressIndicator()),
            )
          else if (items.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: _EmptySearch(
                message: _error ?? '当前真实来源没有返回内容',
                onRetry: _load,
              ),
            )
          else ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
                child: _SectionHeader(
                  title: _channel == ContentChannel.novel ? '今日精选' : '正在热播',
                  action: '更多',
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 292,
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
                  scrollDirection: Axis.horizontal,
                  itemCount: items.take(3).length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(width: 14),
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return _FeaturedCard(item: item, onTap: () => _open(item));
                  },
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
              sliver: SliverToBoxAdapter(
                child: _SectionHeader(
                  title: _channel == ContentChannel.novel ? '热门榜单' : '热度榜单',
                  action: '完整榜单',
                ),
              ),
            ),
            SliverList(
              delegate: SliverChildBuilderDelegate((context, index) {
                final item = items[index % items.length];
                return _RankingRow(
                  index: index,
                  item: item,
                  onTap: () => _open(item),
                );
              }, childCount: items.length < 5 ? 5 : items.length),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        ],
      ),
    );
  }
}

class _FeaturedCard extends StatelessWidget {
  const _FeaturedCard({required this.item, required this.onTap});

  final ContentItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 132,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Hero(
              tag: 'cover-${item.id}',
              child: ContentCover(
                asset: item.coverAsset,
                width: 132,
                height: 176,
              ),
            ),
            const SizedBox(height: 9),
            Text(
              item.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Text(item.category, maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 3),
            Text(
              item.popularity,
              style: const TextStyle(color: AppColors.sage, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _RankingRow extends StatelessWidget {
  const _RankingRow({
    required this.index,
    required this.item,
    required this.onTap,
  });

  final int index;
  final ContentItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.divider)),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 32,
              child: Text(
                '${index + 1}',
                style: TextStyle(
                  color: index < 3
                      ? const Color(0xFFF07C32)
                      : AppColors.secondaryText,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            ContentCover(
              asset: item.coverAsset,
              width: 58,
              height: 72,
              radius: 8,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text('${item.creator} · ${item.category}'),
                ],
              ),
            ),
            Text(
              item.popularity,
              style: const TextStyle(color: AppColors.sage, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.action});

  final String title;
  final String action;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(title, style: Theme.of(context).textTheme.titleLarge),
        ),
        TextButton(onPressed: () {}, child: Text(action)),
      ],
    );
  }
}

class _EmptySearch extends StatelessWidget {
  const _EmptySearch({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.search_off_rounded,
            size: 44,
            color: AppColors.secondaryText,
          ),
          const SizedBox(height: 12),
          const Text('没有可展示的真实内容'),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(message, textAlign: TextAlign.center),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('重新加载'),
          ),
        ],
      ),
    );
  }
}
