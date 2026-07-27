import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/content_cover.dart';
import '../../data/content_repository.dart';
import '../../domain/content.dart';
import '../reader/chapter_catalog_page.dart';
import 'audiobook_controller.dart';

class AudiobookPage extends StatefulWidget {
  const AudiobookPage({
    super.key,
    required this.item,
    required this.initialChapterIndex,
    required this.repository,
  });

  final ContentItem item;
  final int initialChapterIndex;
  final ContentRepository repository;

  @override
  State<AudiobookPage> createState() => _AudiobookPageState();
}

class _AudiobookPageState extends State<AudiobookPage> {
  final _controller = AudiobookController.instance;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_refresh);
    _controller.open(
      item: widget.item,
      initialChapterIndex: widget.initialChapterIndex,
      repository: widget.repository,
    );
  }

  @override
  void dispose() {
    _controller.cancelPendingInitialization();
    _controller.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  Future<void> _openCatalog() async {
    final selected = await Navigator.of(context).push<int>(
      MaterialPageRoute<int>(
        builder: (_) => ChapterCatalogPage(
          item: _controller.item ?? widget.item,
          selectedSource: widget.item.sourceName,
          repository: widget.repository,
        ),
      ),
    );
    if (selected == null) return;
    await _controller.stop();
    await _controller.open(
      item: _controller.item ?? widget.item,
      initialChapterIndex: selected,
      repository: widget.repository,
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final chapter = controller.chapter;
    return Scaffold(
      backgroundColor: const Color(0xFFF7F2EA),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('听书'),
        actions: [
          IconButton(
            tooltip: '定时关闭',
            onPressed: _showSleepTimer,
            icon: const Icon(Icons.bedtime_outlined),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
          child: Column(
            children: [
              const Spacer(),
              Hero(
                tag: 'audio-cover-${widget.item.id}',
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x24000000),
                        blurRadius: 24,
                        offset: Offset(0, 12),
                      ),
                    ],
                  ),
                  child: ContentCover(
                    asset: widget.item.coverAsset,
                    width: 176,
                    height: 236,
                    radius: 14,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                widget.item.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.text,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '${widget.item.creator} · ${chapter?.title ?? '正在加载章节'}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.secondaryText,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 22),
              Container(
                width: double.infinity,
                constraints: const BoxConstraints(minHeight: 72),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .74),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.divider),
                ),
                child: Text(
                  controller.errorMessage ??
                      (controller.currentParagraph.isEmpty
                          ? '准备系统语音…'
                          : controller.currentParagraph),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: controller.errorMessage == null
                        ? AppColors.secondaryText
                        : AppColors.danger,
                    fontSize: 12,
                    height: 1.6,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Slider(
                value: controller.chapterProgress,
                onChanged: chapter == null ? null : controller.seekParagraph,
              ),
              Row(
                children: [
                  Text(
                    chapter == null ? '--' : '${controller.paragraphIndex + 1}',
                    style: const TextStyle(
                      color: AppColors.tertiaryText,
                      fontSize: 10,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    chapter == null ? '--' : '${chapter.paragraphs.length} 段',
                    style: const TextStyle(
                      color: AppColors.tertiaryText,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  IconButton(
                    tooltip: '上一章',
                    onPressed: controller.canGoPrevious
                        ? controller.previousChapter
                        : null,
                    icon: const Icon(Icons.skip_previous_rounded, size: 30),
                  ),
                  IconButton(
                    tooltip: '后退一段',
                    onPressed: () => controller.skipParagraph(-1),
                    icon: const Icon(Icons.replay_10_rounded, size: 29),
                  ),
                  FilledButton(
                    onPressed:
                        controller.state == AudiobookPlaybackState.loading
                        ? null
                        : controller.isPlaying
                        ? controller.pause
                        : controller.play,
                    style: FilledButton.styleFrom(
                      shape: const CircleBorder(),
                      padding: const EdgeInsets.all(19),
                    ),
                    child: controller.state == AudiobookPlaybackState.loading
                        ? const SizedBox(
                            width: 26,
                            height: 26,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Icon(
                            controller.isPlaying
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded,
                            size: 34,
                          ),
                  ),
                  IconButton(
                    tooltip: '前进一段',
                    onPressed: () => controller.skipParagraph(1),
                    icon: const Icon(Icons.forward_10_rounded, size: 29),
                  ),
                  IconButton(
                    tooltip: '下一章',
                    onPressed: controller.canGoNext
                        ? controller.nextChapter
                        : null,
                    icon: const Icon(Icons.skip_next_rounded, size: 30),
                  ),
                ],
              ),
              const Spacer(),
              Row(
                children: [
                  _Action(
                    icon: Icons.format_list_bulleted_rounded,
                    label: '目录',
                    onTap: _openCatalog,
                  ),
                  _Action(
                    icon: Icons.speed_rounded,
                    label: '${controller.rate.toStringAsFixed(1)}x',
                    onTap: _showSpeed,
                  ),
                  _Action(
                    icon: Icons.record_voice_over_outlined,
                    label: '声音',
                    onTap: _showVoices,
                  ),
                  _Action(
                    icon: Icons.timer_outlined,
                    label:
                        controller.sleepEndsAt == null &&
                            !controller.stopAtChapterEnd
                        ? '定时'
                        : '已设置',
                    onTap: _showSleepTimer,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showSpeed() async {
    var value = _controller.rate;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '语速 ${value.toStringAsFixed(1)}x',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              Slider(
                min: .3,
                max: .8,
                divisions: 10,
                value: value,
                onChanged: (next) {
                  setSheetState(() => value = next);
                  _controller.updateVoice(rate: next);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showVoices() async {
    final voices = _controller.voices;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: SizedBox(
          height: 360,
          child: voices.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      '设备未返回可选中文语音。\n请在系统设置中安装中文语音包后重试。',
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : RadioGroup<String>(
                  groupValue: _controller.voiceName,
                  onChanged: (name) {
                    if (name == null) return;
                    final voice = voices.firstWhere(
                      (value) => (value['name']?.toString() ?? '系统声音') == name,
                    );
                    _controller.updateVoice(
                      voiceName: name,
                      locale: voice['locale']?.toString() ?? 'zh-CN',
                    );
                    Navigator.pop(sheetContext);
                  },
                  child: ListView.builder(
                    itemCount: voices.length,
                    itemBuilder: (context, index) {
                      final voice = voices[index];
                      final name = voice['name']?.toString() ?? '系统声音';
                      final locale = voice['locale']?.toString() ?? 'zh-CN';
                      return RadioListTile<String>(
                        value: name,
                        title: Text(name),
                        subtitle: Text(locale),
                      );
                    },
                  ),
                ),
        ),
      ),
    );
  }

  Future<void> _showSleepTimer() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(
              title: Text(
                '定时关闭',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            for (final minutes in [15, 30, 60])
              ListTile(
                leading: const Icon(Icons.timer_outlined),
                title: Text('$minutes 分钟后'),
                onTap: () {
                  _controller.setSleepTimer(Duration(minutes: minutes));
                  Navigator.pop(sheetContext);
                },
              ),
            ListTile(
              leading: const Icon(Icons.stop_circle_outlined),
              title: const Text('本章结束后'),
              onTap: () {
                _controller.setSleepTimer(null, chapterEnd: true);
                Navigator.pop(sheetContext);
              },
            ),
            ListTile(
              leading: const Icon(Icons.timer_off_outlined),
              title: const Text('关闭定时'),
              onTap: () {
                _controller.setSleepTimer(null);
                Navigator.pop(sheetContext);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _Action extends StatelessWidget {
  const _Action({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Expanded(
    child: InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Column(
          children: [
            Icon(icon, size: 21),
            const SizedBox(height: 5),
            Text(label, style: const TextStyle(fontSize: 10)),
          ],
        ),
      ),
    ),
  );
}
