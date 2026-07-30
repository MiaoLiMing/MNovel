import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../core/api_config.dart';
import '../core/js_runner.dart';
import '../domain/content.dart';
import '../domain/content_source.dart';
import 'offline_library.dart';
import 'source_store.dart';

class ContentRepositoryException implements Exception {
  const ContentRepositoryException(this.message);

  final String message;

  @override
  String toString() => message;
}

class HomeData {
  const HomeData({
    required this.featured,
    required this.carousel,
    required this.editorsPick,
    required this.latest,
    this.fromNetwork = false,
    this.fromCache = false,
    this.sourceCount = 0,
    this.failedSourceCount = 0,
  });

  final ContentItem? featured;
  final List<ContentItem> carousel;
  final List<ContentItem> editorsPick;
  final List<ContentItem> latest;
  final bool fromNetwork;
  final bool fromCache;
  final int sourceCount;
  final int failedSourceCount;

  bool get isEmpty =>
      featured == null &&
      carousel.isEmpty &&
      editorsPick.isEmpty &&
      latest.isEmpty;
}

class FilterOption {
  const FilterOption({required this.value, required this.label});

  final String value;
  final String label;
}

class FilterGroup {
  const FilterGroup({
    required this.id,
    required this.label,
    required this.options,
  });

  final String id;
  final String label;
  final List<FilterOption> options;
}

class SearchMeta {
  const SearchMeta({required this.hot, required this.suggestions});

  final List<ContentItem> hot;
  final List<String> suggestions;
}

class SourceProbeResult {
  const SourceProbeResult({
    required this.health,
    required this.latencyMs,
    this.message = '',
  });

  final SourceHealth health;
  final int latencyMs;
  final String message;
}

class ContentRepository {
  static const _chapterTimeout = Duration(seconds: 20);
  static const _maxChapterResponseBytes = 512 * 1024;
  static const _maxChapterCharacters = 120000;

  ContentRepository({
    http.Client? client,
    SourceStore? sourceStore,
    String? baseUrl,
  }) : _client = client ?? http.Client(),
       _sourceStore = sourceStore ?? SourceStore(),
       _baseUrl = baseUrl ?? ApiConfig.baseUrl;

  final http.Client _client;
  final SourceStore _sourceStore;
  final String _baseUrl;
  int _homeRefreshSeed = 0;
  int _sourceWindowOffset = 0;
  int _lastSourceCount = 0;
  int _lastFailedSourceCount = 0;

  Future<HomeData?> cachedHome({String channel = '推荐'}) async {
    final items = await _readHomeCache(channel);
    if (items.isEmpty) return null;
    return _composeHome(
      items,
      fromCache: true,
      sourceCount: _lastSourceCount,
      failedSourceCount: _lastFailedSourceCount,
    );
  }

  HomeData localHome({String channel = '推荐'}) =>
      const HomeData(featured: null, carousel: [], editorsPick: [], latest: []);

  Future<HomeData> home({String channel = '推荐'}) async {
    final collected = <ContentItem>[];
    var reachedNetwork = false;
    var reachedBackend = false;
    const refreshPage = 1;
    _homeRefreshSeed++;
    try {
      final data = await _getObject('/home', {'page': '$refreshPage'});
      final sections = data['sections'] as List<dynamic>? ?? const [];
      List<ContentItem> sectionItems(String id) {
        for (final rawSection in sections) {
          final section = Map<String, dynamic>.from(rawSection as Map);
          if (section['id'] == id) {
            return _parseItems(section['items']);
          }
        }
        return const [];
      }

      collected.add(
        ContentItem.fromJson(
          Map<String, dynamic>.from(data['featured'] as Map),
        ),
      );
      collected
        ..addAll(_parseItems(data['carousel']))
        ..addAll(sectionItems('editors-pick'))
        ..addAll(sectionItems('latest'));
      reachedBackend = collected.isNotEmpty;
      reachedNetwork = reachedBackend;
    } catch (_) {}

    final sourceItems = await _loadEnabledSourceCatalog(
      page: refreshPage,
      includePublicFallback: !reachedBackend,
    );
    if (sourceItems.isNotEmpty) {
      reachedNetwork = true;
    }
    final merged = _mergeItems([...sourceItems, ...collected]);
    if (reachedNetwork && merged.isNotEmpty) {
      await _writeHomeCache(channel, merged);
    }
    return _composeHome(
      merged,
      fromNetwork: reachedNetwork,
      sourceCount: _lastSourceCount,
      failedSourceCount: _lastFailedSourceCount,
    );
  }

  HomeData _composeHome(
    List<ContentItem> items, {
    bool fromNetwork = false,
    bool fromCache = false,
    int sourceCount = 0,
    int failedSourceCount = 0,
  }) {
    if (items.isEmpty) {
      return HomeData(
        featured: null,
        carousel: const [],
        editorsPick: const [],
        latest: const [],
        fromNetwork: fromNetwork,
        fromCache: fromCache,
        sourceCount: sourceCount,
        failedSourceCount: failedSourceCount,
      );
    }
    final rotated = items.length <= 1
        ? items
        : [
            ...items.skip(_homeRefreshSeed % items.length),
            ...items.take(_homeRefreshSeed % items.length),
          ];
    return HomeData(
      featured: rotated.first,
      carousel: rotated.take(6).toList(growable: false),
      editorsPick: rotated.skip(2).take(8).toList(growable: false),
      latest: rotated.reversed.take(10).toList(growable: false),
      fromNetwork: fromNetwork,
      fromCache: fromCache,
      sourceCount: sourceCount,
      failedSourceCount: failedSourceCount,
    );
  }

