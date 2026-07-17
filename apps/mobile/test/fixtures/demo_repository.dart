import 'package:mnovel/domain/content.dart';

class DemoRepository {
  const DemoRepository();

  static const items = <ContentItem>[
    ContentItem(
      id: 'novel-sword',
      channel: ContentChannel.novel,
      title: '长风问剑',
      creator: '山止川行',
      category: '仙侠 · 剑道',
      summary: '测试阅读器使用的本地内容。',
      coverAsset: 'assets/covers/cover-changfeng-wenjian.png',
      popularity: '测试数据',
      progress: .36,
      episodeCount: 12,
    ),
  ];

  List<Chapter> chaptersFor(ContentItem item) => List<Chapter>.generate(
    12,
    (index) => Chapter(
      title: '第 ${index + 1} 章  风从远山来',
      paragraphs: const [
        '晨雾沿着山脊缓慢散开，石阶尽头传来一声清越的剑鸣。',
        '林砚停下脚步。他走了整整三日，终于看见云海之上那座只存在于传闻中的山门。',
        '风穿过松林，卷起衣角，也把旧日的疑问重新送到眼前。前路并不明朗，但他已经没有回头的打算。',
        '远处钟声响起，群山依次回应。少年握紧剑鞘，向着石阶更高处走去。',
      ],
    ),
  );
}
