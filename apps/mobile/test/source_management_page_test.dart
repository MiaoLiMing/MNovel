import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mnovel/features/profile/source_management_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('千级书源目录完成加载后不持续调度动画', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const MaterialApp(home: SourceManagementPage()));

    for (var attempt = 0; attempt < 40; attempt++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 25)),
      );
      await tester.pump(const Duration(milliseconds: 100));
      if (find.textContaining('当前显示').evaluate().isNotEmpty) break;
    }
    await tester.pumpAndSettle();

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.textContaining('当前显示'), findsOneWidget);
  });
}
