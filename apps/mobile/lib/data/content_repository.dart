import 'dart:convert';

import 'package:http/http.dart' as http;

import '../domain/content.dart';
import '../domain/content_source.dart';
import 'source_store.dart';

class ContentRepositoryException implements Exception {
  const ContentRepositoryException(this.message);
  final String message;

  @override
  String toString() => message;
}

class ContentRepository {
  ContentRepository({http.Client? client, SourceStore? sourceStore})
    : _client = client ?? http.Client(),
      _sourceStore = sourceStore ?? SourceStore();

  final http.Client _client;
  final SourceStore _sourceStore;

  Future<List<ContentItem>> discover(
    ContentChannel channel, {
    String query = '',
    String category = '',
  }) async {
    try {
      return await _discoverDirect(channel, query: query, category: category);
    } on ContentRepositoryException {
      rethrow;
    } catch (_) {
      throw const ContentRepositoryException('内容源加载失败，请检查网络或来源配置');
    }
  }

  Future<List<ContentItem>> _discoverDirect(
    ContentChannel channel, {
    String query = '',
    String category = '',
  }) async {
    final isSearch = query.trim().isNotEmpty;
    final sources = await _sourceStore.list();
    final enabledSources = sources
        .where((source) => source.enabled && source.channels.contains(channel))
        .toList(growable: false);
    final curatedList = <ContentItem>[];
    final customItems = await _loadCustomSources(
      enabledSources.where((source) => source.kind == SourceKind.json),
      channel,
    );

    if (channel == ContentChannel.novel) {
      if (!enabledSources.any((source) => source.kind == SourceKind.gutendex)) {
        return _filterItems([...curatedList, ...customItems], query, category);
      }
      final searchPart = isSearch
          ? '&search=${Uri.encodeComponent(query.trim())}'
          : '';
      final url =
          'https://gutendex.com/books/?mime_type=text%2Fplain$searchPart';

      final response = await _client
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) {
        throw ContentRepositoryException(
          'Gutendex returned ${response.statusCode}',
        );
      }
      final data =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      final results = data['results'] as List<dynamic>? ?? const [];
      final apiItems = results.map((item) {
        final book = Map<String, dynamic>.from(item as Map);
        final authors = book['authors'] as List<dynamic>? ?? const [];
        final author = authors.isNotEmpty
            ? authors[0]['name'] as String
            : 'Unknown';
        final formats = book['formats'] as Map<String, dynamic>? ?? const {};
        final cover = formats['image/jpeg'] as String? ?? '';
        final bookshelves = book['bookshelves'] as List<dynamic>? ?? const [];
        final genre = bookshelves.isNotEmpty
            ? bookshelves[0] as String
            : 'Classic';
        final downloads = book['download_count'] as int? ?? 0;

        return ContentItem(
          id: 'gutenberg-${book['id']}',
          title: book['title'] as String? ?? 'Untitled',
          creator: author,
          coverAsset: cover,
          category: genre,
          popularity: '$downloads次下载',
          summary: book['subjects'] != null
              ? (book['subjects'] as List).join(', ')
              : 'No description.',
          channel: ContentChannel.novel,
          progress: 0.0,
          episodeCount: 15,
          isLive: true,
          sourceName: 'Project Gutenberg',
        );
      }).toList();

      return _filterItems(
        [...curatedList, ...apiItems, ...customItems],
        query,
        category,
      );
    } else if (channel == ContentChannel.shortDrama) {
      if (!enabledSources.any((source) => source.kind == SourceKind.tvmaze)) {
        return _filterItems([...curatedList, ...customItems], query, category);
      }
      final url = isSearch
          ? 'https://api.tvmaze.com/search/shows?q=${Uri.encodeComponent(query.trim())}'
          : 'https://api.tvmaze.com/shows';

      final response = await _client
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) {
        throw ContentRepositoryException(
          'TVmaze returned ${response.statusCode}',
        );
      }
      final rawData = jsonDecode(utf8.decode(response.bodyBytes));
      final List<dynamic> results = isSearch
          ? (rawData as List<dynamic>).map((x) => x['show']).toList()
          : (rawData as List<dynamic>);

