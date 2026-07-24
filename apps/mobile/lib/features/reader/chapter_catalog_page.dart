import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/theme/app_theme.dart';
import '../../data/content_repository.dart';
import '../../data/reading_progress_store.dart';
import '../../domain/content.dart';

class ChapterCatalogPage extends StatefulWidget {
  const ChapterCatalogPage({
    super.key,
    required this.item,
    required this.selectedSource,
    this.repository,
  });

  final ContentItem item;
  final String selectedSource;
  final ContentRepository? repository;

  @override
  State<ChapterCatalogPage> createState() => _ChapterCatalogPageState();
}

class _ChapterCatalogPageState extends State<ChapterCatalogPage> {
  late final ContentRepository _repository;
  final _scrollController = ScrollController();
  final _progressStore = ReadingProgressStore();
  List<ChapterEntry> _chapters = const [];
  late String _source = widget.selectedSource;
  bool _loading = true;
  bool _loadingMore = false;
  bool _descending = false;
  bool _subscribed = false;
  int _currentIndex = 0;
  String? _error;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? ContentRepository();
    _scrollController.addListener(_onScroll);
    unawaited(_initialize());
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  Future<void> _initialize() async {
    final progress = await _progressStore.load(widget.item.id);
    final prefs = await SharedPreferences.getInstance();
    _currentIndex = progress.chapterIndex;
    _subscribed = prefs.getBool('book.subscribe.${widget.item.id}') ?? false;
    await _loadInitial();
  }

  Future<void> _loadInitial() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final chapters = await _repository.chapters(widget.item, limit: 200);
      if (!mounted) return;
      setState(() {
        _chapters = chapters;
        _loading = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_scrollController.hasClients || _chapters.isEmpty) return;
        final target = (_currentIndex * 44.0)
            .clamp(0, _scrollController.position.maxScrollExtent)
            .toDouble();
        _scrollController.jumpTo(target);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '目录加载失败';
      });
    }
  }

  void _onScroll() {
    if (_loadingMore ||
        _chapters.length >= widget.item.episodeCount ||
        !_scrollController.hasClients) {
      return;
    }
    if (_scrollController.position.extentAfter < 360) {
      unawaited(_loadMore());
    }
  }

  Future<void> _loadMore() async {
    setState(() => _loadingMore = true);
    final more = await _repository.chapters(
      widget.item,
      offset: _chapters.length,
      limit: 200,
    );
    if (!mounted) return;
    setState(() {
      _chapters = [..._chapters, ...more];
      _loadingMore = false;
    });
  }

  List<ChapterEntry> get _visibleChapters =>
      _descending ? _chapters.reversed.toList(growable: false) : _chapters;

  Future<void> _downloadCurrent() async {
    final chapter = await _repository.chapter(widget.item, _currentIndex);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'offline.chapter.${widget.item.id}.$_currentIndex',
      jsonEncode({
        'title': chapter.title,
        'paragraphs': chapter.paragraphs,
        'source': _source,
      }),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('当前章节已缓存')));
  }

  Future<void> _toggleSubscribe() async {
    final prefs = await SharedPreferences.getInstance();
    _subscribed = !_subscribed;
    await prefs.setBool('book.subscribe.${widget.item.id}', _subscribed);
    if (!mounted) return;
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(_subscribed ? '已开启更新订阅' : '已取消更新订阅')),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      leading: IconButton(
        tooltip: '返回',
        onPressed: () => Navigator.pop(context),
        icon: const Icon(Icons.chevron_left_rounded, size: 25),
      ),
      title: const Text('目录'),
      actions: [
        TextButton(
          onPressed: () => setState(() => _descending = !_descending),
          child: Text(
            _descending ? '正序' : '倒序',
            style: const TextStyle(
              color: AppColors.secondaryText,
              fontSize: 11,
            ),
          ),
        ),
      ],
    ),
    body: Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
          child: DropdownButtonFormField<String>(
            initialValue: _source,
            icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18),
            decoration: const InputDecoration(
              labelText: '当前来源',
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            items:
                (widget.item.sourceLabels.isEmpty
                        ? [widget.item.sourceName]
                        : widget.item.sourceLabels)
                    .map(
                      (source) =>
                          DropdownMenuItem(value: source, child: Text(source)),
                    )
                    .toList(),
            onChanged: (value) {
              if (value == null) return;
              setState(() => _source = value);
              unawaited(_loadInitial());
            },
          ),
        ),
        Expanded(child: _buildBody()),
        DecoratedBox(
          decoration: const BoxDecoration(
            color: AppColors.surface,
            border: Border(
              top: BorderSide(color: AppColors.divider, width: .7),
            ),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _downloadCurrent,
                      child: const Text('下载本章'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _toggleSubscribe,
                      child: Text(_subscribed ? '取消订阅' : '批量订阅'),
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

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _error!,
              style: const TextStyle(
                color: AppColors.secondaryText,
                fontSize: 12,
              ),
            ),
            TextButton(onPressed: _loadInitial, child: const Text('重试')),
          ],
        ),
      );
    }
    final chapters = _visibleChapters;
    return ListView.builder(
      controller: _scrollController,
      itemExtent: 44,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: chapters.length + (_loadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= chapters.length) {
          return const Center(
            child: SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        }
        final chapter = chapters[index];
        final current = chapter.index == _currentIndex;
        return InkWell(
          onTap: () => Navigator.pop(context, chapter.index),
          child: Container(
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: current ? AppColors.coralSoft : Colors.transparent,
              borderRadius: BorderRadius.circular(7),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    chapter.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: current ? AppColors.coral : AppColors.text,
                      fontSize: 11,
                      fontWeight: current ? FontWeight.w700 : FontWeight.w400,
                    ),
                  ),
                ),
                if (current)
                  const Text(
                    '当前',
                    style: TextStyle(color: AppColors.coral, fontSize: 9),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
