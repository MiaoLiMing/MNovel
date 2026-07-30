import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mnovel/app/mnovel_app.dart';
import 'package:mnovel/data/content_repository.dart';
import 'package:mnovel/data/source_store.dart';
import 'package:mnovel/domain/content.dart';
import 'package:mnovel/domain/content_source.dart';
import 'package:mnovel/features/reader/reader_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fixtures/demo_repository.dart';

class _FailingNextChapterRepository extends ContentRepository {
  @override
  Future<Chapter> chapter(
    ContentItem item,
    int index, {
    bool preferOffline = true,
  }) async {
    if (index == 0) {
      return const Chapter(
        index: 0,
        title: '第一章 可正常阅读',
        paragraphs: ['当前章节正文。'],
      );
    }
    throw const ContentRepositoryException('当前网络不可用，且本章尚未下载');
  }
}

class _AlwaysFailingChapterRepository extends ContentRepository {
  int calls = 0;

  @override
  Future<Chapter> chapter(
    ContentItem item,
    int index, {
    bool preferOffline = true,
  }) async {
    calls++;
    throw const ContentRepositoryException('Not Found');
  }
}

void main() {
  Future<void> pumpUntilFound(
    WidgetTester tester,
    Finder finder, {
    int attempts = 200,
  }) async {
    for (var attempt = 0; attempt < attempts; attempt++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 25)),
      );
      await tester.pump(const Duration(milliseconds: 100));
      if (finder.evaluate().isNotEmpty) return;
    }
    final visibleTexts = tester
        .widgetList<Text>(find.byType(Text))
        .map((widget) => widget.data)
        .whereType<String>()
        .join(' | ');
    fail('等待目标内容超时。当前文本：$visibleTexts');
  }

  testWidgets('主导航只展示书架、书城和我的', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const MNovelApp());
    await tester.pumpAndSettle();

    expect(find.text('书架'), findsWidgets);
    expect(find.text('书城'), findsOneWidget);
    expect(find.text('我的'), findsOneWidget);
    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).destinations,
      hasLength(3),
    );
    expect(find.text('最近阅读'), findsOneWidget);
  });

  testWidgets('我的页面可以进入书源管理', (tester) async {
    SourceStore.clearMemoryCache();
    SharedPreferences.setMockInitialValues({
      'content.sources.verified.v1': jsonEncode([
        {
          'id': 'verified-demo',
          'name': '已验证小说源',
          'description': '已验证',
          'channels': ['novel'],
          'kind': 'legacy',
          'endpoint': 'https://verified.example',
          'enabled': true,
          'built_in': true,
          'health': 'healthy',
        },
      ]),
    });
    await tester.pumpWidget(const MNovelApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('我的'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('书源管理'));
    await pumpUntilFound(tester, find.textContaining('已验证 1 个'));
    await tester.pumpAndSettle();

    expect(find.text('我的书源'), findsOneWidget);
    expect(find.text('已验证小说源'), findsOneWidget);
    expect(find.byType(ChoiceChip), findsNothing);
    expect(find.byType(Switch), findsNothing);
  });

  testWidgets('未经过服务端巡检的自定义书源不会混入健康目录', (tester) async {
    SourceStore.clearMemoryCache();
    SharedPreferences.setMockInitialValues({
      'content.sources.verified.v1': '[]',
    });
    await SourceStore().addCustom(
      const ContentSource(
        id: 'custom-editable',
        name: '我的可编辑书源',
        description: '仅保存在本机',
        channels: {ContentChannel.novel},
        kind: SourceKind.json,
        endpoint: 'https://example.com/catalog.json',
        builtIn: false,
      ),
    );
    await tester.pumpWidget(const MNovelApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('我的'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('书源管理'));
    await pumpUntilFound(tester, find.textContaining('已验证 0 个'));
    await tester.pumpAndSettle();

    expect(find.text('我的可编辑书源'), findsNothing);
    expect(find.text('编辑书源'), findsNothing);
    expect(find.byType(Switch), findsNothing);
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

  testWidgets('长章节先翻章内页，不会提前切到下一章', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({'reader.pageMode': 2});
    final base = DemoRepository.items.first;
    final item = base.copyWith(episodeCount: 2);
    final chapters = [
      Chapter(
        index: 0,
        title: '第一章 长章节',
        paragraphs: List.generate(
          70,
          (index) => '这是第 $index 段很长的正文，用于验证阅读器会先切换章内页码。',
        ),
      ),
      const Chapter(index: 1, title: '第二章 不应提前出现', paragraphs: ['下一章正文']),
    ];
    await tester.pumpWidget(
      MaterialApp(
        home: ReaderPage(item: item, initialChapters: chapters),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('第一章 长章节'), findsWidgets);
    await tester.drag(find.byType(PageView), const Offset(-340, 0));
    await tester.pumpAndSettle();

    expect(find.textContaining('第一章 长章节'), findsOneWidget);
    expect(find.textContaining('第二章 不应提前出现'), findsNothing);
    expect(find.textContaining('本章 2 /'), findsOneWidget);
  });

  testWidgets('仿真翻页模式启用透视明暗渲染', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({'reader.pageMode': 1});
    final item = DemoRepository.items.first;
    await tester.pumpWidget(
      MaterialApp(
        home: ReaderPage(
          item: item,
          initialChapters: const DemoRepository().chaptersFor(item),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(ColorFiltered), findsWidgets);
  });

  testWidgets('阅读页右下角听书入口可进入完整听书页', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    final item = DemoRepository.items.first;
    await tester.pumpWidget(
      MaterialApp(
        home: ReaderPage(
          item: item,
          initialChapters: const DemoRepository().chaptersFor(item),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.headphones_rounded));
    await tester.pumpAndSettle();

    expect(find.text('听书'), findsOneWidget);
    expect(find.text('目录'), findsOneWidget);
    expect(find.text('定时'), findsOneWidget);
    expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
  });

  testWidgets('下一章加载失败会回到当前章节而不是进入错误页', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({'reader.pageMode': 2});
    final base = DemoRepository.items.first;
    final item = base.copyWith(episodeCount: 2);
    await tester.pumpWidget(
      MaterialApp(
        home: ReaderPage(
          item: item,
          repository: _FailingNextChapterRepository(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.drag(find.byType(PageView), const Offset(-340, 0));
    await tester.pumpAndSettle();

    expect(find.textContaining('第一章 可正常阅读'), findsWidgets);
    expect(find.textContaining('已返回当前章节'), findsOneWidget);
    expect(find.text('重试'), findsOneWidget);
  });

  testWidgets('首次章节失败后保持稳定错误态且不自动重复请求', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    final repository = _AlwaysFailingChapterRepository();
    final item = DemoRepository.items.first.copyWith(episodeCount: 1);

    await tester.pumpWidget(
      MaterialApp(
        home: ReaderPage(item: item, repository: repository),
      ),
    );
    await pumpUntilFound(tester, find.text('章节加载失败'));

    expect(repository.calls, 1);
    expect(find.text('当前来源没有提供本章正文'), findsOneWidget);

    tester.view.physicalSize = const Size(410, 860);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));

    expect(repository.calls, 1);
    expect(find.text('章节加载失败'), findsOneWidget);
  });
}
