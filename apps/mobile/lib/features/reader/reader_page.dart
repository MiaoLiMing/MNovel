import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/theme/app_theme.dart';
import '../../data/content_repository.dart';
import '../../data/reading_progress_store.dart';
import '../../domain/content.dart';
import 'chapter_catalog_page.dart';
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
  late final PageController _pageController;
  final _settingsStore = ReaderSettingsStore();
  final _progressStore = ReadingProgressStore();
  final Map<int, Future<Chapter>> _chapterFutures = {};

  late int _chapterIndex = widget.initialChapterIndex.clamp(
    0,
    widget.item.episodeCount - 1,
  );
  ReaderSettings _settings = const ReaderSettings();
  bool _controlsVisible = true;
  bool _settingsLoaded = false;
  late String _selectedSource =
      widget.item.sourceLabels.firstOrNull ?? widget.item.sourceName;
  Timer? _autoPageTimer;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? ContentRepository();
    _pageController = PageController(initialPage: _chapterIndex);
    unawaited(_restoreSettings());
  }

  @override
  void dispose() {
    _autoPageTimer?.cancel();
    unawaited(_saveProgress());
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _restoreSettings() async {
    final settings = await _settingsStore.load();
    final progress = await _progressStore.load(widget.item.id);
    if (!mounted) return;
    final restoredIndex = widget.initialChapterIndex > 0
        ? widget.initialChapterIndex
        : progress.chapterIndex.clamp(0, widget.item.episodeCount - 1);
    setState(() {
      _settings = settings;
      _settingsLoaded = true;
      _chapterIndex = restoredIndex;
    });
    if (_pageController.hasClients &&
        _pageController.page?.round() != restoredIndex) {
      _pageController.jumpToPage(restoredIndex);
    }
    _syncAutoPage();
  }

  Future<Chapter> _loadChapter(int index) {
    if (widget.initialChapters != null &&
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

  Future<void> _saveProgress() => _progressStore.save(
    widget.item.id,
    chapterIndex: _chapterIndex,
    ratio: (_chapterIndex + 1) / widget.item.episodeCount,
  );

  void _changeChapter(int index) {
    final target = index.clamp(0, widget.item.episodeCount - 1);
    _pageController.animateToPage(
      target,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  void _onPageChanged(int index) {
    setState(() => _chapterIndex = index);
    unawaited(_saveProgress());
  }

  void _toggleControls() {
    setState(() => _controlsVisible = !_controlsVisible);
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
    if (selected != null && mounted) _changeChapter(selected);
  }

  Future<void> _showSources() async {
    final sources = widget.item.sourceLabels.isEmpty
        ? [widget.item.sourceName]
        : widget.item.sourceLabels;
    final selected = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      backgroundColor: AppColors.surface,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '切换书源',
                style: TextStyle(
                  color: AppColors.text,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              RadioGroup<String>(
                groupValue: _selectedSource,
                onChanged: (value) {
                  if (value != null) Navigator.pop(sheetContext, value);
                },
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: sources
                      .map(
                        (source) => RadioListTile<String>(
                          value: source,
                          activeColor: AppColors.coral,
                          title: Text(source),
                          subtitle: const Text('章节可用 · 自动记住选择'),
                        ),
                      )
                      .toList(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (selected == null || selected == _selectedSource) return;
    setState(() {
      _selectedSource = selected;
      _chapterFutures.clear();
    });
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
            setState(() => _settings = value);
            setSheetState(() {});
            unawaited(_settingsStore.save(value));
            _syncAutoPage();
          }

          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Center(
                    child: Text(
                      '阅读设置',
                      style: TextStyle(
                        color: AppColors.text,
                        fontSize: 15,
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
                            style: const TextStyle(
                              color: AppColors.text,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
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
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: _SelectionBox(
                              selected: selected,
                              onTap: () => update(
                                _settings.copyWith(lineHeight: height),
                              ),
                              child: Icon(
                                Icons.format_line_spacing_rounded,
                                color: selected
                                    ? AppColors.coral
                                    : AppColors.secondaryText,
                                size: 18 + ((height - 1.55) * 4),
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
                    style: TextStyle(
                      color: AppColors.text,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
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
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              width: 34,
                              height: 34,
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
                            const SizedBox(height: 5),
                            Text(
                              palette.label,
                              style: const TextStyle(
                                color: AppColors.secondaryText,
                                fontSize: 9,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    '翻页动画',
                    style: TextStyle(
                      color: AppColors.text,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 9),
                  Row(
                    children: ReaderPageMode.values.map((mode) {
                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: _SelectionBox(
                            selected: _settings.pageMode == mode,
                            onTap: () =>
                                update(_settings.copyWith(pageMode: mode)),
                            child: Text(
                              mode.label,
                              style: TextStyle(
                                color: _settings.pageMode == mode
                                    ? AppColors.coral
                                    : AppColors.secondaryText,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
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
                    style: TextStyle(
                      color: AppColors.text,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 9),
                  Row(
                    children: ReaderScript.values.map((script) {
                      final label = script == ReaderScript.simplified
                          ? '简体'
                          : '繁体';
                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: _SelectionBox(
                            selected: _settings.script == script,
                            onTap: () =>
                                update(_settings.copyWith(script: script)),
                            child: Text(
                              label,
                              style: TextStyle(
                                color: _settings.script == script
                                    ? AppColors.coral
                                    : AppColors.secondaryText,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),
                  Center(
                    child: TextButton(
                      onPressed: () {
                        Navigator.pop(sheetContext);
                        _showAdvancedSettings();
                      },
                      child: const Text(
                        '更多设置 >',
                        style: TextStyle(
                          color: AppColors.secondaryText,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _showAdvancedSettings() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: AppColors.surface,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) {
          Future<void> update(ReaderSettings value) async {
            setState(() => _settings = value);
            setSheetState(() {});
            await _settingsStore.save(value);
            _syncAutoPage();
          }

          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SwitchListTile(
                    title: const Text('首行缩进'),
                    value: _settings.firstLineIndent,
                    onChanged: (value) =>
                        update(_settings.copyWith(firstLineIndent: value)),
                  ),
                  SwitchListTile(
                    title: const Text('自动翻页'),
                    value: _settings.autoPage,
                    onChanged: (value) =>
                        update(_settings.copyWith(autoPage: value)),
                  ),
                  SwitchListTile(
                    title: const Text('横屏阅读'),
                    subtitle: const Text('保存偏好，下次进入阅读器继续使用'),
                    value: _settings.landscape,
                    onChanged: (value) =>
                        update(_settings.copyWith(landscape: value)),
                  ),
                  ListTile(
                    title: const Text('左右页边距'),
                    subtitle: Slider(
                      min: 14,
                      max: 36,
                      divisions: 11,
                      value: _settings.horizontalPadding,
                      onChanged: (value) =>
                          update(_settings.copyWith(horizontalPadding: value)),
                    ),
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
      if (!mounted || _chapterIndex >= widget.item.episodeCount - 1) return;
      _changeChapter(_chapterIndex + 1);
    });
  }

  Future<void> _showMore() async {
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
                  if (!sheetContext.mounted) return;
                  Navigator.pop(sheetContext);
                  if (!mounted) return;
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(const SnackBar(content: Text('当前章节已复制')));
                },
              ),
              ListTile(
                leading: const Icon(Icons.download_outlined),
                title: const Text('缓存当前章节'),
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
      ),
    );
  }

  Future<void> _downloadCurrent() async {
    final chapter = await _chapterFuture(_chapterIndex);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'offline.chapter.${widget.item.id}.$_chapterIndex',
      jsonEncode({
        'title': chapter.title,
        'paragraphs': chapter.paragraphs,
        'source': _selectedSource,
      }),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('当前章节已缓存')));
  }

  @override
  Widget build(BuildContext context) {
    if (!_settingsLoaded) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final background = _settings.palette.background;
    final foreground = _settings.palette.foreground;
    final progress = (_chapterIndex + 1) / widget.item.episodeCount;

    return Scaffold(
      backgroundColor: background,
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: _settings.palette == ReaderPalette.night
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark,
        child: Stack(
          children: [
            SafeArea(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTapUp: (details) {
                  final width = MediaQuery.sizeOf(context).width;
                  if (details.localPosition.dx < width * .28) {
                    _changeChapter(_chapterIndex - 1);
                  } else if (details.localPosition.dx > width * .72) {
                    _changeChapter(_chapterIndex + 1);
                  } else {
                    _toggleControls();
                  }
                },
                child: PageView.builder(
                  controller: _pageController,
                  scrollDirection: Axis.horizontal,
                  physics: _settings.pageMode == ReaderPageMode.none
                      ? const NeverScrollableScrollPhysics()
                      : const PageScrollPhysics(),
                  itemCount: widget.item.episodeCount,
                  onPageChanged: _onPageChanged,
                  itemBuilder: (context, index) => FutureBuilder<Chapter>(
                    future: _chapterFuture(index),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState != ConnectionState.done) {
                        return Center(
                          child: CircularProgressIndicator(
                            color: foreground.withValues(alpha: .65),
                            strokeWidth: 2,
                          ),
                        );
                      }
                      if (snapshot.hasError || snapshot.data == null) {
                        return _ReaderError(
                          color: foreground,
                          onRetry: () => setState(() {
                            _chapterFutures.remove(index);
                          }),
                        );
                      }
                      return _ChapterView(
                        chapter: snapshot.data!,
                        item: widget.item,
                        settings: _settings,
                      );
                    },
                  ),
                ),
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
                    chapter: '第 ${_chapterIndex + 1} 章',
                    onBack: () => Navigator.pop(context),
                    onSource: _showSources,
                    onMore: _showMore,
                  ),
                ),
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
                    progress: progress,
                    chapterIndex: _chapterIndex,
                    total: widget.item.episodeCount,
                    night: _settings.palette == ReaderPalette.night,
                    onProgressChanged: (value) => _changeChapter(
                      (value * (widget.item.episodeCount - 1)).round(),
                    ),
                    onPrevious: _chapterIndex == 0
                        ? null
                        : () => _changeChapter(_chapterIndex - 1),
                    onNext: _chapterIndex >= widget.item.episodeCount - 1
                        ? null
                        : () => _changeChapter(_chapterIndex + 1),
                    onCatalog: _openCatalog,
                    onNight: () {
                      final palette = _settings.palette == ReaderPalette.night
                          ? ReaderPalette.white
                          : ReaderPalette.night;
                      setState(
                        () => _settings = _settings.copyWith(palette: palette),
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
        ),
      ),
    );
  }
}

class _ChapterView extends StatelessWidget {
  const _ChapterView({
    required this.chapter,
    required this.item,
    required this.settings,
  });

  final Chapter chapter;
  final ContentItem item;
  final ReaderSettings settings;

  @override
  Widget build(BuildContext context) {
    final foreground = settings.palette.foreground;
    return ListView(
      padding: EdgeInsets.fromLTRB(
        settings.horizontalPadding,
        62,
        settings.horizontalPadding,
        118,
      ),
      children: [
        Text(
          chapter.title,
          style: TextStyle(
            color: foreground,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 20),
        ...chapter.paragraphs.map(
          (paragraph) => Padding(
            padding: EdgeInsets.only(bottom: settings.paragraphSpacing),
            child: Text(
              _convertScript(
                settings.firstLineIndent ? '　　$paragraph' : paragraph,
                settings.script,
              ),
              style: TextStyle(
                color: foreground,
                fontSize: settings.fontSize,
                height: settings.lineHeight,
                letterSpacing: settings.letterSpacing,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          '${chapter.index + 1}',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: foreground.withValues(alpha: .45),
            fontSize: 10,
          ),
        ),
      ],
    );
  }
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
            TextButton(
              onPressed: onSource,
              child: const Text(
                '换源',
                style: TextStyle(color: AppColors.secondaryText, fontSize: 10),
              ),
            ),
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
            padding: const EdgeInsets.fromLTRB(14, 7, 14, 0),
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
                  '${chapterIndex + 1}',
                  style: const TextStyle(
                    color: AppColors.tertiaryText,
                    fontSize: 9,
                  ),
                ),
                const Spacer(),
                Text(
                  '${(progress * 100).toStringAsFixed(1)}%',
                  style: const TextStyle(
                    color: AppColors.tertiaryText,
                    fontSize: 9,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 3),
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
  const _ReaderError({required this.color, required this.onRetry});

  final Color color;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.error_outline_rounded, color: color),
        const SizedBox(height: 8),
        Text('章节加载失败', style: TextStyle(color: color, fontSize: 12)),
        TextButton(onPressed: onRetry, child: const Text('重试')),
      ],
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
          style: const TextStyle(
            color: AppColors.text,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
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
            style: const TextStyle(
              color: AppColors.text,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
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
    '钟': '鐘',
    '声': '聲',
    '轻': '輕',
    '经': '經',
    '实': '實',
    '秘': '祕',
  };
  var converted = value;
  for (final entry in replacements.entries) {
    converted = converted.replaceAll(entry.key, entry.value);
  }
  return converted;
}
