import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
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

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
        children: [
          Text('我的', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 22),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.sageSoft,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                const CircleAvatar(
                  radius: 25,
                  backgroundColor: AppColors.sage,
                  child: Icon(Icons.auto_stories_rounded, color: Colors.white),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '私人内容空间',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 3),
                      const Text('本地优先 · 无广告'),
                    ],
                  ),
                ),
                const Icon(Icons.cloud_done_outlined, color: AppColors.sage),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: const [
              Expanded(
                child: _Metric(value: '12', label: '收藏'),
              ),
              Expanded(
                child: _Metric(value: '28h', label: '阅读观看'),
              ),
              Expanded(
                child: _Metric(value: '1.2G', label: '本地缓存'),
              ),
            ],
          ),
          const SizedBox(height: 26),
          Text('内容与存储', style: Theme.of(context).textTheme.titleLarge),
          _SettingTile(
            icon: Icons.hub_outlined,
            title: '内容源管理',
            subtitle: '6 个来源 · 4 个已启用',
            onTap: () => _open(const SourceManagementPage()),
          ),
          _SettingTile(
            icon: Icons.download_outlined,
            title: '下载管理',
            subtitle: '3 个离线任务',
            onTap: () => _open(const DownloadManagementPage()),
          ),
          _SettingTile(
            icon: Icons.sync_rounded,
            title: 'WebDAV 备份',
            subtitle: '今天 10:28 已同步',
            onTap: () => _open(const WebDavPage()),
          ),
          _SettingTile(
            icon: Icons.cleaning_services_outlined,
            title: '缓存管理',
            subtitle: '可清理 236 MB',
            onTap: () => _open(const CacheManagementPage()),
          ),
          const SizedBox(height: 22),
          Text('偏好', style: Theme.of(context).textTheme.titleLarge),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('加载失败时自动换源'),
            subtitle: const Text('切换前会保留当前阅读或播放位置'),
            value: _autoSwitch,
            onChanged: (value) => setState(() => _autoSwitch = value),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('仅 Wi-Fi 自动下载'),
            value: _wifiOnly,
            onChanged: (value) => setState(() => _wifiOnly = value),
          ),
        ],
      ),
    );
  }

  void _open(Widget page) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.value, required this.label});
  final String value;
  final String label;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text(value, style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 3),
      Text(label),
    ],
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
    leading: Icon(icon),
    title: Text(title),
    subtitle: Text(subtitle),
    trailing: const Icon(Icons.chevron_right_rounded),
    onTap: onTap,
  );
}
