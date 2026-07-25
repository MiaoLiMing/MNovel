import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/content.dart';
import 'offline_models.dart';
import 'shelf_store.dart';

class OfflineLibraryStore {
  static const _indexKey = 'offline.library.v2';
  static const _migrationKey = 'offline.library.v2.migrated';
  static final changes = StreamController<String>.broadcast();

  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_migrationKey) == true) return;
    final shelf = await ShelfStore().listAll();
    final itemsById = {for (final item in shelf) item.id: item};
    final keys = prefs
        .getKeys()
        .where((key) => key.startsWith('offline.chapter.'))
        .toList();
    for (final key in keys) {
      final match = RegExp(r'^offline\.chapter\.(.+)\.(\d+)$').firstMatch(key);
      if (match == null) continue;
      final id = match.group(1)!;
      final index = int.parse(match.group(2)!);
      final raw = prefs.getString(key);
      if (raw == null) continue;
      try {
        final value = Map<String, dynamic>.from(jsonDecode(raw) as Map);
        final item =
            itemsById[id] ??
            ContentItem(
              id: id,
              title: '已缓存小说',
              creator: '未知作者',
              category: '离线内容',
              summary: '',
              coverAsset: '',
              popularity: '',
              progress: 0,
              episodeCount: index + 1,
            );
        await saveChapter(
          item: item,
          sourceId: value['source'] as String? ?? item.sourceId,
          chapter: Chapter(
            index: index,
            title: value['title'] as String? ?? '第 ${index + 1} 章',
            paragraphs: (value['paragraphs'] as List<dynamic>? ?? const [])
                .map((entry) => entry.toString())
                .toList(),
          ),
          notify: false,
        );
      } catch (_) {
        continue;
      }
    }
    await prefs.setBool(_migrationKey, true);
  }

  Future<Directory> _root() async {
    final base = await getApplicationDocumentsDirectory();
    final directory = Directory(
      '${base.path}${Platform.pathSeparator}offline-v2',
    );
    if (!directory.existsSync()) {
      await directory.create(recursive: true);
    }
    return directory;
  }

  String _safeId(String value) =>
      base64Url.encode(utf8.encode(value)).replaceAll('=', '');

  Future<File> _chapterFile(String contentId, int chapterIndex) async {
    final root = await _root();
    final directory = Directory(
      '${root.path}${Platform.pathSeparator}${_safeId(contentId)}',
    );
    if (!directory.existsSync()) {
      await directory.create(recursive: true);
    }
    return File(
      '${directory.path}${Platform.pathSeparator}chapter-$chapterIndex.json',
    );
  }

  Future<void> saveChapter({
    required ContentItem item,
    required String sourceId,
    required Chapter chapter,
    bool notify = true,
  }) async {
    final file = await _chapterFile(item.id, chapter.index);
    final payload = jsonEncode({
      'index': chapter.index,
      'title': chapter.title,
      'paragraphs': chapter.paragraphs,
      'source_id': sourceId,
    });
    await file.writeAsString(payload, flush: true);
    final records = await _readIndex();
    final previous = records[item.id];
    final chapters = {...?previous?.chapterIndexes, chapter.index};
    final failed = {...?previous?.failedChapterIndexes}..remove(chapter.index);
    records[item.id] = OfflineBookRecord(
      item: item,
      sourceId: sourceId,
      chapterIndexes: chapters,
      failedChapterIndexes: failed,
      updatedAt: DateTime.now(),
      bytes: await _directoryBytes(file.parent),
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
      bytes: previous?.bytes ?? 0,
    );
    await _writeIndex(records);
    changes.add(item.id);
  }

  Future<Chapter?> loadChapter(
    String contentId,
    int chapterIndex, {
    String? sourceId,
  }) async {
    final file = await _chapterFile(contentId, chapterIndex);
    if (!file.existsSync()) return null;
    try {
      final value = Map<String, dynamic>.from(
        jsonDecode(await file.readAsString()) as Map,
      );
      final storedSource = value['source_id'] as String?;
      if (sourceId != null &&
          storedSource != null &&
          storedSource != sourceId &&
          sourceId != 'unknown') {
        return null;
      }
      return Chapter.fromJson(value);
    } catch (_) {
      return null;
    }
  }

  Future<List<OfflineBookRecord>> listBooks() async {
    await initialize();
    final records = (await _readIndex()).values.toList()
      ..sort((left, right) => right.updatedAt.compareTo(left.updatedAt));
    return records;
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
    final root = await _root();
    final directory = Directory(
      '${root.path}${Platform.pathSeparator}${_safeId(contentId)}',
    );
    if (directory.existsSync()) await directory.delete(recursive: true);
    final records = await _readIndex()
      ..remove(contentId);
    await _writeIndex(records);
    changes.add(contentId);
  }

  Future<void> clearAll() async {
    final root = await _root();
    if (root.existsSync()) {
      for (final entity in root.listSync()) {
        await entity.delete(recursive: true);
      }
    }
    await _writeIndex({});
    changes.add('*');
  }

  Future<Map<String, OfflineBookRecord>> _readIndex() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_indexKey);
    if (raw == null || raw.isEmpty) return {};
    try {
      final value = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      return value.map(
        (key, record) => MapEntry(
          key,
          OfflineBookRecord.fromJson(Map<String, dynamic>.from(record as Map)),
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

  Future<int> _directoryBytes(Directory directory) async {
    var total = 0;
    await for (final entity in directory.list()) {
      if (entity is File) total += await entity.length();
    }
    return total;
  }
}
