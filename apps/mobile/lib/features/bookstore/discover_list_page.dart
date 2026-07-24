import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/novel_widgets.dart';
import '../../data/content_repository.dart';
import '../../domain/content.dart';
import '../detail/content_detail_page.dart';

class DiscoverListPage extends StatefulWidget {
  const DiscoverListPage({
    super.key,
    required this.channel,
    required this.title,
    required this.listType,
    this.repository,
    this.initialItems = const [],
  });

  final ContentChannel channel;
  final String title;
  final String listType;
  final ContentRepository? repository;
  final List<ContentItem> initialItems;

  @override
  State<DiscoverListPage> createState() => _DiscoverListPageState();
}

class _DiscoverListPageState extends State<DiscoverListPage> {
  late final ContentRepository _repository;
  late List<ContentItem> _items = widget.initialItems;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? ContentRepository();
    if (_items.isEmpty) unawaited(_load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await _repository.discover(widget.channel);
      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '列表加载失败';
      });
    }
  }

  void _open(ContentItem item) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ContentDetailPage(item: item, repository: _repository),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.title)),
    body: RefreshIndicator(
      color: AppColors.coral,
      onRefresh: _load,
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? ListView(
              children: [
                const SizedBox(height: 160),
                const Icon(
                  Icons.cloud_off_rounded,
                  color: AppColors.tertiaryText,
                ),
                const SizedBox(height: 8),
                Center(
                  child: Text(
                    _error!,
                    style: const TextStyle(
                      color: AppColors.secondaryText,
                      fontSize: 12,
                    ),
                  ),
                ),
                Center(
                  child: TextButton(onPressed: _load, child: const Text('重试')),
                ),
              ],
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
              itemCount: _items.length,
              itemBuilder: (context, index) {
                final item = _items[index];
                return NovelListRow(
                  item: item,
                  onTap: () => _open(item),
                  trailing: widget.listType == 'ranking'
                      ? Text(
                          '${index + 1}',
                          style: TextStyle(
                            color: index < 3
                                ? AppColors.coral
                                : AppColors.tertiaryText,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        )
                      : const Icon(
                          Icons.chevron_right_rounded,
                          color: AppColors.tertiaryText,
                        ),
                );
              },
              separatorBuilder: (_, _) =>
                  const Divider(height: 1, color: AppColors.divider),
            ),
    ),
  );
}
