import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/content_cover.dart';
import '../../core/widgets/empty_state.dart';
import '../../data/content_repository.dart';
import '../../data/offline_download_service.dart';
import '../../data/offline_library.dart';
import '../../data/offline_models.dart';
import '../reader/reader_page.dart';

class OfflineLibraryPage extends StatefulWidget {
  const OfflineLibraryPage({super.key});

  @override
  State<OfflineLibraryPage> createState() => _OfflineLibraryPageState();
}

class _OfflineLibraryPageState extends State<OfflineLibraryPage> {
  final _store = OfflineLibraryStore();
  final _downloads = OfflineDownloadService.instance;
  List<OfflineBookRecord> _records = const [];
  bool _loading = true;
  StreamSubscription<String>? _subscription;

  @override
  void initState() {
    super.initState();
    _downloads.addListener(_refresh);
    _subscription = OfflineLibraryStore.changes.stream.listen((_) => _load());
    unawaited(_load());
  }

  @override
  void dispose() {
    _downloads.removeListener(_refresh);
    _subscription?.cancel();
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  Future<void> _load() async {
    final records = await _store.listBooks();
    if (!mounted) return;
    setState(() {
      _records = records;
      _loading = false;
    });
  }

  void _read(OfflineBookRecord record) {
    final initial = record.chapterIndexes.isEmpty
        ? 0
        : record.chapterIndexes.reduce(
            (left, right) => left < right ? left : right,
          );
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ReaderPage(
          item: record.item.copyWith(
            sourceId: record.sourceId,
            sourceName: record.sourceId,
          ),
          initialChapterIndex: initial,
        ),
      ),
    );
  }

  Future<void> _delete(OfflineBookRecord record) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('删除离线小说'),
        content: Text(
          '将删除《${record.item.title}》的 ${record.downloadedCount} 个已下载章节，书架和阅读进度不受影响。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    _downloads.cancel(record.item.id);
    await _store.deleteBook(record.item.id);
    await _load();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('离线书库'),
      actions: [
        IconButton(
          tooltip: '刷新',
          onPressed: _load,
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
    ),
    body: _loading
        ? const Center(child: CircularProgressIndicator())
        : _records.isEmpty
        ? const EmptyState(
            icon: Icons.download_done_outlined,
            title: '还没有下载小说',
            description: '可在小说详情页选择下载范围，完成后会集中显示在这里。',
          )
        : RefreshIndicator(
            onRefresh: _load,
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
              itemCount: _records.length,
              separatorBuilder: (_, _) =>
                  const Divider(height: 1, color: AppColors.divider),
              itemBuilder: (context, index) {
                final record = _records[index];
                final job = _downloads.jobFor(record.item.id);
                final running =
                    job?.state == DownloadJobState.running ||
                    job?.state == DownloadJobState.queued;
                final progress = running ? job!.progress : record.progress;
                return InkWell(
                  onTap: () => _read(record),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Stack(
                          children: [
                            ContentCover(
                              asset: record.item.coverAsset,
                              width: 58,
                              height: 82,
                              radius: 6,
                            ),
                            Positioned(
                              right: 3,
                              bottom: 3,
                              child: Container(
                                padding: const EdgeInsets.all(3),
                                decoration: const BoxDecoration(
                                  color: AppColors.success,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.download_done_rounded,
                                  size: 11,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                record.item.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: AppColors.text,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                running
                                    ? '下载中 ${job!.completed} / ${job.chapterIndexes.length} 章'
                                    : record.state ==
                                          OfflineDownloadState.completed
                                    ? '已下载全本 · ${record.downloadedCount} 章'
                                    : '已下载 ${record.downloadedCount} / ${record.item.episodeCount} 章',
                                style: TextStyle(
                                  color: record.failedChapterIndexes.isEmpty
                                      ? AppColors.secondaryText
                                      : AppColors.danger,
                                  fontSize: 10,
                                ),
                              ),
                              const SizedBox(height: 8),
                              LinearProgressIndicator(
                                value: progress.clamp(0, 1),
                                minHeight: 4,
                                borderRadius: BorderRadius.circular(99),
                              ),
                              const SizedBox(height: 7),
                              Text(
                                '${_formatBytes(record.bytes)} · ${record.sourceId}',
                                style: const TextStyle(
                                  color: AppColors.tertiaryText,
                                  fontSize: 9,
                                ),
                              ),
                            ],
                          ),
                        ),
                        PopupMenuButton<String>(
                          onSelected: (value) {
                            if (value == 'delete') {
                              _delete(record);
                            } else if (value == 'cancel') {
                              _downloads.cancel(record.item.id);
                            } else if (value == 'retry') {
                              _downloads.retryFailed(
                                store: _store,
                                repository: ContentRepository(),
                                item: record.item,
                                sourceId: record.sourceId,
                              );
                            }
                          },
                          itemBuilder: (_) => [
                            if (running)
                              const PopupMenuItem(
                                value: 'cancel',
                                child: Text('取消下载'),
                              ),
                            if (record.failedChapterIndexes.isNotEmpty)
                              const PopupMenuItem(
                                value: 'retry',
                                child: Text('重试失败章节'),
                              ),
                            const PopupMenuItem(
                              value: 'delete',
                              child: Text('删除离线内容'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
  );

  String _formatBytes(int bytes) {
    if (bytes >= 1024 * 1024) {
      return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
    }
    return '${(bytes / 1024).toStringAsFixed(1)} KB';
  }
}
