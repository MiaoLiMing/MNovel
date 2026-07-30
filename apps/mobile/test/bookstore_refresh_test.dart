import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mnovel/data/content_repository.dart';
import 'package:mnovel/features/bookstore/bookstore_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fixtures/demo_repository.dart';

class _RefreshRepository extends ContentRepository {
  int calls = 0;

  @override
  Future<HomeData> home({String channel = '推荐'}) async {
    calls += 1;
    return HomeData(
      featured: DemoRepository.items.first,
      carousel: DemoRepository.items,
      editorsPick: DemoRepository.items,
      latest: DemoRepository.items,
    );
  }
}

class _DelayedRepository extends ContentRepository {
  final response = Completer<HomeData>();

  @override
  Future<HomeData> home({String channel = '推荐'}) => response.future;
}

class _EmptyRepository extends ContentRepository {
  int calls = 0;

  @override
  Future<HomeData> home({String channel = '推荐'}) async {
    calls += 1;
    return const HomeData(
      featured: null,
      carousel: [],
      editorsPick: [],
      latest: [],
      sourceCount: 2,
      failedSourceCount: 2,
    );
  }
}

class _FailingRepository extends ContentRepository {
  @override
  Future<HomeData> home({String channel = '推荐'}) {
    throw const ContentRepositoryException('所有启用书源均暂不可用');
  }
}

void main() {
  testWidgets('书城支持下拉刷新', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final repository = _RefreshRepository();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: BookstorePage(repository: repository)),
      ),
    );
    await tester.pumpAndSettle();
    expect(repository.calls, 1);

    await tester.drag(
      find.byKey(const PageStorageKey('bookstore-scroll')),
      const Offset(0, 360),
    );
    await tester.pumpAndSettle();
    expect(repository.calls, 2);
  });

  testWidgets('书城请求期间不显示本地试读目录', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final repository = _DelayedRepository();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: BookstorePage(repository: repository)),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('诡秘之主'), findsNothing);

    repository.response.complete(
      const HomeData(featured: null, carousel: [], editorsPick: [], latest: []),
    );
    await tester.pumpAndSettle();
    expect(find.text('暂时没有可展示的小说'), findsOneWidget);
    expect(find.text('诡秘之主'), findsNothing);
  });

  testWidgets('书源零数据时显示可重试的专业空状态', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final repository = _EmptyRepository();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: BookstorePage(repository: repository)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.auto_stories_outlined), findsOneWidget);
    expect(find.text('暂时没有可展示的小说'), findsOneWidget);
    expect(find.text('重新加载'), findsOneWidget);

    await tester.tap(find.text('重新加载'));
    await tester.pumpAndSettle();
    expect(repository.calls, 2);
  });

  testWidgets('全部书源不可用时显示错误空状态', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: BookstorePage(repository: _FailingRepository())),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.cloud_off_outlined), findsOneWidget);
    expect(find.text('书城暂时不可用'), findsOneWidget);
    expect(find.textContaining('所有启用书源均暂不可用'), findsOneWidget);
    expect(find.text('诡秘之主'), findsNothing);
  });
}
