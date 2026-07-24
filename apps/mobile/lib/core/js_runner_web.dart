// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter

import 'dart:convert';
import 'dart:js' as js;

class JsRunner {
  static Future<String> runFunction(
    String setupCode,
    String functionName,
    List<dynamic> args,
  ) async {
    final argsJson = args.map((e) => jsonEncode(e)).join(', ');
    final script =
        '''
      (function() {
        $setupCode
        return $functionName($argsJson);
      })()
    ''';
    final result = js.context.callMethod('eval', [script]);
    if (result == null) return '';
    if (result is String) return result;
    try {
      return jsonEncode(result);
    } catch (_) {
      return result.toString();
    }
  }
}
