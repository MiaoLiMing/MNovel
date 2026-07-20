import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/content.dart';
import 'reading_progress_store.dart';

class ShelfStore {
  static const _key = 'shelf.items.v1';
  final _progressStore = ReadingProgressStore();

  Future<List<ContentItem>> list(ContentChannel channel) async {
    final items = await _read();
    final channelItems = items.where((item) => item.channel == channel);
    return Future.wait(
      channelItems.map((item) async {
        final progress = await _progressStore.load(item.id);
        return item.copyWith(progress: progress.ratio);
      }),
    );
  }

  Future<bool> contains(String id) async {
    final items = await _read();
    return items.any((item) => item.id == id);
  }

  Future<void> add(ContentItem item) async {
    final items = await _read();
    items.removeWhere((value) => value.id == item.id);
    items.insert(0, item);
    await _write(items);
  }

  Future<void> remove(String id) async {
    final items = await _read()
      ..removeWhere((item) => item.id == id);
    await _write(items);
  }

  Future<List<ContentItem>> _read() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return [];
    try {
      final values = jsonDecode(raw) as List<dynamic>;
      return values
          .map((value) => ContentItem.fromJson(value as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _write(List<ContentItem> items) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      jsonEncode(items.map((item) => item.toJson()).toList()),
    );
  }
}
