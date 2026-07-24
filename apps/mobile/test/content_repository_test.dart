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
  test('后端不可用时回退到可阅读的内置书库', () async {
    SharedPreferences.setMockInitialValues({});
    final repository = ContentRepository(
      sourceStore: _MockSourceStore(const []),
      client: MockClient((_) async => http.Response('', 503)),
    );

    final items = await repository.discover(ContentChannel.novel);
    expect(items, isNotEmpty);
    expect(items.first.title, '诡秘之主');
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
}
