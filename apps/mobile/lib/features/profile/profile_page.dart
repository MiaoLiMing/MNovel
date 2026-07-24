import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/theme/app_theme.dart';
import '../../data/reading_progress_store.dart';
import '../../data/shelf_store.dart';
import '../../data/source_store.dart';
import '../../domain/content.dart';
import 'backup_restore_page.dart';
import 'profile_detail_pages.dart';
import 'settings_page.dart';
import 'source_management_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  int _shelfCount = 0;
  int _historyCount = 0;
  int _completedCount = 0;
  int _sourceCount = 0;
  double _readingHours = 0;
  double _cacheSize = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final shelf = await ShelfStore().listAll();
    final progress = await ReadingProgressStore().getAllProgress();
    final sources = await SourceStore().list();
    final cacheSize = await _calculateCacheSize();
    if (!mounted) return;
    setState(() {
      _shelfCount = shelf.length;
      _historyCount = progress.length;
      _completedCount = progress.values.where((value) {
        if (value is! Map) return false;
        return ((value['ratio'] as num?)?.toDouble() ?? 0) >= .98;
      }).length;
      _readingHours = progress.values.fold<double>(0, (sum, value) {
        if (value is! Map) return sum;
        final chapter = (value['chapter_index'] as num?)?.toInt() ?? 0;
        final ratio = (value['ratio'] as num?)?.toDouble() ?? 0;
        return sum + chapter * .08 + ratio * .6;
      });
      _sourceCount = sources.length;
      _cacheSize = cacheSize;
      _loading = false;
    });
  }

  Future<double> _calculateCacheSize() async {
    final prefs = await SharedPreferences.getInstance();
    var bytes = 0;
    for (final key in prefs.getKeys()) {
      final value = prefs.get(key);
      if (value is String) {
        bytes += value.length * 2;
      } else {
        bytes += 8;
      }
    }
    return bytes / 1024 / 1024;
  }

  void _open(Widget page) {
    Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => page))
        .then((_) => _loadData());
  }

  Future<void> _importLocalBook() async {
    final titleController = TextEditingController();
    final authorController = TextEditingController();
    final contentController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('导入本地小说'),
        content: SizedBox(
          width: 360,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(labelText: '书名'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: authorController,
                  decoration: const InputDecoration(labelText: '作者'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: contentController,
                  minLines: 6,
                  maxLines: 10,
                  decoration: const InputDecoration(
                    labelText: '正文',
                    hintText: '粘贴 TXT 内容，空行将分隔段落',
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('导入'),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      titleController.dispose();
      authorController.dispose();
      contentController.dispose();
      return;
    }
    final title = titleController.text.trim();
    final author = authorController.text.trim();
    final paragraphs = contentController.text
        .split(RegExp(r'\r?\n\s*\r?\n'))
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList(growable: false);
    titleController.dispose();
    authorController.dispose();
    contentController.dispose();
    if (title.isEmpty || paragraphs.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请填写书名并粘贴正文')));
      return;
    }
    final item = ContentItem(
      id: 'local-${DateTime.now().millisecondsSinceEpoch}',
      title: title,
      creator: author.isEmpty ? '本地作者' : author,
      category: '本地导入',
      summary: paragraphs.first,
      coverAsset: '',
      popularity: '本地书籍',
      progress: 0,
      episodeCount: 1,
      sourceId: 'local-import',
      sourceName: '本地导入',
      localChapters: [
        {'title': '正文', 'paragraphs': paragraphs},
      ],
      tags: const ['本地'],
      sourceLabels: const ['本地导入'],
      wordCount: paragraphs.join().length,
    );
    await ShelfStore().add(item);
    if (!mounted) return;
    await _loadData();
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('《$title》已加入书架')));
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    bottom: false,
    child: _loading
        ? const Center(child: CircularProgressIndicator())
        : ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadii.large),
                  border: Border.all(color: AppColors.divider, width: .7),
                ),
                child: Row(
                  children: [
                    const CircleAvatar(
                      radius: 26,
                      backgroundColor: AppColors.sand,
                      backgroundImage: AssetImage(
                        'assets/design/reader-avatar.png',
                      ),
                    ),
                    const SizedBox(width: 13),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '清风读书',
                            style: TextStyle(
                              color: AppColors.text,
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            '专注阅读 · 享受文字',
                            style: TextStyle(
                              color: AppColors.tertiaryText,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: AppColors.tertiaryText,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(vertical: 13),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadii.medium),
                ),
                child: Row(
                  children: [
                    _Metric(value: '$_shelfCount', label: '书架'),
                    _Metric(
                      value: '${_readingHours.toStringAsFixed(1)}h',
                      label: '阅读时长',
                    ),
                    _Metric(value: '$_completedCount', label: '完本'),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              _MenuCard(
                children: [
                  _MenuTile(
                    icon: Icons.history_rounded,
                    title: '阅读历史',
                    subtitle: '$_historyCount 条记录',
                    onTap: () => _open(const HistoryPage()),
                  ),
                  _MenuTile(
                    icon: Icons.hub_outlined,
                    title: '书源管理',
                    subtitle: '$_sourceCount 个来源',
                    onTap: () => _open(const SourceManagementPage()),
                  ),
                  _MenuTile(
                    icon: Icons.inventory_2_outlined,
                    title: '缓存管理',
                    subtitle: '已用 ${_cacheSize.toStringAsFixed(2)} MB',
                    onTap: () => _open(const CacheManagementPage()),
                  ),
                  _MenuTile(
                    icon: Icons.cloud_upload_outlined,
                    title: '备份与恢复',
                    onTap: () => _open(const BackupRestorePage()),
                  ),
                  _MenuTile(
                    icon: Icons.note_add_outlined,
                    title: '导入本地书籍',
                    onTap: _importLocalBook,
                  ),
                  _MenuTile(
                    icon: Icons.settings_outlined,
                    title: '设置',
                    onTap: () => _open(const SettingsPage()),
                    isLast: true,
                  ),
                ],
              ),
            ],
          ),
  );
}

class _Metric extends StatelessWidget {
  const _Metric({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: AppColors.text,
            fontSize: 14,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          style: const TextStyle(color: AppColors.tertiaryText, fontSize: 9),
        ),
      ],
    ),
  );
}

class _MenuCard extends StatelessWidget {
  const _MenuCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadii.large),
      border: Border.all(color: AppColors.divider, width: .7),
    ),
    child: Column(children: children),
  );
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.isLast = false,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final bool isLast;

  @override
  Widget build(BuildContext context) => InkWell(
    borderRadius: BorderRadius.vertical(
      top: title == '阅读历史'
          ? const Radius.circular(AppRadii.large)
          : Radius.zero,
      bottom: isLast ? const Radius.circular(AppRadii.large) : Radius.zero,
    ),
    onTap: onTap,
    child: Container(
      height: 54,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : const Border(
                bottom: BorderSide(color: AppColors.divider, width: .7),
              ),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.secondaryText, size: 19),
          const SizedBox(width: 13),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: AppColors.text,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (subtitle != null)
            Text(
              subtitle!,
              style: const TextStyle(
                color: AppColors.tertiaryText,
                fontSize: 9,
              ),
            ),
          const SizedBox(width: 5),
          const Icon(
            Icons.chevron_right_rounded,
            color: AppColors.tertiaryText,
            size: 18,
          ),
        ],
      ),
    ),
  );
}
