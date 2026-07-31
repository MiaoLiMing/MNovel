import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mnovel/data/source_store.dart';
import 'package:mnovel/domain/content_source.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    SourceStore.clearMemoryCache();
  });

  test('只加载服务端验证通过的健康书源并统一为内置启用', () async {
    final store = SourceStore(
      baseUrl: 'https://api.example/mnovel',
      client: MockClient(
        (_) async => http.Response.bytes(
          utf8.encode(
            jsonEncode([
              {
                'id': 'miui-reader-rule',
                'name': '免费小说之王（MIUI）',
                'endpoint': 'https://one.example',
                'priority': 90,
                'health': 'healthy',
                'latency_ms': 120,
                'kind': 'backend_rule',
              },
              {
                'id': 'legacy-healthy-two',
                'name': '健康书源二',
                'endpoint': 'https://two.example',
                'priority': 80,
                'health': 'healthy',
                'latency_ms': 240,
              },
            ]),
          ),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        ),
      ),
    );

    final sources = await store.list();

    expect(sources.map((source) => source.name), ['免费小说之王（MIUI）', '健康书源二']);
    expect(sources.every((source) => source.builtIn), isTrue);
    expect(sources.every((source) => source.enabled), isTrue);
    expect(
      sources.every((source) => source.health == SourceHealth.healthy),
      isTrue,
    );
    expect(sources.first.kind, SourceKind.backendRule);
    expect(sources.last.kind, SourceKind.legacy);
  });

  test('网络失败时使用最近一次健康目录缓存', () async {
    SharedPreferences.setMockInitialValues({
      'content.sources.verified.v1': jsonEncode([
        {
          'id': 'legacy-cached',
          'name': '缓存健康源',
          'description': '已验证',
          'channels': ['novel'],
          'kind': 'legacy',
          'endpoint': 'https://cached.example',
          'enabled': true,
          'built_in': true,
          'health': 'healthy',
        },
      ]),
    });
    final store = SourceStore(
      client: MockClient((_) async => http.Response('', 503)),
    );

    final sources = await store.list();

    expect(sources.single.name, '缓存健康源');
  });
}