      final apiItems = results.map((item) {
        final show = Map<String, dynamic>.from(item as Map);
        final image = show['image'] as Map<String, dynamic>? ?? const {};
        final cover = image['medium'] as String? ?? '';
        final network = show['network'] as Map<String, dynamic>?;
        final webChannel = show['webChannel'] as Map<String, dynamic>?;
        final creator = network != null
            ? network['name'] as String
            : (webChannel != null ? webChannel['name'] as String : 'TVmaze');
        final genres = show['genres'] as List<dynamic>? ?? const [];
        final genre = genres.isNotEmpty ? genres[0] as String : 'Drama';
        final rating = show['rating'] as Map<String, dynamic>?;
        final score = rating != null && rating['average'] != null
            ? '评分 ${rating['average']}'
            : '推荐';
        final summary = show['summary'] as String? ?? 'No description.';

        return ContentItem(
          id: 'tvmaze-${show['id']}',
          title: show['name'] as String? ?? 'Untitled Drama',
          creator: creator,
          coverAsset: cover,
          category: genre,
          popularity: score,
          summary: summary.replaceAll(RegExp(r'<[^>]*>'), ''),
          channel: ContentChannel.shortDrama,
          progress: 0.0,
          episodeCount: 20,
          isLive: true,
          sourceName: 'TVmaze 官方源',
        );
      }).toList();

