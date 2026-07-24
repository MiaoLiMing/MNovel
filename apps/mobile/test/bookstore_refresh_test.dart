import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mnovel/data/content_repository.dart';
import 'package:mnovel/data/curated_catalog.dart';
import 'package:mnovel/features/bookstore/bookstore_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _RefreshRepository extends ContentRepository {
  int calls = 0;

  @override
  Future<HomeData> home({String channel = '推荐'}) async {
    calls += 1;
    return HomeData(
      featured: curatedCatalog[1],
      carousel: curatedCatalog.take(4).toList(),
      editorsPick: curatedCatalog.skip(2).take(4).toList(),
      latest: curatedCatalog.reversed.take(4).toList(),
    );
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
}
