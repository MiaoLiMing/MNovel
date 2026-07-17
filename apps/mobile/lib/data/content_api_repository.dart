import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../domain/content.dart';

class ContentApiException implements Exception {
  const ContentApiException(this.message);
  final String message;

  @override
  String toString() => message;
}

class ContentApiRepository {
  // Flag to completely bypass FastAPI backend server and run in 100% direct local-only client-side mode
  static const bool forceLocalDirect = true;

  ContentApiRepository({http.Client? client, String? baseUrl})
      : _client = client ?? http.Client(),
        baseUrl = baseUrl ?? _defaultBaseUrl;

  final http.Client _client;
  final String baseUrl;

  static String get _defaultBaseUrl {
    const configured = String.fromEnvironment('API_BASE_URL');
    if (configured.isNotEmpty) return configured;
    if (kIsWeb || defaultTargetPlatform == TargetPlatform.iOS) {
      return 'http://127.0.0.1:8000/api/v1';
    }
    return 'http://10.0.2.2:8000/api/v1';
  }

  // Curated Chinese test data for when the backend is offline (Mapped to pre-packaged assets)
  List<ContentItem> _curatedChineseItems(ContentChannel channel) {
    if (channel == ContentChannel.novel) {
      return [
        const ContentItem(
          id: 'curated-novel-1',
          title: '万古剑神',
          creator: '剑道 · 玄幻',
          coverAsset: 'asset://cover-changfeng-wenjian.png',
          category: '玄幻',
          popularity: '128万在读',
          summary: '天下万界，唯我剑尊！少年自微末崛起，以手中三尺青锋斩尽神魔，踏上一条横扫诸天的热血仙途。',
          channel: ContentChannel.novel,
          progress: 0.0,
          episodeCount: 120,
          isLive: true,
          sourceName: '本地书源',
        ),
        const ContentItem(
          id: 'curated-novel-2',
          title: '末世之最强系统',
          creator: '末世 · 科幻',
          coverAsset: 'asset://cover-xinghai-yujin.png',
          category: '科幻',
          popularity: '96万在读',
          summary: '丧尸横行，异兽复苏，人类文明处于毁灭边缘。少年获得宇宙神级系统系统，不断升级进化，在绝境中开创人类新纪元。',
          channel: ContentChannel.novel,
          progress: 0.0,
          episodeCount: 88,
          isLive: true,
          sourceName: '本地书源',
        ),
        const ContentItem(
          id: 'curated-novel-3',
          title: '嫡女重生：凤倾天下',
          creator: '重生 · 古言',
          coverAsset: 'asset://cover-fenggui-changan.png',
          category: '古言',
          popularity: '78万在读',
          summary: '前世错付深情，被害惨死。重活一世，她誓要让所有伤害她的人百倍偿还，步步为营，执掌风云，登顶天下。',
          channel: ContentChannel.novel,
          progress: 0.0,
          episodeCount: 150,
          isLive: true,
          sourceName: '本地书源',
        ),
        const ContentItem(
          id: 'curated-novel-4',
          title: '绝世武神',
          creator: '净无痕 · 玄幻',
          coverAsset: 'asset://cover-changfeng-wenjian.png',
          category: '武侠玄幻',
          popularity: '156.8万在读',
          summary: '九霄大陆，宗门林立，强者如云。林枫携武魂穿越而来，修无上武道，斩各路天骄，终成绝世武神。',
          channel: ContentChannel.novel,
          progress: 0.0,
          episodeCount: 220,
          isLive: true,
          sourceName: '本地书源',
        ),
        const ContentItem(
          id: 'curated-novel-5',
          title: '凡人修仙传',
          creator: '忘语 · 仙侠',
          coverAsset: 'asset://cover-xinghai-yujin.png',
          category: '仙侠修真',
          popularity: '128.6万在读',
          summary: '凡人资质，却有一颗不甘平凡的心。韩立偶然间得到神秘小绿瓶，克敌制胜，低调修炼，终登仙界。',
          channel: ContentChannel.novel,
          progress: 0.0,
          episodeCount: 300,
          isLive: true,
          sourceName: '本地书源',
        ),
      ];
    } else if (channel == ContentChannel.shortDrama) {
      return [
        const ContentItem(
          id: 'curated-drama-1',
          title: '全班修仙归来：你们无双我大乘',
          creator: '爽文 · 都市',
          coverAsset: 'asset://poster-wucheng-huixiang.png',
          category: '都市修仙',
          popularity: '5967万热度',
          summary: '本以为大家只是普通同学，没想到毕业十年聚会，全班戏谑修仙大佬，而主角早已大乘期大圆满！',
          channel: ContentChannel.shortDrama,
          progress: 0.0,
          episodeCount: 80,
          isLive: true,
          sourceName: '短剧外链源',
        ),
        const ContentItem(
          id: 'curated-drama-2',
          title: '带着一亿现金重生回高中',
          creator: '逆袭 · 青春',
          coverAsset: 'asset://poster-wucheng-huixiang.png',
          category: '青春重生',
          popularity: '4512万热度',
          summary: '中年社畜意外重回高中时代，随身携带一亿巨额现金，且看他如何逆天改命，玩转商海，弥补所有遗憾。',
          channel: ContentChannel.shortDrama,
          progress: 0.0,
          episodeCount: 65,
          isLive: true,
          sourceName: '短剧外链源',
        ),
      ];
    } else {
      return [
        const ContentItem(
          id: 'curated-video-1',
          title: '流浪地球 2',
          creator: '郭帆 · 科幻',
          coverAsset: 'asset://poster-yuanshan-zhixia.png',
          category: '科幻电影',
          popularity: '9800万热度',
          summary: '人类文明面临太阳危机，万座行星发动机启动在即，移山计划面临重重考验，人类如何在太空中寻找新的家园。',
          channel: ContentChannel.video,
          progress: 0.0,
          episodeCount: 1,
          isLive: true,
          sourceName: '电影直连源',
        ),
        const ContentItem(
          id: 'curated-video-2',
          title: '长安三万里',
          creator: '谢君伟 · 动画',
          coverAsset: 'asset://poster-yuanshan-zhixia.png',
          category: '历史动画',
          popularity: '8200万热度',
          summary: '以唐代著名诗人李白与高适的友情为主线，展现一幅波澜壮阔的大唐盛世图景，群星闪耀，诗意盎然。',
          channel: ContentChannel.video,
          progress: 0.0,
          episodeCount: 1,
          isLive: true,
          sourceName: '电影直连源',
        ),
      ];
    }
  }

