import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:imboy/component/ui/nodata_view.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/service/e2ee_social_service.dart';
import 'package:imboy/theme/default/app_radius.dart';

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
        title: Text(t.e2eeSocialManageTitle),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
          tooltip: t.buttonBack,
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
                    children: {
                      0: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 8,
                        ),
                        child: Text(t.e2eeSocialMyShards),
                      ),
                      1: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 8,
                        ),
                        child: Text(t.e2eeSocialProxyShards),
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
      return _buildEmptyView(t.e2eeSocialNoShards);
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
      return _buildEmptyView(t.e2eeSocialNoProxyShards);
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
    return NoDataView(
      text: message,
      description: t.e2eeSocialCreateFirst,
      icon: Icons.folder_open,
      iconSize: 64,
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
                    t.e2eeSocialShardOf(
                      idx: shardIndex as int,
                      total: totalShards as int,
                    ),
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
                    borderRadius: AppRadius.borderRadiusSmall,
                  ),
                  child: Text(
                    status == 'active'
                        ? t.e2eeSocialShardActive
                        : t.e2eeSocialShardUsed,
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
            _buildInfoRow(t.e2eeSocialProxyUserLabel, proxyUid.toString()),
            _buildInfoRow(
              t.e2eeSocialRecoveryThresholdLabel,
              '$threshold / $totalShards',
            ),
            _buildInfoRow(t.e2eeBackupCreatedAtRow, _formatDateTime(createdAt)),
            if (shard.containsKey('used_at'))
              _buildInfoRow(
                t.e2eeSocialUsedAtLabel,
                _formatDateTime(shard['used_at']),
              ),
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
                const Icon(Icons.person, size: 20, color: Colors.purple),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    t.e2eeSocialUserShard(uid: uid.toString()),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildInfoRow(t.e2eeSocialShardIndexLabel, '$shardIndex'),
            _buildInfoRow(t.e2eeSocialKeyVersionLabel, keyVersion.toString()),
            _buildInfoRow(t.e2eeBackupCreatedAtRow, _formatDateTime(createdAt)),
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
                  status == 'active'
                      ? t.e2eeSocialShardValid
                      : t.e2eeSocialShardUsed,
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
