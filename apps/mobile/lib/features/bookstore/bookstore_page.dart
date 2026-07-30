import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/empty_state.dart';
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
  static const _tabs = ['推荐', '分类', '榜单'];

  late final ContentRepository _repository;
  final _carouselController = PageController();
  String _tab = _tabs.first;
  String _audience = '男';
  HomeData? _data;
  bool _loading = true;
  String? _error;
  int _carouselIndex = 0;
  int _pickOffset = 0;
  int _loadToken = 0;
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
    final token = ++_loadToken;
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
        _data = null;
      });
    }
    try {
      final data = await _repository.home();
      if (!mounted || token != _loadToken) return;
      setState(() {
        _data = data;
        _loading = false;
        _error = null;
        _carouselIndex = 0;
        _pickOffset = 0;
      });
      if (_carouselController.hasClients) _carouselController.jumpToPage(0);
    } catch (error) {
      if (!mounted || token != _loadToken) return;
      setState(() {
        _loading = false;
        _data = null;
        _error = error is ContentRepositoryException
            ? error.message
            : '无法连接在线书源，请检查网络后重试';
      });
    }
  }

  void _changeTab(String value) {
    if (_tab == value) return;
    setState(() => _tab = value);
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
                          itemCount: _tabs.length,
                          separatorBuilder: (_, _) => const SizedBox(width: 26),
                          itemBuilder: (context, index) {
                            final tab = _tabs[index];
                            final selected = tab == _tab;
                            return InkWell(
                              onTap: () => _changeTab(tab),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    tab,
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
                    _AudienceToggle(
                      value: _audience,
                      onChanged: (value) => setState(() => _audience = value),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: _openSearch,
                  child: Container(
                    height: 44,
                    padding: const EdgeInsets.symmetric(horizontal: 13),
                    decoration: BoxDecoration(
                      color: AppColors.sand,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Row(
                      children: [
                        Icon(
                          Icons.search_rounded,
                          color: AppColors.tertiaryText,
                          size: 21,
                        ),
                        SizedBox(width: 9),
                        Text(
                          '请输入作者、书名',
                          style: TextStyle(
                            color: AppColors.tertiaryText,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                if (_tab == '分类')
                  _BookstoreCategoryGrid(onTap: _openCategory)
                else if (_loading)
                  SizedBox(
                    height: (MediaQuery.sizeOf(context).height - 190).clamp(
                      360,
                      720,
                    ),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (_error != null)
                  _BookstoreEmptyState(
                    icon: Icons.cloud_off_outlined,
                    title: '书城暂时不可用',
                    description: '$_error\n在线书源恢复后即可重新获取内容。',
                    onRetry: _load,
                  )
                else if (_data == null || _data!.isEmpty)
                  _BookstoreEmptyState(
                    icon: Icons.auto_stories_outlined,
                    title: '暂时没有可展示的小说',
                    description:
                        '当前频道的启用书源没有返回内容。\n'
                        '你可以稍后重试，或前往书源管理检查状态。',
                    onRetry: _load,
                  )
                else if (_tab == '榜单')
                  _BookstoreRankings(
                    items: _data!.latest.isNotEmpty
                        ? _data!.latest
                        : _data!.carousel,
                    onTap: _open,
                    onMore: _openList,
                  )
                else ...[
                  Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: _data!.fromNetwork
                          ? AppColors.sageSoft
                          : AppColors.coralSoft,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _data!.fromNetwork
                              ? Icons.public_rounded
                              : _data!.fromCache
                              ? Icons.offline_pin_rounded
                              : Icons.cloud_off_rounded,
                          size: 15,
                          color: _data!.fromNetwork
                              ? AppColors.success
                              : AppColors.coral,
                        ),
                        const SizedBox(width: 7),
                        Expanded(
                          child: Text(
                            _data!.fromNetwork
                                ? '下拉可换一批'
                                : _data!.fromCache
                                ? '当前网络不可用，展示最近一次聚合缓存'
                                : '内容来自当前设备启用的自定义书源',
                            style: const TextStyle(
                              color: AppColors.secondaryText,
                              fontSize: 9,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
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

class _BookstoreCategoryGrid extends StatelessWidget {
  const _BookstoreCategoryGrid({required this.onTap});

  final ValueChanged<String> onTap;

  static const _items = [
    ('玄幻', 'assets/design/cover-mystery-lord.png'),
    ('奇幻', 'assets/design/cover-fate-ring.png'),
    ('武侠', 'assets/design/cover-sword-arrival.png'),
    ('仙侠', 'assets/design/cover-weird-immortal.png'),
    ('都市', 'assets/design/cover-night-guard.png'),
    ('历史', 'assets/design/cover-red-heart.png'),
    ('军事', 'assets/covers/cover-changfeng-wenjian.png'),
    ('科幻', 'assets/covers/cover-xinghai-yujin.png'),
    ('游戏', 'assets/covers/cover-fenggui-changan.png'),
    ('悬疑', 'assets/design/cover-underworld-judge.png'),
    ('职场', 'assets/design/cover-mystery-lord.png'),
    ('其他', 'assets/design/cover-fate-ring.png'),
  ];

  @override
  Widget build(BuildContext context) => GridView.builder(
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    itemCount: _items.length,
    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: 3,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: .94,
    ),
    itemBuilder: (context, index) {
      final item = _items[index];
      return InkWell(
        borderRadius: BorderRadius.circular(9),
        onTap: () => onTap(item.$1 == '其他' ? '全部' : item.$1),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(9),
          child: Stack(
            fit: StackFit.expand,
            children: [
              ColorFiltered(
                colorFilter: ColorFilter.mode(
                  Colors.white.withValues(alpha: .38),
                  BlendMode.screen,
                ),
                child: Image.asset(item.$2, fit: BoxFit.cover),
              ),
              const DecoratedBox(
                decoration: BoxDecoration(
                  color: Color.fromRGBO(255, 255, 255, .24),
                ),
              ),
              Align(
                alignment: Alignment.bottomCenter,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 7),
                  color: Colors.white.withValues(alpha: .82),
                  child: Text(
                    item.$1,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.text,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _AudienceToggle extends StatelessWidget {
  const _AudienceToggle({required this.value, required this.onChanged});

  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(3),
    decoration: BoxDecoration(
      color: AppColors.sand,
      borderRadius: BorderRadius.circular(7),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: ['男', '女'].map((label) {
        final selected = value == label;
        return InkWell(
          borderRadius: BorderRadius.circular(5),
          onTap: () => onChanged(label),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: selected ? AppColors.text : Colors.transparent,
              borderRadius: BorderRadius.circular(5),
            ),
            child: Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : AppColors.secondaryText,
                fontSize: 11,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
        );
      }).toList(growable: false),
    ),
  );
}

class _BookstoreRankings extends StatelessWidget {
  const _BookstoreRankings({
    required this.items,
    required this.onTap,
    required this.onMore,
  });

  final List<ContentItem> items;
  final ValueChanged<ContentItem> onTap;
  final void Function(String title, List<ContentItem> items) onMore;

  static const _titles = ['人气榜', '完结榜', '新书榜'];

  @override
  Widget build(BuildContext context) => Column(
    children: List.generate(_titles.length, (sectionIndex) {
      var ranked = items
          .skip(sectionIndex * 3)
          .take(3)
          .toList(growable: false);
      if (ranked.isEmpty) ranked = items.take(3).toList(growable: false);
      return Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.divider, width: .7),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    _titles[sectionIndex],
                    style: const TextStyle(
                      color: AppColors.text,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => onMore(_titles[sectionIndex], ranked),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('更多'),
                      Icon(Icons.chevron_right_rounded, size: 17),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...ranked.indexed.map(
              (entry) => InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => onTap(entry.$2),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      Text(
                        '${entry.$1 + 1}',
                        style: TextStyle(
                          color: entry.$1 == 0
                              ? AppColors.coral
                              : AppColors.secondaryText,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(width: 12),
                      OfflineContentCover(
                        item: entry.$2,
                        width: 38,
                        height: 50,
                        radius: 5,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              entry.$2.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppColors.text,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              entry.$2.creator,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppColors.tertiaryText,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }),
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
            OfflineContentCover(item: item, width: 46, height: 64, radius: 5),
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

class _BookstoreEmptyState extends StatelessWidget {
  const _BookstoreEmptyState({
    required this.icon,
    required this.title,
    required this.description,
    required this.onRetry,
  });

  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: (MediaQuery.sizeOf(context).height - 190).clamp(360, 720),
    child: EmptyState(
      icon: icon,
      title: title,
      description: description,
      actionLabel: '重新加载',
      actionIcon: Icons.refresh_rounded,
      onAction: onRetry,
    ),
  );
}
