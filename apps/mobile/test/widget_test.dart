import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mnovel/app/mnovel_app.dart';
import 'package:mnovel/features/reader/reader_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fixtures/demo_repository.dart';

void main() {
  testWidgets('主导航完整展示书架、书城、分类和我的', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const MNovelApp());
    await tester.pumpAndSettle();

    expect(find.text('书架'), findsWidgets);
    expect(find.text('书城'), findsOneWidget);
    expect(find.text('分类'), findsOneWidget);
    expect(find.text('我的'), findsOneWidget);
    expect(find.text('最近阅读'), findsOneWidget);
  });

  testWidgets('我的页面可以进入书源管理', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const MNovelApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('我的'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('书源管理'));
    await tester.pumpAndSettle();

    expect(find.text('起点中文网'), findsOneWidget);
    expect(find.text('添加书源'), findsOneWidget);
  });

  testWidgets('阅读器控制栏可以打开完整设置', (tester) async {
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

    expect(find.text('上一章'), findsOneWidget);
    expect(find.text('下一章'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.text_fields_rounded));
    await tester.pumpAndSettle();
    expect(find.text('阅读设置'), findsOneWidget);
    expect(find.text('字体大小'), findsOneWidget);
    expect(find.text('行间距'), findsOneWidget);
    expect(find.text('翻页动画'), findsOneWidget);
    expect(find.text('简繁转换'), findsOneWidget);
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

    expect(find.text('第 1 章  风从远山来'), findsOneWidget);
    await tester.drag(find.byType(PageView), const Offset(-340, 0));
    await tester.pumpAndSettle();

    expect(find.text('第 2 章  风从远山来'), findsOneWidget);
  });
}
