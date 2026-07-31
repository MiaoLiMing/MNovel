import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../data/content_repository.dart';
import '../../data/source_store.dart';
import '../../domain/content_source.dart';

class SourceManagementPage extends StatefulWidget {
  const SourceManagementPage({super.key, this.repository, this.store});

  final ContentRepository? repository;
  final SourceStore? store;

  @override
  State<SourceManagementPage> createState() => _SourceManagementPageState();
}

class _SourceManagementPageState extends State<SourceManagementPage> {
  late final ContentRepository _repository;
  late final SourceStore _store;
  final _searchController = TextEditingController();
  List<ContentSource> _sources = const [];
  SourceAuditProgress? _audit;
  Timer? _pollTimer;
  bool _loading = true;
  bool _polling = false;
  String _query = '';
  String? _error;

  List<ContentSource> get _visibleSources {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return _sources;
    return _sources
        .where(
          (source) =>
              '${source.name} ${source.endpoint}'.toLowerCase().contains(query),
        )
        .toList(growable: false);
  }

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? ContentRepository();
    _store = widget.store ?? SourceStore();
    unawaited(_initialize());
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _initialize() async {
    await _reloadSources();
    if (!mounted) return;
    setState(() => _loading = false);
    unawaited(_refreshAudit());
  }

  Future<void> _reloadSources({bool refresh = false}) async {
    final sources = await _store.list(refresh: refresh);
    if (!mounted) return;
    setState(() => _sources = sources);
  }

  Future<void> _refreshAudit() async {
    if (_polling) return;
    _polling = true;
    try {
      final previousRunning = _audit?.isRunning ?? false;
      final progress = await _repository.sourceAuditStatus();
      if (!mounted) return;
      setState(() {
        _audit = progress;
        _error = progress.state == SourceAuditState.failed
            ? (progress.error.isEmpty ? '全部检测失败，请重试' : progress.error)
            : null;
      });
      if (progress.isRunning) {
        _startPolling();
      } else {
        _pollTimer?.cancel();
        _pollTimer = null;
        if (previousRunning || progress.state == SourceAuditState.completed) {
          await _reloadSources(refresh: true);
        }
      }
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = '无法获取检测状态，请检查网络后重试');
    } finally {
      _polling = false;
    }
  }

  Future<void> _startAudit() async {
    setState(() => _error = null);
    try {
      final progress = await _repository.startSourceAudit();
      if (!mounted) return;
      setState(() => _audit = progress);
      _startPolling();
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = '全部检测启动失败，请稍后重试');
    }
  }

  void _startPolling() {
    if (_pollTimer?.isActive ?? false) return;
    _pollTimer = Timer.periodic(
      const Duration(seconds: 2),
      (_) => unawaited(_refreshAudit()),
    );
  }

  Future<void> _showSource(ContentSource source) => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(source.name),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('该书源已通过搜索、目录和首章正文完整链路检测。'),
          const SizedBox(height: 12),
          SelectableText(
            source.endpoint,
            style: const TextStyle(
              color: AppColors.secondaryText,
              fontSize: 11,
            ),
          ),
          if (source.latencyMs > 0) ...[
            const SizedBox(height: 8),
            Text(
              '检测耗时 ${source.latencyMs}ms',
              style: const TextStyle(
                color: AppColors.tertiaryText,
                fontSize: 10,
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('关闭'),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final visibleSources = _visibleSources;
    final audit = _audit;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: '返回',
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.chevron_left_rounded, size: 26),
        ),
        title: const Text('我的书源'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              controller: _searchController,
              onChanged: (value) => setState(() => _query = value),
              decoration: const InputDecoration(
                hintText: '搜索书源名称或域名',
                prefixIcon: Icon(Icons.search_rounded, size: 20),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 2, 12, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    audit?.isRunning == true
                        ? '正在检测 ${audit!.completed}/${audit.total}'
                              '${audit.currentSource.isEmpty ? '' : ' · ${audit.currentSource}'}'
                        : '已验证 ${_sources.length} 个可用小说源',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.secondaryText,
                      fontSize: 10,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: audit?.isRunning == true ? null : _startAudit,
                  icon: const Icon(Icons.fact_check_outlined, size: 17),
                  label: const Text('全部检测'),
                ),
              ],
            ),
          ),
          if (audit?.isRunning == true)
            LinearProgressIndicator(value: audit!.ratio),
          if (_error != null)
            Material(
              color: AppColors.danger.withValues(alpha: .08),
              child: ListTile(
                dense: true,
                leading: const Icon(
                  Icons.error_outline_rounded,
                  color: AppColors.danger,
                  size: 18,
                ),
                title: Text(_error!, style: const TextStyle(fontSize: 10)),
                trailing: TextButton(
                  onPressed: _refreshAudit,
                  child: const Text('重试'),
                ),
              ),
            ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : visibleSources.isEmpty
                ? _EmptySources(
                    searching: _query.trim().isNotEmpty,
                    auditRunning: audit?.isRunning ?? false,
                    onAudit: _startAudit,
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(18, 2, 18, 24),
                    itemCount: visibleSources.length,
                    itemBuilder: (context, index) {
                      final source = visibleSources[index];
                      return _SourceRow(
                        source: source,
                        onTap: () => _showSource(source),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _SourceRow extends StatelessWidget {
  const _SourceRow({required this.source, required this.onTap});

  final ContentSource source;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Container(
      constraints: const BoxConstraints(minHeight: 68),
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.divider, width: .7)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  source.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.text,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  source.endpoint,
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
          const SizedBox(width: 12),
          const Icon(Icons.check_rounded, color: AppColors.text, size: 20),
        ],
      ),
    ),
  );
}

class _EmptySources extends StatelessWidget {
  const _EmptySources({
    required this.searching,
    required this.auditRunning,
    required this.onAudit,
  });

  final bool searching;
  final bool auditRunning;
  final VoidCallback onAudit;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.source_outlined,
            color: AppColors.tertiaryText,
            size: 36,
          ),
          const SizedBox(height: 10),
          Text(
            searching
                ? '没有匹配的可用书源'
                : auditRunning
                ? '检测完成后，可用书源会自动显示在这里'
                : '尚未检测出可用小说源',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.secondaryText,
              fontSize: 11,
            ),
          ),
          if (!searching && !auditRunning) ...[
            const SizedBox(height: 12),
            FilledButton.tonal(onPressed: onAudit, child: const Text('开始全部检测')),
          ],
        ],
      ),
    ),
  );
}
