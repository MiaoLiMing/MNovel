import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mnovel/data/content_repository.dart';
import 'package:mnovel/data/source_store.dart';
import 'package:mnovel/domain/content.dart';
import 'package:mnovel/domain/content_source.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockSourceStore extends SourceStore {
  _MockSourceStore(this.sources);

  final List<ContentSource> sources;

  @override
  Future<List<ContentSource>> list({bool refresh = false}) async => sources;
}

void main() {
  test('书城首页不再使用内置试读目录兜底', () async {
    SharedPreferences.setMockInitialValues({});
    final repository = ContentRepository(
      sourceStore: _MockSourceStore(const []),
      client: MockClient((_) async => http.Response('', 503)),
    );

    final home = await repository.home();

    expect(home.isEmpty, isTrue);
    expect(home.featured, isNull);
    expect(home.carousel, isEmpty);
  });

  test('内置源未部署时返回明确检测结果', () async {
    SharedPreferences.setMockInitialValues({});
    final repository = ContentRepository(
      sourceStore: _MockSourceStore(const []),
      client: MockClient(
        (_) async => http.Response(
          '{"detail":"书源不存在"}',
          404,
          headers: {'content-type': 'application/json; charset=utf-8'},
        ),
      ),
    );
    const source = ContentSource(
      id: 'shuchong-rule',
      name: '书虫网',
      description: 'test',
      channels: {ContentChannel.novel},
      kind: SourceKind.backendRule,
      endpoint: 'https://www.shuchong.info/',
      builtIn: true,
    );

    final result = await repository.probeSource(source);

    expect(result.health, SourceHealth.error);
    expect(result.message, '服务器尚未部署此内置源');
  });

  test('内置源保留后端返回的结构异常详情', () async {
    SharedPreferences.setMockInitialValues({});
    final repository = ContentRepository(
      sourceStore: _MockSourceStore(const []),
      client: MockClient(
        (_) async => http.Response(
          '{"status":"error","latency_ms":321,'
          '"message":"发现规则未解析到任何小说"}',
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        ),
      ),
    );
    const source = ContentSource(
      id: 'shuchong-rule',
      name: '书虫网',
      description: 'test',
      channels: {ContentChannel.novel},
      kind: SourceKind.backendRule,
      endpoint: 'https://www.shuchong.info/',
      builtIn: true,
    );

    final result = await repository.probeSource(source);

    expect(result.health, SourceHealth.error);
    expect(result.latencyMs, 321);
    expect(result.message, contains('发现规则'));
  });

  test('后端不可用时发现页返回空数据而不是本地试读', () async {
    SharedPreferences.setMockInitialValues({});
    final repository = ContentRepository(
      sourceStore: _MockSourceStore(const []),
      client: MockClient((_) async => http.Response('', 503)),
    );

    final items = await repository.discover(ContentChannel.novel);
    expect(items, isEmpty);
  });

  test('后端不可用时带筛选的发现页同样返回空数据', () async {
    SharedPreferences.setMockInitialValues({});
    final repository = ContentRepository(
      sourceStore: _MockSourceStore(const []),
      client: MockClient((_) async => http.Response('', 503)),
    );

    final items = await repository.discover(
      ContentChannel.novel,
      category: '仙侠',
      status: 'completed',
      wordCount: '1m-3m',
    );
    expect(items, isEmpty);
  });

  test('自定义 JSON 书源会与聚合目录合并', () async {
    SharedPreferences.setMockInitialValues({});
    const source = ContentSource(
      id: 'custom-test',
      name: '自定义测试源',
      description: 'inline',
      channels: {ContentChannel.novel},
      kind: SourceKind.json,
      endpoint:
          '[{"id":"custom-1","title":"云上长歌","creator":"测试作者",'
          '"category":"仙侠","summary":"简介","cover":"",'
          '"popularity":"新书","progress":0,"unit_count":12}]',
      builtIn: false,
    );
    final repository = ContentRepository(
      sourceStore: _MockSourceStore(const [source]),
      client: MockClient((_) async => http.Response('', 503)),
    );

    final items = await repository.discover(
      ContentChannel.novel,
      query: '云上长歌',
    );
    expect(items.single.title, '云上长歌');
    expect(items.single.sourceName, '自定义测试源');
  });

  test('搜索使用后端多书源聚合接口并保留来源', () async {
    SharedPreferences.setMockInitialValues({});
    final requestedPaths = <String>[];
    final repository = ContentRepository(
      sourceStore: _MockSourceStore(const []),
      client: MockClient((request) async {
        requestedPaths.add(request.url.path);
        if (request.url.path.endsWith('/sources/legacy/search')) {
          return http.Response(
            jsonEncode([
              {
                'id': 'legado-one:book-1',
                'title': '诡秘之主',
                'author': '爱潜水的乌贼',
                'detail_url': 'https://one.example/book/1',
                'source_id': 'legado-one',
                'source_name': '来源一',
                'chapter_count': 326,
                'readable': true,
                'unavailable_reason': '',
              },
              {
                'id': 'legado-two:book-2',
                'title': '诡秘之主',
                'author': '爱潜水的乌贼',
                'detail_url': 'https://two.example/book/2',
                'source_id': 'legado-two',
                'source_name': '来源二',
                'chapter_count': 0,
                'readable': false,
                'unavailable_reason': '当前来源没有可用章节',
              },
            ]),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }
        return http.Response('[]', 200);
      }),
    );

    final items = await repository.discover(
      ContentChannel.novel,
      query: '爱潜水的乌贼',
    );

    expect(requestedPaths, contains(endsWith('/sources/legacy/search')));
    expect(items, hasLength(2));
    expect(items.map((item) => item.sourceName), containsAll(['来源一', '来源二']));
    expect(items.first.episodeCount, 326);
    expect(items.first.isReadable, isTrue);
    expect(items.last.isReadable, isFalse);
    expect(items.last.unavailableReason, '当前来源没有可用章节');
  });

  test('书城首页从 Gutendex 真实来源动态构建', () async {
    SharedPreferences.setMockInitialValues({});
    const source = ContentSource(
      id: 'project-gutenberg',
      name: 'Project Gutenberg',
      description: 'public domain',
      channels: {ContentChannel.novel},
      kind: SourceKind.gutendex,
      endpoint: 'https://gutendex.com/books/',
      builtIn: true,
    );
    final repository = ContentRepository(
      sourceStore: _MockSourceStore(const [source]),
      client: MockClient((request) async {
        if (request.url.host == 'gutendex.com') {
          return http.Response(
            '{"count":78986,"results":[{'
            '"id":123,"title":"A Public Domain Book",'
            '"authors":[{"name":"Test Author"}],'
            '"subjects":["Fiction"],"download_count":42,'
            '"formats":{"text/plain; charset=utf-8":"https://books.example/123.txt",'
            '"image/jpeg":"https://books.example/123.jpg"}}]}',
            200,
          );
        }
        return http.Response('', 503);
      }),
    );

    final home = await repository.home();
    expect(home.fromNetwork, isTrue);
    expect(home.carousel.first.title, 'A Public Domain Book');
    expect(home.carousel.first.chapterUrls, ['https://books.example/123.txt']);
  });

  test('中文维基文库同名子页会聚合成一本多章小说', () async {
    SharedPreferences.setMockInitialValues({});
    const source = ContentSource(
      id: 'zh-wikisource',
      name: '中文维基文库',
      description: 'public domain',
      channels: {ContentChannel.novel},
      kind: SourceKind.wikisource,
      endpoint: 'https://zh.wikisource.org/w/api.php',
      builtIn: true,
    );
    final repository = ContentRepository(
      sourceStore: _MockSourceStore(const [source]),
      client: MockClient((request) async {
        if (request.url.host == 'zh.wikisource.org') {
          return http.Response.bytes(
            utf8.encode(
              '{"query":{"pages":['
              '{"pageid":2,"title":"紅樓夢/第2回","extract":"第二回"},'
              '{"pageid":1,"title":"紅樓夢/第1回","extract":"第一回"}'
              ']}}',
            ),
            200,
          );
        }
        return http.Response('', 503);
      }),
    );

    final home = await repository.home();
    final book = home.carousel.single;
    expect(book.title, '紅樓夢');
    expect(book.episodeCount, 2);
    expect(book.chapterUrls, hasLength(2));
    expect(book.sourceName, '中文维基文库');
  });

  test('媒体线路反序列化后可被识别为可播放内容', () {
    final item = ContentItem.fromJson({
      'id': 'media-1',
      'title': '测试媒体',
      'creator': '测试作者',
      'category': '短剧',
      'summary': '简介',
      'cover': '',
      'media_playlists': [
        {
          'name': '直连',
          'episodes': [
            {'name': '第 1 集', 'url': 'https://cdn.example.com/1.m3u8'},
          ],
        },
      ],
    });

    expect(item.hasPlayableMedia, isTrue);
  });

  test('章节响应会读取服务端返回的实际总章数', () async {
    SharedPreferences.setMockInitialValues({});
    final repository = ContentRepository(
      sourceStore: _MockSourceStore(const []),
      client: MockClient(
        (_) async => http.Response.bytes(
          utf8.encode(
            '{"index":0,"title":"第一节","paragraphs":["正文"],'
            '"source_id":"project-gutenberg","unit_count":7}',
          ),
          200,
        ),
      ),
    );
    final item = ContentItem.fromJson({
      'id': 'gutendex-7',
      'title': '测试作品',
      'creator': '作者',
      'category': '公共领域',
      'summary': '',
      'cover': '',
      'unit_count': 1,
      'source_id': 'project-gutenberg',
      'source_name': 'Project Gutenberg',
      'is_live': true,
    });

    final chapter = await repository.chapter(item, 0, preferOffline: false);

    expect(chapter.totalCount, 7);
  });

  test('异常大的旧版单章响应会在排版前被拒绝', () async {
    SharedPreferences.setMockInitialValues({});
    final repository = ContentRepository(
      sourceStore: _MockSourceStore(const []),
      client: MockClient(
        (_) async => http.Response.bytes(List<int>.filled(600 * 1024, 32), 200),
      ),
    );
    final item = ContentItem.fromJson({
      'id': 'gutendex-large',
      'title': '超大作品',
      'creator': '作者',
      'category': '公共领域',
      'summary': '',
      'cover': '',
      'unit_count': 1,
      'source_id': 'project-gutenberg',
      'source_name': 'Project Gutenberg',
      'is_live': true,
    });

    expect(
      () => repository.chapter(item, 0, preferOffline: false),
      throwsA(
        isA<ContentRepositoryException>().having(
          (error) => error.message,
          'message',
          contains('单章正文过大'),
        ),
      ),
    );
  });

  test('健康书源复检不会请求服务端重新扫描原始全量目录', () async {
    SharedPreferences.setMockInitialValues({});
    late Uri requested;
    final repository = ContentRepository(
      sourceStore: _MockSourceStore(const []),
      client: MockClient((request) async {
        requested = request.url;
        return http.Response(
          '{"status":"running","total":3,"completed":0,'
          '"healthy":0,"quarantined":0}',
          200,
        );
      }),
    );

    final progress = await repository.startSourceAudit();

    expect(progress.total, 3);
    expect(requested.path, endsWith('/sources/audit'));
    expect(requested.queryParameters.containsKey('force'), isFalse);
  });
}
