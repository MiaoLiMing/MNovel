import 'package:flutter_test/flutter_test.dart';
import 'package:mnovel/data/reading_progress_store.dart';
import 'package:mnovel/data/source_store.dart';
import 'package:mnovel/domain/content.dart';
import 'package:mnovel/domain/content_source.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('内置列表只保留三个可用公共书源', () async {
    SharedPreferences.setMockInitialValues({
      'content.sources.enabled.v1':
          '{"qidian":true,"fanqie":true,"custom-example":true}',
    });
    final sources = await SourceStore().list();
    final builtIns = sources.where((source) => source.builtIn).toList();

    expect(
      builtIns.map((source) => source.id),
      containsAllInOrder([
        'project-gutenberg',
        'zh-wikisource',
        'internet-archive-chinese',
      ]),
    );
    expect(builtIns, hasLength(3));
    expect(
      builtIns.where(
        (source) => source.health == SourceHealth.configurationRequired,
      ),
      isEmpty,
    );
  });

  test('来源启停与自定义 JSON 来源保存在本机', () async {
    SharedPreferences.setMockInitialValues({});
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

    final sources = await store.list();
    expect(
      sources.singleWhere((source) => source.id == 'custom-test').enabled,
      isFalse,
    );
    expect(
      sources.singleWhere((source) => source.id == 'custom-test').name,
      '测试来源',
    );
  });

  test('阅读章节与总体进度保存在本机', () async {
    SharedPreferences.setMockInitialValues({});
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
      '{"sources":[{"name":"来源甲","kind":"json",'
      '"endpoint":"https://example.com/a.json"},'
      '{"name":"来源乙","kind":"js",'
      '"endpoint":"https://example.com/b.js",'
      '"rules":{"discover":"function discover(body){return body;}"}}]}',
    );

    expect(count, 2);
    final sources = await store.list();
    expect(sources.where((source) => source.name == '来源甲'), hasLength(1));
    expect(
      sources.singleWhere((source) => source.name == '来源乙').kind,
      SourceKind.js,
    );
  });
}
