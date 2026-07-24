import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/content_source.dart';

class SourceStore {
  static const _customKey = 'content.sources.custom.v1';
  static const _enabledKey = 'content.sources.enabled.v1';
  static const _orderKey = 'content.sources.order.v1';

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
    final sources = [...builtIns, ...custom];
    final order = _decodeOrder(prefs.getString(_orderKey));
    sources.sort((left, right) {
      final leftIndex = order.indexOf(left.id);
      final rightIndex = order.indexOf(right.id);
      if (leftIndex >= 0 && rightIndex >= 0) {
        return leftIndex.compareTo(rightIndex);
      }
      if (leftIndex >= 0) return -1;
      if (rightIndex >= 0) return 1;
      return right.priority.compareTo(left.priority);
    });
    return sources;
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
    if (source.builtIn ||
        (source.kind != SourceKind.json && source.kind != SourceKind.js)) {
      throw const FormatException('只能添加 JSON 或 JS 规则自定义来源');
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
        jsonDecode(_sanitizeJsonString(endpoint));
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

  Future<void> updateCustom(ContentSource source) async {
    if (source.builtIn) {
      throw const FormatException('内置书源不能修改地址');
    }
    await addCustom(source);
  }

  Future<void> saveOrder(List<String> sourceIds) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_orderKey, jsonEncode(sourceIds));
  }

  String _sanitizeJsonString(String source) {
    final buffer = StringBuffer();
    bool inQuotes = false;
    bool escaped = false;
    for (int i = 0; i < source.length; i++) {
      final char = source[i];
      if (char == '"' && !escaped) {
        inQuotes = !inQuotes;
        buffer.write(char);
      } else if (char == '\\' && !escaped) {
        escaped = true;
        buffer.write(char);
      } else {
        if (escaped) {
          escaped = false;
        }
        if (inQuotes && char == '\n') {
          buffer.write('\\n');
        } else if (inQuotes && char == '\r') {
          // Skip
        } else {
          buffer.write(char);
        }
      }
    }
    return buffer.toString();
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

  List<String> _decodeOrder(String? raw) {
    if (raw == null || raw.isEmpty) return const [];
    try {
      return (jsonDecode(raw) as List<dynamic>)
          .map((value) => value.toString())
          .toList(growable: false);
    } catch (_) {
      return const [];
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
