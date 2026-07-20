import 'content.dart';

enum SourceKind { localCatalog, gutendex, tvmaze, itunes, json }

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
  });

  final String id;
  final String name;
  final String description;
  final Set<ContentChannel> channels;
  final SourceKind kind;
  final String endpoint;
  final bool enabled;
  final bool builtIn;

  ContentSource copyWith({bool? enabled}) => ContentSource(
    id: id,
    name: name,
    description: description,
    channels: channels,
    kind: kind,
    endpoint: endpoint,
    enabled: enabled ?? this.enabled,
    builtIn: builtIn,
  );

  factory ContentSource.fromJson(Map<String, dynamic> json) => ContentSource(
    id: json['id'] as String,
    name: json['name'] as String,
    description: json['description'] as String? ?? '自定义 JSON 来源',
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
    endpoint: json['endpoint'] as String,
    enabled: json['enabled'] as bool? ?? true,
    builtIn: json['built_in'] as bool? ?? false,
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
  };
}

const builtInContentSources = <ContentSource>[
  ContentSource(
    id: 'local-catalog',
    name: 'MNovel 本地目录',
    description: '随 App 内置的示例内容；无网络时仍可浏览与阅读',
    channels: {
      ContentChannel.novel,
      ContentChannel.shortDrama,
      ContentChannel.video,
    },
    kind: SourceKind.localCatalog,
    endpoint: 'local://catalog',
    builtIn: true,
  ),
  ContentSource(
    id: 'gutendex',
    name: 'Project Gutenberg',
    description: '设备端直连公共领域电子书目录与正文',
    channels: {ContentChannel.novel},
    kind: SourceKind.gutendex,
    endpoint: 'https://gutendex.com/books/',
    builtIn: true,
  ),
  ContentSource(
    id: 'tvmaze',
    name: 'TVmaze 开放数据',
    description: '设备端直连全球公开电视节目元数据',
    channels: {ContentChannel.shortDrama},
    kind: SourceKind.tvmaze,
    endpoint: 'https://api.tvmaze.com',
    builtIn: true,
  ),
  ContentSource(
    id: 'itunes',
    name: 'iTunes Search',
    description: '设备端直连影视目录与预览元数据',
    channels: {ContentChannel.video},
    kind: SourceKind.itunes,
    endpoint: 'https://itunes.apple.com/search',
    builtIn: true,
  ),
];
