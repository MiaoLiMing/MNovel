import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mnovel/data/reading_progress_store.dart';
import 'package:mnovel/data/source_store.dart';
import 'package:mnovel/domain/content.dart';
import 'package:mnovel/domain/content_source.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SourceStore.clearMemoryCache();
  });

  test('书源列表只包含服务端验证通过的统一内置目录', () async {
    SharedPreferences.setMockInitialValues({
      'content.sources.verified.v1': jsonEncode([
        {
          'id': 'verified-one',
          'name': '验证源一',
          'description': '已验证',
          'channels': ['novel'],
          'kind': 'legacy',
          'endpoint': 'https://one.example',
          'enabled': true,
          'built_in': true,
          'health': 'healthy',
        },
      ]),
    });
    final sources = await SourceStore().list();

    expect(sources.single.id, 'verified-one');
    expect(sources.single.builtIn, isTrue);
    expect(sources.single.enabled, isTrue);
  });

  test('自定义 JSON 来源继续保存在本机但不会混入健康目录', () async {
    SharedPreferences.setMockInitialValues({
      'content.sources.verified.v1': '[]',
    });
    final store = SourceStore();

    final testSource = const ContentSource(
      id: 'custom-test',
      name: '测试来源',
      description: '测试',
      channels: {ContentChannel.novel},
      kind: SourceKind.json,
      endpoint: 'https://example.com/catalog.json',
    );

    await store.addCustom(testSource);
    await store.setEnabled('custom-test', false);

    expect(await store.list(), isEmpty);
    final stored = await store.findById('custom-test');
    expect(stored?.name, '测试来源');
    expect(stored?.enabled, isTrue);
  });

  test('阅读章节与总体进度保存在本机', () async {
    SharedPreferences.setMockInitialValues({
      'content.sources.verified.v1': '[]',
    });
    final store = ReadingProgressStore();

    await store.save(
      'book-1',
      chapterIndex: 12,
      pageIndex: 4,
      characterOffset: 1680,
      ratio: .48,
    );
    final progress = await store.load('book-1');

    expect(progress.chapterIndex, 12);
    expect(progress.ratio, .48);
    expect(progress.pageIndex, 4);
    expect(progress.characterOffset, 1680);
  });

  test('支持批量导入 MNovel JSON 书源清单', () async {
    SharedPreferences.setMockInitialValues({});
    final store = SourceStore();
    final count = await store.importMany(
      '{"sources":[{"id":"custom-a","name":"来源甲","kind":"json",'
      '"endpoint":"https://example.com/a.json"},'
      '{"id":"custom-b","name":"来源乙","kind":"js",'
      '"endpoint":"https://example.com/b.js",'
      '"rules":{"discover":"function discover(body){return body;}"}}]}',
    );

    expect(count, 2);
    expect(await store.list(), isEmpty);
    expect((await store.findById('custom-a'))?.name, '来源甲');
    expect((await store.findById('custom-b'))?.kind, SourceKind.js);
  });

  test('支持直接导入 Legado 完整书源规则', () async {
    SharedPreferences.setMockInitialValues({
      'content.sources.verified.v1': '[]',
    });
    final store = SourceStore();

    final count = await store.importMany(
      '[{"bookSourceName":"Legado 测试源",'
      '"bookSourceUrl":"https://example.com",'
      '"searchUrl":"/search?q={{key}}",'
      '"ruleSearch":{"bookList":".book","name":".name@text",'
      '"bookUrl":".name@href"}}]',
    );

    expect(count, 1);
    expect(await store.list(), isEmpty);
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString('content.sources.custom.v1') ?? '';
    expect(stored, contains('Legado 测试源'));
    expect(stored, contains('ruleSearch'));
  });
}
