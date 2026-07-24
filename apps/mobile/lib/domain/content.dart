enum ContentChannel { novel }

extension ContentChannelLabel on ContentChannel {
  String get label => '小说';
}

enum NovelStatus { serializing, completed }

extension NovelStatusLabel on NovelStatus {
  String get label => switch (this) {
    NovelStatus.serializing => '连载中',
    NovelStatus.completed => '已完结',
  };
}

class MediaEpisode {
  const MediaEpisode({required this.name, required this.url});

  final String name;
  final String url;

  factory MediaEpisode.fromJson(Map<String, dynamic> json) => MediaEpisode(
    name: json['name'] as String? ?? '章',
    url: json['url'] as String? ?? '',
  );

  Map<String, dynamic> toJson() => {'name': name, 'url': url};
}

class MediaPlaylist {
  const MediaPlaylist({required this.name, required this.episodes});

  final String name;
  final List<MediaEpisode> episodes;

  factory MediaPlaylist.fromJson(Map<String, dynamic> json) => MediaPlaylist(
    name: json['name'] as String? ?? '默认目录',
    episodes: (json['episodes'] as List<dynamic>? ?? const [])
        .map(
          (value) =>
              MediaEpisode.fromJson(Map<String, dynamic>.from(value as Map)),
        )
        .where((episode) => episode.url.isNotEmpty)
        .toList(growable: false),
  );

  Map<String, dynamic> toJson() => {
    'name': name,
    'episodes': episodes.map((episode) => episode.toJson()).toList(),
  };
}

class ContentItem {
  const ContentItem({
    required this.id,
    this.channel = ContentChannel.novel,
    required this.title,
    required this.creator,
    required this.category,
    required this.summary,
    required this.coverAsset,
    required this.popularity,
    required this.progress,
    required this.episodeCount,
    this.sourceId = 'mnovel-curated',
    this.sourceName = '内置书库',
    this.isLive = false,
    this.score = 0,
    this.ratingCount = 0,
    this.wordCount = 0,
    this.status = NovelStatus.serializing,
    this.latestChapter = '',
    this.tags = const [],
    this.sourceLabels = const [],
    this.updateFrequency = '持续更新',
    this.chapterUrls,
    this.localChapters,
    this.mediaPlaylists = const [],
  });

  final String id;
  final ContentChannel channel;
  final String title;
  final String creator;
  final String category;
  final String summary;
  final String coverAsset;
  final String popularity;
  final double progress;
  final int episodeCount;
  final String sourceId;
  final String sourceName;
  final bool isLive;
  final double score;
  final int ratingCount;
  final int wordCount;
  final NovelStatus status;
  final String latestChapter;
  final List<String> tags;
  final List<String> sourceLabels;
  final String updateFrequency;
  final List<String>? chapterUrls;
  final List<Map<String, dynamic>>? localChapters;
  final List<MediaPlaylist> mediaPlaylists;

  String get unitLabel => '章';

  bool get hasPlayableMedia => false;

  String get wordCountLabel {
    if (wordCount >= 10000) {
      final value = wordCount / 10000;
      return '${value >= 100 ? value.round() : value.toStringAsFixed(1)}万字';
    }
    return '$wordCount字';
  }

  ContentItem copyWith({
    double? progress,
    String? title,
    String? creator,
    String? category,
    String? summary,
    String? coverAsset,
    String? popularity,
    int? episodeCount,
    String? sourceId,
    String? sourceName,
    double? score,
    int? ratingCount,
    int? wordCount,
    NovelStatus? status,
    String? latestChapter,
    List<String>? tags,
    List<String>? sourceLabels,
    String? updateFrequency,
    List<MediaPlaylist>? mediaPlaylists,
  }) => ContentItem(
    id: id,
    channel: ContentChannel.novel,
    title: title ?? this.title,
    creator: creator ?? this.creator,
    category: category ?? this.category,
    summary: summary ?? this.summary,
    coverAsset: coverAsset ?? this.coverAsset,
    popularity: popularity ?? this.popularity,
    progress: progress ?? this.progress,
    episodeCount: episodeCount ?? this.episodeCount,
    sourceId: sourceId ?? this.sourceId,
    sourceName: sourceName ?? this.sourceName,
    isLive: isLive,
    score: score ?? this.score,
    ratingCount: ratingCount ?? this.ratingCount,
    wordCount: wordCount ?? this.wordCount,
    status: status ?? this.status,
    latestChapter: latestChapter ?? this.latestChapter,
    tags: tags ?? this.tags,
    sourceLabels: sourceLabels ?? this.sourceLabels,
    updateFrequency: updateFrequency ?? this.updateFrequency,
    chapterUrls: chapterUrls,
    localChapters: localChapters,
    mediaPlaylists: mediaPlaylists ?? this.mediaPlaylists,
  );

