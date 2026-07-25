import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../domain/content.dart';
import 'content_repository.dart';
import 'offline_library.dart';

enum DownloadJobState { queued, running, completed, failed, cancelled }

class DownloadJob {
  DownloadJob({
    required this.item,
    required this.sourceId,
    required this.chapterIndexes,
  });

  final ContentItem item;
  final String sourceId;
  final List<int> chapterIndexes;
  DownloadJobState state = DownloadJobState.queued;
  int completed = 0;
  int failed = 0;
  bool cancelRequested = false;

  double get progress =>
      chapterIndexes.isEmpty ? 0 : completed / chapterIndexes.length;
}

class OfflineDownloadService extends ChangeNotifier {
  OfflineDownloadService._();

  static final instance = OfflineDownloadService._();

  final Map<String, DownloadJob> _jobs = {};
  Map<String, DownloadJob> get jobs => Map.unmodifiable(_jobs);

  DownloadJob? jobFor(String contentId) => _jobs[contentId];

  Future<DownloadJob> download({
    required ContentItem item,
    required ContentRepository repository,
    required String sourceId,
    required Iterable<int> chapterIndexes,
  }) async {
    final indexes =
        chapterIndexes
            .where((index) => index >= 0 && index < item.episodeCount)
            .toSet()
            .toList()
          ..sort();
    final job = DownloadJob(
      item: item,
      sourceId: sourceId,
      chapterIndexes: indexes,
    );
    _jobs[item.id]?.cancelRequested = true;
    _jobs[item.id] = job;
    notifyListeners();
    unawaited(_run(job, repository));
    return job;
  }

  void cancel(String contentId) {
    final job = _jobs[contentId];
    if (job == null) return;
    job.cancelRequested = true;
    job.state = DownloadJobState.cancelled;
    notifyListeners();
  }

  Future<void> retryFailed({
    required OfflineLibraryStore store,
    required ContentRepository repository,
    required ContentItem item,
    required String sourceId,
  }) async {
    final records = await store.listBooks();
    final record = records
        .where((value) => value.item.id == item.id)
        .firstOrNull;
    if (record == null || record.failedChapterIndexes.isEmpty) return;
    await download(
      item: item,
      repository: repository,
      sourceId: sourceId,
      chapterIndexes: record.failedChapterIndexes,
    );
  }

  Future<void> _run(DownloadJob job, ContentRepository repository) async {
    job.state = DownloadJobState.running;
    notifyListeners();
    final store = OfflineLibraryStore();
    await store.initialize();
    const concurrency = 3;
    for (
      var offset = 0;
      offset < job.chapterIndexes.length;
      offset += concurrency
    ) {
      if (job.cancelRequested) break;
      final end = math.min(offset + concurrency, job.chapterIndexes.length);
      final batch = job.chapterIndexes.sublist(offset, end);
      await Future.wait(
        batch.map((index) async {
          if (job.cancelRequested) return;
          try {
            final chapter = await repository.chapter(
              job.item.copyWith(
                sourceId: job.sourceId,
                sourceName: job.sourceId,
              ),
              index,
              preferOffline: false,
            );
            await store.saveChapter(
              item: job.item,
              sourceId: job.sourceId,
              chapter: chapter,
            );
            job.completed++;
          } catch (_) {
            job.failed++;
            await store.markFailed(
              item: job.item,
              sourceId: job.sourceId,
              chapterIndex: index,
            );
          }
          notifyListeners();
        }),
      );
    }
    if (job.cancelRequested) {
      job.state = DownloadJobState.cancelled;
    } else if (job.failed > 0) {
      job.state = DownloadJobState.failed;
    } else {
      job.state = DownloadJobState.completed;
    }
    notifyListeners();
  }
}
