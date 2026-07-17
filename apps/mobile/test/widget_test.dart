import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mnovel/app/mnovel_app.dart';
import 'package:mnovel/features/reader/reader_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fixtures/demo_repository.dart';

void main() {
  testWidgets('书城默认展示四栏导航与三频道', (tester) async {
    await tester.pumpWidget(const MNovelApp());
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('书城'), findsWidgets);
    expect(find.text('书架'), findsWidgets);
    expect(find.text('分类'), findsWidgets);
    expect(find.text('我的'), findsWidgets);
    expect(find.text('小说'), findsWidgets);
    expect(find.text('短剧'), findsWidgets);
    expect(find.text('视频'), findsWidgets);
  });

  testWidgets('我的内容与存储入口可以进入明细页', (tester) async {
    await tester.pumpWidget(const MNovelApp());
    await tester.pump(const Duration(milliseconds: 500));

    await tester.tap(find.text('我的').last);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('内容源管理'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Open Library'), findsOneWidget);
    expect(find.text('Project Gutenberg OPDS'), findsOneWidget);
    expect(find.text('内容源管理'), findsOneWidget);
  });

  testWidgets('阅读器控制栏联动并打开完整设置', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    final item = DemoRepository.items.first;
    final chapters = const DemoRepository().chaptersFor(item);
    await tester.pumpWidget(
      MaterialApp(
        home: ReaderPage(item: item, initialChapters: chapters),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tapAt(const Offset(200, 320));
    await tester.pumpAndSettle();
    expect(find.text('上一章'), findsOneWidget);
    expect(find.text('下一章'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.text_fields_rounded));
    await tester.pumpAndSettle();
    expect(find.text('阅读设置'), findsOneWidget);
    expect(find.text('亮度'), findsOneWidget);
    expect(find.text('翻页'), findsOneWidget);
    expect(find.text('自动翻页'), findsOneWidget);
  });

  testWidgets('阅读器左滑跨越章节边界', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    final item = DemoRepository.items.first;
    final chapters = const DemoRepository().chaptersFor(item);
    await tester.pumpWidget(
      MaterialApp(
        home: ReaderPage(item: item, initialChapters: chapters),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('第 1 章'), findsOneWidget);
    await tester.drag(find.byType(PageView), const Offset(-340, 0));
    await tester.pumpAndSettle();

    expect(find.textContaining('第 2 章'), findsOneWidget);
  });
}
