import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:go_router/go_router.dart';

import 'package:imboy/page/scanner/scanner_page.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/i18n/strings.g.dart';

class DiscoverPage extends StatelessWidget {
  const DiscoverPage({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    return Scaffold(
      appBar: AppBar(
        title: Text(t.discover),
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
      ),
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: ListView(
        children: [
          ListTile(
            title: Text(t.scan),
            leading: const Icon(
              Icons.qr_code_scanner,
              color: AppColors.primary,
            ),
            trailing: const Icon(Icons.chevron_right, size: 20),
            onTap: () {
              // 导航到扫一扫页面
              Navigator.push(
                context,
                CupertinoPageRoute(builder: (_) => const ScannerPage()),
              );
            },
          ),
          const Divider(height: 1),
          ListTile(
            title: Text(t.moments),
            leading: const Icon(
              Icons.dynamic_feed_outlined,
              color: Colors.blue,
            ),
            trailing: const Icon(Icons.chevron_right, size: 20),
            onTap: () {
              context.push('/moment/feed');
            },
          ),
          const Divider(height: 1),
          ListTile(
            title: Text(t.shake),
            leading: const Icon(Icons.vibration, color: AppColors.primary),
            trailing: const Icon(Icons.chevron_right, size: 20),
            onTap: () {
              // 摇一摇功能 - 显示开发中提示
              _showComingSoonDialog(context, t.shake);
            },
          ),
          const SizedBox(height: 10),
          ListTile(
            title: Text(t.topStories),
            leading: const Icon(Icons.remove_red_eye, color: Colors.orange),
            trailing: const Icon(Icons.chevron_right, size: 20),
            onTap: () {
              // 头条功能 - 显示开发中提示
              _showComingSoonDialog(context, t.topStories);
            },
          ),
          const Divider(height: 1),
          ListTile(
            title: Text(t.search),
            leading: const Icon(Icons.search, color: Colors.red),
            trailing: const Icon(Icons.chevron_right, size: 20),
            onTap: () {
              // 导航到搜索页面
              context.push('/search');
            },
          ),
        ],
      ),
    );
  }

  /// 显示开发中提示对话框
  void _showComingSoonDialog(BuildContext context, String featureName) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(featureName),
          content: Text(context.t.featureComingSoon),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(context.t.confirm),
            ),
          ],
        );
      },
    );
  }
}
