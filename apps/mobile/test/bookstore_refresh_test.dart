import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mnovel/data/content_repository.dart';
import 'package:mnovel/domain/content.dart';
import 'package:mnovel/features/bookstore/bookstore_page.dart';

class _RefreshRepository extends ContentRepository {
  int calls = 0;

  @override
  Future<List<ContentItem>> discover(
    ContentChannel channel, {
    String query = '',
    String category = '',
  }) async {
    calls += 1;
    return const [];
  }
}

void main() {
  testWidgets('bookstore channels support pull to refresh', (tester) async {
    final repository = _RefreshRepository();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: BookstorePage(repository: repository)),
      ),
    );
    await tester.pumpAndSettle();
    expect(repository.calls, 1);

    await tester.drag(
      find.byKey(const PageStorageKey('bookstore-scroll-novel')),
      const Offset(0, 320),
    );
    await tester.pumpAndSettle();
    expect(repository.calls, 2);

    await tester.tap(find.text('短剧'));
    await tester.pumpAndSettle();
    await tester.drag(
      find.byKey(const PageStorageKey('bookstore-scroll-shortDrama')),
      const Offset(0, 320),
    );
    await tester.pumpAndSettle();
    expect(repository.calls, 4);
  });
}
