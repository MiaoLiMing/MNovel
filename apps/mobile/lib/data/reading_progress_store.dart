import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class ReadingProgress {
  const ReadingProgress({required this.chapterIndex, required this.ratio});

  final int chapterIndex;
  final double ratio;
}

class ReadingProgressStore {
  static const _key = 'reading.progress.v1';

  Future<ReadingProgress> load(String contentId) async {
    final values = await _read();
    final value = values[contentId];
    if (value is! Map<String, dynamic>) {
      return const ReadingProgress(chapterIndex: 0, ratio: 0);
    }
    return ReadingProgress(
      chapterIndex: value['chapter_index'] as int? ?? 0,
      ratio: (value['ratio'] as num?)?.toDouble() ?? 0,
    );
  }

  Future<void> save(
    String contentId, {
    required int chapterIndex,
    required double ratio,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final values = await _read();
    values[contentId] = {
      'chapter_index': chapterIndex,
      'ratio': ratio.clamp(0, 1),
      'updated_at': DateTime.now().toIso8601String(),
    };
    await prefs.setString(_key, jsonEncode(values));
  }

  Future<Map<String, dynamic>> getAllProgress() async {
    return _read();
  }

  Future<Map<String, dynamic>> _read() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return {};
    try {
      return Map<String, dynamic>.from(jsonDecode(raw) as Map);
    } catch (_) {
      return {};
    }
  }
}
