// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';

// Keep track of registered views to prevent duplicates
final Set<String> _registeredImageUrls = {};

Widget createWebImage(String url, double? width, double? height) {
  final viewId = 'web-image-${url.hashCode}';

  if (!_registeredImageUrls.contains(viewId)) {
    ui_web.platformViewRegistry.registerViewFactory(viewId, (int id) {
      final element = html.ImageElement()
        ..src = url
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.objectFit = 'cover'
        ..style.border = 'none';
      return element;
    });
    _registeredImageUrls.add(viewId);
  }

  return SizedBox(
    width: width,
    height: height,
    child: HtmlElementView(viewType: viewId),
  );
}