  Future<List<ContentItem>> discover(
    ContentChannel channel, {
    String query = '',
    String category = '',
  }) async {
    if (forceLocalDirect) {
      return await _discoverDirect(channel, query: query, category: category);
    }
    final isSearch = query.trim().isNotEmpty;
    final uri = Uri.parse('$baseUrl/${isSearch ? 'search' : 'discover'}')
        .replace(
          queryParameters: {
            'channel': channel.name,
            if (isSearch) 'query': query.trim(),
            if (!isSearch && category.isNotEmpty && category != '全部')
              'category': category,
          },
        );
    try {
      final response = await _client
          .get(uri)
          .timeout(const Duration(seconds: 4));
      if (response.statusCode != 200) {
        return await _discoverDirect(channel, query: query, category: category);
      }
      final body = jsonDecode(utf8.decode(response.bodyBytes)) as List<dynamic>;
      return body
          .map((item) {
            final data = Map<String, dynamic>.from(item as Map);
            final cover = data['cover'] as String? ?? '';
            if (cover.isNotEmpty && !cover.startsWith('http')) {
              data['cover'] = '$baseUrl/$cover';
            }
            return ContentItem.fromJson(data);
          })
          .where((item) => item.isLive)
          .toList(growable: false);
    } catch (_) {
      debugPrint('ContentApiRepository: FastAPI down. Running direct online search/discover.');
      try {
        return await _discoverDirect(channel, query: query, category: category);
      } catch (e) {
        return _curatedChineseItems(channel);
      }
    }
  }

