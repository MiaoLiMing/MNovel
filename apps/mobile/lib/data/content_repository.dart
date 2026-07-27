import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../core/api_config.dart';
import '../core/js_runner.dart';
import '../domain/content.dart';
import '../domain/content_source.dart';
import 'curated_catalog.dart';
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

  final ContentItem featured;
  final List<ContentItem> carousel;
  final List<ContentItem> editorsPick;
  final List<ContentItem> latest;
  final bool fromNetwork;
  final bool fromCache;
  final int sourceCount;
  final int failedSourceCount;
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
      _composeHome(_channelFallback(channel));

  Future<HomeData> home({String channel = '推荐'}) async {
    final collected = <ContentItem>[];
    var reachedNetwork = false;
    var reachedBackend = false;
    final refreshPage =
        ((DateTime.now().millisecondsSinceEpoch ~/ 86400000) +
                _homeRefreshSeed++)
            .remainder(30) +
        1;
    try {
      final data = await _getObject('/home', {
        'channel': channel,
        'page': '$refreshPage',
      });
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

    var sourceItems = await _loadEnabledSourceCatalog(
      page: refreshPage,
      includePublicFallback: !reachedBackend,
    );
    var fromCache = false;
    if (sourceItems.isNotEmpty) {
      reachedNetwork = true;
    } else {
      sourceItems = await _readHomeCache(channel);
      fromCache = sourceItems.isNotEmpty;
      reachedNetwork = collected.any((item) => item.isLive);
    }
    final merged = _mergeItems([...sourceItems, ...collected]);
    final items = merged.isEmpty ? _channelFallback(channel) : merged;
    if (reachedNetwork && merged.isNotEmpty) {
      await _writeHomeCache(channel, merged);
    }
    return _composeHome(
      items,
      fromNetwork: reachedNetwork,
      fromCache: fromCache,
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
      'channel': channel.name,
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
      items = _filterCurated(
        query: query,
        category: category,
        status: status,
        wordCount: wordCount,
        source: source,
      );
    }

    final sourceItems = await _loadEnabledSourceCatalog(
      query: query,
      page: page,
      includePublicFallback: !reachedBackend,
    );
    return _mergeItems([...sourceItems, ...items]);
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
      final hot = [...curatedCatalog]
        ..sort((left, right) => right.score.compareTo(left.score));
      return SearchMeta(
        hot: hot,
        suggestions: hot.take(6).map((item) => item.title).toList(),
      );
    }
  }

  Future<SourceProbeResult> probeSource(ContentSource source) async {
    if (!source.builtIn) {
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
      final data = await _getObject('/sources/${source.id}/health');
      stopwatch.stop();
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
        message: _networkErrorMessage(error),
      );
    }
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
      return _fallbackTaxonomy;
    }
  }

  Future<ContentItem> detail(ContentItem item) async {
    try {
      final data = await _getObject('/content/${item.id}');
      return ContentItem.fromJson(data).copyWith(progress: item.progress);
    } catch (_) {
      return _asTrial(
        curatedCatalog.firstWhere(
          (candidate) => candidate.id == item.id,
          orElse: () => item,
        ),
      );
    }
  }

  /// 将本地状态异步同步到后端；失败时保留本地状态，避免弱网阻塞阅读。
  Future<void> syncFavorite(ContentItem item, bool active) async {
    try {
      final response = await _client
          .put(
            _uri('/favorites/${Uri.encodeComponent(item.id)}'),
            headers: const {'content-type': 'application/json'},
            body: jsonEncode({'channel': item.channel.name, 'active': active}),
          )
          .timeout(const Duration(seconds: 8));
      if (response.statusCode != 204) return;
    } catch (_) {
      // 本地书架是主状态，后端同步在下一次操作时重试。
    }
  }

  Future<void> syncProgress(
    ContentItem item, {
    required int unitIndex,
    required double position,
  }) async {
    try {
      await _client
          .put(
            _uri('/progress/${Uri.encodeComponent(item.id)}'),
            headers: const {'content-type': 'application/json'},
            body: jsonEncode({
              'channel': item.channel.name,
              'unit_index': unitIndex,
              'position': position.clamp(0, 1),
            }),
          )
          .timeout(const Duration(seconds: 8));
    } catch (_) {
      // 本地阅读进度不依赖网络。
    }
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
    try {
      final data = await _getList('/content/${item.id}/units', {
        'offset': '$offset',
        'limit': '$limit',
      }, _chapterTimeout);
      return data
          .map((value) => ChapterEntry.fromJson(value))
          .toList(growable: false);
    } catch (_) {
      final count = (item.episodeCount - offset).clamp(0, limit);
      return List.generate(count, (index) {
        final actualIndex = offset + index;
        return ChapterEntry(
          index: actualIndex,
          title:
              '第 ${actualIndex + 1} 章 '
              '${chapterTitleCycle[actualIndex % chapterTitleCycle.length]}',
        );
      });
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

    if (item.chapterUrls != null && index < item.chapterUrls!.length) {
      final chapter = await _loadCustomChapter(item, index);
      if (chapter != null) return chapter;
    }

    try {
      final data = await _getChapterObject(
        '/content/${item.id}/chapters/$index',
        {'source_id': item.sourceId},
      );
      return _validateChapter(Chapter.fromJson(data));
    } catch (error) {
      if (item.isLive || index > 0) {
        throw ContentRepositoryException(_networkErrorMessage(error));
      }
      return Chapter(
        index: index,
        title: '内置试读 · ${chapterTitleCycle[index % chapterTitleCycle.length]}',
        paragraphs: const [
          '“愚者”，梅林沉默地注视着这个年轻人。良久，他轻声说道：',
          '“或许你还没有意识到，成为非凡者的你，已经不再是普通的你了。”',
          '晨雾沿着山脊缓慢散开，石阶尽头传来一声清越的钟鸣。',
          '这个世界上有很多秘密，有些被牢牢藏在泥土和灰尘之下。',
          '如果你真的决定踏上这条道路，就必须无惧深渊的凝视，接受这一切。',
          '他顿了顿，目光深邃。',
          '“记住，力量越大，责任越大，代价也越大。”',
        ],
      );
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
      throw ContentRepositoryException('服务暂不可用（${response.statusCode}）');
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
      throw ContentRepositoryException('服务暂不可用（${response.statusCode}）');
    }
    return (jsonDecode(utf8.decode(response.bodyBytes)) as List<dynamic>)
        .map((value) => Map<String, dynamic>.from(value as Map))
        .toList(growable: false);
  }

  Future<Map<String, dynamic>> _getChapterObject(
    String path,
    Map<String, String> query,
  ) async {
    final response = await _client
        .get(_uri(path, query))
        .timeout(_chapterTimeout);
    if (response.statusCode != 200) {
      throw ContentRepositoryException('服务暂不可用（${response.statusCode}）');
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

  List<ContentItem> _channelFallback(String channel) {
    if (channel == '女生') {
      return curatedCatalog
          .where(
            (item) => item.id == 'novel-judge' || item.id == 'novel-fate-ring',
          )
          .map(_asTrial)
          .toList(growable: false);
    }
    if (channel == '出版') {
      return curatedCatalog
          .where((item) => item.status == NovelStatus.completed)
          .map(_asTrial)
          .toList(growable: false);
    }
    return curatedCatalog.map(_asTrial).toList(growable: false);
  }

  List<ContentItem> _filterCurated({
    String query = '',
    String category = '',
    String status = '',
    String wordCount = '',
    String source = '',
  }) {
    final normalized = query.trim().toLowerCase();
    return curatedCatalog
        .where((item) {
          final matchesQuery =
              normalized.isEmpty ||
              item.title.toLowerCase().contains(normalized) ||
              item.creator.toLowerCase().contains(normalized) ||
              item.tags.any((tag) => tag.toLowerCase().contains(normalized));
          final matchesCategory =
              category.isEmpty ||
              category == '全部' ||
              item.category.contains(category) ||
              item.tags.contains(category);
          final matchesStatus =
              status.isEmpty ||
              status == 'all' ||
              (status == 'completed' && item.status == NovelStatus.completed) ||
              (status == 'serializing' &&
                  item.status == NovelStatus.serializing);
          final matchesSource =
              source.isEmpty ||
              source == '全部' ||
              item.sourceLabels.contains(source);
          return matchesQuery &&
              matchesCategory &&
              matchesStatus &&
              matchesSource &&
              _matchesWordCount(item.wordCount, wordCount);
        })
        .map(_asTrial)
        .toList(growable: false);
  }

  ContentItem _asTrial(ContentItem item) => item.copyWith(
    episodeCount: 1,
    latestChapter: '内置试读',
    updateFrequency: '仅提供首章试读',
  );

  Future<List<ContentItem>> _loadEnabledSourceCatalog({
    String query = '',
    int page = 1,
    bool includePublicFallback = false,
  }) async {
    final sources = await _sourceStore.list();
    final enabled = sources.where((source) => source.enabled).toList()
      ..sort((left, right) => right.priority.compareTo(left.priority));
    final supported = enabled
        .where(
          (source) =>
              (includePublicFallback &&
                  (source.kind == SourceKind.gutendex ||
                      source.kind == SourceKind.wikisource ||
                      source.kind == SourceKind.internetArchive)) ||
              source.kind == SourceKind.json ||
              source.kind == SourceKind.js,
        )
        .toList(growable: false);
    _lastSourceCount = supported.length;
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

  bool _matchesWordCount(int value, String bucket) {
    if (bucket.isEmpty || bucket == 'all') return true;
    return switch (bucket) {
      'under-300k' => value < 300000,
      '300k-1m' => value >= 300000 && value < 1000000,
      '1m-3m' => value >= 1000000 && value < 3000000,
      '3m-5m' => value >= 3000000 && value < 5000000,
      'over-5m' => value >= 5000000,
      _ => true,
    };
  }
}

const _fallbackTaxonomy = <FilterGroup>[
  FilterGroup(
    id: 'category',
    label: '题材',
    options: [
      FilterOption(value: '全部', label: '全部'),
      FilterOption(value: '玄幻', label: '玄幻'),
      FilterOption(value: '奇幻', label: '奇幻'),
      FilterOption(value: '武侠', label: '武侠'),
      FilterOption(value: '仙侠', label: '仙侠'),
      FilterOption(value: '都市', label: '都市'),
      FilterOption(value: '历史', label: '历史'),
      FilterOption(value: '军事', label: '军事'),
      FilterOption(value: '科幻', label: '科幻'),
      FilterOption(value: '游戏', label: '游戏'),
      FilterOption(value: '悬疑', label: '悬疑'),
      FilterOption(value: '其他', label: '其他'),
    ],
  ),
  FilterGroup(
    id: 'status',
    label: '状态',
    options: [
      FilterOption(value: 'all', label: '全部'),
      FilterOption(value: 'serializing', label: '连载中'),
      FilterOption(value: 'completed', label: '已完结'),
    ],
  ),
  FilterGroup(
    id: 'word_count',
    label: '字数',
    options: [
      FilterOption(value: 'all', label: '全部'),
      FilterOption(value: 'under-300k', label: '30万以下'),
      FilterOption(value: '300k-1m', label: '30-100万'),
      FilterOption(value: '1m-3m', label: '100-300万'),
      FilterOption(value: '3m-5m', label: '300-500万'),
      FilterOption(value: 'over-5m', label: '500万以上'),
    ],
  ),
  FilterGroup(
    id: 'source',
    label: '来源',
    options: [
      FilterOption(value: '全部', label: '全部'),
      FilterOption(value: 'Project Gutenberg', label: 'Gutenberg'),
      FilterOption(value: '中文维基文库', label: '中文维基文库'),
      FilterOption(value: 'Internet Archive 中文馆藏', label: '中文公开馆藏'),
      FilterOption(value: '内置试读', label: '内置试读'),
      FilterOption(value: '自定义书源', label: '自定义'),
    ],
  ),
];
