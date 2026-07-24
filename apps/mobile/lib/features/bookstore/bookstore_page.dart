import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/content_cover.dart';
import '../../core/widgets/novel_widgets.dart';
import '../../data/content_repository.dart';
import '../../domain/content.dart';
import '../category/category_page.dart';
import '../detail/content_detail_page.dart';
import '../search/search_page.dart';
import 'discover_list_page.dart';

class BookstorePage extends StatefulWidget {
  const BookstorePage({super.key, this.repository});

  final ContentRepository? repository;

  @override
  State<BookstorePage> createState() => _BookstorePageState();
}

class _BookstorePageState extends State<BookstorePage> {
  static const _channels = ['推荐', '男生', '女生', '出版'];

  late final ContentRepository _repository;
  final _carouselController = PageController();
  String _channel = _channels.first;
  HomeData? _data;
  bool _loading = true;
  String? _error;
  int _carouselIndex = 0;
  int _pickOffset = 0;
  Timer? _carouselTimer;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? ContentRepository();
    unawaited(_load());
    _carouselTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      final data = _data;
      if (!mounted || data == null || data.carousel.length < 2) return;
      final next = (_carouselIndex + 1) % data.carousel.length;
      _carouselController.animateToPage(
        next,
        duration: const Duration(milliseconds: 380),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  void dispose() {
    _carouselTimer?.cancel();
    _carouselController.dispose();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final data = await _repository.home(channel: _channel);
      if (!mounted) return;
      setState(() {
        _data = data;
        _loading = false;
        _error = null;
        _carouselIndex = 0;
        _pickOffset = 0;
      });
      if (_carouselController.hasClients) _carouselController.jumpToPage(0);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '书城加载失败，请检查网络后重试';
      });
    }
  }

  void _changeChannel(String value) {
    if (_channel == value) return;
    setState(() => _channel = value);
    unawaited(_load());
  }

  void _open(ContentItem item) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ContentDetailPage(item: item, repository: _repository),
      ),
    );
  }

  void _openSearch() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SearchPage(repository: _repository),
      ),
    );
  }

  void _openCategory(String category) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CategoryPage(
          initialCategory: category,
          standalone: true,
          repository: _repository,
        ),
      ),
    );
  }

  void _openList(String title, List<ContentItem> items) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => DiscoverListPage(
          channel: ContentChannel.novel,
          title: title,
          listType: title == '精选推荐' ? 'featured' : 'ranking',
          repository: _repository,
          initialItems: items,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    bottom: false,
    child: RefreshIndicator(
      color: AppColors.coral,
      onRefresh: () => _load(silent: true),
      child: CustomScrollView(
        key: const PageStorageKey('bookstore-scroll'),
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            sliver: SliverList.list(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 48,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: _channels.length,
                          separatorBuilder: (_, _) => const SizedBox(width: 20),
                          itemBuilder: (context, index) {
                            final channel = _channels[index];
                            final selected = channel == _channel;
                            return InkWell(
                              onTap: () => _changeChannel(channel),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    channel,
                                    style: TextStyle(
                                      color: selected
                                          ? AppColors.text
                                          : AppColors.secondaryText,
                                      fontSize: selected ? 15 : 13,
                                      fontWeight: selected
                                          ? FontWeight.w800
                                          : FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 5),
                                  AnimatedContainer(
                                    duration: const Duration(milliseconds: 180),
                                    width: selected ? 20 : 0,
                                    height: 2,
                                    decoration: BoxDecoration(
                                      color: AppColors.coral,
                                      borderRadius: BorderRadius.circular(99),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: '搜索小说',
                      onPressed: _openSearch,
                      icon: const Icon(Icons.search_rounded, size: 20),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (_loading)
                  const SizedBox(
                    height: 170,
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (_error != null)
                  _LoadError(message: _error!, onRetry: _load)
                else ...[
                  _HeroCarousel(
                    items: _data!.carousel,
                    controller: _carouselController,
                    currentIndex: _carouselIndex,
                    onPageChanged: (value) =>
                        setState(() => _carouselIndex = value),
                    onTap: _open,
                  ),
                  const SizedBox(height: 15),
                  _QuickCategories(onTap: _openCategory),
                  const SizedBox(height: 20),
                  SectionTitle(
                    title: '精选推荐',
                    action: '换一换',
                    onAction: _rotatePicks,
                  ),
                  const SizedBox(height: 8),
                  _PickGrid(items: _visiblePicks(), onTap: _open),
                  const SizedBox(height: 18),
                  SectionTitle(
                    title: '最近上新',
                    action: '更多',
                    onAction: () => _openList('最近上新', _data!.latest),
                  ),
                  const SizedBox(height: 4),
                  ..._data!.latest
                      .take(4)
                      .map(
                        (item) => NovelListRow(
                          item: item,
                          compact: true,
                          onTap: () => _open(item),
                          trailing: const Icon(
                            Icons.chevron_right_rounded,
                            color: AppColors.tertiaryText,
                            size: 18,
                          ),
                        ),
                      ),
                ],
                const SizedBox(height: 28),
              ],
            ),
          ),
        ],
      ),
    ),
  );

  List<ContentItem> _visiblePicks() {
    final picks = _data!.editorsPick;
    if (picks.isEmpty) return _data!.carousel.take(4).toList();
    return List.generate(
      picks.length.clamp(0, 4),
      (index) => picks[(_pickOffset + index) % picks.length],
    );
  }

  void _rotatePicks() {
    final length = _data?.editorsPick.length ?? 0;
    if (length < 2) return;
    setState(() => _pickOffset = (_pickOffset + 1) % length);
  }
}

class _HeroCarousel extends StatelessWidget {
  const _HeroCarousel({
    required this.items,
    required this.controller,
    required this.currentIndex,
    required this.onPageChanged,
    required this.onTap,
  });

  final List<ContentItem> items;
  final PageController controller;
  final int currentIndex;
  final ValueChanged<int> onPageChanged;
  final ValueChanged<ContentItem> onTap;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 158,
    child: Stack(
      children: [
        PageView.builder(
          controller: controller,
          itemCount: items.length,
          onPageChanged: onPageChanged,
          itemBuilder: (context, index) {
            final item = items[index];
            return Material(
              color: const Color(0xFF1B2329),
              borderRadius: BorderRadius.circular(AppRadii.medium),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => onTap(item),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.asset(
                      'assets/design/bookstore-hero.png',
                      fit: BoxFit.cover,
                      alignment: Alignment.centerRight,
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 22, 150, 18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 21,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 7),
                          Text(
                            item.creator,
                            style: const TextStyle(
                              color: Color(0xFFD8DFE2),
                              fontSize: 11,
                            ),
                          ),
                          const Spacer(),
                          const Text(
                            '沉浸阅读 · 多源聚合',
                            style: TextStyle(
                              color: Color(0xFFB9C5C9),
                              fontSize: 9,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 8,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              items.length,
              (index) => AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: index == currentIndex ? 13 : 4,
                height: 4,
                margin: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(
                  color: index == currentIndex
                      ? AppColors.coral
                      : Colors.white.withValues(alpha: .7),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

class _QuickCategories extends StatelessWidget {
  const _QuickCategories({required this.onTap});

  final ValueChanged<String> onTap;

  static const _items = [
    ('分类', Icons.grid_view_rounded),
    ('排行榜', Icons.workspace_premium_rounded),
    ('完结', Icons.bookmark_added_rounded),
    ('新书', Icons.new_releases_rounded),
    ('书单', Icons.favorite_rounded),
  ];

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: _items.map((entry) {
      return InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => onTap(
          entry.$1 == '完结'
              ? '全部'
              : entry.$1 == '新书'
              ? '玄幻'
              : entry.$1 == '排行榜'
              ? '仙侠'
              : entry.$1 == '书单'
              ? '都市'
              : '全部',
        ),
        child: SizedBox(
          width: 54,
          child: Column(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: const BoxDecoration(
                  color: AppColors.coral,
                  shape: BoxShape.circle,
                ),
                child: Icon(entry.$2, color: Colors.white, size: 18),
              ),
              const SizedBox(height: 5),
              Text(
                entry.$1,
                style: const TextStyle(
                  color: AppColors.secondaryText,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
      );
    }).toList(),
  );
}

class _PickGrid extends StatelessWidget {
  const _PickGrid({required this.items, required this.onTap});

  final List<ContentItem> items;
  final ValueChanged<ContentItem> onTap;

  @override
  Widget build(BuildContext context) => GridView.builder(
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    itemCount: items.length,
    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 2.45,
    ),
    itemBuilder: (context, index) {
      final item = items[index];
      return InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => onTap(item),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ContentCover(
              asset: item.coverAsset,
              width: 46,
              height: 64,
              radius: 5,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.text,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.creator,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.secondaryText,
                      fontSize: 9,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    item.tags.firstOrNull ?? item.category,
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
      );
    },
  );
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 170,
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.cloud_off_rounded, color: AppColors.tertiaryText),
        const SizedBox(height: 8),
        Text(
          message,
          style: const TextStyle(color: AppColors.secondaryText, fontSize: 11),
        ),
        TextButton(onPressed: onRetry, child: const Text('重新加载')),
      ],
    ),
  );
}
