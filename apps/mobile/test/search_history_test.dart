import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mnovel/data/content_repository.dart';
import 'package:mnovel/features/search/search_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _EmptySearchRepository extends ContentRepository {
  @override
  Future<SearchMeta> searchMeta() async =>
      const SearchMeta(hot: [], suggestions: []);
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
}