  Future<List<ContentItem>> _discoverDirect(
    ContentChannel channel, {
    String query = '',
    String category = '',
  }) async {
    final isSearch = query.trim().isNotEmpty;
    final curatedList = _curatedChineseItems(channel);

    if (channel == ContentChannel.novel) {
      final searchPart = isSearch ? '&search=${Uri.encodeComponent(query.trim())}' : '';
      final url = 'https://gutendex.com/books/?mime_type=text%2Fplain$searchPart';
      
      final response = await _client.get(Uri.parse(url)).timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) {
        throw ContentApiException('Gutendex returned ${response.statusCode}');
      }
      final data = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      final results = data['results'] as List<dynamic>? ?? const [];
      final apiItems = results.map((item) {
        final book = Map<String, dynamic>.from(item as Map);
        final authors = book['authors'] as List<dynamic>? ?? const [];
        final author = authors.isNotEmpty ? authors[0]['name'] as String : 'Unknown';
        final formats = book['formats'] as Map<String, dynamic>? ?? const {};
        final cover = formats['image/jpeg'] as String? ?? '';
        final bookshelves = book['bookshelves'] as List<dynamic>? ?? const [];
        final genre = bookshelves.isNotEmpty ? bookshelves[0] as String : 'Classic';
        final downloads = book['download_count'] as int? ?? 0;
        
        return ContentItem(
          id: 'gutenberg-${book['id']}',
          title: book['title'] as String? ?? 'Untitled',
          creator: author,
          coverAsset: cover,
          category: genre,
          popularity: '$downloads次下载',
          summary: book['subjects'] != null ? (book['subjects'] as List).join(', ') : 'No description.',
          channel: ContentChannel.novel,
          progress: 0.0,
          episodeCount: 15,
          isLive: true,
          sourceName: 'Project Gutenberg',
        );
      }).toList();
      
      return [...curatedList, ...apiItems];

    } else if (channel == ContentChannel.shortDrama) {
      final url = isSearch 
          ? 'https://api.tvmaze.com/search/shows?q=${Uri.encodeComponent(query.trim())}'
          : 'https://api.tvmaze.com/shows';
      
      final response = await _client.get(Uri.parse(url)).timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) {
        throw ContentApiException('TVmaze returned ${response.statusCode}');
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
        final creator = network != null ? network['name'] as String : (webChannel != null ? webChannel['name'] as String : 'TVmaze');
        final genres = show['genres'] as List<dynamic>? ?? const [];
        final genre = genres.isNotEmpty ? genres[0] as String : 'Drama';
        final rating = show['rating'] as Map<String, dynamic>?;
        final score = rating != null && rating['average'] != null ? '评分 ${rating['average']}' : '推荐';
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

      return [...curatedList, ...apiItems];

    } else {
      final searchTerm = isSearch ? query.trim() : 'popular';
      final url = 'https://itunes.apple.com/search?media=movie&limit=20&term=${Uri.encodeComponent(searchTerm)}';
      
      final response = await _client.get(Uri.parse(url)).timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) {
        throw ContentApiException('iTunes API returned ${response.statusCode}');
      }
      final data = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      final results = data['results'] as List<dynamic>? ?? const [];
      final apiItems = results.map((item) {
        final movie = Map<String, dynamic>.from(item as Map);
        final trackId = movie['trackId'] as int? ?? 0;
        final cover = (movie['artworkUrl100'] as String? ?? '').replaceAll('100x100bb', '400x400bb');
        final director = movie['artistName'] as String? ?? 'Unknown';
        final genre = movie['primaryGenreName'] as String? ?? 'Movie';
        final price = movie['trackPrice'] != null ? '售价 \$${movie['trackPrice']}' : '推荐';
        final desc = movie['longDescription'] as String? ?? movie['shortDescription'] as String? ?? 'No description.';
        
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

      return [...curatedList, ...apiItems];
    }
  }

  Future<Chapter> chapter(ContentItem item, int index) async {
    if (forceLocalDirect) {
      return await _chapterDirect(item, index);
    }
    final isDirectItem = item.id.startsWith('gutenberg-') ||
        item.id.startsWith('tvmaze-') ||
        item.id.startsWith('itunes-') ||
        item.id.startsWith('curated-');
        
    if (isDirectItem) {
      return await _chapterDirect(item, index);
    }
    
    final uri = Uri.parse('$baseUrl/content/${item.id}/chapters/$index');
    try {
      final response = await _client
          .get(uri)
          .timeout(const Duration(seconds: 5));
      if (response.statusCode != 200) {
        return await _chapterDirect(item, index);
      }
      final data =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      return Chapter(
        title: data['title'] as String? ?? item.title,
        paragraphs: (data['paragraphs'] as List<dynamic>? ?? const [])
            .map((value) => value.toString())
            .toList(growable: false),
      );
    } catch (_) {
      return await _chapterDirect(item, index);
    }
  }

  Future<Chapter> _chapterDirect(ContentItem item, int index) async {
    if (item.id.startsWith('gutenberg-')) {
      final realId = item.id.substring('gutenberg-'.length);
      try {
        final response = await _client
            .get(Uri.parse('https://www.gutenberg.org/cache/epub/$realId/pg$realId.txt'))
            .timeout(const Duration(seconds: 15));
        if (response.statusCode == 200) {
          return _parseGutenbergText(response.body, index, item.title);
        }
      } catch (_) {}
      try {
        final response = await _client
            .get(Uri.parse('https://www.gutenberg.org/files/$realId/$realId-0.txt'))
            .timeout(const Duration(seconds: 15));
        if (response.statusCode == 200) {
          return _parseGutenbergText(response.body, index, item.title);
        }
      } catch (_) {}
    }
    
    return Chapter(
      title: '第 ${index + 1} 章  ${item.title}',
      paragraphs: [
        '【${item.sourceName}】正在以客户端直接抓取形式展示。',
        '当前由于本地 FastAPI 缓存与规则后端处于离线状态，客户端已自动启用直连网络公开源模式。',
        '段落二：直连模式下，系统能够从公开源直接拉取最新目录。本章内容由本地沙盒机制直接生成或在线解析。',
        '段落三：在真实的开发部署环境中，我们推荐通过 uvicorn 启动本地后端，以支持对海量第三方 JSON 书源的分布式解析与高级防爬模拟。',
        '段落四：聚合短剧/影视源支持点击返回。感谢您的开发测试！',
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
