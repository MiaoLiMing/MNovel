import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/novel_widgets.dart';
import '../../data/content_repository.dart';
import '../../domain/content.dart';
import '../detail/content_detail_page.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key, this.initialQuery = '', this.repository});

  final String initialQuery;
  final ContentRepository? repository;

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  static const _historyKey = 'search.history.v2';

  late final ContentRepository _repository;
  late final TextEditingController _controller;
  final _focusNode = FocusNode();
  SearchMeta? _meta;
  List<String> _recent = const [];
  List<ContentItem> _results = const [];
  bool _loading = false;
  String? _error;
  Timer? _debounce;

  bool get _hasQuery => _controller.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? ContentRepository();
    _controller = TextEditingController(text: widget.initialQuery);
    unawaited(_initialize());
  }

  Future<void> _initialize() async {
    final prefs = await SharedPreferences.getInstance();
    final rawHistory = prefs.getString(_historyKey);
    final recent = rawHistory == null
        ? const ['诡秘之主', '剑来', '道诡异仙', '宿命之环']
        : (jsonDecode(rawHistory) as List<dynamic>)
              .map((value) => value.toString())
              .toList(growable: false);
    final meta = await _repository.searchMeta();
    if (!mounted) return;
    setState(() {
      _recent = recent;
      _meta = meta;
    });
    if (_hasQuery) {
      await _search(widget.initialQuery, commitHistory: false);
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _focusNode.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    setState(() {});
    _debounce?.cancel();
    if (value.trim().isEmpty) {
      setState(() {
        _results = const [];
        _loading = false;
        _error = null;
      });
      return;
    }
    _debounce = Timer(
      const Duration(milliseconds: 360),
      () => _search(value, commitHistory: false),
    );
  }

  Future<void> _search(String value, {bool commitHistory = true}) async {
    final query = value.trim();
    if (query.isEmpty) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await _repository.discover(
        ContentChannel.novel,
        query: query,
      );
      if (!mounted || query != _controller.text.trim()) return;
      setState(() {
        _results = items;
        _loading = false;
      });
      if (commitHistory) await _remember(query);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '搜索暂时不可用，请稍后重试';
      });
    }
  }

  Future<void> _remember(String query) async {
    final recent = [
      query,
      ..._recent.where((value) => value != query),
    ].take(8).toList(growable: false);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_historyKey, jsonEncode(recent));
    if (!mounted) return;
    setState(() => _recent = recent);
  }

  Future<void> _clearHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_historyKey, '[]');
    if (!mounted) return;
    setState(() => _recent = const []);
  }

  void _useQuery(String query) {
    _controller.value = TextEditingValue(
      text: query,
      selection: TextSelection.collapsed(offset: query.length),
    );
    setState(() {});
    unawaited(_search(query));
  }

  void _open(ContentItem item) {
    FocusScope.of(context).unfocus();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ContentDetailPage(item: item, repository: _repository),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      automaticallyImplyLeading: false,
      titleSpacing: 12,
      title: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 38,
              child: TextField(
                controller: _controller,
                focusNode: _focusNode,
                onChanged: _onChanged,
                onSubmitted: (value) => _search(value),
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: '搜索书名 / 作者 / 关键词',
                  prefixIcon: const Icon(Icons.search_rounded, size: 18),
                  suffixIcon: _hasQuery
                      ? IconButton(
                          tooltip: '清空',
                          onPressed: () {
                            _controller.clear();
                            _onChanged('');
                            _focusNode.requestFocus();
                          },
                          icon: const Icon(Icons.close_rounded, size: 17),
                        )
                      : null,
                ),
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              '取消',
              style: TextStyle(color: AppColors.text, fontSize: 12),
            ),
          ),
        ],
      ),
    ),
    body: AnimatedSwitcher(
      duration: const Duration(milliseconds: 180),
      child: _hasQuery ? _buildResults() : _buildDiscovery(),
    ),
  );

  Widget _buildDiscovery() {
    final meta = _meta;
    return ListView(
      key: const ValueKey('search-discovery'),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 30),
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                '最近搜索',
                style: TextStyle(
                  color: AppColors.text,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            IconButton(
              tooltip: '清空搜索历史',
              onPressed: _recent.isEmpty ? null : _clearHistory,
              icon: const Icon(Icons.delete_outline_rounded, size: 17),
            ),
          ],
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _recent
              .map(
                (query) => ActionChip(
                  label: Text(query),
                  onPressed: () => _useQuery(query),
                  backgroundColor: AppColors.sand,
                  side: BorderSide.none,
                  labelStyle: const TextStyle(
                    color: AppColors.secondaryText,
                    fontSize: 10,
                  ),
                  visualDensity: VisualDensity.compact,
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 24),
        const Text(
          '热门搜索',
          style: TextStyle(
            color: AppColors.text,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        if (meta == null)
          const SizedBox(
            height: 180,
            child: Center(child: CircularProgressIndicator()),
          )
        else
          ...meta.hot
              .take(8)
              .toList()
              .asMap()
              .entries
              .map(
                (entry) => InkWell(
                  onTap: () => _useQuery(entry.value.title),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 28,
                          child: Text(
                            '${entry.key + 1}',
                            style: TextStyle(
                              color: entry.key < 3
                                  ? AppColors.coral
                                  : AppColors.tertiaryText,
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                entry.value.title,
                                style: const TextStyle(
                                  color: AppColors.text,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                entry.value.creator,
                                style: const TextStyle(
                                  color: AppColors.tertiaryText,
                                  fontSize: 9,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          entry.value.popularity.replaceAll('人在读', '+'),
                          style: const TextStyle(
                            color: AppColors.tertiaryText,
                            fontSize: 9,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
      ],
    );
  }

  Widget _buildResults() => ListView(
    key: const ValueKey('search-results'),
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 30),
    children: [
      if (_loading)
        const Padding(
          padding: EdgeInsets.only(top: 120),
          child: Center(child: CircularProgressIndicator()),
        )
      else if (_error != null)
        _MessageState(
          icon: Icons.wifi_off_rounded,
          message: _error!,
          action: '重试',
          onAction: () => _search(_controller.text),
        )
      else if (_results.isEmpty)
        const _MessageState(
          icon: Icons.search_off_rounded,
          message: '没有找到相关小说\n换个关键词试试',
        )
      else ...[
        Text(
          '找到 ${_results.length} 本相关小说',
          style: const TextStyle(color: AppColors.secondaryText, fontSize: 11),
        ),
        const SizedBox(height: 6),
        ..._results.map(
          (item) => NovelListRow(item: item, onTap: () => _open(item)),
        ),
      ],
    ],
  );
}

class _MessageState extends StatelessWidget {
  const _MessageState({
    required this.icon,
    required this.message,
    this.action,
    this.onAction,
  });

  final IconData icon;
  final String message;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 120),
    child: Column(
      children: [
        Icon(icon, color: AppColors.tertiaryText, size: 36),
        const SizedBox(height: 12),
        Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: AppColors.secondaryText,
            fontSize: 12,
            height: 1.6,
          ),
        ),
        if (action != null) ...[
          const SizedBox(height: 10),
          TextButton(onPressed: onAction, child: Text(action!)),
        ],
      ],
    ),
  );
}
