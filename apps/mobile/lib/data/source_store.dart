import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../core/api_config.dart';
import '../domain/content.dart';
import '../domain/content_source.dart';

class SourceStore {
  static const _customKey = 'content.sources.custom.v1';
  static const _verifiedKey = 'content.sources.verified.v1';
  // v1 was generated while bundled sources defaulted to disabled. A new key
  // prevents those historical defaults from silently disabling a fresh catalog.
  static const _enabledKey = 'content.sources.enabled.v2';
  static const _orderKey = 'content.sources.order.v1';
  static List<ContentSource>? _legacyCache;
  static List<ContentSource>? _verifiedCache;

  SourceStore({http.Client? client, String? baseUrl})
    : _client = client ?? http.Client(),
      _baseUrl = baseUrl ?? ApiConfig.baseUrl;

  final http.Client _client;
  final String _baseUrl;

  Future<int> count() async {
    return (await list()).length;
  }

  Future<List<ContentSource>> list({bool refresh = false}) async {
    final prefs = await SharedPreferences.getInstance();
    var verified = refresh
        ? null
        : _verifiedCache ??
              (prefs.containsKey(_verifiedKey)
                  ? _decodeVerified(prefs.getString(_verifiedKey))
                  : null);
    if (refresh || verified == null) {
      try {
        final response = await _client
            .get(Uri.parse('$_baseUrl/sources/verified'))
            .timeout(const Duration(seconds: 8));
        if (response.statusCode == 200) {
          verified =
              (jsonDecode(utf8.decode(response.bodyBytes)) as List<dynamic>)
                  .map(
                    (value) => _verifiedSource(
                      Map<String, dynamic>.from(value as Map),
                    ),
                  )
                  .toList(growable: false);
          _verifiedCache = verified;
          await prefs.setString(
            _verifiedKey,
            jsonEncode(verified.map((source) => source.toJson()).toList()),
          );
        }
      } catch (_) {}
    }
    verified ??= _decodeVerified(prefs.getString(_verifiedKey));
    _verifiedCache = verified;
    final sources = [...verified];
    sources.sort((left, right) {
      final priority = right.priority.compareTo(left.priority);
      return priority != 0 ? priority : left.name.compareTo(right.name);
    });
    return sources;
  }

  Future<ContentSource?> findById(String id) async {
    for (final source in await list()) {
      if (source.id == id) return source;
    }
    final prefs = await SharedPreferences.getInstance();
    for (final source in _decodeCustom(prefs.getString(_customKey))) {
      if (source.id == id) return source.copyWith(enabled: true);
    }
    for (final source in [
      ...builtInContentSources,
      ...await _loadLegacySources(),
    ]) {
      if (source.id == id) return source.copyWith(enabled: true);
    }
    return null;
  }

  static void clearMemoryCache() {
    _verifiedCache = null;
  }

  ContentSource _verifiedSource(Map<String, dynamic> value) => ContentSource(
    id: value['id']?.toString() ?? '',
    name: value['name']?.toString() ?? '未命名书源',
    description: '已通过搜索、目录和正文完整链路验证',
    channels: const {ContentChannel.novel},
    kind: value['kind'] == 'backend_rule'
        ? SourceKind.backendRule
        : SourceKind.legacy,
    endpoint: value['endpoint']?.toString() ?? '',
    enabled: true,
    builtIn: true,
    priority: (value['priority'] as num?)?.toInt() ?? 0,
    health: SourceHealth.healthy,
    latencyMs: (value['latency_ms'] as num?)?.toInt() ?? 0,
    compatibility: 'verified',
    compatibilityReason: '搜索、目录和正文完整链路正常',
  );

