import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/content_source.dart';

class SourceStore {
  static const _customKey = 'content.sources.custom.v1';
  static const _enabledKey = 'content.sources.enabled.v1';

  Future<List<ContentSource>> list() async {
    final prefs = await SharedPreferences.getInstance();
    final enabledOverrides = _decodeEnabled(prefs.getString(_enabledKey));
    final builtIns = builtInContentSources
        .map(
          (source) => source.copyWith(
            enabled: enabledOverrides[source.id] ?? source.enabled,
          ),
        )
        .toList();
    final custom = _decodeCustom(prefs.getString(_customKey));
    return [...builtIns, ...custom];
  }

  Future<void> setEnabled(String id, bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    final values = _decodeEnabled(prefs.getString(_enabledKey));
    values[id] = enabled;
    await prefs.setString(_enabledKey, jsonEncode(values));

    final custom = _decodeCustom(prefs.getString(_customKey));
    final index = custom.indexWhere((source) => source.id == id);
    if (index >= 0) {
      custom[index] = custom[index].copyWith(enabled: enabled);
      await _writeCustom(prefs, custom);
    }
  }

  Future<void> addCustom(ContentSource source) async {
    if (source.builtIn || source.kind != SourceKind.json) {
      throw const FormatException('只能添加 JSON 自定义来源');
    }
    final endpoint = source.endpoint.trim();
    final isJsonText = endpoint.startsWith('{') || endpoint.startsWith('[');
    if (!isJsonText) {
      final uri = Uri.tryParse(endpoint);
      if (uri == null || !uri.isScheme('https')) {
        throw const FormatException('来源地址必须是有效的 HTTPS URL 或 JSON 格式文本');
      }
    } else {
      try {
        jsonDecode(endpoint);
      } catch (_) {
        throw const FormatException('非法的 JSON 格式文本');
      }
    }
    final prefs = await SharedPreferences.getInstance();
    final custom = _decodeCustom(prefs.getString(_customKey));
    custom.removeWhere((value) => value.id == source.id);
    custom.add(source);
    await _writeCustom(prefs, custom);
  }

  Future<void> removeCustom(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final custom = _decodeCustom(prefs.getString(_customKey))
      ..removeWhere((source) => source.id == id);
    await _writeCustom(prefs, custom);
  }

  Map<String, bool> _decodeEnabled(String? raw) {
    if (raw == null || raw.isEmpty) return {};
    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      return data.map((key, value) => MapEntry(key, value == true));
    } catch (_) {
      return {};
    }
  }

  List<ContentSource> _decodeCustom(String? raw) {
    if (raw == null || raw.isEmpty) return [];
    try {
      return (jsonDecode(raw) as List<dynamic>)
          .map(
            (value) =>
                ContentSource.fromJson(Map<String, dynamic>.from(value as Map)),
          )
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _writeCustom(
    SharedPreferences prefs,
    List<ContentSource> sources,
  ) => prefs.setString(
    _customKey,
    jsonEncode(sources.map((source) => source.toJson()).toList()),
  );
}
