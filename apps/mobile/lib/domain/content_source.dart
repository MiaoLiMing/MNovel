import 'content.dart';

enum SourceKind {
  localCatalog,
  backendRule,
  backendHtml,
  gutendex,
  wikisource,
  internetArchive,
  tvmaze,
  itunes,
  json,
  js,
}

enum SourceHealth { healthy, checking, error, configurationRequired, unknown }

extension SourceHealthLabel on SourceHealth {
  String get label => switch (this) {
    SourceHealth.healthy => '正常',
    SourceHealth.checking => '测试中',
    SourceHealth.error => '异常',
    SourceHealth.configurationRequired => '待配置',
    SourceHealth.unknown => '未检测',
  };
}

class ContentSource {
  const ContentSource({
    required this.id,
    required this.name,
    required this.description,
    required this.channels,
    required this.kind,
    required this.endpoint,
    this.enabled = true,
    this.builtIn = false,
    this.priority = 50,
    this.health = SourceHealth.healthy,
    this.latencyMs = 0,
    this.rules,
  });

  final String id;
  final String name;
  final String description;
  final Set<ContentChannel> channels;
  final SourceKind kind;
  final String endpoint;
  final bool enabled;
  final bool builtIn;
  final int priority;
  final SourceHealth health;
  final int latencyMs;
  final Map<String, String>? rules;

  ContentSource copyWith({
    String? name,
    String? description,
    String? endpoint,
    bool? enabled,
    int? priority,
    SourceHealth? health,
    int? latencyMs,
  }) => ContentSource(
    id: id,
    name: name ?? this.name,
    description: description ?? this.description,
    channels: channels,
    kind: kind,
    endpoint: endpoint ?? this.endpoint,
    enabled: enabled ?? this.enabled,
    builtIn: builtIn,
    priority: priority ?? this.priority,
    health: health ?? this.health,
    latencyMs: latencyMs ?? this.latencyMs,
    rules: rules,
  );

  factory ContentSource.fromJson(Map<String, dynamic> json) => ContentSource(
    id: json['id'] as String,
    name: json['name'] as String,
    description: json['description'] as String? ?? '自定义小说书源',
    channels: (json['channels'] as List<dynamic>? ?? const ['novel'])
        .map(
          (value) => ContentChannel.values.firstWhere(
            (channel) => channel.name == value,
            orElse: () => ContentChannel.novel,
          ),
        )
        .toSet(),
    kind: SourceKind.values.firstWhere(
      (kind) => kind.name == json['kind'],
      orElse: () => SourceKind.json,
    ),
    endpoint: json['endpoint'] as String? ?? '',
    enabled: json['enabled'] as bool? ?? true,
    builtIn: json['built_in'] as bool? ?? false,
    priority: (json['priority'] as num?)?.toInt() ?? 50,
    health: SourceHealth.values.firstWhere(
      (health) => health.name == json['health'],
      orElse: () => SourceHealth.unknown,
    ),
    latencyMs: (json['latency_ms'] as num?)?.toInt() ?? 0,
    rules: (json['rules'] as Map<dynamic, dynamic>?)?.map(
      (key, value) => MapEntry(key as String, value as String),
    ),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'channels': channels.map((channel) => channel.name).toList(),
    'kind': kind.name,
    'endpoint': endpoint,
    'enabled': enabled,
    'built_in': builtIn,
    'priority': priority,
    'health': health.name,
    'latency_ms': latencyMs,
    if (rules != null) 'rules': rules,
  };
}

const builtInContentSources = <ContentSource>[
  ContentSource(
    id: 'miui-reader-rule',
    name: '免费小说之王（MIUI）',
    description: '统一规则引擎 · JSONPath · 详情/目录/正文在线解析',
    channels: {ContentChannel.novel},
    kind: SourceKind.backendRule,
    endpoint: 'https://reader.browser.miui.com/',
    builtIn: true,
    priority: 120,
    health: SourceHealth.unknown,
  ),
  ContentSource(
    id: 'shuchong-rule',
    name: '书虫中文网',
    description: '统一规则引擎 · CSS Selector · 当前域名状态异常',
    channels: {ContentChannel.novel},
    kind: SourceKind.backendRule,
    endpoint: 'https://www.shuchong.info/',
    builtIn: true,
    priority: 110,
    health: SourceHealth.unknown,
  ),
  ContentSource(
    id: 'xntk-rule',
    name: '567中文',
    description: '统一规则引擎 · CSS Selector · 当前域名不可用',
    channels: {ContentChannel.novel},
    kind: SourceKind.backendRule,
    endpoint: 'http://www.xntk.org/',
    builtIn: true,
    priority: 100,
    health: SourceHealth.unknown,
  ),
];
