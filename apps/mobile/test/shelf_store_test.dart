import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mnovel/data/shelf_store.dart';
import 'package:mnovel/domain/content.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('fresh install starts with an empty shelf', () async {
    SharedPreferences.setMockInitialValues({});

    final items = await ShelfStore().listAll();

    expect(items, isEmpty);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('shelf.items.v1'), '[]');
  });

  test('retired demo entries are removed from an existing shelf', () async {
    const realItem = ContentItem(
      id: 'real-book',
      channel: ContentChannel.novel,
      title: '真实书目',
      creator: '作者',
      category: '小说',
      summary: '',
      coverAsset: '',
      popularity: '',
      progress: 0,
      episodeCount: 0,
    );
    const demoItem = ContentItem(
      id: 'novel-mystery-lord',
      channel: ContentChannel.novel,
      title: '旧演示书目',
      creator: '演示作者',
      category: '小说',
      summary: '',
      coverAsset: '',
      popularity: '',
      progress: 0,
      episodeCount: 0,
    );
    SharedPreferences.setMockInitialValues({
      'shelf.items.v1': jsonEncode([demoItem.toJson(), realItem.toJson()]),
    });

    final items = await ShelfStore().listAll();

    expect(items.map((item) => item.id), ['real-book']);
  });
}
