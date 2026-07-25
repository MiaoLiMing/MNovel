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
  Future<List<ContentSource>> list() async => sources;
}

void main() {
  test('后端不可用时回退到明确标识的内置试读目录', () async {
    SharedPreferences.setMockInitialValues({});
    final repository = ContentRepository(
      sourceStore: _MockSourceStore(const []),
      client: MockClient((_) async => http.Response('', 503)),
    );

    final items = await repository.discover(ContentChannel.novel);
    expect(items, isNotEmpty);
    expect(items.first.title, '诡秘之主');
    expect(items.first.sourceLabels, ['内置试读']);
  });

  test('分类、状态和字数筛选在离线书库同样生效', () async {
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
    expect(items.map((item) => item.title), contains('道诡异仙'));
    expect(items.every((item) => item.category.contains('仙侠')), isTrue);
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
}
