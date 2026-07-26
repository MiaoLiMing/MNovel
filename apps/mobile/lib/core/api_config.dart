class ApiConfig {
  static const String baseUrl = String.fromEnvironment(
    'MNOVEL_API_URL',
    defaultValue: 'https://www.flowercat.art/api/v1/mnovel',
  );

  static Uri uri(String path, [Map<String, String>? query]) {
    final normalizedPath = path.startsWith('/') ? path : '/$path';
    return Uri.parse(
      '$baseUrl$normalizedPath',
    ).replace(queryParameters: query?.isEmpty ?? true ? null : query);
  }
}
