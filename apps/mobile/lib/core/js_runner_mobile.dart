import 'dart:convert';
import 'package:flutter_js/flutter_js.dart';

class JsRunner {
  static Future<String> runFunction(
    String setupCode,
    String functionName,
    List<dynamic> args,
  ) async {
    final JavascriptRuntime runtime = getJavascriptRuntime();
    try {
      final argsJson = args.map((e) => jsonEncode(e)).join(', ');
      final script = '$setupCode\n$functionName($argsJson);';
      final JsEvalResult result = await runtime.evaluateAsync(script);
      if (result.isError) {
        throw Exception('JS Execution Error: ${result.stringResult}');
      }
      return result.stringResult;
    } finally {
      runtime.dispose();
    }
  }
}
