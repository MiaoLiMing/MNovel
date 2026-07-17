import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import 'app_shell.dart';

class MNovelApp extends StatelessWidget {
  const MNovelApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MNovel',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const AppShell(initialIndex: 1),
    );
  }
}
