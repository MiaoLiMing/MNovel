import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../domain/content.dart';
import 'reader_settings.dart';

class ReaderPageContent {
  const ReaderPageContent({
    required this.chapterIndex,
    required this.pageIndex,
    required this.pageCount,
    required this.chapterTitle,
    required this.text,
    required this.startOffset,
    required this.endOffset,
  });

  final int chapterIndex;
  final int pageIndex;
  final int pageCount;
  final String chapterTitle;
  final String text;
  final int startOffset;
  final int endOffset;

  bool get isFirstPage => pageIndex == 0;
}

class ReaderPaginator {
  const ReaderPaginator();

  static const maxInputCharacters = 120000;

  List<ReaderPageContent> paginate({
    required Chapter chapter,
    required Size viewport,
    required ReaderSettings settings,
    TextScaler textScaler = TextScaler.noScaling,
  }) {
    final usableWidth = math.max(
      80.0,
      viewport.width - settings.horizontalPadding * 2,
    );
    final usableHeight = math.max(120.0, viewport.height - 88);
    final body = chapter.paragraphs
        .map(
          (paragraph) => settings.firstLineIndent
              ? '　　${paragraph.trim()}'
              : paragraph.trim(),
        )
        .where((paragraph) => paragraph.isNotEmpty)
        .join('\n\n');
    if (body.length > maxInputCharacters) {
      throw StateError('单章正文超过安全排版上限');
    }
    if (body.isEmpty) {
      return [
        ReaderPageContent(
          chapterIndex: chapter.index,
          pageIndex: 0,
          pageCount: 1,
          chapterTitle: chapter.title,
          text: '',
          startOffset: 0,
          endOffset: 0,
        ),
      ];
    }

    final style = TextStyle(
      fontSize: settings.fontSize,
      height: settings.lineHeight,
      letterSpacing: settings.letterSpacing,
      fontWeight: FontWeight.w400,
    );
    final titlePainter = TextPainter(
      text: TextSpan(
        text: chapter.title,
        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
      ),
      textDirection: TextDirection.ltr,
      textScaler: textScaler,
      maxLines: 2,
    )..layout(maxWidth: usableWidth);

    final slices = <({int start, int end, String text})>[];
    var offset = 0;
    while (offset < body.length) {
      while (offset < body.length && body[offset] == '\n') {
        offset++;
      }
      if (offset >= body.length) break;
      final maxHeight = math.max(
        80.0,
        usableHeight - (slices.isEmpty ? titlePainter.height + 24 : 0),
      );
      final end = _findPageEnd(
        body: body,
        start: offset,
        maxWidth: usableWidth,
        maxHeight: maxHeight,
        style: style,
        textScaler: textScaler,
      );
      final safeEnd = math.max(offset + 1, end);
      slices.add((
        start: offset,
        end: safeEnd,
        text: body.substring(offset, safeEnd).trim(),
      ));
      offset = safeEnd;
    }

    return List.generate(slices.length, (index) {
      final slice = slices[index];
      return ReaderPageContent(
        chapterIndex: chapter.index,
        pageIndex: index,
        pageCount: slices.length,
        chapterTitle: chapter.title,
        text: slice.text,
        startOffset: slice.start,
        endOffset: slice.end,
      );
    }, growable: false);
  }

  int _findPageEnd({
    required String body,
    required int start,
    required double maxWidth,
    required double maxHeight,
    required TextStyle style,
    required TextScaler textScaler,
  }) {
    var low = start + 1;
    var high = body.length;
    var best = low;
    while (low <= high) {
      final middle = low + ((high - low) ~/ 2);
      final painter = TextPainter(
        text: TextSpan(text: body.substring(start, middle), style: style),
        textDirection: TextDirection.ltr,
        textScaler: textScaler,
      )..layout(maxWidth: maxWidth);
      if (painter.height <= maxHeight) {
        best = middle;
        low = middle + 1;
      } else {
        high = middle - 1;
      }
    }
    if (best >= body.length) return body.length;
    final minimumBreak = start + ((best - start) * .72).floor();
    for (var index = best; index > minimumBreak; index--) {
      if ('\n。！？；，、,.!?;'.contains(body[index - 1])) return index;
    }
    return best;
  }
}
