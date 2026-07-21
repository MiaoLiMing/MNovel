import 'package:flutter_test/flutter_test.dart';
import 'package:mnovel/data/reading_progress_store.dart';
import 'package:mnovel/data/source_store.dart';
import 'package:mnovel/domain/content.dart';
import 'package:mnovel/domain/content_source.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
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

    await store.save('book-1', chapterIndex: 12, ratio: .48);
    final progress = await store.load('book-1');

    expect(progress.chapterIndex, 12);
    expect(progress.ratio, .48);
  });
}
