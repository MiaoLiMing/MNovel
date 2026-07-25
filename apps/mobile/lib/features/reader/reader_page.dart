import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_theme.dart';
import '../../data/content_repository.dart';
import '../../data/offline_library.dart';
import '../../data/reading_progress_store.dart';
import '../../domain/content.dart';
import '../audiobook/audiobook_page.dart';
import 'chapter_catalog_page.dart';
import 'reader_pagination.dart';
import 'reader_settings.dart';

class ReaderPage extends StatefulWidget {
  const ReaderPage({
    super.key,
    required this.item,
    this.initialChapterIndex = 0,
    this.initialChapters,
    this.repository,
  });

  final ContentItem item;
  final int initialChapterIndex;
  final List<Chapter>? initialChapters;
  final ContentRepository? repository;

  @override
  State<ReaderPage> createState() => _ReaderPageState();
}

class _ReaderPageState extends State<ReaderPage> {
  late final ContentRepository _repository;
  final _settingsStore = ReaderSettingsStore();
  final _progressStore = ReadingProgressStore();
  final _offlineStore = OfflineLibraryStore();
  final _paginator = const ReaderPaginator();
  final Map<int, Future<Chapter>> _chapterFutures = {};
  final PageController _pageController = PageController();

  late int _chapterIndex = widget.initialChapterIndex.clamp(
    0,
    math.max(0, widget.item.episodeCount - 1),
  );
  int _pageIndex = 0;
  int _restoreCharacterOffset = 0;
  ReaderSettings _settings = const ReaderSettings();
  List<ReaderPageContent> _pages = const [];
  Chapter? _chapter;
  Size? _viewport;
  String? _paginationSignature;
  String? _loadError;
  bool _controlsVisible = true;
  bool _settingsLoaded = false;
  bool _loading = false;
  bool _switchingChapter = false;
  int _loadToken = 0;
  late String _selectedSource =
      widget.item.sourceLabels.firstOrNull ?? widget.item.sourceName;
  Timer? _autoPageTimer;

