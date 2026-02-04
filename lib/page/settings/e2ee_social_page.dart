import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:imboy/page/settings/e2ee_social_create_page.dart';
import 'package:imboy/page/settings/e2ee_social_recover_page.dart';
import 'package:imboy/page/settings/e2ee_social_manage_page.dart';
import 'package:imboy/service/e2ee_social_service.dart';

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
        title: const Text('社交恢复'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
          tooltip: '返回',
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
        borderRadius: BorderRadius.circular(12),
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
                        _canRecover ? '可以恢复密钥' : '设置恢复代理',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.purple,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _canRecover ? '您已有足够的分片可以恢复密钥' : '选择信任的联系人作为恢复代理',
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
                const Text(
                  '现有恢复分片',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...(_shards.take(3).map((shard) => _buildShardItem(shard))),
            if (_shards.length > 3)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  '还有 ${_shards.length - 3} 个分片...',
                  style: TextStyle(fontSize: 13, color: Colors.grey),
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
              borderRadius: BorderRadius.circular(8),
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
                Text('代理用户: $proxyUid', style: const TextStyle(fontSize: 13)),
                Text(
                  '状态: $status',
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
          title: '创建恢复分片',
          description: '将密钥分割成多个分片，存储到代理设备（服务端不保存）',
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
            title: '恢复密钥',
            description: '使用代理的分片恢复密钥',
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
          title: '管理分片',
          description: '查看和管理所有恢复分片',
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
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
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
