import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mnovel/domain/content.dart';
import 'package:mnovel/features/reader/reader_pagination.dart';
import 'package:mnovel/features/reader/reader_settings.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('长章节按真实排版拆成多页并保留字符偏移', () {
    final chapter = Chapter(
      index: 3,
      title: '第四章 很长的一天',
      paragraphs: List.generate(
        80,
        (index) => '这是第 $index 段正文。晨雾沿着山脊散开，人物继续向前走，并认真记录沿途发生的事情。',
      ),
    );
    final pages = const ReaderPaginator().paginate(
      chapter: chapter,
      viewport: const Size(390, 720),
      settings: const ReaderSettings(),
    );

    expect(pages.length, greaterThan(2));
    expect(pages.first.pageIndex, 0);
    expect(pages.first.pageCount, pages.length);
    expect(pages.last.endOffset, greaterThan(pages.first.endOffset));
    for (var index = 1; index < pages.length; index++) {
      expect(
        pages[index].startOffset,
        greaterThanOrEqualTo(pages[index - 1].endOffset),
      );
    }
  });

  test('增大字号会重新分页且页数不会减少', () {
    final chapter = Chapter(
      title: '测试章节',
      paragraphs: List.generate(40, (_) => '一段用于验证字号变化后重新分页的中文正文，内容长度保持一致。'),
    );
    const paginator = ReaderPaginator();
    final normal = paginator.paginate(
      chapter: chapter,
      viewport: const Size(390, 720),
      settings: const ReaderSettings(fontSize: 16),
    );
    final large = paginator.paginate(
      chapter: chapter,
      viewport: const Size(390, 720),
      settings: const ReaderSettings(fontSize: 25),
    );

    expect(large.length, greaterThanOrEqualTo(normal.length));
  });
}
