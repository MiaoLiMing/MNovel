import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../app/app_shell.dart';
import '../../core/theme/app_theme.dart';
import '../../data/shelf_store.dart';
import '../../data/reading_progress_store.dart';
import '../../data/source_store.dart';
import 'profile_detail_pages.dart';
import 'source_management_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  bool _autoSwitch = true;
  bool _wifiOnly = true;

  int _favCount = 0;
  int _historyCount = 0;
  double _cacheSize = 12.4;
  int _sourceCount = 0;
  int _activeSourceCount = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<double> _calculateCacheSize() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys();
    int totalBytes = 0;
    for (final key in keys) {
      final value = prefs.get(key);
      if (value is String) {
        totalBytes += value.length * 2;
      } else if (value is bool) {
        totalBytes += 4;
      } else if (value is int) {
        totalBytes += 8;
      }
    }
    final dynamicSizeKb = totalBytes / 1024.0;
    return 12.4 + (dynamicSizeKb / 1024.0); // Baseline 12.4 MB
  }

  Future<void> _loadData() async {
    final favs = await ShelfStore().listAll();
    final progress = await ReadingProgressStore().getAllProgress();
    final cache = await _calculateCacheSize();
    final sources = await SourceStore().list();
    final activeSources = sources.where((s) => s.enabled);
    if (!mounted) return;
    setState(() {
      _favCount = favs.length;
      _historyCount = progress.length;
      _cacheSize = cache;
      _sourceCount = sources.length;
      _activeSourceCount = activeSources.length;
      _loading = false;
    });
  }

  void _open(Widget page) {
    Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => page))
        .then((_) => _loadData());
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 28),
              children: [
                // Premium User Profile Header Card
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: AppColors.sageSoft,
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Row(
                    children: [
                      const CircleAvatar(
                        radius: 26,
                        backgroundImage: AssetImage('assets/logo.png'),
                        backgroundColor: Colors.transparent,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '李明',
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.text,
                                  ),
                            ),
                            const SizedBox(height: 3),
                            const Text(
                              '尊享会员 · 本地优先无广告',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.secondaryText,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.verified_user_rounded, color: AppColors.sage, size: 24),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                
                // Interactive Statistics Row
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () {
                          // Navigate to Shelf Tab
                          context.findAncestorStateOfType<AppShellState>()?.setIndex(0);
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: _Metric(value: '$_favCount', label: '收藏'),
                      ),
                    ),
                    Expanded(
                      child: InkWell(
                        onTap: () => _open(const HistoryPage()),
                        borderRadius: BorderRadius.circular(12),
                        child: _Metric(value: '$_historyCount 项', label: '阅读观看'),
                      ),
                    ),
                    Expanded(
                      child: InkWell(
                        onTap: () => _open(const CacheManagementPage()),
                        borderRadius: BorderRadius.circular(12),
                        child: _Metric(value: '${_cacheSize.toStringAsFixed(1)} M', label: '本地缓存'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 26),
                
                Text('内容与存储', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                _SettingTile(
                  icon: Icons.hub_outlined,
                  title: '内容源管理',
                  subtitle: '$_sourceCount 个来源 · $_activeSourceCount 个已启用',
                  onTap: () => _open(const SourceManagementPage()),
                ),
                _SettingTile(
                  icon: Icons.download_outlined,
                  title: '下载管理',
                  subtitle: '分频道离线缓存',
                  onTap: () => _open(const DownloadManagementPage()),
                ),
                _SettingTile(
                  icon: Icons.sync_rounded,
                  title: 'WebDAV 备份',
                  subtitle: '云端同步与还原',
                  onTap: () => _open(const WebDavPage()),
                ),
                _SettingTile(
                  icon: Icons.cleaning_services_outlined,
                  title: '缓存管理',
                  subtitle: '可清理 ${_cacheSize.toStringAsFixed(2)} MB',
                  onTap: () => _open(const CacheManagementPage()),
                ),
                const SizedBox(height: 22),
                
                Text('偏好设置', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  activeThumbColor: AppColors.sage,
                  title: const Text('加载失败时自动换源'),
                  subtitle: const Text('切换前会保留当前阅读或播放位置'),
                  value: _autoSwitch,
                  onChanged: (value) => setState(() => _autoSwitch = value),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  activeThumbColor: AppColors.sage,
                  title: const Text('仅 Wi-Fi 自动下载'),
                  value: _wifiOnly,
                  onChanged: (value) => setState(() => _wifiOnly = value),
                ),
              ],
            ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.value, required this.label});
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Column(
      children: [
        Text(
          value,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
                color: AppColors.sage,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: AppColors.secondaryText,
          ),
        ),
      ],
    ),
  );
}

class _SettingTile extends StatelessWidget {
  const _SettingTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: CircleAvatar(
      backgroundColor: AppColors.sageSoft,
      child: Icon(icon, color: AppColors.sage, size: 20),
    ),
    title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
    subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
    trailing: const Icon(Icons.chevron_right_rounded, size: 20),
    onTap: onTap,
  );
}