  int get _leadingPageCount => _chapterIndex > 0 ? 1 : 0;
  int get _controllerPage => _leadingPageCount + _pageIndex;
  bool get _hasNextChapter => _chapterIndex < widget.item.episodeCount - 1;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? ContentRepository();
    unawaited(_initialize());
  }

  @override
  void dispose() {
    _autoPageTimer?.cancel();
    unawaited(_saveProgress());
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _initialize() async {
    await _offlineStore.initialize();
    final settings = await _settingsStore.load();
    final progress = await _progressStore.load(widget.item.id);
    if (!mounted) return;
    final shouldRestore = widget.initialChapterIndex == 0;
    setState(() {
      _settings = settings;
      _settingsLoaded = true;
      if (shouldRestore) {
        _chapterIndex = progress.chapterIndex.clamp(
          0,
          math.max(0, widget.item.episodeCount - 1),
        );
        _pageIndex = progress.pageIndex;
        _restoreCharacterOffset = progress.characterOffset;
      }
    });
    _syncAutoPage();
    await _loadAndPaginate();
  }

  Future<Chapter> _loadChapter(int index) {
    if (widget.initialChapters != null &&
        index >= 0 &&
        index < widget.initialChapters!.length) {
      return Future.value(widget.initialChapters![index]);
    }
    return _repository.chapter(
      widget.item.copyWith(
        sourceId: _selectedSource,
        sourceName: _selectedSource,
      ),
      index,
    );
  }

  Future<Chapter> _chapterFuture(int index) =>
      _chapterFutures.putIfAbsent(index, () => _loadChapter(index));

  Future<void> _loadAndPaginate({
    int? targetPage,
    bool targetLastPage = false,
    int? characterOffset,
  }) async {
    final viewport = _viewport;
    if (!_settingsLoaded || viewport == null) return;
    final textScaler = MediaQuery.textScalerOf(context);
    final token = ++_loadToken;
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final chapter = await _chapterFuture(_chapterIndex);
      final pages = _paginator.paginate(
        chapter: chapter,
        viewport: viewport,
        settings: _settings,
        textScaler: textScaler,
      );
      if (!mounted || token != _loadToken) return;
      var nextPage = targetLastPage
          ? pages.length - 1
          : targetPage ?? _pageIndex;
      final desiredOffset = characterOffset ?? _restoreCharacterOffset;
      if (desiredOffset > 0) {
        final matched = pages.indexWhere(
          (page) =>
              desiredOffset >= page.startOffset &&
              desiredOffset < page.endOffset,
        );
        if (matched >= 0) nextPage = matched;
      }
      nextPage = nextPage.clamp(0, math.max(0, pages.length - 1));
      setState(() {
        _chapter = chapter;
        _pages = pages;
        _pageIndex = nextPage;
        _restoreCharacterOffset = 0;
        _loading = false;
        _switchingChapter = false;
        _paginationSignature = _signature(viewport);
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_pageController.hasClients) return;
        _pageController.jumpToPage(_controllerPage);
      });
      _preloadAdjacentChapters();
      unawaited(_saveProgress());
    } catch (error) {
      if (!mounted || token != _loadToken) return;
      setState(() {
        _loading = false;
        _switchingChapter = false;
        _loadError = error.toString();
      });
    }
  }

  void _preloadAdjacentChapters() {
    if (_chapterIndex > 0) {
      unawaited(
        _chapterFuture(_chapterIndex - 1).catchError(
          (_) => Chapter(
            index: _chapterIndex - 1,
            title: '',
            paragraphs: const [],
          ),
        ),
      );
    }
    if (_hasNextChapter) {
      unawaited(
        _chapterFuture(_chapterIndex + 1).catchError(
          (_) => Chapter(
            index: _chapterIndex + 1,
            title: '',
            paragraphs: const [],
          ),
        ),
      );
    }
  }

  String _signature(Size size) =>
      '${size.width.toStringAsFixed(1)}:${size.height.toStringAsFixed(1)}:'
      '${_settings.fontSize}:${_settings.lineHeight}:'
      '${_settings.letterSpacing}:${_settings.horizontalPadding}:'
      '${_settings.firstLineIndent}:${_settings.script.name}';

  void _handleViewport(Size size) {
    if (size.width <= 0 || size.height <= 0) return;
    final changed =
        _viewport == null ||
        (_viewport!.width - size.width).abs() > .5 ||
        (_viewport!.height - size.height).abs() > .5;
    _viewport = size;
    if (!_settingsLoaded) return;
    final signature = _signature(size);
    if ((changed || signature != _paginationSignature) && !_loading) {
      final offset = _pages.isEmpty
          ? 0
          : _pages[_pageIndex.clamp(0, _pages.length - 1)].startOffset;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _loadAndPaginate(characterOffset: offset);
        }
      });
    } else if (_pages.isEmpty && !_loading) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _loadAndPaginate();
      });
    }
  }

  Future<void> _switchChapter(int index, {bool targetLastPage = false}) async {
    final target = index
        .clamp(0, math.max(0, widget.item.episodeCount - 1))
        .toInt();
    if (_switchingChapter || target == _chapterIndex) {
      if (_pageController.hasClients) {
        _pageController.jumpToPage(_controllerPage);
      }
      return;
    }
    setState(() {
      _switchingChapter = true;
      _chapterIndex = target;
      _pageIndex = 0;
      _pages = const [];
      _chapter = null;
    });
    await _loadAndPaginate(targetLastPage: targetLastPage);
  }

  Future<void> _turnPage(int delta) async {
    if (_loading || _switchingChapter || _pages.isEmpty) return;
    final target = _pageIndex + delta;
    if (target >= 0 && target < _pages.length) {
      await _moveControllerTo(_leadingPageCount + target);
      return;
    }
    if (delta > 0 && _hasNextChapter) {
      await _switchChapter(_chapterIndex + 1);
    } else if (delta < 0 && _chapterIndex > 0) {
      await _switchChapter(_chapterIndex - 1, targetLastPage: true);
    }
  }

  Future<void> _moveControllerTo(int index) async {
    if (!_pageController.hasClients) return;
    if (_settings.pageMode == ReaderPageMode.none) {
      _pageController.jumpToPage(index);
      return;
    }
    await _pageController.animateToPage(
      index,
      duration: switch (_settings.pageMode) {
        ReaderPageMode.simulation => const Duration(milliseconds: 430),
        ReaderPageMode.cover => const Duration(milliseconds: 320),
        ReaderPageMode.slide => const Duration(milliseconds: 260),
        ReaderPageMode.none => Duration.zero,
      },
      curve: _settings.pageMode == ReaderPageMode.simulation
          ? Curves.easeInOutCubic
          : Curves.easeOutCubic,
    );
  }

  void _onPageChanged(int controllerIndex) {
    if (_switchingChapter || _pages.isEmpty) return;
    if (_leadingPageCount == 1 && controllerIndex == 0) {
      unawaited(_switchChapter(_chapterIndex - 1, targetLastPage: true));
      return;
    }
    final actualIndex = controllerIndex - _leadingPageCount;
    if (actualIndex >= _pages.length) {
      if (_hasNextChapter) {
        unawaited(_switchChapter(_chapterIndex + 1));
      } else {
        _pageController.jumpToPage(_controllerPage);
      }
      return;
    }
    if (actualIndex < 0) return;
    setState(() => _pageIndex = actualIndex);
    unawaited(_saveProgress());
  }

  Future<void> _saveProgress() async {
    final page = _pages.isEmpty
        ? null
        : _pages[_pageIndex.clamp(0, _pages.length - 1)];
    final chapterFraction = _pages.isEmpty
        ? 0.0
        : (_pageIndex + 1) / _pages.length;
    final ratio = widget.item.episodeCount <= 0
        ? 0.0
        : ((_chapterIndex + chapterFraction) / widget.item.episodeCount)
              .clamp(0, 1)
              .toDouble();
    await _progressStore.save(
      widget.item.id,
      chapterIndex: _chapterIndex,
      pageIndex: _pageIndex,
      characterOffset: page?.startOffset ?? 0,
      ratio: ratio,
    );
    unawaited(
      _repository.syncProgress(
        widget.item,
        unitIndex: _chapterIndex,
        position: ratio,
      ),
    );
  }

  Future<void> _openCatalog() async {
    final selected = await Navigator.of(context).push<int>(
      MaterialPageRoute<int>(
        builder: (_) => ChapterCatalogPage(
          item: widget.item,
          selectedSource: _selectedSource,
          repository: _repository,
        ),
      ),
    );
    if (selected != null && mounted) await _switchChapter(selected);
  }

  Future<void> _openAudiobook() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => AudiobookPage(
          item: widget.item.copyWith(
            sourceId: _selectedSource,
            sourceName: _selectedSource,
          ),
          initialChapterIndex: _chapterIndex,
          repository: _repository,
        ),
      ),
    );
  }

  Future<void> _showSources() async {
    final sources = widget.item.sourceLabels.isEmpty
        ? [widget.item.sourceName]
        : widget.item.sourceLabels;
    final selected = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(
              title: Text(
                '切换书源',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              subtitle: Text('切换后从当前章节重新排版'),
            ),
            RadioGroup<String>(
              groupValue: _selectedSource,
              onChanged: (value) {
                if (value != null) Navigator.pop(sheetContext, value);
              },
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final source in sources)
                    RadioListTile<String>(value: source, title: Text(source)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
    if (selected == null || selected == _selectedSource) return;
    setState(() {
      _selectedSource = selected;
      _chapterFutures.clear();
      _pages = const [];
    });
    await _loadAndPaginate();
  }

  Future<void> _showSettings() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: AppColors.surface,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) {
          void update(ReaderSettings value) {
            final offset = _pages.isEmpty
                ? 0
                : _pages[_pageIndex.clamp(0, _pages.length - 1)].startOffset;
            setState(() {
              _settings = value;
              _paginationSignature = null;
            });
            setSheetState(() {});
            unawaited(_settingsStore.save(value));
            _syncAutoPage();
            unawaited(_loadAndPaginate(characterOffset: offset));
          }

          return SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Center(
                    child: Text(
                      '阅读设置',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  _SettingRow(
                    label: '字体大小',
                    child: Row(
                      children: [
                        _SquareButton(
                          label: 'A−',
                          onTap: () => update(
                            _settings.copyWith(
                              fontSize: (_settings.fontSize - 1).clamp(14, 28),
                            ),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            '${_settings.fontSize.round()}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                        _SquareButton(
                          label: 'A+',
                          onTap: () => update(
                            _settings.copyWith(
                              fontSize: (_settings.fontSize + 1).clamp(14, 28),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _SettingRow(
                    label: '行间距',
                    child: Row(
                      children: [1.55, 1.8, 2.05].map((height) {
                        final selected =
                            (_settings.lineHeight - height).abs() < .1;
                        return Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: _SelectionBox(
                              selected: selected,
                              onTap: () => update(
                                _settings.copyWith(lineHeight: height),
                              ),
                              child: const Icon(
                                Icons.format_line_spacing_rounded,
                                size: 18,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    '主题模式',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 9),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: ReaderPalette.values.map((palette) {
                      final selected = _settings.palette == palette;
                      return InkWell(
                        borderRadius: BorderRadius.circular(99),
                        onTap: () =>
                            update(_settings.copyWith(palette: palette)),
                        child: Column(
                          children: [
                            Container(
                              width: 35,
                              height: 35,
                              decoration: BoxDecoration(
                                color: palette.background,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: selected
                                      ? AppColors.coral
                                      : AppColors.divider,
                                  width: selected ? 2 : 1,
                                ),
                              ),
                              child: selected
                                  ? Icon(
                                      Icons.check_rounded,
                                      size: 16,
                                      color: palette.foreground,
                                    )
                                  : null,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              palette.label,
                              style: const TextStyle(fontSize: 9),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    '翻页动画',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 9),
                  Row(
                    children: ReaderPageMode.values.map((mode) {
                      final selected = _settings.pageMode == mode;
                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: _SelectionBox(
                            selected: selected,
                            onTap: () =>
                                update(_settings.copyWith(pageMode: mode)),
                            child: Text(
                              mode.label,
                              style: TextStyle(
                                color: selected
                                    ? AppColors.coral
                                    : AppColors.secondaryText,
                                fontSize: 10,
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    '简繁转换',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 9),
                  Row(
                    children: ReaderScript.values.map((script) {
                      final selected = _settings.script == script;
                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: _SelectionBox(
                            selected: selected,
                            onTap: () =>
                                update(_settings.copyWith(script: script)),
                            child: Text(
                              script == ReaderScript.simplified ? '简体' : '繁体',
                              style: TextStyle(
                                color: selected
                                    ? AppColors.coral
                                    : AppColors.secondaryText,
                                fontSize: 10,
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 10),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('首行缩进'),
                    value: _settings.firstLineIndent,
                    onChanged: (value) =>
                        update(_settings.copyWith(firstLineIndent: value)),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('自动翻页'),
                    subtitle: const Text('每 18 秒翻一页，章末自动进入下一章'),
                    value: _settings.autoPage,
                    onChanged: (value) =>
                        update(_settings.copyWith(autoPage: value)),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _syncAutoPage() {
    _autoPageTimer?.cancel();
    if (!_settings.autoPage) return;
    _autoPageTimer = Timer.periodic(const Duration(seconds: 18), (_) {
      if (mounted) unawaited(_turnPage(1));
    });
  }

  Future<void> _showMore() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.copy_rounded),
              title: const Text('复制当前章节'),
              onTap: () async {
                final chapter = await _chapterFuture(_chapterIndex);
                await Clipboard.setData(
                  ClipboardData(
                    text:
                        '${chapter.title}\n\n${chapter.paragraphs.join('\n\n')}',
                  ),
                );
                if (sheetContext.mounted) Navigator.pop(sheetContext);
              },
            ),
            ListTile(
              leading: const Icon(Icons.download_outlined),
              title: const Text('下载当前章节'),
              onTap: () async {
                await _downloadCurrent();
                if (sheetContext.mounted) Navigator.pop(sheetContext);
              },
            ),
            ListTile(
              leading: const Icon(Icons.hub_outlined),
              title: const Text('切换书源'),
              onTap: () {
                Navigator.pop(sheetContext);
                _showSources();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _downloadCurrent() async {
    try {
      final chapter = await _chapterFuture(_chapterIndex);
      await _offlineStore.saveChapter(
        item: widget.item,
        sourceId: _selectedSource,
        chapter: chapter,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('当前章节已下载，可离线阅读')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('下载失败：$error')));
    }
  }

  void _toggleControls() {
    setState(() => _controlsVisible = !_controlsVisible);
  }

  @override
  Widget build(BuildContext context) {
    if (!_settingsLoaded) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final background = _settings.palette.background;
    final foreground = _settings.palette.foreground;
    final chapterProgress = widget.item.episodeCount <= 0
        ? 0.0
        : (_chapterIndex + 1) / widget.item.episodeCount;
    return Scaffold(
      backgroundColor: background,
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: _settings.palette == ReaderPalette.night
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark,
        child: LayoutBuilder(
          builder: (context, constraints) {
            _handleViewport(constraints.biggest);
            return Stack(
              children: [
                SafeArea(
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTapUp: (details) {
                      final width = MediaQuery.sizeOf(context).width;
                      if (details.localPosition.dx < width * .28) {
                        unawaited(_turnPage(-1));
                      } else if (details.localPosition.dx > width * .72) {
                        unawaited(_turnPage(1));
                      } else {
                        _toggleControls();
                      }
                    },
                    child: _buildPager(background, foreground),
                  ),
                ),
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: IgnorePointer(
                    ignoring: !_controlsVisible,
                    child: AnimatedOpacity(
                      opacity: _controlsVisible ? 1 : 0,
                      duration: const Duration(milliseconds: 180),
                      child: _ReaderTopBar(
                        title: widget.item.title,
                        chapter: _chapter?.title ?? '第 ${_chapterIndex + 1} 章',
                        onBack: () => Navigator.pop(context),
                        onSource: _showSources,
                        onMore: _showMore,
                      ),
                    ),
                  ),
                ),
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 180),
                  right: 18,
                  bottom: _controlsVisible ? 151 : 22,
                  child: FloatingActionButton.small(
                    heroTag: 'audiobook-${widget.item.id}',
                    tooltip: '听书',
                    onPressed: _openAudiobook,
                    backgroundColor: AppColors.coral,
                    foregroundColor: Colors.white,
                    child: const Icon(Icons.headphones_rounded),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: IgnorePointer(
                    ignoring: !_controlsVisible,
                    child: AnimatedOpacity(
                      opacity: _controlsVisible ? 1 : 0,
                      duration: const Duration(milliseconds: 180),
                      child: _ReaderBottomBar(
                        progress: chapterProgress,
                        chapterIndex: _chapterIndex,
                        total: widget.item.episodeCount,
                        pageIndex: _pageIndex,
                        pageCount: _pages.length,
                        night: _settings.palette == ReaderPalette.night,
                        onProgressChanged: (value) => _switchChapter(
                          (value * (widget.item.episodeCount - 1)).round(),
                        ),
                        onPrevious: _chapterIndex == 0
                            ? null
                            : () => _switchChapter(_chapterIndex - 1),
                        onNext: !_hasNextChapter
                            ? null
                            : () => _switchChapter(_chapterIndex + 1),
                        onCatalog: _openCatalog,
                        onNight: () {
                          final palette =
                              _settings.palette == ReaderPalette.night
                              ? ReaderPalette.white
                              : ReaderPalette.night;
                          setState(
                            () => _settings = _settings.copyWith(
                              palette: palette,
                            ),
                          );
                          unawaited(_settingsStore.save(_settings));
                        },
                        onSettings: _showSettings,
                        onSources: _showSources,
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildPager(Color background, Color foreground) {
    if (_loading || _pages.isEmpty) {
      if (_loadError != null) {
        return _ReaderError(
          color: foreground,
          message: _loadError!,
          onRetry: () {
            _chapterFutures.remove(_chapterIndex);
            _loadAndPaginate();
          },
        );
      }
      return Center(
        child: CircularProgressIndicator(
          color: foreground.withValues(alpha: .65),
          strokeWidth: 2,
        ),
      );
    }
    final itemCount =
        _leadingPageCount + _pages.length + (_hasNextChapter ? 1 : 0);
    return PageView.builder(
      controller: _pageController,
      physics: _settings.pageMode == ReaderPageMode.none
          ? const NeverScrollableScrollPhysics()
          : const PageScrollPhysics(),
      itemCount: itemCount,
      onPageChanged: _onPageChanged,
      itemBuilder: (context, index) {
        final actual = index - _leadingPageCount;
        final boundary = actual < 0 || actual >= _pages.length;
        final child = boundary
            ? _BoundaryPage(
                color: foreground,
                label: actual < 0 ? '正在加载上一章…' : '正在加载下一章…',
              )
            : _ReaderTextPage(page: _pages[actual], settings: _settings);
        return _AnimatedPageItem(
          controller: _pageController,
          index: index,
          mode: _settings.pageMode,
          background: background,
          child: child,
        );
      },
    );
  }
}

class _AnimatedPageItem extends StatelessWidget {
  const _AnimatedPageItem({
    required this.controller,
    required this.index,
    required this.mode,
    required this.background,
    required this.child,
  });

  final PageController controller;
  final int index;
  final ReaderPageMode mode;
  final Color background;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (mode == ReaderPageMode.slide || mode == ReaderPageMode.none) {
      return ColoredBox(color: background, child: child);
    }
    return AnimatedBuilder(
      animation: controller,
      child: ColoredBox(color: background, child: child),
      builder: (context, child) {
        final page = controller.hasClients
            ? controller.page ?? controller.initialPage.toDouble()
            : controller.initialPage.toDouble();
        final delta = index - page;
        if (mode == ReaderPageMode.cover) {
          final width = MediaQuery.sizeOf(context).width;
          return Transform.translate(
            offset: Offset(delta > 0 ? -delta * width : 0, 0),
            child: DecoratedBox(
              decoration: BoxDecoration(
                boxShadow: delta.abs() < 1.1
                    ? const [
                        BoxShadow(
                          color: Color(0x26000000),
                          blurRadius: 14,
                          offset: Offset(-5, 0),
                        ),
                      ]
                    : null,
              ),
              child: child,
            ),
          );
        }
        final clamped = delta.clamp(-1.0, 1.0);
        final matrix = Matrix4.identity()
          ..setEntry(3, 2, .0015)
          ..rotateY(-clamped * .48);
        return Transform(
          alignment: clamped > 0 ? Alignment.centerLeft : Alignment.centerRight,
          transform: matrix,
          child: ColorFiltered(
            colorFilter: ColorFilter.mode(
              Colors.black.withValues(alpha: clamped.abs() * .12),
              BlendMode.srcOver,
            ),
            child: child,
          ),
        );
      },
    );
  }
}

class _ReaderTextPage extends StatelessWidget {
  const _ReaderTextPage({required this.page, required this.settings});

  final ReaderPageContent page;
  final ReaderSettings settings;

  @override
  Widget build(BuildContext context) {
    final foreground = settings.palette.foreground;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        settings.horizontalPadding,
        22,
        settings.horizontalPadding,
        28,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (page.isFirstPage) ...[
            Text(
              page.chapterTitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: foreground,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 20),
          ],
          Expanded(
            child: Text(
              _convertScript(page.text, settings.script),
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
              '${page.pageIndex + 1} / ${page.pageCount}',
              style: TextStyle(
                color: foreground.withValues(alpha: .46),
                fontSize: 10,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BoundaryPage extends StatelessWidget {
  const _BoundaryPage({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.auto_stories_outlined,
          color: color.withValues(alpha: .62),
          size: 28,
        ),
        const SizedBox(height: 12),
        Text(label, style: TextStyle(color: color, fontSize: 11)),
      ],
    ),
  );
}

class _ReaderTopBar extends StatelessWidget {
  const _ReaderTopBar({
    required this.title,
    required this.chapter,
    required this.onBack,
    required this.onSource,
    required this.onMore,
  });

  final String title;
  final String chapter;
  final VoidCallback onBack;
  final VoidCallback onSource;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) => SafeArea(
    bottom: false,
    child: Material(
      color: AppColors.surface.withValues(alpha: .97),
      child: SizedBox(
        height: 54,
        child: Row(
          children: [
            IconButton(
              tooltip: '返回',
              onPressed: onBack,
              icon: const Icon(Icons.chevron_left_rounded, size: 25),
            ),
            Expanded(
              child: Text(
                '$title · $chapter',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.text,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            TextButton(onPressed: onSource, child: const Text('换源')),
            IconButton(
              tooltip: '更多',
              onPressed: onMore,
              icon: const Icon(Icons.more_horiz_rounded, size: 20),
            ),
          ],
        ),
      ),
    ),
  );
}

class _ReaderBottomBar extends StatelessWidget {
  const _ReaderBottomBar({
    required this.progress,
    required this.chapterIndex,
    required this.total,
    required this.pageIndex,
    required this.pageCount,
    required this.night,
    required this.onProgressChanged,
    required this.onPrevious,
    required this.onNext,
    required this.onCatalog,
    required this.onNight,
    required this.onSettings,
    required this.onSources,
  });

  final double progress;
  final int chapterIndex;
  final int total;
  final int pageIndex;
  final int pageCount;
  final bool night;
  final ValueChanged<double> onProgressChanged;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final VoidCallback onCatalog;
  final VoidCallback onNight;
  final VoidCallback onSettings;
  final VoidCallback onSources;

  @override
  Widget build(BuildContext context) => Material(
    color: AppColors.surface.withValues(alpha: .98),
    child: SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 5, 14, 0),
            child: Row(
              children: [
                TextButton(onPressed: onPrevious, child: const Text('上一章')),
                Expanded(
                  child: Slider(
                    value: progress.clamp(0, 1),
                    onChanged: onProgressChanged,
                  ),
                ),
                TextButton(onPressed: onNext, child: const Text('下一章')),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Row(
              children: [
                Text(
                  '第 ${chapterIndex + 1} / $total 章',
                  style: const TextStyle(
                    color: AppColors.tertiaryText,
                    fontSize: 9,
                  ),
                ),
                const Spacer(),
                Text(
                  '本章 ${pageIndex + 1} / ${math.max(1, pageCount)} 页',
                  style: const TextStyle(
                    color: AppColors.tertiaryText,
                    fontSize: 9,
                  ),
                ),
              ],
            ),
          ),
          Row(
            children: [
              _ReaderAction(
                icon: Icons.format_list_bulleted_rounded,
                label: '目录',
                onTap: onCatalog,
              ),
              _ReaderAction(
                icon: night
                    ? Icons.light_mode_outlined
                    : Icons.dark_mode_outlined,
                label: night ? '白天' : '夜间',
                onTap: onNight,
              ),
              _ReaderAction(
                icon: Icons.text_fields_rounded,
                label: '设置',
                onTap: onSettings,
              ),
              _ReaderAction(
                icon: Icons.sync_alt_rounded,
                label: '换源',
                onTap: onSources,
              ),
            ],
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
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          children: [
            Icon(icon, color: AppColors.text, size: 19),
            const SizedBox(height: 3),
            Text(
              label,
              style: const TextStyle(
                color: AppColors.secondaryText,
                fontSize: 9,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _ReaderError extends StatelessWidget {
  const _ReaderError({
    required this.color,
    required this.message,
    required this.onRetry,
  });

  final Color color;
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline_rounded, color: color),
          const SizedBox(height: 8),
          Text(
            '章节加载失败',
            style: TextStyle(
              color: color,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            message,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(color: color.withValues(alpha: .7), fontSize: 10),
          ),
          TextButton(onPressed: onRetry, child: const Text('重试')),
        ],
      ),
    ),
  );
}

class _SettingRow extends StatelessWidget {
  const _SettingRow({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      SizedBox(
        width: 62,
        child: Text(
          label,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
        ),
      ),
      Expanded(child: child),
    ],
  );
}

class _SquareButton extends StatelessWidget {
  const _SquareButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: AppColors.sand,
    borderRadius: BorderRadius.circular(8),
    child: InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: SizedBox(
        width: 48,
        height: 34,
        child: Center(
          child: Text(
            label,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
          ),
        ),
      ),
    ),
  );
}

class _SelectionBox extends StatelessWidget {
  const _SelectionBox({
    required this.selected,
    required this.onTap,
    required this.child,
  });

  final bool selected;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) => Material(
    color: selected ? AppColors.coralSoft : AppColors.sand,
    borderRadius: BorderRadius.circular(8),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? AppColors.coral : Colors.transparent,
            width: .8,
          ),
        ),
        child: child,
      ),
    ),
  );
}

String _convertScript(String value, ReaderScript script) {
  if (script == ReaderScript.simplified) return value;
  const replacements = {
    '这': '這',
    '个': '個',
    '为': '為',
    '么': '麼',
    '说': '說',
    '话': '話',
    '没': '沒',
    '时': '時',
    '间': '間',
    '门': '門',
    '开': '開',
    '关': '關',
    '书': '書',
    '来': '來',
    '后': '後',
    '里': '裡',
    '发': '發',
    '现': '現',
    '长': '長',
    '过': '過',
    '还': '還',
    '远': '遠',
    '风': '風',
    '声': '聲',
    '轻': '輕',
    '经': '經',
    '实': '實',
  };
  var converted = value;
  for (final entry in replacements.entries) {
    converted = converted.replaceAll(entry.key, entry.value);
  }
  return converted;
}
