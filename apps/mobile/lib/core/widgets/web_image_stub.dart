import 'package:flutter/material.dart';

Widget createWebImage(String url, double? width, double? height) {
  return Image.network(url, width: width, height: height, fit: BoxFit.cover);
}
