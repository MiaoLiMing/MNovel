import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_theme.dart';
import '../../data/reading_progress_store.dart';
import '../../data/shelf_store.dart';
import '../../domain/content.dart';

class BackupRestorePage extends StatefulWidget {
  const BackupRestorePage({super.key});

  @override
  State<BackupRestorePage> createState() => _BackupRestorePageState();
}

class _BackupRestorePageState extends State<BackupRestorePage> {
  final _shelfStore = ShelfStore();
  final _progressStore = ReadingProgressStore();
  bool _working = false;

  Future<void> _export() async {
    setState(() => _working = true);
    final shelf = await _shelfStore.listAll();
    final progress = await _progressStore.getAllProgress();
    final payload = const JsonEncoder.withIndent('  ').convert({
      'version': 1,
      'created_at': DateTime.now().toIso8601String(),
      'shelf': shelf.map((item) => item.toJson()).toList(),
      'progress': progress,
    });
    await Clipboard.setData(ClipboardData(text: payload));
    if (!mounted) return;
    setState(() => _working = false);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('备份 JSON 已复制到剪贴板')));
  }

  Future<void> _import() async {
    final controller = TextEditingController();
    final clipboard = await Clipboard.getData(Clipboard.kTextPlain);
    controller.text = clipboard?.text ?? '';
    if (!mounted) return;
    final raw = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('恢复备份'),
        content: TextField(
          controller: controller,
          minLines: 8,
          maxLines: 14,
          decoration: const InputDecoration(hintText: '粘贴由 MNovel 导出的备份 JSON'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text),
            child: const Text('恢复'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (raw == null || raw.trim().isEmpty) return;
    setState(() => _working = true);
    try {
      final data = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      final shelf = (data['shelf'] as List<dynamic>? ?? const [])
          .map(
            (value) =>
                ContentItem.fromJson(Map<String, dynamic>.from(value as Map)),
          )
          .toList(growable: false);
      final progress = Map<String, dynamic>.from(
        data['progress'] as Map? ?? const {},
      );
      await _shelfStore.replaceAll(shelf);
      await _progressStore.replaceAll(progress);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('已恢复 ${shelf.length} 本书及阅读进度')));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('备份格式不正确，未修改本地数据')));
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('备份与恢复')),
    body: ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.coralSoft,
            borderRadius: BorderRadius.circular(AppRadii.large),
          ),
          child: const Row(
            children: [
              Icon(Icons.shield_outlined, color: AppColors.coral, size: 28),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  '备份包含书架和阅读进度，不包含正文缓存。数据仅在你主动复制或恢复时传递。',
                  style: TextStyle(
                    color: AppColors.secondaryText,
                    fontSize: 11,
                    height: 1.6,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const CircleAvatar(
            backgroundColor: AppColors.sand,
            child: Icon(Icons.upload_rounded, color: AppColors.coral),
          ),
          title: const Text('导出备份'),
          subtitle: const Text('生成 JSON 并复制到剪贴板'),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: _working ? null : _export,
        ),
        const Divider(color: AppColors.divider),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const CircleAvatar(
            backgroundColor: AppColors.sand,
            child: Icon(Icons.download_rounded, color: AppColors.coral),
          ),
          title: const Text('恢复备份'),
          subtitle: const Text('从剪贴板或手动粘贴 JSON'),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: _working ? null : _import,
        ),
        if (_working) ...[
          const SizedBox(height: 18),
          const LinearProgressIndicator(),
        ],
      ],
    ),
  );
}