  List<ContentSource> _decodeVerified(String? raw) {
    if (raw == null || raw.isEmpty) return const [];
    try {
      return (jsonDecode(raw) as List<dynamic>)
          .map(
            (value) =>
                ContentSource.fromJson(Map<String, dynamic>.from(value as Map)),
          )
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  Future<List<ContentSource>> _loadLegacySources() async {
    final cached = _legacyCache;
    if (cached != null) return cached;
    final sources = await _readLegacySources();
    _legacyCache = sources;
    return sources;
  }

  Future<List<ContentSource>> _readLegacySources() async {
    try {
      final bytes = await rootBundle.load(
        'assets/book_sources/legacy_sources.json',
      );
      final raw = utf8.decode(
        bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
      );
      final payload = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      return (payload['sources'] as List<dynamic>? ?? const [])
          .map(
            (value) =>
                ContentSource.fromJson(Map<String, dynamic>.from(value as Map)),
          )
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
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
        (source.kind != SourceKind.json &&
            source.kind != SourceKind.js &&
            source.kind != SourceKind.legacy)) {
      throw const FormatException('只能添加 JSON、JS 或 Legado 规则自定义来源');
    }
    final endpoint = source.endpoint.trim();
    final isJsonText = endpoint.startsWith('{') || endpoint.startsWith('[');
    if (!isJsonText) {
      final uri = Uri.tryParse(endpoint);
      if (uri == null ||
          (!uri.isScheme('https') &&
              !(source.kind == SourceKind.legacy && uri.isScheme('http')))) {
        throw const FormatException('来源地址必须是有效的 HTTPS URL；Legado 规则也兼容 HTTP');
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

  Future<int> importMany(String raw) async {
    dynamic decoded;
    try {
      decoded = jsonDecode(_sanitizeJsonString(raw.trim()));
    } catch (_) {
      throw const FormatException('书源文件不是有效的 JSON');
    }
    final values = decoded is List<dynamic>
        ? decoded
        : decoded is Map<String, dynamic>
        ? (decoded['sources'] as List<dynamic>? ?? [decoded])
        : const <dynamic>[];
    if (values.isEmpty) throw const FormatException('没有找到可导入的书源');
    var imported = 0;
    final errors = <String>[];
    for (var index = 0; index < values.length; index++) {
      try {
        final value = Map<String, dynamic>.from(values[index] as Map);
        if (value.containsKey('bookSourceUrl')) {
          final name = value['bookSourceName']?.toString().trim() ?? '';
          final endpoint = value['bookSourceUrl']?.toString().trim() ?? '';
          if (name.isEmpty || endpoint.isEmpty) {
            throw const FormatException('Legado 规则缺少书源名称或地址');
          }
          await addCustom(
            ContentSource(
              id: 'legacy-import-${DateTime.now().microsecondsSinceEpoch}-$index',
              name: name,
              description: 'Legado 完整规则 · JVM 兼容运行时',
              channels: const {ContentChannel.novel},
              kind: SourceKind.legacy,
              endpoint: endpoint,
              enabled: value['enabled'] as bool? ?? true,
              priority: (value['weight'] as num?)?.toInt() ?? 50,
              health: SourceHealth.unknown,
              group: value['bookSourceGroup']?.toString() ?? '',
              compatibility: 'jvm_runtime',
              compatibilityReason: '由隔离的 JVM 规则运行时解析',
              rules: {'__source_json': jsonEncode(value)},
            ),
          );
          imported++;
          continue;
        }
        final kindName =
            value['kind']?.toString() ?? value['type']?.toString() ?? 'json';
        final kind = kindName.toLowerCase() == 'js'
            ? SourceKind.js
            : SourceKind.json;
        final name =
            value['name']?.toString().trim() ??
            value['source_name']?.toString().trim() ??
            '';
        final endpoint =
            value['endpoint']?.toString().trim() ??
            value['url']?.toString().trim() ??
            '';
        if (name.isEmpty || endpoint.isEmpty) {
          throw const FormatException('缺少 name 或 endpoint');
        }
        final rules = (value['rules'] as Map<dynamic, dynamic>?)?.map(
          (key, rule) => MapEntry(key.toString(), rule.toString()),
        );
        await addCustom(
          ContentSource(
            id:
                value['id']?.toString() ??
                'import-${DateTime.now().microsecondsSinceEpoch}-$index',
            name: name,
            description:
                value['description']?.toString() ??
                (endpoint.startsWith('https://') ? endpoint : '导入书源'),
            channels: const {ContentChannel.novel},
            kind: kind,
            endpoint: endpoint,
            enabled: value['enabled'] as bool? ?? true,
            priority: (value['priority'] as num?)?.toInt() ?? 50,
            health: SourceHealth.unknown,
            rules: rules,
          ),
        );
        imported++;
      } on FormatException catch (error) {
        errors.add('第 ${index + 1} 项：${error.message}');
      } catch (_) {
        errors.add('第 ${index + 1} 项：格式不受支持');
      }
    }
    if (imported == 0) {
      throw FormatException(errors.take(3).join('；'));
    }
    return imported;
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
