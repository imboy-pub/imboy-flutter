import 'package:flutter/material.dart';
import 'package:imboy/page/moments/moments_page.dart';
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
            title: Text(t.moments),
            leading: const Icon(Icons.camera_alt, color: AppColors.primary),
            trailing: const Icon(Icons.chevron_right, size: 20),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const MomentsPage()),
              );
            },
          ),
          const SizedBox(height: 10),
          ListTile(
            title: Text(t.scan),
            leading: const Icon(
              Icons.qr_code_scanner,
              color: AppColors.primary,
            ),
            trailing: const Icon(Icons.chevron_right, size: 20),
            onTap: () {
              // TODO: Navigate to Scan
            },
          ),
          const Divider(height: 1),
          ListTile(
            title: Text(t.shake),
            leading: const Icon(Icons.vibration, color: AppColors.primary),
            trailing: const Icon(Icons.chevron_right, size: 20),
            onTap: () {
              // TODO: Navigate to Shake
            },
          ),
          const SizedBox(height: 10),
          ListTile(
            title: Text(t.topStories),
            leading: const Icon(Icons.remove_red_eye, color: Colors.orange),
            trailing: const Icon(Icons.chevron_right, size: 20),
            onTap: () {
              // TODO: Navigate to Top Stories
            },
          ),
          const Divider(height: 1),
          ListTile(
            title: Text(t.search),
            leading: const Icon(Icons.search, color: Colors.red),
            trailing: const Icon(Icons.chevron_right, size: 20),
            onTap: () {
              // TODO: Navigate to Search
            },
          ),
        ],
      ),
    );
  }
}
