import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_theme.dart';
import '../../data/content_api_repository.dart';
import '../../domain/content.dart';
import 'reader_settings.dart';

class ReaderPage extends StatefulWidget {
  const ReaderPage({super.key, required this.item, this.initialChapters});

  final ContentItem item;
  final List<Chapter>? initialChapters;

  @override
  State<ReaderPage> createState() => _ReaderPageState();
}

class _ReaderPageState extends State<ReaderPage> {
  static const _motion = Duration(milliseconds: 260);

  final _contentRepository = ContentApiRepository();
  final _settingsStore = ReaderSettingsStore();
  PageController _pageController = PageController(initialPage: 1);
  Timer? _autoPageTimer;
  ReaderSettings _settings = const ReaderSettings();
  bool _controlsVisible = false;
  bool _switchingChapter = false;
  bool _chapterLoading = false;
  String? _chapterError;
  int _chapterIndex = 0;
  List<Chapter> _chapters = const [];

  @override
  void initState() {
    super.initState();
    unawaited(_restoreSettings());
    unawaited(_initializeChapters());
  }

  Future<void> _initializeChapters() async {
    if (widget.initialChapters case final chapters?) {
      setState(() => _chapters = chapters);
      return;
    }
    if (!widget.item.isLive) {
      setState(() => _chapterError = '该内容没有可用的真实数据源');
      return;
    }
    final count = math.max(1, widget.item.episodeCount);
    setState(() {
      _chapters = List.generate(
        count,
        (index) => Chapter(title: '第 ${index + 1} 节', paragraphs: const []),
      );
    });
    await _loadChapter(0);
  }

