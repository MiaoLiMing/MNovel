// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';

// Keep track of registered views to prevent duplicate registrations
final Set<String> _registeredViews = {};

Widget createWebVideoPlayer(String url, String coverUrl) {
  final viewId = 'video-player-${url.hashCode}';

  // Resolve asset:// schema to the correct Flutter Web asset path
  final resolvedCover = coverUrl.startsWith('asset://')
      ? 'assets/assets/covers/${coverUrl.substring(8)}'
      : coverUrl;

  if (!_registeredViews.contains(viewId)) {
    ui_web.platformViewRegistry.registerViewFactory(viewId, (int id) {
      final element = html.VideoElement()
        ..src = url
        ..poster = resolvedCover
        ..autoplay = true
        ..muted =
            true // Required by Chrome to bypass autoplay blocking
        ..controls = true
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.objectFit = 'contain'
        ..style.border = 'none';
      return element;
    });
    _registeredViews.add(viewId);
  }

  return HtmlElementView(viewType: viewId);
}