      return _filterItems(
        [...curatedList, ...apiItems, ...customItems],
        query,
        category,
      );
    } else {
      if (!enabledSources.any((source) => source.kind == SourceKind.itunes)) {
        return _filterItems([...curatedList, ...customItems], query, category);
      }
      final searchTerm = isSearch ? query.trim() : 'popular';
      final url =
          'https://itunes.apple.com/search?media=movie&limit=20&term=${Uri.encodeComponent(searchTerm)}';

      final response = await _client
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) {
        throw ContentRepositoryException(
          'iTunes API returned ${response.statusCode}',
        );
      }
      final data =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      final results = data['results'] as List<dynamic>? ?? const [];
      final apiItems = results.map((item) {
        final movie = Map<String, dynamic>.from(item as Map);
        final trackId = movie['trackId'] as int? ?? 0;
        final cover = (movie['artworkUrl100'] as String? ?? '').replaceAll(
          '100x100bb',
          '400x400bb',
        );
        final director = movie['artistName'] as String? ?? 'Unknown';
        final genre = movie['primaryGenreName'] as String? ?? 'Movie';
        final price = movie['trackPrice'] != null
            ? '售价 \$${movie['trackPrice']}'
            : '推荐';
        final desc =
            movie['longDescription'] as String? ??
            movie['shortDescription'] as String? ??
            'No description.';

        return ContentItem(
          id: 'itunes-$trackId',
          title: movie['trackName'] as String? ?? 'Untitled Movie',
          creator: director,
          coverAsset: cover,
          category: genre,
          popularity: price,
          summary: desc,
          channel: ContentChannel.video,
          progress: 0.0,
          episodeCount: 1,
          isLive: true,
          sourceName: 'iTunes 影视源',
        );
      }).toList();

      return _filterItems(
        [...curatedList, ...apiItems, ...customItems],
        query,
        category,
      );
    }
  }

  Future<List<ContentItem>> _loadCustomSources(
    Iterable<ContentSource> sources,
    ContentChannel channel,
  ) async {
    final results = await Future.wait(
      sources.map((source) async {
        try {
          final endpoint = source.endpoint.trim();
          dynamic decoded;
          if (endpoint.startsWith('{') || endpoint.startsWith('[')) {
            decoded = jsonDecode(endpoint);
          } else {
            final response = await _client
                .get(Uri.parse(endpoint))
                .timeout(const Duration(seconds: 8));
            if (response.statusCode != 200) return <ContentItem>[];
            decoded = jsonDecode(utf8.decode(response.bodyBytes));
          }
          final values = decoded is List<dynamic>
              ? decoded
              : decoded is Map<String, dynamic>
              ? (decoded['items'] ?? decoded['results']) as List<dynamic>? ??
                    const []
              : const <dynamic>[];
          return values
              .map((value) {
                final json = Map<String, dynamic>.from(value as Map);
                json['channel'] ??= channel.name;
                json['source_id'] ??= source.id;
                json['source_name'] ??= source.name;
                json['is_live'] ??= true;
                return ContentItem.fromJson(json);
              })
              .toList(growable: false);
        } catch (_) {
          return <ContentItem>[];
        }
      }),
    );
    return results.expand((items) => items).toList(growable: false);
  }

  List<ContentItem> _filterItems(
    List<ContentItem> items,
    String query,
    String category,
  ) {
    final normalizedQuery = query.trim().toLowerCase();
    return items
        .where((item) {
          final matchesQuery =
              normalizedQuery.isEmpty ||
              item.title.toLowerCase().contains(normalizedQuery) ||
              item.creator.toLowerCase().contains(normalizedQuery);
          final matchesCategory =
              category.isEmpty ||
              category == '全部' ||
              item.category.contains(category);
          return matchesQuery && matchesCategory;
        })
        .toList(growable: false);
  }

  Future<Chapter> chapter(ContentItem item, int index) async {
    return _chapterDirect(item, index);
  }

  Future<Chapter> _chapterDirect(ContentItem item, int index) async {
    // 1. Check if the item contains inline local chapters
    if (item.localChapters != null && index < item.localChapters!.length) {
      final chap = item.localChapters![index];
      final title = chap['title'] as String? ?? '第 ${index + 1} 章';
      final paragraphs = (chap['paragraphs'] as List<dynamic>?)?.map((e) => e as String).toList() ?? const [];
      return Chapter(title: title, paragraphs: paragraphs);
    }

    // 2. Check if the item contains remote chapter URLs
    if (item.chapterUrls != null && index < item.chapterUrls!.length) {
      final url = item.chapterUrls![index];
      try {
        final response = await _client.get(Uri.parse(url)).timeout(const Duration(seconds: 15));
        if (response.statusCode == 200) {
          final text = utf8.decode(response.bodyBytes);
          final paragraphs = text.split('\n').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
          return Chapter(
            title: '第 ${index + 1} 章  ${item.title}',
            paragraphs: paragraphs.isEmpty ? ['[本章内容为空]'] : paragraphs,
          );
        }
      } catch (_) {}
    }

    // 3. Keep standard Gutenberg fetching
    if (item.id.startsWith('gutenberg-')) {
      final realId = item.id.substring('gutenberg-'.length);
      try {
        final response = await _client
            .get(
              Uri.parse(
                'https://www.gutenberg.org/cache/epub/$realId/pg$realId.txt',
              ),
            )
            .timeout(const Duration(seconds: 15));
        if (response.statusCode == 200) {
          return _parseGutenbergText(response.body, index, item.title);
        }
      } catch (_) {}
      try {
        final response = await _client
            .get(
              Uri.parse(
                'https://www.gutenberg.org/files/$realId/$realId-0.txt',
              ),
            )
            .timeout(const Duration(seconds: 15));
        if (response.statusCode == 200) {
          return _parseGutenbergText(response.body, index, item.title);
        }
      } catch (_) {}
    }

    final String displayTitle = item.title;
    return Chapter(
      title: '第 ${index + 1} 章  $displayTitle',
      paragraphs: [
        '【${item.sourceName}】内容由 App 在设备端直接读取。',
        '当前条目未提供可解析的正文内容。',
        '如果您是此自定义数据源的所有者，请在 JSON 配置中为该条目添加 "chapters"（本地章节列表）或 "chapter_urls"（远程章节正文 URL 列表）属性。',
      ],
    );
  }

  Chapter _parseGutenbergText(String text, int index, String bookTitle) {
    final RegExp chapterRegExp = RegExp(
      r'^\s*(chapter|section|act|letter|prologue|epilogue)\s+[ivxldcm0-9]+',
      caseSensitive: false,
      multiLine: true,
    );
    final parts = text.split(chapterRegExp);

    if (parts.length > 1) {
      final matches = chapterRegExp.allMatches(text).toList();
      String title = '第 ${index + 1} 章';
      if (index < matches.length) {
        title = matches[index].group(0)?.trim() ?? title;
      }

      final bodyIndex = (index + 1) % parts.length;
      final body = parts[bodyIndex];
      final paragraphs = body
          .split('\n')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty && !s.startsWith('***'))
          .toList();

      return Chapter(
        title: title,
        paragraphs: paragraphs.isEmpty ? ['[本章正文加载失败，请刷新重试]'] : paragraphs,
      );
    } else {
      final paragraphs = text
          .split('\n')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
      final chunkSize = 60;
      final start = (index * chunkSize).clamp(0, paragraphs.length);
      final end = ((index + 1) * chunkSize).clamp(0, paragraphs.length);
      final subList = paragraphs.sublist(start, end);
      return Chapter(
        title: '第 ${index + 1} 章节',
        paragraphs: subList.isEmpty ? ['[本章内容已加载完毕]'] : subList,
      );
    }
  }
}
