import 'package:flutter_test/flutter_test.dart';
import 'package:mnovel/data/source_store.dart';
import 'package:mnovel/domain/content_source.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test(
    'loads the APK legacy source catalog without duplicating primary sources',
    () async {
      final sources = await SourceStore().list();

      expect(sources.length, greaterThan(1100));
      expect(sources.take(3).map((source) => source.id), const [
        'miui-reader-rule',
        'shuchong-rule',
        'xntk-rule',
      ]);
      expect(
        sources.where((source) => source.kind == SourceKind.legacy).length,
        greaterThan(1100),
      );
      expect(
        sources.any(
          (source) =>
              source.name == '爱豆看书' && source.endpoint.contains('a6ksw.com'),
        ),
        isTrue,
      );
      expect(
        sources
            .where((source) => source.kind == SourceKind.legacy)
            .every((source) => source.enabled),
        isTrue,
      );
    },
  );

  test('persists a legacy source disable override', () async {
    final store = SourceStore();
    final source = (await store.list()).firstWhere(
      (item) =>
          item.kind == SourceKind.legacy &&
          item.compatibility == 'compatible_core',
    );

    await store.setEnabled(source.id, false);
    final reloaded = await SourceStore().list();

    expect(
      reloaded.firstWhere((item) => item.id == source.id).enabled,
      isFalse,
    );
  });

  test('ignores the retired v1 disabled defaults', () async {
    SharedPreferences.setMockInitialValues({
      'content.sources.enabled.v1': '{"miui-reader-rule":false}',
    });

    final source = (await SourceStore().list()).first;

    expect(source.id, 'miui-reader-rule');
    expect(source.enabled, isTrue);
  });
}