  factory ContentItem.fromJson(Map<String, dynamic> json) {
    final parsedChapterUrls = (json['chapter_urls'] as List<dynamic>?)
        ?.map((value) => value.toString())
        .toList(growable: false);
    final mediaPlaylists =
        (json['media_playlists'] as List<dynamic>? ?? const [])
            .map(
              (value) => MediaPlaylist.fromJson(
                Map<String, dynamic>.from(value as Map),
              ),
            )
            .where((playlist) => playlist.episodes.isNotEmpty)
            .toList(growable: false);

    final idVal = (json['id'] ?? json['vod_id'])?.toString() ?? '';
    final titleVal =
        json['title'] as String? ?? json['vod_name'] as String? ?? '未命名小说';
    final creatorVal =
        json['creator'] as String? ?? json['author'] as String? ?? '未知作者';
    final categoryVal =
        json['category'] as String? ?? json['type_name'] as String? ?? '分类小说';
    final summaryVal =
        json['summary'] as String? ?? json['vod_content'] as String? ?? '';

    var coverVal = json['cover'] as String? ?? json['vod_pic'] as String? ?? '';
    if (coverVal.startsWith('//')) {
      coverVal = 'https:$coverVal';
    }

    final popularityVal = json['popularity'] as String? ?? '热门推荐';
    final explicitUnitCount = (json['unit_count'] as num?)?.toInt() ?? 0;
    final unitCountVal = explicitUnitCount > 0
        ? explicitUnitCount
        : parsedChapterUrls?.length ?? 10;
    final rawStatus = json['status']?.toString() ?? 'serializing';

    return ContentItem(
      id: idVal,
      channel: ContentChannel.novel,
      title: titleVal,
      creator: creatorVal,
      category: categoryVal,
      summary: summaryVal,
      coverAsset: coverVal,
      popularity: popularityVal,
      progress: (json['progress'] as num?)?.toDouble() ?? 0,
      episodeCount: unitCountVal,
      sourceId: json['source_id'] as String? ?? 'unknown',
      sourceName: json['source_name'] as String? ?? '开放书源',
      isLive: json['is_live'] as bool? ?? false,
      score: (json['score'] as num?)?.toDouble() ?? 0,
      ratingCount: (json['rating_count'] as num?)?.toInt() ?? 0,
      wordCount: (json['word_count'] as num?)?.toInt() ?? 0,
      status: rawStatus == 'completed'
          ? NovelStatus.completed
          : NovelStatus.serializing,
      latestChapter: json['latest_chapter'] as String? ?? '',
      tags: (json['tags'] as List<dynamic>? ?? const [])
          .map((value) => value.toString())
          .toList(growable: false),
      sourceLabels: (json['source_labels'] as List<dynamic>? ?? const [])
          .map((value) => value.toString())
          .toList(growable: false),
      updateFrequency: json['update_frequency'] as String? ?? '持续更新',
      chapterUrls: parsedChapterUrls,
      mediaPlaylists: mediaPlaylists,
      localChapters: (json['chapters'] as List<dynamic>?)
          ?.map((value) => Map<String, dynamic>.from(value as Map))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'channel': channel.name,
    'title': title,
    'creator': creator,
    'category': category,
    'summary': summary,
    'cover': coverAsset,
    'popularity': popularity,
    'progress': progress,
    'unit_count': episodeCount,
    'source_id': sourceId,
    'source_name': sourceName,
    'is_live': isLive,
    'score': score,
    'rating_count': ratingCount,
    'word_count': wordCount,
    'status': status.name,
    'latest_chapter': latestChapter,
    'tags': tags,
    'source_labels': sourceLabels,
    'update_frequency': updateFrequency,
    if (chapterUrls != null) 'chapter_urls': chapterUrls,
    if (localChapters != null) 'chapters': localChapters,
    if (mediaPlaylists.isNotEmpty)
      'media_playlists': mediaPlaylists
          .map((playlist) => playlist.toJson())
          .toList(),
  };
}

class Chapter {
  const Chapter({
    required this.title,
    required this.paragraphs,
    this.index = 0,
  });

  final String title;
  final List<String> paragraphs;
  final int index;

  factory Chapter.fromJson(Map<String, dynamic> json) => Chapter(
    title: json['title'] as String? ?? '章节',
    paragraphs: (json['paragraphs'] as List<dynamic>? ?? const [])
        .map((value) => value.toString())
        .toList(growable: false),
    index: (json['index'] as num?)?.toInt() ?? 0,
  );
}

class ChapterEntry {
  const ChapterEntry({required this.index, required this.title});

  final int index;
  final String title;

  factory ChapterEntry.fromJson(Map<String, dynamic> json) => ChapterEntry(
    index: (json['index'] as num?)?.toInt() ?? 0,
    title: json['title'] as String? ?? '章节',
  );
}