  Future<List<ContentItem>> discover(
    ContentChannel channel, {
    String query = '',
    String category = '',
    String status = '',
    String wordCount = '',
    String source = '',
    int page = 1,
  }) async {
    final queryParameters = <String, String>{
      if (query.trim().isNotEmpty) 'query': query.trim(),
      if (category.isNotEmpty && category != '全部') 'category': category,
      if (status.isNotEmpty && status != 'all') 'status': status,
      if (wordCount.isNotEmpty && wordCount != 'all') 'word_count': wordCount,
      if (source.isNotEmpty && source != '全部') 'source': source,
      'page': '$page',
    };
    List<ContentItem> items;
    var reachedBackend = false;
    try {
      final data = await _getList('/discover', queryParameters);
      items = data
          .map((value) => ContentItem.fromJson(value))
          .toList(growable: false);
      reachedBackend = true;
    } catch (_) {
      items = const [];
    }

    var aggregateReached = false;
    var aggregateItems = const <ContentItem>[];
    if (query.trim().isNotEmpty) {
      try {
        aggregateItems = await _loadAggregatedLegacySearch(
          query: query,
          page: page,
        );
        aggregateReached = true;
      } catch (_) {}
    }
    final sourceItems = await _loadEnabledSourceCatalog(
      query: query,
      page: page,
      includePublicFallback: !reachedBackend,
      includeBundledLegacy: !aggregateReached,
    );
    final combined = [...aggregateItems, ...sourceItems, ...items];
    return query.trim().isEmpty
        ? _mergeItems(combined)
        : _mergeSearchItems(combined);
  }

  Future<SearchMeta> searchMeta() async {
    try {
      final data = await _getObject('/search/meta');
      return SearchMeta(
        hot: _parseItems(data['hot']),
        suggestions: (data['suggestions'] as List<dynamic>? ?? const [])
            .map((value) => value.toString())
            .toList(growable: false),
      );
    } catch (_) {
      return const SearchMeta(hot: [], suggestions: []);
    }
  }

  Future<SourceAuditProgress> sourceAuditStatus() async =>
      SourceAuditProgress.fromJson(await _getObject('/sources/audit/status'));

  Future<SourceAuditProgress> startSourceAudit({bool force = true}) async {
    final response = await _client
        .post(_uri('/sources/audit', {'force': '$force'}))
        .timeout(const Duration(seconds: 8));
    if (response.statusCode != 200) {
      throw ContentRepositoryException(_responseError(response));
    }
    return SourceAuditProgress.fromJson(
      Map<String, dynamic>.from(
        jsonDecode(utf8.decode(response.bodyBytes)) as Map,
      ),
    );
  }

  Future<SourceProbeResult> probeSource(ContentSource source) async {
    if (!source.builtIn) {
      if (source.kind == SourceKind.legacy) {
        final stopwatch = Stopwatch()..start();
        try {
          final values = await _postList('/sources/runtime/search', {
            'source': _legacySourcePayload(source),
            'keyword': '红楼梦',
            'page': 1,
          });
          stopwatch.stop();
          return SourceProbeResult(
            health: values.isEmpty ? SourceHealth.error : SourceHealth.healthy,
            latencyMs: stopwatch.elapsedMilliseconds,
            message: values.isEmpty ? '搜索规则未返回结果' : 'JVM 规则运行时搜索链路正常',
          );
        } catch (error) {
          stopwatch.stop();
          return SourceProbeResult(
            health: SourceHealth.error,
            latencyMs: stopwatch.elapsedMilliseconds,
            message: _networkErrorMessage(error),
          );
        }
      }
      final endpoint = source.endpoint.trim();
      if (endpoint.isEmpty) {
        return const SourceProbeResult(
          health: SourceHealth.configurationRequired,
          latencyMs: 0,
          message: '请先填写来源地址或规则',
        );
      }
      if (endpoint.startsWith('[') || endpoint.startsWith('{')) {
        return const SourceProbeResult(
          health: SourceHealth.healthy,
          latencyMs: 0,
          message: '本地规则格式有效',
        );
      }
      final stopwatch = Stopwatch()..start();
      try {
        final response = await _client
            .get(Uri.parse(endpoint))
            .timeout(const Duration(seconds: 8));
        stopwatch.stop();
        return SourceProbeResult(
          health: response.statusCode < 500
              ? SourceHealth.healthy
              : SourceHealth.error,
          latencyMs: stopwatch.elapsedMilliseconds,
          message: 'HTTP ${response.statusCode}',
        );
      } catch (error) {
        stopwatch.stop();
        return SourceProbeResult(
          health: SourceHealth.error,
          latencyMs: stopwatch.elapsedMilliseconds,
          message: _networkErrorMessage(error),
        );
      }
    }

    final stopwatch = Stopwatch()..start();
    try {
      final response = await _client
          .get(_uri('/sources/${source.id}/health'))
          .timeout(const Duration(seconds: 8));
      stopwatch.stop();
      Map<String, dynamic> data = const {};
      try {
        data = Map<String, dynamic>.from(
          jsonDecode(utf8.decode(response.bodyBytes)) as Map,
        );
      } catch (_) {}
      if (response.statusCode != 200) {
        final detail = data['detail']?.toString().trim();
        return SourceProbeResult(
          health: SourceHealth.error,
          latencyMs: stopwatch.elapsedMilliseconds,
          message: response.statusCode == 404
              ? '服务器尚未部署此内置源'
              : detail?.isNotEmpty == true
              ? detail!
              : '检测接口返回 HTTP ${response.statusCode}',
        );
      }
      final status = data['status']?.toString() ?? 'error';
      return SourceProbeResult(
        health: status == 'healthy' ? SourceHealth.healthy : SourceHealth.error,
        latencyMs:
            (data['latency_ms'] as num?)?.toInt() ??
            stopwatch.elapsedMilliseconds,
        message: data['message']?.toString() ?? '',
      );
    } catch (error) {
      stopwatch.stop();
      return SourceProbeResult(
        health: SourceHealth.error,
        latencyMs: stopwatch.elapsedMilliseconds,
        message: _sourceProbeErrorMessage(error),
      );
    }
  }

