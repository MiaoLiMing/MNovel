import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/theme/app_theme.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _autoSource = true;
  bool _wifiOnly = true;
  bool _updateReminder = true;
  bool _volumeTurn = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _autoSource = prefs.getBool('app.autoSource') ?? true;
      _wifiOnly = prefs.getBool('app.wifiOnly') ?? true;
      _updateReminder = prefs.getBool('app.updateReminder') ?? true;
      _volumeTurn = prefs.getBool('app.volumeTurn') ?? false;
      _loading = false;
    });
  }

  Future<void> _save(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('设置')),
    body: _loading
        ? const Center(child: CircularProgressIndicator())
        : ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
            children: [
              const _GroupTitle('阅读'),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('加载失败时自动换源'),
                subtitle: const Text('切换前保留当前章节和阅读位置'),
                value: _autoSource,
                onChanged: (value) {
                  setState(() => _autoSource = value);
                  _save('app.autoSource', value);
                },
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('音量键翻页'),
                value: _volumeTurn,
                onChanged: (value) {
                  setState(() => _volumeTurn = value);
                  _save('app.volumeTurn', value);
                },
              ),
              const Divider(color: AppColors.divider),
              const _GroupTitle('下载与更新'),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('仅 Wi-Fi 自动下载'),
                value: _wifiOnly,
                onChanged: (value) {
                  setState(() => _wifiOnly = value);
                  _save('app.wifiOnly', value);
                },
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('书籍更新提醒'),
                value: _updateReminder,
                onChanged: (value) {
                  setState(() => _updateReminder = value);
                  _save('app.updateReminder', value);
                },
              ),
              const Divider(color: AppColors.divider),
              const _GroupTitle('关于'),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('当前版本'),
                trailing: const Text(
                  '1.0.0',
                  style: TextStyle(color: AppColors.tertiaryText, fontSize: 11),
                ),
                onTap: () => showAboutDialog(
                  context: context,
                  applicationName: 'MNovel',
                  applicationVersion: '1.0.0',
                  applicationLegalese: '本地优先 · 无广告 · 尊重内容版权',
                ),
              ),
            ],
          ),
  );
}

class _GroupTitle extends StatelessWidget {
  const _GroupTitle(this.label);

  final String label;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 12, bottom: 4),
    child: Text(
      label,
      style: const TextStyle(
        color: AppColors.secondaryText,
        fontSize: 11,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}
