import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/channel_tabs.dart';
import '../../core/widgets/content_cover.dart';
import '../../core/widgets/empty_state.dart';
import '../../data/content_repository.dart';
import '../../data/source_store.dart';
import '../../domain/content.dart';
import '../detail/content_detail_page.dart';
import '../profile/source_management_page.dart';

class BookstorePage extends StatefulWidget {
  const BookstorePage({super.key, this.repository});

  final ContentRepository? repository;

  @override
  State<BookstorePage> createState() => _BookstorePageState();
}

class _BookstorePageState extends State<BookstorePage> {
  late final ContentRepository _repository;
  final _searchController = TextEditingController();
  ContentChannel _channel = ContentChannel.novel;
  String _query = '';
  List<ContentItem> _items = const [];
  Timer? _searchDebounce;
  bool _loading = true;
  String? _error;
  int _requestId = 0;
  bool _hasSources = true;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? ContentRepository();
    unawaited(_load());
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load({bool showLoading = true}) async {
    final requestId = ++_requestId;
    setState(() {
      if (showLoading) _loading = true;
      _error = null;
    });
    try {
      final sources = await SourceStore().list();
      final active = sources.where((s) => s.enabled && s.channels.contains(_channel));
      final hasSources = active.isNotEmpty;

      final items = await _repository.discover(_channel, query: _query);
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _items = items;
        _loading = false;
        _hasSources = hasSources;
      });
    } on ContentRepositoryException catch (error) {
      if (!mounted || requestId != _requestId) return;
      final sources = await SourceStore().list();
      final active = sources.where((s) => s.enabled && s.channels.contains(_channel));
      setState(() {
        _items = const [];
        _loading = false;
        _error = error.message;
        _hasSources = active.isNotEmpty;
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
      child: RefreshIndicator(
        onRefresh: () => _load(showLoading: false),
        child: CustomScrollView(
          key: PageStorageKey('bookstore-scroll-${_channel.name}'),
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
              sliver: SliverList(
                delegate: SliverChildListDelegate.fixed([
                  TextField(
                    controller: _searchController,
                    onChanged: _onQueryChanged,
                    onSubmitted: (_) => unawaited(_load()),
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      hintText: _channel == ContentChannel.novel
                          ? '搜索书名或作者'
                          : '搜索片名或主创',
                      prefixIcon: const Icon(Icons.search_rounded, size: 22),
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
                  hasSources: _hasSources,
                  query: _query,
                  channel: _channel,
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
                      return _FeaturedCard(
                        item: item,
                        onTap: () => _open(item),
                      );
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
  const _EmptySearch({
    required this.message,
    required this.onRetry,
    required this.hasSources,
    required this.query,
    required this.channel,
  });

  final String message;
  final VoidCallback onRetry;
  final bool hasSources;
  final String query;
  final ContentChannel channel;

  @override
  Widget build(BuildContext context) {
    if (!hasSources) {
      return EmptyState(
        icon: Icons.explore_off_outlined,
        title: '暂无订阅内容源',
        description: '您尚未启用或导入任何可用的${channel.label}内容源，请前往配置。',
        actionLabel: '前往配置内容源',
        onAction: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const SourceManagementPage()),
          ).then((_) => onRetry());
        },
      );
    }
    
    if (query.isNotEmpty) {
      return EmptyState(
        icon: Icons.search_off_rounded,
        title: '未找到匹配结果',
        description: '未在当前启用的数据源中找到与“$query”相关的结果，请尝试其他词。',
        actionLabel: '重新加载',
        onAction: onRetry,
      );
    }

    return EmptyState(
      icon: Icons.cloud_off_rounded,
      title: '加载未成功',
      description: message,
      actionLabel: '重新加载',
      onAction: onRetry,
    );
  }
}