  String _sourceProbeErrorMessage(Object error) {
    final message = error.toString().toLowerCase();
    if (message.contains('timed out') || message.contains('timeoutexception')) {
      return '书源检测超时，请稍后重试';
    }
    if (message.contains('socketexception') ||
        message.contains('failed host lookup') ||
        message.contains('network is unreachable') ||
        message.contains('connection refused')) {
      return '无法连接检测服务，请检查网络';
    }
    if (message.contains('certificate_verify_failed') ||
        message.contains('handshakeexception')) {
      return '检测服务安全连接失败';
    }
    return error is ContentRepositoryException ? error.message : '书源检测失败，请稍后重试';
  }

  Future<List<FilterGroup>> taxonomy() async {
    try {
      final data = await _getObject('/taxonomy');
      return (data['groups'] as List<dynamic>? ?? const [])
          .map((raw) {
            final group = Map<String, dynamic>.from(raw as Map);
            return FilterGroup(
              id: group['id'] as String,
              label: group['label'] as String,
              options: (group['options'] as List<dynamic>? ?? const [])
                  .map((rawOption) {
                    final option = Map<String, dynamic>.from(rawOption as Map);
                    return FilterOption(
                      value: option['value'] as String,
                      label: option['label'] as String,
                    );
                  })
                  .toList(growable: false),
            );
          })
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  Future<ContentItem> detail(ContentItem item) async {
    if (!item.isReadable) {
      throw ContentRepositoryException(
        item.unavailableReason.isEmpty ? '当前来源没有可阅读正文' : item.unavailableReason,
      );
    }
    if (_isLegacyItem(item)) {
      final chapters = await _loadLegacyChapters(item);
      if (chapters.isEmpty) {
        throw const ContentRepositoryException('当前来源没有可用章节');
      }
      return item.copyWith(
        episodeCount: chapters.length,
        chapterUrls: chapters
            .map((chapter) => chapter['url']?.toString() ?? '')
            .where((url) => url.isNotEmpty)
            .toList(growable: false),
      );
    }
    try {
      final data = await _getObject('/content/${item.id}');
      return ContentItem.fromJson(data).copyWith(progress: item.progress);
    } catch (error) {
      if (item.isLive) {
        throw ContentRepositoryException(_networkErrorMessage(error));
      }
      return item;
    }
  }

  /// 将本地状态异步同步到后端；失败时保留本地状态，避免弱网阻塞阅读。
  Future<void> syncFavorite(ContentItem item, bool active) async {
    // 最新后端未提供收藏写接口；书架以本地持久化为准。
  }

  Future<void> syncProgress(
    ContentItem item, {
    required int unitIndex,
    required double position,
  }) async {
    // 最新后端未提供进度写接口；阅读进度以本地持久化为准。
  }

  Future<List<ContentItem>> alternatives(ContentItem item) async {
    final discovered = await discover(item.channel, query: item.title);
    final expectedTitle = _normalizeTitle(item.title);
    final bySource = <String, ContentItem>{item.sourceId: item};
    for (final candidate in discovered) {
      final candidateTitle = _normalizeTitle(candidate.title);
      if (candidateTitle == expectedTitle ||
          candidateTitle.contains(expectedTitle) ||
          expectedTitle.contains(candidateTitle)) {
        bySource[candidate.sourceId] = candidate;
      }
    }
    if (bySource.length == 1 && item.sourceLabels.length > 1) {
      for (final label in item.sourceLabels.skip(1)) {
        bySource[label] = item.copyWith(sourceId: label, sourceName: label);
      }
    }
    return bySource.values.toList(growable: false);
  }

  Future<List<ChapterEntry>> chapters(
    ContentItem item, {
    int offset = 0,
    int limit = 100,
  }) async {
    if (_isLegacyItem(item)) {
      final chapters = await _loadLegacyChapters(item);
      return chapters
          .skip(offset)
          .take(limit)
          .map((chapter) {
            return ChapterEntry(
              index: (chapter['index'] as num?)?.toInt() ?? 0,
              title: chapter['title']?.toString() ?? '未命名章节',
            );
          })
          .toList(growable: false);
    }
    try {
      final data = await _getList('/content/${item.id}/units', {
        'offset': '$offset',
        'limit': '$limit',
      }, _chapterTimeout);
      return data
          .map((value) => ChapterEntry.fromJson(value))
          .toList(growable: false);
    } catch (error) {
      throw ContentRepositoryException(_networkErrorMessage(error));
    }
  }

  Future<Chapter> chapter(
    ContentItem item,
    int index, {
    bool preferOffline = true,
  }) async {
    if (preferOffline) {
      final offline = await OfflineLibraryStore().loadChapter(
        item.id,
        index,
        sourceId: item.sourceId,
      );
      if (offline != null) return offline;
    }
    if (item.localChapters != null && index < item.localChapters!.length) {
      final raw = item.localChapters![index];
      return Chapter(
        title: raw['title'] as String? ?? '第 ${index + 1} 章',
        paragraphs: (raw['paragraphs'] as List<dynamic>? ?? const [])
            .map((value) => value.toString())
            .toList(growable: false),
        index: index,
      );
    }

    if (_isLegacyItem(item)) {
      var urls = item.chapterUrls;
      if (urls == null || index >= urls.length) {
        final chapters = await _loadLegacyChapters(item);
        urls = chapters
            .map((chapter) => chapter['url']?.toString() ?? '')
            .where((url) => url.isNotEmpty)
            .toList(growable: false);
      }
      if (index >= urls.length) {
        throw const ContentRepositoryException('当前书源没有提供这一章');
      }
      final data = await _loadLegacyContent(
        item,
        urls[index],
        '第 ${index + 1} 章',
      );
      return _validateChapter(
        Chapter(
          title: data['title']?.toString() ?? '第 ${index + 1} 章',
          paragraphs: (data['paragraphs'] as List<dynamic>? ?? const [])
              .map((value) => value.toString())
              .toList(growable: false),
          index: index,
        ),
      );
    }

    if (item.chapterUrls != null && index < item.chapterUrls!.length) {
      final chapter = await _loadCustomChapter(item, index);
      if (chapter != null) return chapter;
    }

    try {
      final data = await _getChapterObject(
        '/content/${item.id}/chapters/$index',
        const {},
      );
      return _validateChapter(Chapter.fromJson(data));
    } catch (error) {
      throw ContentRepositoryException(_networkErrorMessage(error));
    }
  }

  String _networkErrorMessage(Object error) {
    final message = error.toString().toLowerCase();
    if (message.contains('certificate_verify_failed') ||
        message.contains('handshakeexception') ||
        message.contains('ip address mismatch')) {
      return '安全连接校验失败，请检查服务地址或稍后重试';
    }
    if (message.contains('timed out') || message.contains('timeoutexception')) {
      return '章节请求超时，请检查网络后重试';
    }
    if (message.contains('socketexception') ||
        message.contains('failed host lookup') ||
        message.contains('network is unreachable') ||
        message.contains('connection refused')) {
      return '当前网络不可用，且本章尚未下载';
    }
    if (message.contains('404') || message.contains('正文不存在')) {
      return '当前书源没有提供这一章的正文';
    }
    if (error is ContentRepositoryException) return error.message;
    return '章节暂时无法加载，请重试或切换书源';
  }

  Future<Map<String, dynamic>> _getObject(
    String path, [
    Map<String, String>? query,
  ]) async {
    final response = await _client
        .get(_uri(path, query))
        .timeout(const Duration(seconds: 8));
    if (response.statusCode != 200) {
      throw ContentRepositoryException(_responseError(response));
    }
    return Map<String, dynamic>.from(
      jsonDecode(utf8.decode(response.bodyBytes)) as Map,
    );
  }

  Future<List<Map<String, dynamic>>> _getList(
    String path, [
    Map<String, String>? query,
    Duration timeout = const Duration(seconds: 8),
  ]) async {
    final response = await _client.get(_uri(path, query)).timeout(timeout);
    if (response.statusCode != 200) {
      throw ContentRepositoryException(_responseError(response));
    }
    return (jsonDecode(utf8.decode(response.bodyBytes)) as List<dynamic>)
        .map((value) => Map<String, dynamic>.from(value as Map))
        .toList(growable: false);
  }

  Future<List<Map<String, dynamic>>> _postList(
    String path,
    Map<String, dynamic> payload,
  ) async {
    final response = await _client
        .post(
          _uri(path),
          headers: const {'content-type': 'application/json; charset=utf-8'},
          body: jsonEncode(payload),
        )
        .timeout(_chapterTimeout);
    if (response.statusCode != 200) {
      throw ContentRepositoryException(_responseError(response));
    }
    return (jsonDecode(utf8.decode(response.bodyBytes)) as List<dynamic>)
        .map((value) => Map<String, dynamic>.from(value as Map))
        .toList(growable: false);
  }

  Future<Map<String, dynamic>> _postObject(
    String path,
    Map<String, dynamic> payload,
  ) async {
    final response = await _client
        .post(
          _uri(path),
          headers: const {'content-type': 'application/json; charset=utf-8'},
          body: jsonEncode(payload),
        )
        .timeout(_chapterTimeout);
    if (response.statusCode != 200) {
      throw ContentRepositoryException(_responseError(response));
    }
    return Map<String, dynamic>.from(
      jsonDecode(utf8.decode(response.bodyBytes)) as Map,
    );
  }

  Future<Map<String, dynamic>> _getChapterObject(
    String path,
    Map<String, String> query,
  ) async {
    final response = await _client
        .get(_uri(path, query))
        .timeout(_chapterTimeout);
    if (response.statusCode != 200) {
      throw ContentRepositoryException(_responseError(response));
    }
    if (response.bodyBytes.length > _maxChapterResponseBytes) {
      throw const ContentRepositoryException('书源返回的单章正文过大，已停止处理以避免应用卡死');
    }
    return Map<String, dynamic>.from(
      jsonDecode(utf8.decode(response.bodyBytes)) as Map,
    );
  }

  Chapter _validateChapter(Chapter chapter) {
    var characters = 0;
    for (final paragraph in chapter.paragraphs) {
      characters += paragraph.length;
      if (characters > _maxChapterCharacters) {
        throw const ContentRepositoryException('书源返回的单章正文过大，已停止排版以避免应用卡死');
      }
    }
    return chapter;
  }

  Uri _uri(String path, [Map<String, String>? query]) {
    final normalizedPath = path.startsWith('/') ? path : '/$path';
    return Uri.parse(
      '$_baseUrl$normalizedPath',
    ).replace(queryParameters: query?.isEmpty ?? true ? null : query);
  }

  String _responseError(http.Response response) {
    try {
      final payload = Map<String, dynamic>.from(
        jsonDecode(utf8.decode(response.bodyBytes)) as Map,
      );
      final detail = payload['detail']?.toString().trim();
      if (detail?.isNotEmpty == true) return detail!;
    } catch (_) {}
    return '服务暂不可用（${response.statusCode}）';
  }

  Future<List<ContentItem>> _loadEnabledSourceCatalog({
    String query = '',
    int page = 1,
    bool includePublicFallback = false,
    bool includeBundledLegacy = true,
  }) async {
    final sources = await _sourceStore.list();
    final enabled = sources.where((source) => source.enabled).toList()
      ..sort((left, right) => right.priority.compareTo(left.priority));
    final eligible = enabled
        .where(
          (source) =>
              (includePublicFallback &&
                  (source.kind == SourceKind.gutendex ||
                      source.kind == SourceKind.wikisource ||
                      source.kind == SourceKind.internetArchive)) ||
              source.kind == SourceKind.json ||
              source.kind == SourceKind.js ||
              (source.kind == SourceKind.legacy &&
                  (includeBundledLegacy || !source.builtIn)),
        )
        .toList(growable: false);
    const windowSize = 12;
    final supported = <ContentSource>[];
    if (eligible.isNotEmpty) {
      final start = _sourceWindowOffset % eligible.length;
      final count = eligible.length < windowSize ? eligible.length : windowSize;
      for (var index = 0; index < count; index++) {
        supported.add(eligible[(start + index) % eligible.length]);
      }
      _sourceWindowOffset = (start + count) % eligible.length;
    }
    _lastSourceCount =
        eligible.length +
        enabled.where((source) => source.kind == SourceKind.backendRule).length;
    final results = await Future.wait(
      supported.map((source) async {
        try {
          return switch (source.kind) {
            SourceKind.gutendex => _loadGutendex(
              source,
              query: query,
              page: page,
            ),
            SourceKind.wikisource => _loadWikisource(
              source,
              query: query,
              page: page,
            ),
            SourceKind.internetArchive => _loadInternetArchiveBooks(
              source,
              query: query,
              page: page,
            ),
            SourceKind.json ||
            SourceKind.js => _loadOneCustomSource(source, query: query),
            SourceKind.legacy => _loadOneLegacySource(
              source,
              query: query,
              page: page,
            ),
            _ => Future.value(<ContentItem>[]),
          };
        } catch (_) {
          return <ContentItem>[];
        }
      }),
    );
    _lastFailedSourceCount = results.where((items) => items.isEmpty).length;
    return _mergeItems(results.expand((items) => items).toList());
  }

  Future<List<ContentItem>> _loadGutendex(
    ContentSource source, {
    String query = '',
    int page = 1,
  }) async {
    final endpoint = Uri.parse(source.endpoint).replace(
      queryParameters: {
        if (query.trim().isNotEmpty) 'search': query.trim(),
        'page': '$page',
      },
    );
    final response = await _client
        .get(endpoint)
        .timeout(const Duration(seconds: 12));
    if (response.statusCode != 200) {
      throw ContentRepositoryException(
        '${source.name} 暂不可用（${response.statusCode}）',
      );
    }
    final payload = Map<String, dynamic>.from(
      jsonDecode(utf8.decode(response.bodyBytes)) as Map,
    );
    final values = payload['results'] as List<dynamic>? ?? const [];
    return values
        .map((raw) {
          final book = Map<String, dynamic>.from(raw as Map);
          final formats = Map<String, dynamic>.from(
            book['formats'] as Map? ?? const {},
          );
          final authors = book['authors'] as List<dynamic>? ?? const [];
          final author = authors.isEmpty
              ? '未知作者'
              : Map<String, dynamic>.from(
                      authors.first as Map,
                    )['name']?.toString() ??
                    '未知作者';
          final subjects = (book['subjects'] as List<dynamic>? ?? const [])
              .map((value) => value.toString())
              .toList();
          final textUrl = formats.entries
              .where(
                (entry) =>
                    entry.key.startsWith('text/plain') &&
                    entry.value.toString().startsWith('http'),
              )
              .map((entry) => entry.value.toString())
              .firstOrNull;
          final htmlUrl = formats.entries
              .where(
                (entry) =>
                    entry.key.startsWith('text/html') &&
                    entry.value.toString().startsWith('http'),
              )
              .map((entry) => entry.value.toString())
              .firstOrNull;
          final contentUrl = textUrl ?? htmlUrl;
          return ContentItem(
            id: 'gutenberg-${book['id']}',
            title: book['title']?.toString() ?? '未命名作品',
            creator: author,
            category: subjects.take(2).join(' · ').isEmpty
                ? '公共领域文学'
                : subjects.take(2).join(' · '),
            summary: subjects.take(4).join('；'),
            coverAsset:
                formats['image/jpeg']?.toString() ??
                formats['image/png']?.toString() ??
                '',
            popularity: '${book['download_count'] ?? 0} 次下载',
            progress: 0,
            episodeCount: contentUrl == null ? 0 : 1,
            sourceId: source.id,
            sourceName: source.name,
            isLive: true,
            status: NovelStatus.completed,
            sourceLabels: [source.name],
            chapterUrls: contentUrl == null ? null : [contentUrl],
            tags: subjects.take(4).toList(growable: false),
          );
        })
        .where((item) => item.chapterUrls?.isNotEmpty ?? false)
        .toList(growable: false);
  }

  Future<List<ContentItem>> _loadInternetArchiveBooks(
    ContentSource source, {
    String query = '',
    int page = 1,
  }) async {
    final term = query.trim();
    final filters = <String>[
      'mediatype:texts',
      'format:"DjVuTXT"',
      '(language:chi OR language:Chinese OR language:zho)',
      if (term.isNotEmpty) '(title:($term) OR creator:($term))',
    ];
    final uri = Uri.parse(source.endpoint).replace(
      queryParameters: {
        'q': filters.join(' AND '),
        'fl[]':
            'identifier,title,creator,description,downloads,subject,language',
        'rows': '40',
        'page': '$page',
        'output': 'json',
        'sort[]': 'downloads desc',
      },
    );
    final response = await _client
        .get(uri)
        .timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) {
      throw ContentRepositoryException(
        '${source.name} 暂不可用（${response.statusCode}）',
      );
    }
    final payload = Map<String, dynamic>.from(
      jsonDecode(utf8.decode(response.bodyBytes)) as Map,
    );
    final responseData = Map<String, dynamic>.from(
      payload['response'] as Map? ?? const {},
    );
    final docs = responseData['docs'] as List<dynamic>? ?? const [];
    final cjk = RegExp(r'[\u3400-\u9fff]');
    return docs
        .map((raw) {
          final value = Map<String, dynamic>.from(raw as Map);
          final identifier = value['identifier']?.toString() ?? '';
          final creator = value['creator'];
          final creatorText = creator is List
              ? creator.map((entry) => entry.toString()).join('、')
              : creator?.toString() ?? '未知作者';
          final description = value['description'];
          final descriptionText = description is List
              ? description.map((entry) => entry.toString()).join(' ')
              : description?.toString() ?? 'Internet Archive 公开中文馆藏。';
          final subjects = value['subject'] is List
              ? (value['subject'] as List)
                    .map((entry) => entry.toString())
                    .take(4)
                    .toList()
              : <String>[];
          return ContentItem(
            id: 'archive-$identifier',
            title: value['title']?.toString() ?? identifier,
            creator: creatorText,
            category: subjects.isEmpty
                ? '中文公共馆藏'
                : subjects.take(2).join(' · '),
            summary: descriptionText,
            coverAsset: 'https://archive.org/services/img/$identifier',
            popularity: '${value['downloads'] ?? 0} 次下载',
            progress: 0,
            episodeCount: 1,
            sourceId: source.id,
            sourceName: source.name,
            isLive: true,
            status: NovelStatus.completed,
            sourceLabels: [source.name],
            chapterUrls: [
              'https://archive.org/download/$identifier/${identifier}_djvu.txt',
            ],
            tags: subjects,
          );
        })
        .where(
          (item) =>
              item.id != 'archive-' &&
              (cjk.hasMatch(item.title) || cjk.hasMatch(item.creator)),
        )
        .toList(growable: false);
  }

  Future<List<ContentItem>> _loadWikisource(
    ContentSource source, {
    String query = '',
    int page = 1,
  }) async {
    const rotations = ['紅樓夢', '三國演義', '水滸傳', '西遊記', '聊齋志異', '儒林外史'];
    final browsingSeries = query.trim().isEmpty;
    final search = browsingSeries
        ? rotations[(page - 1).remainder(rotations.length)]
        : query.trim();
    final uri = Uri.parse(source.endpoint).replace(
      queryParameters: {
        'action': 'query',
        'generator': browsingSeries ? 'allpages' : 'search',
        if (browsingSeries) 'gapprefix': '$search/',
        if (browsingSeries) 'gapnamespace': '0',
        if (browsingSeries) 'gaplimit': 'max',
        if (!browsingSeries) 'gsrsearch': search,
        if (!browsingSeries) 'gsrnamespace': '0',
        if (!browsingSeries) 'gsrlimit': '30',
        'prop': 'extracts|pageimages',
        'exintro': '1',
        'explaintext': '1',
        'piprop': 'thumbnail',
        'pithumbsize': '320',
        'format': 'json',
        'formatversion': '2',
        'origin': '*',
      },
    );
    final response = await _client
        .get(uri)
        .timeout(const Duration(seconds: 12));
    if (response.statusCode != 200) {
      throw ContentRepositoryException(
        '${source.name} 暂不可用（${response.statusCode}）',
      );
    }
    final payload = Map<String, dynamic>.from(
      jsonDecode(utf8.decode(response.bodyBytes)) as Map,
    );
    final queryData = Map<String, dynamic>.from(
      payload['query'] as Map? ?? const {},
    );
    final pages = queryData['pages'] as List<dynamic>? ?? const [];
    final entries = pages
        .map((raw) {
          final value = Map<String, dynamic>.from(raw as Map);
          final pageId = (value['pageid'] as num?)?.toInt() ?? 0;
          final thumbnail = value['thumbnail'] is Map
              ? Map<String, dynamic>.from(
                      value['thumbnail'] as Map,
                    )['source']?.toString() ??
                    ''
              : '';
          final chapterUri = Uri.parse(source.endpoint).replace(
            queryParameters: {
              'action': 'query',
              'prop': 'extracts',
              'explaintext': '1',
              'exlimit': '1',
              'pageids': '$pageId',
              'format': 'json',
              'formatversion': '2',
              'origin': '*',
            },
          );
          return (
            pageId: pageId,
            title: value['title']?.toString() ?? '未命名作品',
            summary: value['extract']?.toString().trim() ?? '中文维基文库公共领域作品。',
            thumbnail: thumbnail,
            url: chapterUri.toString(),
          );
        })
        .where((entry) => entry.pageId > 0)
        .toList();
    final grouped =
        <
          String,
          List<
            ({
              int pageId,
              String title,
              String summary,
              String thumbnail,
              String url,
            })
          >
        >{};
    for (final entry in entries) {
      final root = entry.title.split('/').first.trim();
      grouped.putIfAbsent(root, () => []).add(entry);
    }
    return grouped.entries
        .map((group) {
          final chapters = group.value
            ..sort((left, right) {
              int chapterNumber(String title) =>
                  int.tryParse(
                    RegExp(r'第(\d+)').firstMatch(title)?.group(1) ?? '',
                  ) ??
                  0;
              return chapterNumber(
                left.title,
              ).compareTo(chapterNumber(right.title));
            });
          return ContentItem(
            id: 'wikisource-${group.key.hashCode.abs()}',
            title: group.key,
            creator: '中文维基文库贡献者',
            category: '中文公共领域',
            summary: chapters.first.summary,
            coverAsset: chapters
                .map((entry) => entry.thumbnail)
                .firstWhere((value) => value.isNotEmpty, orElse: () => ''),
            popularity: '公共领域全文',
            progress: 0,
            episodeCount: chapters.length,
            sourceId: source.id,
            sourceName: source.name,
            isLive: true,
            status: NovelStatus.completed,
            sourceLabels: [source.name],
            chapterUrls: chapters
                .map((entry) => entry.url)
                .toList(growable: false),
            tags: const ['公共领域', '中文'],
          );
        })
        .toList(growable: false);
  }

  Future<List<ContentItem>> _loadOneCustomSource(
    ContentSource source, {
    String query = '',
  }) async {
    final endpoint = source.endpoint.trim();
    final body = endpoint.startsWith('{') || endpoint.startsWith('[')
        ? endpoint
        : utf8.decode(
            (await _client
                    .get(Uri.parse(endpoint))
                    .timeout(const Duration(seconds: 8)))
                .bodyBytes,
          );
    dynamic decoded;
    if (source.kind == SourceKind.js &&
        (source.rules?['discover'] ?? '').isNotEmpty) {
      final result = await JsRunner.runFunction(
        source.rules!['discover']!,
        'discover',
        [body, query],
      );
      decoded = jsonDecode(_sanitizeJsonString(result));
    } else {
      decoded = jsonDecode(_sanitizeJsonString(body));
    }
    final values = decoded is List<dynamic>
        ? decoded
        : decoded is Map<String, dynamic>
        ? (decoded['items'] ?? decoded['results'] ?? decoded['list'])
                  as List<dynamic>? ??
              const []
        : const <dynamic>[];
    return values
        .map((raw) {
          final value = Map<String, dynamic>.from(raw as Map);
          value['source_id'] ??= source.id;
          value['source_name'] ??= source.name;
          value['source_labels'] ??= [source.name];
          value['is_live'] ??= true;
          return ContentItem.fromJson(value);
        })
        .where((item) {
          final normalized = query.trim().toLowerCase();
          return normalized.isEmpty ||
              item.title.toLowerCase().contains(normalized) ||
              item.creator.toLowerCase().contains(normalized);
        })
        .toList(growable: false);
  }

  Future<List<ContentItem>> _loadOneLegacySource(
    ContentSource source, {
    required String query,
    required int page,
  }) async {
    if (query.trim().isEmpty) return const [];
    final values = source.builtIn
        ? await _getList('/sources/legacy/${source.id}/search', {
            'query': query.trim(),
            'page': '$page',
          }, const Duration(seconds: 12))
        : await _postList('/sources/runtime/search', {
            'source': _legacySourcePayload(source),
            'keyword': query.trim(),
            'page': page,
          });
    return values
        .map(
          (value) => ContentItem(
            id: value['id']?.toString() ?? '',
            title: value['title']?.toString() ?? '未命名小说',
            creator: value['author']?.toString() ?? '未知作者',
            category: value['kind']?.toString() ?? '网络小说',
            summary: value['introduction']?.toString() ?? '',
            coverAsset: value['cover']?.toString() ?? '',
            popularity: '来自 ${source.name}',
            progress: 0,
            episodeCount: (value['chapter_count'] as num?)?.toInt() ?? 0,
            sourceId: source.id,
            sourceName: source.name,
            isLive: true,
            latestChapter: value['latest_chapter']?.toString() ?? '',
            sourceLabels: [source.name],
            availability: _legacyAvailability(value),
            unavailableReason: _legacyUnavailableReason(value),
          ),
        )
        .where((item) => item.id.isNotEmpty)
        .toList(growable: false);
  }

  Future<List<ContentItem>> _loadAggregatedLegacySearch({
    required String query,
    required int page,
  }) async {
    final values = await _getList('/sources/legacy/search', {
      'query': query.trim(),
      'page': '$page',
      'limit': '60',
    }, const Duration(seconds: 22));
    return values
        .map((value) {
          final sourceId = value['source_id']?.toString() ?? '';
          final sourceName = value['source_name']?.toString() ?? '未知书源';
          return ContentItem(
            id: value['id']?.toString() ?? '',
            title: value['title']?.toString() ?? '未命名小说',
            creator: value['author']?.toString() ?? '未知作者',
            category: value['kind']?.toString() ?? '网络小说',
            summary: value['introduction']?.toString() ?? '',
            coverAsset: value['cover']?.toString() ?? '',
            popularity: '来自 $sourceName',
            progress: 0,
            episodeCount: (value['chapter_count'] as num?)?.toInt() ?? 0,
            sourceId: sourceId,
            sourceName: sourceName,
            isLive: true,
            latestChapter: value['latest_chapter']?.toString() ?? '',
            sourceLabels: [sourceName],
            availability: _legacyAvailability(value),
            unavailableReason: _legacyUnavailableReason(value),
          );
        })
        .where((item) => item.id.isNotEmpty && item.sourceId.isNotEmpty)
        .toList(growable: false);
  }

  bool _isLegacyItem(ContentItem item) =>
      (item.sourceId.startsWith('legacy-') ||
          item.sourceId.startsWith('legado-')) &&
      item.id.startsWith('${item.sourceId}:');

  ContentAvailability _legacyAvailability(Map<String, dynamic> value) {
    if (value['readable'] == true) return ContentAvailability.readable;
    final reason = _legacyUnavailableReason(value);
    return reason.contains('超时') || reason.contains('稍后')
        ? ContentAvailability.pending
        : ContentAvailability.unavailable;
  }

  String _legacyUnavailableReason(Map<String, dynamic> value) =>
      value['unavailable_reason']?.toString() ?? '当前来源暂无可用正文';

  String _legacyDetailUrl(ContentItem item) {
    final encoded = item.id.substring(item.sourceId.length + 1);
    return Uri.decodeComponent(encoded);
  }

  Future<List<Map<String, dynamic>>> _loadLegacyChapters(
    ContentItem item,
  ) async {
    final source = await _sourceStore.findById(item.sourceId);
    if (source == null) {
      throw const ContentRepositoryException('未找到小说对应的书源规则');
    }
    if (source.builtIn) {
      return _getList('/sources/legacy/${item.sourceId}/chapters', {
        'detail_url': _legacyDetailUrl(item),
      }, _chapterTimeout);
    }
    return _postList('/sources/runtime/chapters', {
      'source': _legacySourcePayload(source),
      'detailUrl': _legacyDetailUrl(item),
    });
  }

  Future<Map<String, dynamic>> _loadLegacyContent(
    ContentItem item,
    String chapterUrl,
    String title,
  ) async {
    final source = await _sourceStore.findById(item.sourceId);
    if (source == null) {
      throw const ContentRepositoryException('未找到小说对应的书源规则');
    }
    if (source.builtIn) {
      return _getChapterObject('/sources/legacy/${item.sourceId}/chapter', {
        'chapter_url': chapterUrl,
        'title': title,
      });
    }
    return _postObject('/sources/runtime/content', {
      'source': _legacySourcePayload(source),
      'chapterUrl': chapterUrl,
      'title': title,
    });
  }

  Map<String, dynamic> _legacySourcePayload(ContentSource source) {
    final raw = source.rules?['__source_json'];
    if (raw == null || raw.isEmpty) {
      throw const ContentRepositoryException('书源缺少可执行的 Legado 规则');
    }
    try {
      return Map<String, dynamic>.from(jsonDecode(raw) as Map);
    } catch (_) {
      throw const ContentRepositoryException('Legado 书源规则 JSON 已损坏');
    }
  }

  List<ContentItem> _mergeItems(List<ContentItem> items) {
    final merged = <String, ContentItem>{};
    for (final item in items) {
      final normalizedTitle = _normalizeTitle(item.title);
      final normalizedAuthor = _normalizeTitle(item.creator);
      final key = '$normalizedTitle::$normalizedAuthor';
      final previous = merged[key];
      if (previous == null) {
        merged[key] = item;
        continue;
      }
      final labels = {
        ...previous.sourceLabels,
        previous.sourceName,
        ...item.sourceLabels,
        item.sourceName,
      }.where((value) => value.isNotEmpty).toList(growable: false);
      merged[key] = previous.copyWith(sourceLabels: labels);
    }
    return merged.values.toList(growable: false);
  }

  List<ContentItem> _mergeSearchItems(List<ContentItem> items) {
    final bySource = <String, ContentItem>{};
    for (final item in items) {
      final key = [
        item.sourceId,
        _normalizeTitle(item.title),
        _normalizeTitle(item.creator),
      ].join('::');
      bySource.putIfAbsent(key, () => item);
    }
    return bySource.values.toList(growable: false);
  }

  Future<void> _writeHomeCache(String channel, List<ContentItem> items) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'catalog.home.cache.v2.$channel',
      jsonEncode({
        'updated_at': DateTime.now().toIso8601String(),
        'items': items.map((item) => item.toJson()).toList(),
      }),
    );
  }

  Future<List<ContentItem>> _readHomeCache(String channel) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('catalog.home.cache.v2.$channel');
    if (raw == null || raw.isEmpty) return const [];
    try {
      final value = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      final updatedAt = DateTime.tryParse(
        value['updated_at']?.toString() ?? '',
      );
      if (updatedAt == null ||
          DateTime.now().difference(updatedAt) > const Duration(days: 7)) {
        return const [];
      }
      return (value['items'] as List<dynamic>? ?? const [])
          .map(
            (item) =>
                ContentItem.fromJson(Map<String, dynamic>.from(item as Map)),
          )
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  Future<Chapter?> _loadCustomChapter(ContentItem item, int index) async {
    try {
      final response = await _client
          .get(Uri.parse(item.chapterUrls![index]))
          .timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) return null;
      if (response.bodyBytes.length > _maxChapterResponseBytes) {
        throw const ContentRepositoryException('直连书源返回的是整本超大文本，请改用后端分章书源');
      }
      var text = utf8.decode(response.bodyBytes);
      final trimmed = text.trimLeft();
      if (trimmed.startsWith('{')) {
        try {
          final value = Map<String, dynamic>.from(jsonDecode(text) as Map);
          if (value['query'] is Map) {
            final query = Map<String, dynamic>.from(value['query'] as Map);
            final pages = query['pages'] as List<dynamic>? ?? const [];
            if (pages.isNotEmpty) {
              text =
                  Map<String, dynamic>.from(
                    pages.first as Map,
                  )['extract']?.toString() ??
                  '';
            }
          } else {
            text =
                value['content']?.toString() ??
                value['text']?.toString() ??
                text;
          }
        } catch (_) {}
      } else if (RegExp(
        r'<(?:html|body|p|div)\b',
        caseSensitive: false,
      ).hasMatch(trimmed)) {
        text = text
            .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
            .replaceAll(RegExp(r'</p>|</div>', caseSensitive: false), '\n\n')
            .replaceAll(RegExp(r'<[^>]+>'), ' ')
            .replaceAll('&nbsp;', ' ')
            .replaceAll('&amp;', '&');
      }
      return _validateChapter(
        Chapter(
          index: index,
          title: '第 ${index + 1} 章',
          totalCount: item.episodeCount,
          paragraphs: text
              .split('\n')
              .map((line) => line.trim())
              .where((line) => line.isNotEmpty)
              .toList(growable: false),
        ),
      );
    } on ContentRepositoryException {
      rethrow;
    } catch (_) {
      return null;
    }
  }

  List<ContentItem> _parseItems(dynamic raw) =>
      (raw as List<dynamic>? ?? const [])
          .map(
            (value) =>
                ContentItem.fromJson(Map<String, dynamic>.from(value as Map)),
          )
          .toList(growable: false);

  String _normalizeTitle(String value) =>
      value.toLowerCase().replaceAll(RegExp(r'[\s·：:（）()【】\[\]_-]+'), '');

  String _sanitizeJsonString(String raw) {
    var trimmed = raw.trim();
    if (trimmed.startsWith('```json')) {
      trimmed = trimmed.substring(7);
    } else if (trimmed.startsWith('```')) {
      trimmed = trimmed.substring(3);
    }
    if (trimmed.endsWith('```')) {
      trimmed = trimmed.substring(0, trimmed.length - 3);
    }
    return trimmed.trim();
  }
}
