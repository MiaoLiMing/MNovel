import 'content.dart';

enum SourceKind { localCatalog, gutendex, tvmaze, itunes, json, js }

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
    id: 'qidian',
    name: '起点中文网',
    description: 'https://www.qidian.com',
    channels: {ContentChannel.novel},
    kind: SourceKind.localCatalog,
    endpoint: 'https://www.qidian.com',
    builtIn: true,
    priority: 100,
  ),
  ContentSource(
    id: 'zongheng',
    name: '纵横中文网',
    description: 'https://www.zongheng.com',
    channels: {ContentChannel.novel},
    kind: SourceKind.localCatalog,
    endpoint: 'https://www.zongheng.com',
    builtIn: true,
    priority: 90,
  ),
  ContentSource(
    id: 'fanqie',
    name: '番茄小说',
    description: 'https://fanqienovel.com',
    channels: {ContentChannel.novel},
    kind: SourceKind.localCatalog,
    endpoint: 'https://fanqienovel.com',
    builtIn: true,
    priority: 80,
  ),
  ContentSource(
    id: 'qimao',
    name: '七猫小说',
    description: 'https://www.qimao.com',
    channels: {ContentChannel.novel},
    kind: SourceKind.localCatalog,
    endpoint: 'https://www.qimao.com',
    builtIn: true,
    priority: 70,
  ),
  ContentSource(
    id: 'faloo',
    name: '飞卢小说',
    description: 'https://b.faloo.com',
    channels: {ContentChannel.novel},
    kind: SourceKind.localCatalog,
    endpoint: 'https://b.faloo.com',
    builtIn: true,
    priority: 60,
    health: SourceHealth.checking,
  ),
  ContentSource(
    id: 'jjwxc',
    name: '晋江文学城',
    description: 'https://www.jjwxc.net',
    channels: {ContentChannel.novel},
    kind: SourceKind.localCatalog,
    endpoint: 'https://www.jjwxc.net',
    builtIn: true,
    priority: 50,
  ),
  ContentSource(
    id: 'ciweimao',
    name: '刺猬猫',
    description: 'https://www.ciweimao.com',
    channels: {ContentChannel.novel},
    kind: SourceKind.localCatalog,
    endpoint: 'https://www.ciweimao.com',
    enabled: false,
    builtIn: true,
    priority: 40,
  ),
  ContentSource(
    id: 'custom-example',
    name: '自定义书源示例',
    description: '本地自定义',
    channels: {ContentChannel.novel},
    kind: SourceKind.json,
    endpoint: '[]',
    enabled: false,
    builtIn: true,
    priority: 30,
    health: SourceHealth.configurationRequired,
  ),
];