  Future<void> _loadChapter(int index) async {
    if (!widget.item.isLive || index < 0 || index >= _chapters.length) return;
    setState(() {
      _chapterLoading = true;
      _chapterError = null;
    });
    try {
      final chapter = await _contentRepository.chapter(widget.item, index);
      if (!mounted) return;
      setState(() {
        _chapters[index] = chapter;
        _chapterLoading = false;
        _resetPageController();
      });
    } on ContentApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _chapterLoading = false;
        _chapterError = error.message;
      });
    }
  }

  Future<void> _restoreSettings() async {
    final value = await _settingsStore.load();
    if (!mounted) return;
    setState(() => _settings = value);
    _syncDeviceAndAutoPage();
  }

  @override
  void dispose() {
    _autoPageTimer?.cancel();
    unawaited(SystemChrome.setPreferredOrientations(DeviceOrientation.values));
    _pageController.dispose();
    super.dispose();
  }

  void _setSettings(ReaderSettings value) {
    final previous = _settings;
    final requiresRepagination =
        previous.fontSize != value.fontSize ||
        previous.lineHeight != value.lineHeight ||
        previous.letterSpacing != value.letterSpacing ||
        previous.paragraphSpacing != value.paragraphSpacing ||
        previous.horizontalPadding != value.horizontalPadding ||
        previous.firstLineIndent != value.firstLineIndent ||
        previous.pageMode != value.pageMode;
    setState(() {
      _settings = value;
      if (requiresRepagination) _resetPageController();
    });
    unawaited(_settingsStore.save(value));
    _syncDeviceAndAutoPage();
  }

  void _resetPageController() {
    final previous = _pageController;
    _pageController = PageController(initialPage: 1);
    WidgetsBinding.instance.addPostFrameCallback((_) => previous.dispose());
  }

  void _syncDeviceAndAutoPage() {
    unawaited(
      SystemChrome.setPreferredOrientations(
        _settings.landscape
            ? const [
                DeviceOrientation.landscapeLeft,
                DeviceOrientation.landscapeRight,
              ]
            : const [
                DeviceOrientation.portraitUp,
                DeviceOrientation.portraitDown,
              ],
      ),
    );
    _autoPageTimer?.cancel();
    if (!_settings.autoPage || _settings.pageMode == ReaderPageMode.vertical) {
      return;
    }
    _autoPageTimer = Timer.periodic(const Duration(seconds: 6), (_) {
      if (!mounted || _controlsVisible || !_pageController.hasClients) return;
      final position = _pageController.position;
      if (position.pixels >= position.maxScrollExtent - 1) {
        _goToChapter(_chapterIndex + 1);
      } else {
        unawaited(
          _pageController.nextPage(
            duration: const Duration(milliseconds: 520),
            curve: Curves.easeInOutCubic,
          ),
        );
      }
    });
  }

  bool _goToChapter(int index) {
    final chapters = _chapters;
    if (index < 0 || index >= chapters.length || _switchingChapter) {
      return false;
    }
    _switchingChapter = true;
    setState(() {
      _chapterIndex = index;
      _resetPageController();
    });
    if (widget.item.isLive && chapters[index].paragraphs.isEmpty) {
      unawaited(_loadChapter(index));
    }
    Future<void>.delayed(const Duration(milliseconds: 320), () {
      _switchingChapter = false;
    });
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final chapters = _chapters;
    if (chapters.isEmpty) {
      return Scaffold(
        backgroundColor: _settings.palette.background,
        body: Center(
          child: _chapterError == null
              ? const CircularProgressIndicator()
              : Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    _chapterError!,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: _settings.palette.foreground),
                  ),
                ),
        ),
      );
    }
    final chapter = chapters[_chapterIndex];
    final background = _settings.palette.background;
    final foreground = _settings.palette.foreground;

    return Scaffold(
      backgroundColor: background,
      body: SafeArea(
        child: Stack(
          children: [
            if (_chapterLoading)
              const Center(child: CircularProgressIndicator())
            else if (_chapterError != null)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_chapterError!, textAlign: TextAlign.center),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: () => _loadChapter(_chapterIndex),
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('重新获取正文'),
                      ),
                    ],
                  ),
                ),
              )
            else
              LayoutBuilder(
                builder: (context, constraints) => GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapUp: (details) {
                    final width = constraints.maxWidth;
                    if (details.localPosition.dx > width * .32 &&
                        details.localPosition.dx < width * .68) {
                      setState(() => _controlsVisible = !_controlsVisible);
                    }
                  },
                  child: _ReaderBody(
                    chapter: chapter,
                    settings: _settings,
                    foreground: foreground,
                    pageController: _pageController,
                    onPageChanged: (_) {},
                    onChapterBoundary: (direction) {
                      return _goToChapter(_chapterIndex + direction);
                    },
                  ),
                ),
              ),
            IgnorePointer(
              child: ColoredBox(
                color: Colors.black.withValues(
                  alpha: (1 - _settings.brightness) * .42,
                ),
                child: const SizedBox.expand(),
              ),
            ),
            AnimatedSlide(
              duration: _motion,
              curve: Curves.easeOutCubic,
              offset: _controlsVisible ? Offset.zero : const Offset(0, -1.1),
              child: AnimatedOpacity(
                duration: _motion,
                opacity: _controlsVisible ? 1 : 0,
                child: _ReaderTopBar(
                  title: widget.item.title,
                  night: _settings.palette == ReaderPalette.night,
                  onBack: () => Navigator.of(context).pop(),
                ),
              ),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: AnimatedSlide(
                duration: _motion,
                curve: Curves.easeOutCubic,
                offset: _controlsVisible ? Offset.zero : const Offset(0, 1.05),
                child: AnimatedOpacity(
                  duration: _motion,
                  opacity: _controlsVisible ? 1 : 0,
                  child: IgnorePointer(
                    ignoring: !_controlsVisible,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _ChapterNavigationBar(
                          current: _chapterIndex + 1,
                          total: chapters.length,
                          night: _settings.palette == ReaderPalette.night,
                          onPrevious: _chapterIndex == 0
                              ? null
                              : () => _goToChapter(_chapterIndex - 1),
                          onNext: _chapterIndex == chapters.length - 1
                              ? null
                              : () => _goToChapter(_chapterIndex + 1),
                        ),
                        _ReaderBottomBar(
                          night: _settings.palette == ReaderPalette.night,
                          onCatalog: () => _showCatalog(chapters),
                          onNight: _toggleNight,
                          onSettings: _showSettings,
                          onSources: _showSources,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _toggleNight() {
    final isNight = _settings.palette == ReaderPalette.night;
    _setSettings(
      _settings.copyWith(
        palette: isNight ? ReaderPalette.parchment : ReaderPalette.night,
      ),
    );
  }

  void _showCatalog(List<Chapter> chapters) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      enableDrag: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: .72,
        minChildSize: .28,
        maxChildSize: .94,
        snap: true,
        snapSizes: const [.45, .72, .94],
        shouldCloseOnMinExtent: true,
        expand: false,
        builder: (context, scrollController) => Material(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              const _SheetHandle(),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 12, 12),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        '目录',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Text('${chapters.length} 章'),
                    IconButton(
                      tooltip: '关闭目录',
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.keyboard_arrow_down_rounded),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  itemCount: chapters.length,
                  itemBuilder: (context, index) => ListTile(
                    selected: index == _chapterIndex,
                    selectedTileColor: AppColors.sage.withValues(alpha: .09),
                    selectedColor: AppColors.sage,
                    title: Text(chapters[index].title),
                    trailing: index == _chapterIndex
                        ? const Icon(
                            Icons.menu_book_rounded,
                            color: AppColors.sage,
                          )
                        : null,
                    onTap: () {
                      _goToChapter(index);
                      Navigator.pop(context);
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSettings() {
    var draft = _settings;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      enableDrag: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: .76,
        minChildSize: .38,
        maxChildSize: .94,
        expand: false,
        snap: true,
        builder: (context, scrollController) => StatefulBuilder(
          builder: (context, setSheetState) {
            void update(ReaderSettings value) {
              draft = value;
              setSheetState(() {});
              _setSettings(value);
            }

            return Material(
              color: draft.palette.background,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(28),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  Expanded(
                    child: ListView(
                      controller: scrollController,
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
                      children: [
                        const _SheetHandle(),
                        Row(
                          children: [
                            Text(
                              '阅读设置',
                              style: TextStyle(
                                color: draft.palette.foreground,
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const Spacer(),
                            IconButton(
                              tooltip: '关闭设置',
                              onPressed: () => Navigator.pop(context),
                              icon: const Icon(
                                Icons.keyboard_arrow_down_rounded,
                              ),
                            ),
                          ],
                        ),
                        _SettingLine(
                          label: '亮度',
                          child: Row(
                            children: [
                              Expanded(
                                child: Slider(
                                  value: draft.brightness,
                                  onChanged: (value) =>
                                      update(draft.copyWith(brightness: value)),
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Text('护眼'),
                              Switch(
                                value: draft.eyeCare,
                                onChanged: (value) => update(
                                  draft.copyWith(
                                    eyeCare: value,
                                    palette: value
                                        ? ReaderPalette.eyeCare
                                        : draft.palette,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        _SettingLine(
                          label: '字号',
                          child: Row(
                            children: [
                              _PillButton(
                                label: 'A−',
                                onTap: () => update(
                                  draft.copyWith(
                                    fontSize: (draft.fontSize - 1).clamp(
                                      15,
                                      30,
                                    ),
                                  ),
                                ),
                              ),
                              SizedBox(
                                width: 46,
                                child: Text(
                                  '${draft.fontSize.round()}',
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              _PillButton(
                                label: 'A+',
                                onTap: () => update(
                                  draft.copyWith(
                                    fontSize: (draft.fontSize + 1).clamp(
                                      15,
                                      30,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        _SettingLine(
                          label: '背景',
                          child: Wrap(
                            spacing: 14,
                            runSpacing: 10,
                            children: ReaderPalette.values.map((palette) {
                              final selected = draft.palette == palette;
                              return Tooltip(
                                message: palette.label,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(28),
                                  onTap: () => update(
                                    draft.copyWith(
                                      palette: palette,
                                      eyeCare: palette == ReaderPalette.eyeCare,
                                    ),
                                  ),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 180),
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      color: palette.background,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: selected
                                            ? AppColors.text
                                            : Colors.black.withValues(
                                                alpha: .10,
                                              ),
                                        width: selected ? 2.5 : 1,
                                      ),
                                    ),
                                    child: selected
                                        ? Icon(
                                            Icons.check_rounded,
                                            color: palette.foreground,
                                          )
                                        : null,
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                        _SettingLine(
                          label: '翻页',
                          child: SegmentedButton<ReaderPageMode>(
                            segments: ReaderPageMode.values
                                .map(
                                  (mode) => ButtonSegment(
                                    value: mode,
                                    label: Text(mode.label),
                                  ),
                                )
                                .toList(),
                            selected: {draft.pageMode},
                            showSelectedIcon: false,
                            onSelectionChanged: (value) =>
                                update(draft.copyWith(pageMode: value.first)),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            FilterChip(
                              label: const Text('自动翻页'),
                              avatar: const Icon(
                                Icons.play_arrow_rounded,
                                size: 18,
                              ),
                              selected: draft.autoPage,
                              onSelected: (value) =>
                                  update(draft.copyWith(autoPage: value)),
                            ),
                            FilterChip(
                              label: const Text('横屏'),
                              avatar: const Icon(
                                Icons.screen_rotation_rounded,
                                size: 18,
                              ),
                              selected: draft.landscape,
                              onSelected: (value) =>
                                  update(draft.copyWith(landscape: value)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ExpansionTile(
                          tilePadding: EdgeInsets.zero,
                          title: const Text('字体与行距'),
                          subtitle: const Text('行高、字距、段距、页边距与首行缩进'),
                          children: [
                            _AdvancedSlider(
                              label: '行高',
                              value: draft.lineHeight,
                              min: 1.4,
                              max: 2.4,
                              onChanged: (value) =>
                                  update(draft.copyWith(lineHeight: value)),
                            ),
                            _AdvancedSlider(
                              label: '字距',
                              value: draft.letterSpacing,
                              min: 0,
                              max: 1.5,
                              onChanged: (value) =>
                                  update(draft.copyWith(letterSpacing: value)),
                            ),
                            _AdvancedSlider(
                              label: '段距',
                              value: draft.paragraphSpacing,
                              min: 8,
                              max: 32,
                              onChanged: (value) => update(
                                draft.copyWith(paragraphSpacing: value),
                              ),
                            ),
                            _AdvancedSlider(
                              label: '页边距',
                              value: draft.horizontalPadding,
                              min: 14,
                              max: 38,
                              onChanged: (value) => update(
                                draft.copyWith(horizontalPadding: value),
                              ),
                            ),
                            SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('首行缩进'),
                              value: draft.firstLineIndent,
                              onChanged: (value) => update(
                                draft.copyWith(firstLineIndent: value),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  _ReaderBottomBar(
                    night: draft.palette == ReaderPalette.night,
                    onCatalog: () {
                      Navigator.pop(context);
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted) _showCatalog(_chapters);
                      });
                    },
                    onNight: () {
                      final nextPalette = draft.palette == ReaderPalette.night
                          ? ReaderPalette.parchment
                          : ReaderPalette.night;
                      update(
                        draft.copyWith(
                          palette: nextPalette,
                          eyeCare: nextPalette == ReaderPalette.eyeCare,
                        ),
                      );
                    },
                    onSettings: () {},
                    onSources: () {
                      Navigator.pop(context);
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted) _showSources();
                      });
                    },
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  void _showSources() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => const SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(12, 0, 12, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: Text('本地 OPDS / JSON'),
                subtitle: Text('12 章 · 41ms · 当前来源'),
                trailing: Icon(Icons.check_rounded, color: AppColors.sage),
              ),
              ListTile(
                title: Text('Project Gutenberg OPDS'),
                subtitle: Text('公共领域内容 · 只读目录'),
              ),
              ListTile(
                title: Text('Open Library'),
                subtitle: Text('书目与版本信息 · 不提供盗版正文'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReaderBody extends StatelessWidget {
  const _ReaderBody({
    required this.chapter,
    required this.settings,
    required this.foreground,
    required this.pageController,
    required this.onPageChanged,
    required this.onChapterBoundary,
  });

  final Chapter chapter;
  final ReaderSettings settings;
  final Color foreground;
  final PageController pageController;
  final ValueChanged<int> onPageChanged;
  final bool Function(int) onChapterBoundary;

  @override
  Widget build(BuildContext context) {
    if (settings.pageMode == ReaderPageMode.vertical) {
      return SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          settings.horizontalPadding,
          34,
          settings.horizontalPadding,
          90,
        ),
        child: _ChapterText(
          chapter: chapter,
          settings: settings,
          foreground: foreground,
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final pages = _paginateChapter(
          chapter,
          Size(constraints.maxWidth, constraints.maxHeight),
          settings,
        );
        return PageView.builder(
          key: ValueKey('${chapter.title}-${settings.hashCode}'),
          controller: pageController,
          itemCount: pages.length + 2,
          onPageChanged: (index) {
            if (index == 0) {
              if (!onChapterBoundary(-1)) {
                pageController.animateToPage(
                  1,
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                );
              }
              return;
            }
            if (index == pages.length + 1) {
              if (!onChapterBoundary(1)) {
                pageController.animateToPage(
                  pages.length,
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                );
              }
              return;
            }
            onPageChanged(index - 1);
          },
          itemBuilder: (context, index) {
            if (index == 0 || index == pages.length + 1) {
              return ColoredBox(color: settings.palette.background);
            }
            final contentIndex = index - 1;
            final page = _ReaderPageText(
              chapterTitle: chapter.title,
              text: pages[contentIndex],
              page: contentIndex + 1,
              pageCount: pages.length,
              settings: settings,
              foreground: foreground,
            );
            if (settings.pageMode != ReaderPageMode.simulation) return page;
            return AnimatedBuilder(
              animation: pageController,
              child: page,
              builder: (context, child) {
                final current =
                    pageController.hasClients &&
                        pageController.position.haveDimensions
                    ? pageController.page ?? 1
                    : 1.0;
                final delta = (index - current).clamp(-1.0, 1.0);
                return Transform(
                  alignment: delta >= 0
                      ? Alignment.centerLeft
                      : Alignment.centerRight,
                  transform: Matrix4.identity()
                    ..setEntry(3, 2, .0014)
                    ..rotateY(delta * math.pi * .08),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(
                            alpha: delta.abs() * .16,
                          ),
                          blurRadius: 18,
                          offset: Offset(-delta * 8, 0),
                        ),
                      ],
                    ),
                    child: child,
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

List<String> _paginateChapter(
  Chapter chapter,
  Size size,
  ReaderSettings settings,
) {
  final indent = settings.firstLineIndent ? '　　' : '';
  var remaining = chapter.paragraphs.map((p) => '$indent$p').join('\n\n');
  final pages = <String>[];
  final style = TextStyle(
    fontSize: settings.fontSize,
    height: settings.lineHeight,
    letterSpacing: settings.letterSpacing,
  );
  final width = math.max(120.0, size.width - settings.horizontalPadding * 2);
  final height = math.max(160.0, size.height - 146);

  while (remaining.isNotEmpty) {
    final painter = TextPainter(
      text: TextSpan(text: remaining, style: style),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: width);
    if (painter.height <= height) {
      pages.add(remaining);
      break;
    }
    var end = painter
        .getPositionForOffset(Offset(width - 2, height - 2))
        .offset;
    end = end.clamp(1, remaining.length);
    final searchFrom = math.max(1, end - 48);
    final punctuation = RegExp(r'[。！？\n]');
    var preferred = -1;
    for (var i = end - 1; i >= searchFrom; i--) {
      if (punctuation.hasMatch(remaining[i])) {
        preferred = i + 1;
        break;
      }
    }
    if (preferred > 0) end = preferred;
    pages.add(remaining.substring(0, end).trim());
    remaining = remaining.substring(end).trimLeft();
  }
  return pages.isEmpty ? const ['本章暂无正文'] : pages;
}

class _ChapterText extends StatelessWidget {
  const _ChapterText({
    required this.chapter,
    required this.settings,
    required this.foreground,
  });

  final Chapter chapter;
  final ReaderSettings settings;
  final Color foreground;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        chapter.title,
        style: TextStyle(
          color: foreground,
          fontSize: settings.fontSize + 3,
          fontWeight: FontWeight.w700,
        ),
      ),
      const SizedBox(height: 28),
      ...chapter.paragraphs.map(
        (paragraph) => Padding(
          padding: EdgeInsets.only(bottom: settings.paragraphSpacing),
          child: Text(
            '${settings.firstLineIndent ? '　　' : ''}$paragraph',
            style: TextStyle(
              color: foreground,
              fontSize: settings.fontSize,
              height: settings.lineHeight,
              letterSpacing: settings.letterSpacing,
            ),
          ),
        ),
      ),
    ],
  );
}

class _ReaderPageText extends StatelessWidget {
  const _ReaderPageText({
    required this.chapterTitle,
    required this.text,
    required this.page,
    required this.pageCount,
    required this.settings,
    required this.foreground,
  });

  final String chapterTitle;
  final String text;
  final int page;
  final int pageCount;
  final ReaderSettings settings;
  final Color foreground;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: settings.palette.background,
    child: Padding(
      padding: EdgeInsets.fromLTRB(
        settings.horizontalPadding,
        28,
        settings.horizontalPadding,
        24,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            chapterTitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: foreground.withValues(alpha: page == 1 ? 1 : .55),
              fontSize: page == 1 ? settings.fontSize + 3 : 13,
              fontWeight: page == 1 ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: foreground,
                fontSize: settings.fontSize,
                height: settings.lineHeight,
                letterSpacing: settings.letterSpacing,
              ),
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              '$page / $pageCount',
              style: TextStyle(
                color: foreground.withValues(alpha: .42),
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _ReaderTopBar extends StatelessWidget {
  const _ReaderTopBar({
    required this.title,
    required this.night,
    required this.onBack,
  });

  final String title;
  final bool night;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) => Material(
    color: night ? const Color(0xFF20221F) : Colors.white,
    elevation: 1,
    child: SizedBox(
      height: 58,
      child: Row(
        children: [
          IconButton(
            tooltip: '返回',
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back_ios_new_rounded),
          ),
          Expanded(
            child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
          IconButton(
            tooltip: '书签',
            onPressed: () {},
            icon: const Icon(Icons.bookmark_border_rounded),
          ),
          IconButton(
            tooltip: '更多',
            onPressed: () {},
            icon: const Icon(Icons.more_horiz_rounded),
          ),
        ],
      ),
    ),
  );
}

class _ChapterNavigationBar extends StatelessWidget {
  const _ChapterNavigationBar({
    required this.current,
    required this.total,
    required this.night,
    required this.onPrevious,
    required this.onNext,
  });

  final int current;
  final int total;
  final bool night;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) => Material(
    color: night ? const Color(0xFF252824) : const Color(0xFFF6F7F3),
    child: SizedBox(
      height: 50,
      child: Row(
        children: [
          Expanded(
            child: TextButton.icon(
              onPressed: onPrevious,
              icon: const Icon(Icons.chevron_left_rounded),
              label: const Text('上一章'),
            ),
          ),
          Text(
            '$current / $total',
            style: TextStyle(
              color: night ? Colors.white54 : AppColors.secondaryText,
              fontSize: 12,
            ),
          ),
          Expanded(
            child: TextButton.icon(
              onPressed: onNext,
              iconAlignment: IconAlignment.end,
              icon: const Icon(Icons.chevron_right_rounded),
              label: const Text('下一章'),
            ),
          ),
        ],
      ),
    ),
  );
}

class _ReaderBottomBar extends StatelessWidget {
  const _ReaderBottomBar({
    required this.night,
    required this.onCatalog,
    required this.onNight,
    required this.onSettings,
    required this.onSources,
  });

  final bool night;
  final VoidCallback onCatalog;
  final VoidCallback onNight;
  final VoidCallback onSettings;
  final VoidCallback onSources;

  @override
  Widget build(BuildContext context) => Material(
    color: night ? const Color(0xFF20221F) : Colors.white,
    elevation: 8,
    child: SizedBox(
      height: 76,
      child: Row(
        children: [
          _ReaderAction(
            icon: Icons.format_list_bulleted_rounded,
            label: '目录',
            onTap: onCatalog,
          ),
          _ReaderAction(
            icon: night ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
            label: '夜间',
            onTap: onNight,
          ),
          _ReaderAction(
            icon: Icons.text_fields_rounded,
            label: '设置',
            onTap: onSettings,
          ),
          _ReaderAction(
            icon: Icons.swap_horiz_rounded,
            label: '换源',
            onTap: onSources,
          ),
        ],
      ),
    ),
  );
}

class _ReaderAction extends StatelessWidget {
  const _ReaderAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Expanded(
    child: InkWell(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon),
          const SizedBox(height: 5),
          Text(label, style: const TextStyle(fontSize: 12)),
        ],
      ),
    ),
  );
}

class _SheetHandle extends StatelessWidget {
  const _SheetHandle();

  @override
  Widget build(BuildContext context) => Center(
    child: Container(
      width: 42,
      height: 4,
      margin: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: .18),
        borderRadius: BorderRadius.circular(4),
      ),
    ),
  );
}

class _SettingLine extends StatelessWidget {
  const _SettingLine({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 10),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 58,
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        Expanded(child: child),
      ],
    ),
  );
}

class _PillButton extends StatelessWidget {
  const _PillButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Expanded(
    child: FilledButton.tonal(
      onPressed: onTap,
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 12),
      ),
      child: Text(label, style: const TextStyle(fontSize: 18)),
    ),
  );
}

class _AdvancedSlider extends StatelessWidget {
  const _AdvancedSlider({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      SizedBox(width: 68, child: Text(label)),
      Expanded(
        child: Slider(value: value, min: min, max: max, onChanged: onChanged),
      ),
      SizedBox(
        width: 38,
        child: Text(value.toStringAsFixed(1), textAlign: TextAlign.end),
      ),
    ],
  );
}
