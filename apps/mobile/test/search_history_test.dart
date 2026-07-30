import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mnovel/data/content_repository.dart';
import 'package:mnovel/domain/content.dart';
import 'package:mnovel/features/detail/content_detail_page.dart';
import 'package:mnovel/features/search/search_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _EmptySearchRepository extends ContentRepository {
  @override
  Future<SearchMeta> searchMeta() async =>
      const SearchMeta(hot: [], suggestions: []);
}

class _UnavailableSearchRepository extends _EmptySearchRepository {
  @override
  Future<List<ContentItem>> discover(
    ContentChannel channel, {
    String query = '',
    String category = '',
    String status = '',
    String wordCount = '',
    String source = '',
    int page = 1,
  }) async => const [
    ContentItem(
      id: 'legacy-broken:book',
      title: '无正文小说',
      creator: '测试作者',
      category: '玄幻',
      summary: '',
      coverAsset: '',
      popularity: '测试来源',
      progress: 0,
      episodeCount: 0,
      sourceId: 'legacy-broken',
      sourceName: '异常来源',
      isLive: true,
      availability: ContentAvailability.unavailable,
      unavailableReason: '当前来源没有可用章节',
    ),
  ];
}

void main() {
  testWidgets('fresh install does not invent recent searches', (tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(
      MaterialApp(home: SearchPage(repository: _EmptySearchRepository())),
    );
    await tester.pumpAndSettle();

    expect(find.text('最近搜索'), findsOneWidget);
    expect(find.byType(ActionChip), findsNothing);
    expect(find.text('诡秘之主'), findsNothing);
  });

  testWidgets('无可用章节的搜索结果显示标识且无法进入详情', (tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(
      MaterialApp(
        home: SearchPage(
          initialQuery: '无正文小说',
          repository: _UnavailableSearchRepository(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('无正文小说'), findsNWidgets(2));
    expect(find.text('当前来源没有可用章节'), findsOneWidget);
    expect(find.byIcon(Icons.block_rounded), findsOneWidget);

    await tester.tap(find.text('无正文小说').first);
    await tester.pumpAndSettle();

    expect(find.byType(ContentDetailPage), findsNothing);
    expect(find.byType(SearchPage), findsOneWidget);
  });
}
