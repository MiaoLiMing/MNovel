import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/api_config.dart';
import '../core/js_runner.dart';
import '../domain/content.dart';
import '../domain/content_source.dart';
import 'curated_catalog.dart';
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
  });

  final ContentItem featured;
  final List<ContentItem> carousel;
  final List<ContentItem> editorsPick;
  final List<ContentItem> latest;
  final bool fromNetwork;
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

class ContentRepository {
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

  Future<HomeData> home({String channel = '推荐'}) async {
    try {
      final data = await _getObject('/home', {'channel': channel});
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

      return HomeData(
        featured: ContentItem.fromJson(
          Map<String, dynamic>.from(data['featured'] as Map),
        ),
        carousel: _parseItems(data['carousel']),
        editorsPick: sectionItems('editors-pick'),
        latest: sectionItems('latest'),
        fromNetwork: true,
      );
    } catch (_) {
      final items = _channelFallback(channel);
      return HomeData(
        featured: items.length > 1 ? items[1] : items.first,
        carousel: items.take(4).toList(growable: false),
        editorsPick: items.skip(2).take(4).toList(growable: false),
        latest: items.reversed.take(5).toList(growable: false),
      );
    }
  }

  Future<List<ContentItem>> discover(
    ContentChannel channel, {
    String query = '',
    String category = '',
    String status = '',
    String wordCount = '',
    String source = '',
  }) async {
    final queryParameters = <String, String>{
      'channel': channel.name,
      if (query.trim().isNotEmpty) 'query': query.trim(),
      if (category.isNotEmpty && category != '全部') 'category': category,
      if (status.isNotEmpty && status != 'all') 'status': status,
      if (wordCount.isNotEmpty && wordCount != 'all') 'word_count': wordCount,
      if (source.isNotEmpty && source != '全部') 'source': source,
    };
    List<ContentItem> items;
    try {
      final data = await _getList('/discover', queryParameters);
      items = data
          .map((value) => ContentItem.fromJson(value))
          .toList(growable: false);
    } catch (_) {
      items = _filterCurated(
        query: query,
        category: category,
        status: status,
        wordCount: wordCount,
        source: source,
      );
    }

    final custom = await _loadCustomSources(query: query);
    final byId = <String, ContentItem>{};
    for (final item in [...items, ...custom]) {
      byId['${item.sourceId}:${item.id}'] = item;
    }
    return byId.values.toList(growable: false);
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
      return curatedCatalog.firstWhere(
        (candidate) => candidate.id == item.id,
        orElse: () => item,
      );
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
      });
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

  Future<Chapter> chapter(ContentItem item, int index) async {
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
      final data = await _getObject('/content/${item.id}/chapters/$index', {
        'source_id': item.sourceId,
      });
      return Chapter.fromJson(data);
    } catch (_) {
      return Chapter(
        index: index,
        title:
            '第 ${index + 1} 章 '
            '${chapterTitleCycle[index % chapterTitleCycle.length]}',
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
  ]) async {
    final response = await _client
        .get(_uri(path, query))
        .timeout(const Duration(seconds: 8));
    if (response.statusCode != 200) {
      throw ContentRepositoryException('服务暂不可用（${response.statusCode}）');
    }
    return (jsonDecode(utf8.decode(response.bodyBytes)) as List<dynamic>)
        .map((value) => Map<String, dynamic>.from(value as Map))
        .toList(growable: false);
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
          .toList(growable: false);
    }
    if (channel == '出版') {
      return curatedCatalog
          .where((item) => item.status == NovelStatus.completed)
          .toList(growable: false);
    }
    return curatedCatalog;
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
        .toList(growable: false);
  }

  Future<List<ContentItem>> _loadCustomSources({String query = ''}) async {
    final sources = await _sourceStore.list();
    final enabled = sources.where(
      (source) =>
          source.enabled &&
          (source.kind == SourceKind.json || source.kind == SourceKind.js),
    );
    final results = await Future.wait(
      enabled.map((source) async {
        try {
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
              [body],
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
        } catch (_) {
          return <ContentItem>[];
        }
      }),
    );
    return results.expand((items) => items).toList(growable: false);
  }

  Future<Chapter?> _loadCustomChapter(ContentItem item, int index) async {
    try {
      final response = await _client
          .get(Uri.parse(item.chapterUrls![index]))
          .timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) return null;
      final text = utf8.decode(response.bodyBytes);
      return Chapter(
        index: index,
        title: '第 ${index + 1} 章',
        paragraphs: text
            .split('\n')
            .map((line) => line.trim())
            .where((line) => line.isNotEmpty)
            .toList(growable: false),
      );
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
      FilterOption(value: '起点中文网', label: '起点中文网'),
      FilterOption(value: '纵横中文网', label: '纵横中文网'),
      FilterOption(value: '番茄小说', label: '番茄小说'),
      FilterOption(value: '七猫小说', label: '七猫小说'),
      FilterOption(value: '飞卢小说', label: '飞卢小说'),
      FilterOption(value: '刺猬猫', label: '刺猬猫'),
      FilterOption(value: '自定义书源', label: '自定义'),
    ],
  ),
];
