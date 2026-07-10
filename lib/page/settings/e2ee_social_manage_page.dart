import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:imboy/component/ui/nodata_view.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/service/e2ee_social_service.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_radius.dart';
import 'package:imboy/theme/default/font_types.dart';
import 'package:imboy/theme/default/app_spacing.dart';

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
        title: Text(t.main.e2eeSocialManageTitle),
        leading: IconButton(
          icon: const Icon(CupertinoIcons.back),
          onPressed: () => Navigator.of(context).pop(),
          tooltip: t.common.buttonBack,
        ),
      ),
      body: _isLoading
          ? const Center(child: CupertinoActivityIndicator())
          : Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(AppSpacing.regular),
                  child: CupertinoSlidingSegmentedControl<int>(
                    groupValue: _tabController.index,
                    children: {
                      0: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.large,
                          vertical: AppSpacing.small,
                        ),
                        child: Text(t.main.e2eeSocialMyShards),
                      ),
                      1: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.large,
                          vertical: AppSpacing.small,
                        ),
                        child: Text(t.main.e2eeSocialProxyShards),
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
      return _buildEmptyView(t.common.e2eeSocialNoShards);
    }

    return ListView.builder(
      padding: const EdgeInsets.all(AppSpacing.regular),
      itemCount: _userShards.length,
      itemBuilder: (context, index) {
        final shard = _userShards[index];
        return _buildShardCard(shard);
      },
    );
  }

  Widget _buildProxyShardsView() {
    if (_proxyShards.isEmpty) {
      return _buildEmptyView(t.common.e2eeSocialNoProxyShards);
    }

    return ListView.builder(
      padding: const EdgeInsets.all(AppSpacing.regular),
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
      description: t.chat.e2eeSocialCreateFirst,
      icon: CupertinoIcons.folder_open,
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
      margin: const EdgeInsets.only(bottom: AppSpacing.medium),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.regular),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.small,
                    vertical: AppSpacing.tiny,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.iosPurple.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '$shardIndex',
                    style: const TextStyle(
                      color: AppColors.iosPurple,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                AppSpacing.horizontalSmall,
                Expanded(
                  child: Text(
                    t.main.e2eeSocialShardOf(
                      idx: shardIndex as int,
                      total: totalShards as int,
                    ),
                    style: context.textStyle(
                      FontSizeType.normal,
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
                        ? AppColors.iosGreen.withValues(alpha: 0.2)
                        : AppColors.iosGray5,
                    borderRadius: AppRadius.borderRadiusSmall,
                  ),
                  child: Text(
                    status == 'active'
                        ? t.main.e2eeSocialShardActive
                        : t.main.e2eeSocialShardUsed,
                    style: context.textStyle(
                      FontSizeType.caption2,
                      color: status == 'active'
                          ? AppColors.iosGreen
                          : AppColors.iosGray,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            AppSpacing.verticalMedium,
            _buildInfoRow(t.main.e2eeSocialProxyUserLabel, proxyUid.toString()),
            _buildInfoRow(
              t.main.e2eeSocialRecoveryThresholdLabel,
              '$threshold / $totalShards',
            ),
            _buildInfoRow(
              t.common.e2eeBackupCreatedAtRow,
              _formatDateTime(createdAt),
            ),
            if (shard.containsKey('used_at'))
              _buildInfoRow(
                t.chat.e2eeSocialUsedAtLabel,
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
      margin: const EdgeInsets.only(bottom: AppSpacing.medium),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.regular),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  CupertinoIcons.person_fill,
                  size: 20,
                  color: AppColors.iosPurple,
                ),
                AppSpacing.horizontalSmall,
                Expanded(
                  child: Text(
                    t.main.e2eeSocialUserShard(uid: uid.toString()),
                    style: context.textStyle(
                      FontSizeType.normal,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            AppSpacing.verticalMedium,
            _buildInfoRow(t.main.e2eeSocialShardIndexLabel, '$shardIndex'),
            _buildInfoRow(
              t.common.e2eeSocialKeyVersionLabel,
              keyVersion.toString(),
            ),
            _buildInfoRow(
              t.common.e2eeBackupCreatedAtRow,
              _formatDateTime(createdAt),
            ),
            AppSpacing.verticalSmall,
            Row(
              children: [
                Icon(
                  status == 'active'
                      ? CupertinoIcons.checkmark_circle_fill
                      : CupertinoIcons.clock,
                  size: 16,
                  color: status == 'active'
                      ? AppColors.iosGreen
                      : AppColors.iosGray,
                ),
                AppSpacing.horizontalTiny,
                Text(
                  status == 'active'
                      ? t.main.e2eeSocialShardValid
                      : t.main.e2eeSocialShardUsed,
                  style: context.textStyle(
                    FontSizeType.small,
                    color: status == 'active'
                        ? AppColors.iosGreen
                        : AppColors.iosGray,
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
      padding: const EdgeInsets.only(bottom: AppSpacing.tiny),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: context.textStyle(
                FontSizeType.small,
                color: AppColors.iosGray,
              ),
            ),
          ),
          Expanded(
            child: Text(value, style: context.textStyle(FontSizeType.small)),
          ),
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
