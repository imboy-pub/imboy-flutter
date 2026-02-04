import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:imboy/service/e2ee_social_service.dart';

/// E2EE 社交恢复 - 管理分片页面
/// 查看和管理所有恢复分片
class E2EESocialManagePage extends StatefulWidget {
  const E2EESocialManagePage({super.key});

  @override
  State<E2EESocialManagePage> createState() => _E2EESocialManagePageState();
}

class _E2EESocialManagePageState extends State<E2EESocialManagePage>
    with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  List<Map<String, dynamic>> _userShards = [];
  List<Map<String, dynamic>> _proxyShards = [];
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    // 延迟加载数据，避免布局期间触发 setState
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadData();
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      final results = await Future.wait([
        E2EESocialService.getShards(),
        E2EESocialService.getProxyShards(),
      ]);

      setState(() {
        _userShards = results[0];
        _proxyShards = results[1];
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _userShards = [];
        _proxyShards = [];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('管理分片'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
          tooltip: '返回',
        ),
      ),
      body: _isLoading
          ? const Center(child: CupertinoActivityIndicator())
          : Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  child: CupertinoSlidingSegmentedControl<int>(
                    groupValue: _tabController.index,
                    children: const {
                      0: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 8,
                        ),
                        child: Text('我的分片'),
                      ),
                      1: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 8,
                        ),
                        child: Text('代理分片'),
                      ),
                    },
                    onValueChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _tabController.index = value;
                        });
                      }
                    },
                  ),
                ),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [_buildUserShardsView(), _buildProxyShardsView()],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildUserShardsView() {
    if (_userShards.isEmpty) {
      return _buildEmptyView('您还没有创建任何恢复分片');
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _userShards.length,
      itemBuilder: (context, index) {
        final shard = _userShards[index];
        return _buildShardCard(shard);
      },
    );
  }

  Widget _buildProxyShardsView() {
    if (_proxyShards.isEmpty) {
      return _buildEmptyView('没有代理分片');
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _proxyShards.length,
      itemBuilder: (context, index) {
        final shard = _proxyShards[index];
        return _buildProxyShardCard(shard);
      },
    );
  }

  Widget _buildEmptyView(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.folder_open, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          Text(message, style: TextStyle(fontSize: 16, color: Colors.grey)),
          const SizedBox(height: 8),
          Text(
            '创建分片后才能看到内容',
            style: TextStyle(fontSize: 14, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildShardCard(Map<String, dynamic> shard) {
    final shardIndex = shard['shard_index'];
    final totalShards = shard['total_shards'];
    final threshold = shard['threshold'];
    final proxyUid = shard['proxy_uid'];
    final status = shard['status'];
    final createdAt = shard['created_at'];

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.purple.shade100,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '$shardIndex',
                    style: TextStyle(
                      color: Colors.purple.shade700,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '分片 $shardIndex / $totalShards',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: status == 'active'
                        ? Colors.green.shade100
                        : Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    status == 'active' ? '活跃' : '已使用',
                    style: TextStyle(
                      fontSize: 11,
                      color: status == 'active'
                          ? Colors.green.shade700
                          : Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildInfoRow('代理用户', proxyUid.toString()),
            _buildInfoRow('恢复阈值', '$threshold / $totalShards'),
            _buildInfoRow('创建时间', _formatDateTime(createdAt)),
            if (shard.containsKey('used_at'))
              _buildInfoRow('使用时间', _formatDateTime(shard['used_at'])),
          ],
        ),
      ),
    );
  }

  Widget _buildProxyShardCard(Map<String, dynamic> shard) {
    final shardIndex = shard['shard_index'];
    final uid = shard['uid'];
    final keyVersion = shard['key_version'];
    final status = shard['status'];
    final createdAt = shard['created_at'];

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.person, size: 20, color: Colors.purple),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '用户 $uid 的密钥分片',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildInfoRow('分片编号', '$shardIndex'),
            _buildInfoRow('密钥版本', keyVersion),
            _buildInfoRow('创建时间', _formatDateTime(createdAt)),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  status == 'active' ? Icons.check_circle : Icons.history,
                  size: 16,
                  color: status == 'active' ? Colors.green : Colors.grey,
                ),
                const SizedBox(width: 4),
                Text(
                  status == 'active' ? '分片有效' : '已使用',
                  style: TextStyle(
                    fontSize: 12,
                    color: status == 'active' ? Colors.green : Colors.grey,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 12))),
        ],
      ),
    );
  }

  String _formatDateTime(dynamic dateTime) {
    if (dateTime == null) return '-';
    try {
      final dt = DateTime.parse(dateTime.toString());
      return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
          '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return dateTime.toString();
    }
  }
}
