import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mnovel/data/content_repository.dart';
import 'package:mnovel/domain/content.dart';
import 'package:mnovel/features/detail/content_detail_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _DetailRepository extends ContentRepository {
  _DetailRepository(this.result);

  final ContentItem result;

  @override
  Future<ContentItem> detail(ContentItem item) async => result;
}

void main() {
  testWidgets(
    'detail page replaces a lightweight novel item with full detail',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      const lightItem = ContentItem(
        id: '11',
        channel: ContentChannel.novel,
        title: '长风问剑',
        creator: '未知作者',
        category: '未分类',
        summary: '',
        coverAsset: '',
        popularity: '更新中',
        progress: 0,
        episodeCount: 0,
        sourceId: 'novel-test',
        sourceName: '开放书源',
        isLive: true,
      );
      const detailItem = ContentItem(
        id: '11',
        channel: ContentChannel.novel,
        title: '长风问剑',
        creator: '山止川行',
        category: '仙侠小说',
        summary: '这是一段长风问剑小说剧情简介。',
        coverAsset: '',
        popularity: '12万人在读',
        progress: 0,
        episodeCount: 12,
        sourceId: 'novel-test',
        sourceName: '开放书源',
        isLive: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ContentDetailPage(
            item: lightItem,
            repository: _DetailRepository(detailItem),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('长风问剑'), findsOneWidget);
      expect(find.text('山止川行'), findsOneWidget);
      expect(find.textContaining('仙侠小说'), findsOneWidget);
      expect(find.text('这是一段长风问剑小说剧情简介。'), findsOneWidget);
      expect(find.text('12章'), findsOneWidget);
      expect(find.text('开始阅读'), findsOneWidget);
    },
  );
}
