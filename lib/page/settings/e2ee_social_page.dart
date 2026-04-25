import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/settings/e2ee_social_create_page.dart';
import 'package:imboy/page/settings/e2ee_social_recover_page.dart';
import 'package:imboy/page/settings/e2ee_social_manage_page.dart';
import 'package:imboy/service/e2ee_social_service.dart';
import 'package:imboy/theme/default/app_radius.dart';

/// E2EE 社交恢复入口页面
/// 通过信任的联系人恢复密钥
class E2EESocialPage extends StatefulWidget {
  const E2EESocialPage({super.key});

  @override
  State<E2EESocialPage> createState() => _E2EESocialPageState();
}

class _E2EESocialPageState extends State<E2EESocialPage> {
  bool _isLoading = true;
  bool _canRecover = false;
  List<Map<String, dynamic>> _shards = [];

  @override
  void initState() {
    super.initState();
    // 延迟到第一帧完成后再加载分片数据
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadShards();
      }
    });
  }

  Future<void> _loadShards() async {
    setState(() => _isLoading = true);

    try {
      final shards = await E2EESocialService.getShards();
      final canRecover = await E2EESocialService.canRecover();

      setState(() {
        _shards = shards;
        _canRecover = canRecover;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(t.e2eeSocialTitle),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
          tooltip: t.buttonBack,
        ),
      ),
      body: _isLoading
          ? const Center(child: CupertinoActivityIndicator())
          : ListView(
              children: [
                _buildStatusCard(),
                const SizedBox(height: 24),
                if (_shards.isNotEmpty) _buildExistingShardsCard(),
                _buildActionCards(),
                const SizedBox(height: 40),
              ],
            ),
    );
  }

  Widget _buildStatusCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.purple.shade50, Colors.purple.shade100],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: AppRadius.borderRadiusMedium,
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              children: [
                Icon(
                  _canRecover ? Icons.check_circle : Icons.info_outline,
                  color: _canRecover ? Colors.green : Colors.purple,
                  size: 32,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _canRecover ? t.e2eeSocialCanRecover : t.e2eeSocialSetupProxy,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.purple,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _canRecover ? t.e2eeSocialEnoughShards : t.e2eeSocialChooseProxy,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.purple.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExistingShardsCard() {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.folder_open, color: Colors.purple, size: 20),
                const SizedBox(width: 8),
                Text(
                  t.e2eeSocialExistingShards,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...(_shards.take(3).map((shard) => _buildShardItem(shard))),
            if (_shards.length > 3)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  t.e2eeSocialMoreShards(count: _shards.length - 3),
                  style: const TextStyle(fontSize: 13, color: Colors.grey),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildShardItem(Map<String, dynamic> shard) {
    final proxyUid = shard['proxy_uid'];
    final shardIndex = shard['shard_index'];
    final status = shard['status'];

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: Colors.purple.shade100,
              borderRadius: AppRadius.borderRadiusSmall,
            ),
            child: Center(
              child: Text(
                '${shardIndex + 1}',
                style: TextStyle(
                  color: Colors.purple.shade700,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t.e2eeProxyUser(uid: proxyUid), style: const TextStyle(fontSize: 13)),
                Text(
                  t.e2eeSocialStatus(status: status),
                  style: TextStyle(
                    fontSize: 12,
                    color: status == 'active' ? Colors.green : Colors.grey,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionCards() {
    return Column(
      children: [
        _buildActionCard(
          icon: Icons.create,
          title: t.e2eeSocialCreateShardsTitle,
          description: t.e2eeSocialCreateShardsDesc,
          color: Colors.blue,
          onTap: () {
            Navigator.push(
              context,
              CupertinoPageRoute(builder: (_) => const E2EESocialCreatePage()),
            );
          },
        ),
        const SizedBox(height: 12),
        if (_canRecover)
          _buildActionCard(
            icon: Icons.restore,
            title: t.e2eeSocialRecoverKeyTitle,
            description: t.e2eeSocialRecoverKeyDesc,
            color: Colors.green,
            onTap: () {
              Navigator.push(
                context,
                CupertinoPageRoute(
                  builder: (_) => const E2EESocialRecoverPage(),
                ),
              );
            },
          ),
        const SizedBox(height: 12),
        _buildActionCard(
          icon: Icons.manage_accounts,
          title: t.e2eeSocialManageShardsTitle,
          description: t.e2eeSocialManageShardsDesc,
          color: Colors.orange,
          onTap: () {
            Navigator.push(
              context,
              CupertinoPageRoute(builder: (_) => const E2EESocialManagePage()),
            );
          },
        ),
      ],
    );
  }

  Widget _buildActionCard({
    required IconData icon,
    required String title,
    required String description,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.borderRadiusMedium,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: AppRadius.borderRadiusSmall,
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.navigate_next, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}
