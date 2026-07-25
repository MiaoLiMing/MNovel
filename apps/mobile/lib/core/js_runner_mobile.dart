import 'dart:convert';

import 'package:flutter/services.dart';

class JsRunner {
  static const _channel = MethodChannel('mnovel/js_runner');

  static Future<String> runFunction(
    String setupCode,
    String functionName,
    List<dynamic> args,
  ) async {
    final argsJson = args.map(jsonEncode).join(', ');
    final script =
        '''
(function() {
  $setupCode
  const result = $functionName($argsJson);
  if (result === undefined || result === null) return '';
  return typeof result === 'string' ? result : JSON.stringify(result);
})()
''';
    final result = await _channel.invokeMethod<String>('evaluate', {
      'script': script,
    });
    return result ?? '';
  }
}
