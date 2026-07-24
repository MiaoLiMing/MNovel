abstract class JsRunner {
  static Future<String> runFunction(
    String setupCode,
    String functionName,
    List<dynamic> args,
  ) {
    throw UnimplementedError('JsRunner is not implemented on this platform');
  }
}
