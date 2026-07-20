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

  // Curated Chinese test data for when the backend is offline (Mapped to pre-packaged assets)
  List<ContentItem> _curatedChineseItems(ContentChannel channel) {
    if (channel == ContentChannel.novel) {
      return [
        const ContentItem(
          id: 'curated-novel-1',
          title: '长风问剑',
          creator: '山止川行 · 剑道',
          coverAsset: 'asset://cover-changfeng-wenjian.png',
          category: '仙侠',
          popularity: '128万在读',
          summary: '少年从边城启程，在山河与人心之间寻找自己的剑道。天下万界，唯我剑尊！',
          channel: ContentChannel.novel,
          progress: 0.0,
          episodeCount: 1268,
          isLive: true,
          sourceName: '本地书源',
        ),
        const ContentItem(
          id: 'curated-novel-2',
          title: '星海余烬',
          creator: '拾光者 · 科幻',
          coverAsset: 'asset://cover-xinghai-yujin.png',
          category: '科幻',
          popularity: '96万在读',
          summary: '旧世界沉入星海，最后一座空间城在余烬中寻找新的航路。少年获得宇宙神级系统，不断升级进化。',
          channel: ContentChannel.novel,
          progress: 0.0,
          episodeCount: 486,
          isLive: true,
          sourceName: '本地书源',
        ),
        const ContentItem(
          id: 'curated-novel-3',
          title: '凤归长安',
          creator: '青梅煮雪 · 古言',
          coverAsset: 'asset://cover-fenggui-changan.png',
          category: '古言',
          popularity: '78万在读',
          summary: '一封旧案卷宗，让她重回长安，也重新走进那场未完的风雪。步步为营，执掌风云，登顶天下。',
          channel: ContentChannel.novel,
          progress: 0.0,
          episodeCount: 392,
          isLive: true,
          sourceName: '本地书源',
        ),
        const ContentItem(
          id: 'curated-novel-4',
          title: '长风问剑 (续作)',
          creator: '山止川行 · 玄幻',
          coverAsset: 'asset://cover-changfeng-wenjian.png',
          category: '仙侠玄幻',
          popularity: '156万在读',
          summary: '长风卷席，剑问苍穹！重开九霄大陆宗门，修无上武道，斩各路天骄。',
          channel: ContentChannel.novel,
          progress: 0.0,
          episodeCount: 220,
          isLive: true,
          sourceName: '本地书源',
        ),
        const ContentItem(
          id: 'curated-novel-5',
          title: '星海余烬 (外传)',
          creator: '拾光者 · 仙侠',
          coverAsset: 'asset://cover-xinghai-yujin.png',
          category: '科幻修真',
          popularity: '128.6万在读',
          summary: '低调修炼，韩立偶然间得到神秘小绿瓶，克敌制胜，终登仙界。',
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
          title: '雾城回响',
          creator: '青岚影业 · 悬疑',
          coverAsset: 'asset://poster-wucheng-huixiang.png',
          category: '悬疑都市',
          popularity: '5967万热度',
          summary: '记者与刑警追查一段消失的录音。毕业十年聚会，全班戏谑修仙大佬，而主角早已大乘期大圆满！',
          channel: ContentChannel.shortDrama,
          progress: 0.0,
          episodeCount: 36,
          isLive: true,
          sourceName: '短剧外链源',
        ),
        const ContentItem(
          id: 'curated-drama-2',
          title: '雾城回响 (第二季)',
          creator: '青岚影业 · 逆袭',
          coverAsset: 'asset://poster-wucheng-huixiang.png',
          category: '青春重生',
          popularity: '4512万热度',
          summary: '中年社畜意外重回高中时代，随身携带一亿巨额现金，且看他如何逆天改命，玩转商海。',
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
          title: '远山之下',
          creator: '原野纪录 · 自然',
          coverAsset: 'asset://poster-yuanshan-zhixia.png',
          category: '纪录片',
          popularity: '9.2 分',
          summary: '沿着雪线与河谷前行，记录人与高山之间的关系。人类文明面临太阳危机，万座发动机启动在即。',
          channel: ContentChannel.video,
          progress: 0.0,
          episodeCount: 6,
          isLive: true,
          sourceName: '电影直连源',
        ),
        const ContentItem(
          id: 'curated-video-2',
          title: '远山之下 (精编版)',
          creator: '原野纪录 · 纪录',
          coverAsset: 'asset://poster-yuanshan-zhixia.png',
          category: '自然探索',
          popularity: '8200万热度',
          summary: '以唐代著名诗人李白与高适的友情为主线，展现一幅波澜壮阔的大唐盛世图景。',
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
    try {
      return await _discoverDirect(channel, query: query, category: category);
    } catch (_) {
      final normalizedQuery = query.trim().toLowerCase();
      return _curatedChineseItems(channel)
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
    final curatedList =
        enabledSources.any((source) => source.kind == SourceKind.localCatalog)
        ? _curatedChineseItems(channel)
        : <ContentItem>[];
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
          final response = await _client
              .get(Uri.parse(source.endpoint))
              .timeout(const Duration(seconds: 8));
          if (response.statusCode != 200) return <ContentItem>[];
          final decoded = jsonDecode(utf8.decode(response.bodyBytes));
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
    List<String> paragraphs = [
      '【${item.sourceName}】内容由 App 在设备端直接读取。',
      'MNovel 不依赖自建服务端，来源配置、书架、阅读进度与设置均保存在本机。',
      '当前条目未提供可解析的正文，因此展示本地占位章节。你可以在“我的 → 内容源管理”中添加有权使用的来源。',
    ];

    if (displayTitle.contains('长风问剑')) {
      paragraphs = [
        '大雪压折了青云宗山门前最后一株古松的枝丫，寒风如刀割般扫过空旷的试炼场。',
        '少年陆青衣一袭单薄的白衣，静静地伫立在试炼悬崖的边缘。他的目光清冷，怀中紧紧抱着一柄锈迹斑斑、甚至没有剑鞘的铁剑。',
        '“陆青衣，你不过是一个气海破碎的废人，也配留在我青云宗问剑？”身后的石阶上，传来冷漠的嘲讽声。',
        '说话的正是内门大弟子周煌。他居高临下地看着陆青衣，眼中满是不屑。',
        '陆青衣没有转过身，也没有回答。他只是轻轻闭上双眼，感受着山谷间呼啸的狂风。',
        '风声中，隐隐传来一丝奇异的律动。那是万物呼吸的声音，也是他苦修十年所领悟的“风雷剑意”。',
        '“我的剑，不问青天，不问神魔。”陆青衣缓缓睁开眼，嘴角勾起一抹淡淡的弧度，“只问我心。”',
      ];
    } else if (displayTitle.contains('星海余烬')) {
      paragraphs = [
        '“警报！反应堆核心完整度已降至3%，系统将在六十秒后强行关闭生命维持装置。”',
        '刺眼的红色警报灯在狭小的驾驶舱内疯狂闪烁，将沈源苍白的脸庞映照得一片通红。',
        '他深深吸了一口气，冰冷刺骨的空气涌入肺部。战舰“余烬号”的一半机体已经在引力风暴中被撕裂，只剩下动力舱和这个孤立的主控室还在残喘。',
        '舷窗外，是浩瀚无垠、又令人窒息的漆黑深空。远处的星系正在以肉眼可见的速度塌陷，旧世界的火光正在慢慢熄灭。',
        '“警告：检测到大乘级宇宙星兽逼近，距离当前坐标还有三万公里。”系统AI的声音毫无感情。',
        '沈源揉了揉太阳穴，嘴角露出一抹苦涩的笑意。',
        '他点开虚空，一道只有他能看见的半透明淡蓝色面板缓缓展开：',
        '【超脑星际系统：已成功绑定。检测到宿主面临必死困境，正在为您解锁‘大乘级超频重组’功能...】',
        '“既然旧世界已经沉没，那就用这漫天星辰的余烬，来重燃我们的航路吧！”沈源的眼神瞬间变得无比锐利，按下了那个血红色的重组启动键。',
      ];
    } else if (displayTitle.contains('凤归长安')) {
      paragraphs = [
        '十二年了，她终于再次踏上了长安的土地。',
        '漫天风雪压塌了城角梅花，马车压过城门前的青石板路，发出沉闷的声响。谢长歌微微掀开马车的布帘，望向那高耸入云的朱红色城门，眼神复杂。',
        '当年谢家满门忠烈，却在一夜之间被扣上谋逆的罪名，血染长安。年仅十岁的她，在忠仆的拼死掩护下，才得以逃出生天。',
        '“小姐，回春堂那边已经打点好了。”身旁的丫鬟小声提醒道，“相国府的人今晚会去回春堂取药。”',
        '谢长歌放下帘子，将冰冷的手缩回暖手炉旁。',
        '“当年夺走谢家一切的人，如今正坐在明堂之上，执掌着相国的权柄。”谢长歌清冷的声音在车厢内回荡，“今夜，就从相国府开始，把他们欠我的，一笔一笔拿回来。”',
      ];
    } else if (displayTitle.contains('末世') ||
        displayTitle.contains('系统') ||
        displayTitle.contains('剑神') ||
        displayTitle.contains('武神')) {
      paragraphs = [
        '【聚合内容直连展示】',
        '丧尸横行，异兽复苏，人类文明处于毁灭边缘。',
        '林风擦了擦长剑上的黑色污血，冷冷地注视着前方废墟中不断涌来的黑潮。在他脑海中，金色的系统指示正有规律地闪烁着。',
        '“叮！检测到宿主成功击杀精英级舔食者一只，获得进化点数 +500，解锁下一阶超凡武技！”',
        '狂风吹起林风有些破旧的披风，这一世重生归来，他誓要用手中之剑重新开创人族纪元。',
      ];
    }

    return Chapter(
      title: '第 ${index + 1} 章  $displayTitle',
      paragraphs: paragraphs,
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
