import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'web_image_stub.dart' if (dart.library.js_util) 'web_image_web.dart';

class ContentCover extends StatelessWidget {
  const ContentCover({
    super.key,
    required this.asset,
    this.width,
    this.height,
    this.radius = 12,
  });

  final String asset;
  final double? width;
  final double? height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final isAssetUrl = asset.startsWith('asset://');
    final resolvedAsset = isAssetUrl ? 'assets/${asset.substring(8)}' : asset;

    final isNetwork =
        resolvedAsset.startsWith('http://') ||
        resolvedAsset.startsWith('https://');

    final image = isNetwork
        ? (kIsWeb
              ? createWebImage(resolvedAsset, width, height)
              : Image.network(
                  resolvedAsset,
                  headers: const {
                    'User-Agent':
                        'Mozilla/5.0 (Linux; Android 13; Mobile) '
                        'AppleWebKit/537.36 (KHTML, like Gecko) '
                        'Chrome/120.0.0.0 Mobile Safari/537.36',
                  },
                  width: width,
                  height: height,
                  fit: BoxFit.cover,
                  filterQuality: FilterQuality.medium,
                  errorBuilder: _error,
                ))
        : Image.asset(
            resolvedAsset,
            width: width,
            height: height,
            fit: BoxFit.cover,
            filterQuality: FilterQuality.medium,
            errorBuilder: _error,
          );
    return ClipRRect(borderRadius: BorderRadius.circular(radius), child: image);
  }

  Widget _error(BuildContext context, Object error, StackTrace? stackTrace) =>
      ColoredBox(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: .12),
        child: SizedBox(
          width: width,
          height: height,
          child: const Icon(Icons.image_not_supported_outlined),
        ),
      );
}
