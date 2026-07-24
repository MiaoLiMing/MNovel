import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mnovel/domain/content.dart';
import 'package:mnovel/data/content_repository.dart';
import 'package:mnovel/features/bookstore/discover_list_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockListRepository extends ContentRepository {
  @override
  Future<List<ContentItem>> discover(
    ContentChannel channel, {
    String query = '',
    String category = '',
    String status = '',
    String wordCount = '',
    String source = '',
  }) async {
    return const [
      ContentItem(
        id: '1',
        channel: ContentChannel.novel,
        title: '长风问剑',
        creator: '山止川行',
        category: '仙侠小说',
        summary: '简介内容',
        coverAsset: '',
        popularity: '12万人在读',
        progress: 0,
        episodeCount: 12,
        sourceId: 'mock-source',
        sourceName: 'Mock',
        isLive: true,
      ),
    ];
  }
}

void main() {
  testWidgets('DiscoverListPage displays featured items in grid view', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      MaterialApp(
        home: DiscoverListPage(
          channel: ContentChannel.novel,
          title: '今日精选',
          listType: 'featured',
          repository: _MockListRepository(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('今日精选'), findsOneWidget);
    expect(find.text('长风问剑'), findsOneWidget);
    expect(find.text('山止川行'), findsOneWidget);
  });

  testWidgets('DiscoverListPage displays ranking items in list view', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      MaterialApp(
        home: DiscoverListPage(
          channel: ContentChannel.novel,
          title: '热门榜单',
          listType: 'ranking',
          repository: _MockListRepository(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('热门榜单'), findsOneWidget);
    expect(find.text('长风问剑'), findsOneWidget);
    expect(find.text('山止川行'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
  });
}
