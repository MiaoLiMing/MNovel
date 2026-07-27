import 'package:flutter_test/flutter_test.dart';
import 'package:mnovel/features/audiobook/audiobook_controller.dart';

void main() {
  test('听书会把超长段落切成系统 TTS 可安全处理的小段', () {
    final text = '${'甲' * 90}。${'乙' * 90}！${'丙' * 90}';

    final segments = splitTtsSegments(text, maxLength: 120);

    expect(segments.length, greaterThan(1));
    expect(segments.every((segment) => segment.length <= 120), isTrue);
    expect(segments.join(), text);
  });
}
