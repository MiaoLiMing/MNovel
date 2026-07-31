import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mnovel/data/content_repository.dart';
import 'package:mnovel/data/source_store.dart';
import 'package:mnovel/domain/content.dart';
import 'package:mnovel/domain/content_source.dart';
import 'package:mnovel/features/profile/source_management_page.dart';

class _SourceStore extends SourceStore {
  @override
  Future<List<ContentSource>> list({bool refresh = false}) async => const [
    ContentSource(
      id: 'healthy-one',
      name: '健康书源一',
      description: '已验证',
      channels: {ContentChannel.novel},
      kind: SourceKind.legacy,
      endpoint: 'https://one.example',
      builtIn: true,
      health: SourceHealth.healthy,
    ),
    ContentSource(
      id: 'healthy-two',
      name: '健康书源二',
      description: '已验证',
      channels: {ContentChannel.novel},
      kind: SourceKind.legacy,
      endpoint: 'https://two.example',
      builtIn: true,
      health: SourceHealth.healthy,
    ),
  ];
}

class _Repository extends ContentRepository {
  @override
  Future<SourceAuditProgress> sourceAuditStatus() async =>
      const SourceAuditProgress(
        state: SourceAuditState.completed,
        total: 2,
        completed: 2,
        healthy: 2,
        quarantined: 0,
      );
}

void main() {
  testWidgets('书源页只显示统一健康列表且没有分类分组与开关', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SourceManagementPage(
          repository: _Repository(),
          store: _SourceStore(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('我的书源'), findsOneWidget);
    expect(find.text('健康书源一'), findsOneWidget);
    expect(find.text('健康书源二'), findsOneWidget);
    expect(find.textContaining('已验证 2 个'), findsOneWidget);
    expect(find.text('全部检测'), findsOneWidget);
    expect(find.byType(ChoiceChip), findsNothing);
    expect(find.byType(Switch), findsNothing);
    expect(find.text('内置小说源'), findsNothing);
    expect(find.text('APK 书源目录'), findsNothing);
    expect(find.byIcon(Icons.check_rounded), findsNWidgets(2));
  });
}
