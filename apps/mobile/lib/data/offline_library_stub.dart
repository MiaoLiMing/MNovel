import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/content.dart';
import 'offline_models.dart';

class OfflineLibraryStore {
  static const _indexKey = 'offline.library.v2';
  static final changes = StreamController<String>.broadcast();

  Future<void> initialize() async {}

  Future<void> saveChapter({
    required ContentItem item,
    required String sourceId,
    required Chapter chapter,
    bool notify = true,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'offline.v2.chapter.${item.id}.${chapter.index}',
      jsonEncode({
        'index': chapter.index,
        'title': chapter.title,
        'paragraphs': chapter.paragraphs,
        'source_id': sourceId,
      }),
    );
    final records = await _readIndex();
    final previous = records[item.id];
    records[item.id] = OfflineBookRecord(
      item: item,
      sourceId: sourceId,
      chapterIndexes: {...?previous?.chapterIndexes, chapter.index},
      updatedAt: DateTime.now(),
      bytes: 0,
    );
    await _writeIndex(records);
    if (notify) changes.add(item.id);
  }

  Future<void> markFailed({
    required ContentItem item,
    required String sourceId,
    required int chapterIndex,
  }) async {
    final records = await _readIndex();
    final previous = records[item.id];
    records[item.id] = OfflineBookRecord(
      item: item,
      sourceId: sourceId,
      chapterIndexes: {...?previous?.chapterIndexes},
      failedChapterIndexes: {...?previous?.failedChapterIndexes, chapterIndex},
      updatedAt: DateTime.now(),
      bytes: 0,
    );
    await _writeIndex(records);
    changes.add(item.id);
  }

  Future<Chapter?> loadChapter(
    String contentId,
    int chapterIndex, {
    String? sourceId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('offline.v2.chapter.$contentId.$chapterIndex');
    if (raw == null) return null;
    try {
      final value = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      return Chapter.fromJson(value);
    } catch (_) {
      return null;
    }
  }

  Future<List<OfflineBookRecord>> listBooks() async {
    final values = (await _readIndex()).values.toList()
      ..sort((left, right) => right.updatedAt.compareTo(left.updatedAt));
    return values;
  }

  Future<OfflineBookStatus> status(String contentId) async {
    final record = (await _readIndex())[contentId];
    if (record == null) return OfflineBookStatus.empty;
    return OfflineBookStatus(
      downloadedCount: record.downloadedCount,
      totalCount: record.item.episodeCount,
      failedCount: record.failedChapterIndexes.length,
    );
  }

  Future<void> deleteBook(String contentId) async {
    final prefs = await SharedPreferences.getInstance();
    for (final key
        in prefs
            .getKeys()
            .where((key) => key.startsWith('offline.v2.chapter.$contentId.'))
            .toList()) {
      await prefs.remove(key);
    }
    final records = await _readIndex()
      ..remove(contentId);
    await _writeIndex(records);
    changes.add(contentId);
  }

  Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    for (final key
        in prefs
            .getKeys()
            .where((key) => key.startsWith('offline.v2.chapter.'))
            .toList()) {
      await prefs.remove(key);
    }
    await _writeIndex({});
    changes.add('*');
  }

  Future<Map<String, OfflineBookRecord>> _readIndex() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_indexKey);
    if (raw == null || raw.isEmpty) return {};
    try {
      return Map<String, dynamic>.from(jsonDecode(raw) as Map).map(
        (key, value) => MapEntry(
          key,
          OfflineBookRecord.fromJson(Map<String, dynamic>.from(value as Map)),
        ),
      );
    } catch (_) {
      return {};
    }
  }

  Future<void> _writeIndex(Map<String, OfflineBookRecord> records) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _indexKey,
      jsonEncode(records.map((key, value) => MapEntry(key, value.toJson()))),
    );
  }
}
