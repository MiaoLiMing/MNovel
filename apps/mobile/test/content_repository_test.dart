import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mnovel/data/content_repository.dart';
import 'package:mnovel/data/source_store.dart';
import 'package:mnovel/domain/content.dart';
import 'package:mnovel/domain/content_source.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockSourceStore extends SourceStore {
  _MockSourceStore({required this.enabled});
  final bool enabled;

  @override
  Future<List<ContentSource>> list() async {
    return [
      ContentSource(
        id: 'gutendex',
        name: 'Project Gutenberg',
        description: 'test',
        channels: const {ContentChannel.novel},
        kind: SourceKind.gutendex,
        endpoint: 'https://gutendex.com/books/',
        enabled: enabled,
      ),
    ];
  }
}

void main() {
  test(
    'disabled sources do not fall back to the local curated catalog',
    () async {
      SharedPreferences.setMockInitialValues({});
      final store = _MockSourceStore(enabled: false);
      final repository = ContentRepository(sourceStore: store);

      expect(await repository.discover(ContentChannel.novel), isEmpty);
    },
  );

  test(
    'a source error is reported instead of returning mock content',
    () async {
      SharedPreferences.setMockInitialValues({});
      final store = _MockSourceStore(enabled: true);
      final repository = ContentRepository(
        sourceStore: store,
        client: MockClient((_) async => http.Response('', 503)),
      );

      expect(
        repository.discover(ContentChannel.novel),
        throwsA(isA<ContentRepositoryException>()),
      );
    },
  );
}
