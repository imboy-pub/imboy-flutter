import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:imboy/component/ui/ios_settings_ui.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/settings/e2ee_social_create_page.dart';
import 'package:imboy/page/settings/e2ee_social_recover_page.dart';
import 'package:imboy/page/settings/e2ee_social_manage_page.dart';
import 'package:imboy/service/e2ee_social_service.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_radius.dart';
import 'package:imboy/theme/default/font_types.dart';
import 'package:imboy/theme/default/app_spacing.dart';

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
    return IosPageTemplate(
      title: t.main.e2eeSocialTitle,
      child: _isLoading
          ? const Padding(
              padding: EdgeInsets.only(top: 120),
              child: Center(child: CupertinoActivityIndicator()),
            )
          : Column(
              children: [
                AppSpacing.verticalRegular,
                _buildStatusCard(),
                AppSpacing.verticalXLarge,
                if (_shards.isNotEmpty) _buildExistingShardsCard(),
                _buildActionCards(),
              ],
            ),
    );
  }

  Widget _buildStatusCard() {
    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: AppSpacing.regular,
        vertical: AppSpacing.small,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.iosPurple.withValues(alpha: 0.1),
            AppColors.iosPurple.withValues(alpha: 0.2),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: AppRadius.borderRadiusMedium,
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.large),
        child: Column(
          children: [
            Row(
              children: [
                Icon(
                  _canRecover
                      ? CupertinoIcons.checkmark_circle_fill
                      : CupertinoIcons.info,
                  color: _canRecover ? AppColors.iosGreen : AppColors.iosPurple,
                  size: 32,
                ),
                AppSpacing.horizontalMedium,
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _canRecover
                            ? t.main.e2eeSocialCanRecover
                            : t.main.e2eeSocialSetupProxy,
                        style: context.textStyle(
                          FontSizeType.large,
                          fontWeight: FontWeight.bold,
                          color: AppColors.iosPurple,
                        ),
                      ),
                      AppSpacing.verticalTiny,
                      Text(
                        _canRecover
                            ? t.common.e2eeSocialEnoughShards
                            : t.main.e2eeSocialChooseProxy,
                        style: context.textStyle(
                          FontSizeType.footnote,
                          color: AppColors.iosPurple,
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
      margin: const EdgeInsets.symmetric(
        horizontal: AppSpacing.regular,
        vertical: AppSpacing.small,
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.regular),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  CupertinoIcons.folder_open,
                  color: AppColors.iosPurple,
                  size: 20,
                ),
                AppSpacing.horizontalSmall,
                Text(
                  t.main.e2eeSocialExistingShards,
                  style: context.textStyle(
                    FontSizeType.medium,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            AppSpacing.verticalRegular,
            ...(_shards.take(3).map((shard) => _buildShardItem(shard))),
            if (_shards.length > 3)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.small),
                child: Text(
                  t.common.e2eeSocialMoreShards(count: _shards.length - 3),
                  style: context.textStyle(
                    FontSizeType.small,
                    color: AppColors.iosGray,
                  ),
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
      padding: const EdgeInsets.only(bottom: AppSpacing.medium),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.iosPurple.withValues(alpha: 0.2),
              borderRadius: AppRadius.borderRadiusSmall,
            ),
            child: Center(
              child: Text(
                '${shardIndex + 1}',
                style: const TextStyle(
                  color: AppColors.iosPurple,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          AppSpacing.horizontalMedium,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t.main.e2eeProxyUser(uid: proxyUid as Object),
                  style: context.textStyle(FontSizeType.footnote),
                ),
                Text(
                  t.chat.e2eeSocialStatus(status: status as Object),
                  style: context.textStyle(
                    FontSizeType.small,
                    color: status == 'active'
                        ? AppColors.iosGreen
                        : AppColors.iosGray,
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
          icon: CupertinoIcons.pencil,
          title: t.chat.e2eeSocialCreateShardsTitle,
          description: t.chat.e2eeSocialCreateShardsDesc,
          color: AppColors.iosBlue,
          onTap: () {
            Navigator.push(
              context,
              CupertinoPageRoute<dynamic>(
                builder: (_) => const E2EESocialCreatePage(),
              ),
            );
          },
        ),
        AppSpacing.verticalMedium,
        if (_canRecover)
          _buildActionCard(
            icon: CupertinoIcons.arrow_counterclockwise,
            title: t.main.e2eeSocialRecoverKeyTitle,
            description: t.main.e2eeSocialRecoverKeyDesc,
            color: AppColors.iosGreen,
            onTap: () {
              Navigator.push(
                context,
                CupertinoPageRoute<dynamic>(
                  builder: (_) => const E2EESocialRecoverPage(),
                ),
              );
            },
          ),
        AppSpacing.verticalMedium,
        _buildActionCard(
          icon: CupertinoIcons.gear_alt_fill,
          title: t.main.e2eeSocialManageShardsTitle,
          description: t.main.e2eeSocialManageShardsDesc,
          color: AppColors.iosOrange,
          onTap: () {
            Navigator.push(
              context,
              CupertinoPageRoute<dynamic>(
                builder: (_) => const E2EESocialManagePage(),
              ),
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
      margin: const EdgeInsets.symmetric(
        horizontal: AppSpacing.regular,
        vertical: AppSpacing.small,
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.borderRadiusMedium,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.regular),
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
              AppSpacing.horizontalRegular,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: context.textStyle(
                        FontSizeType.medium,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    AppSpacing.verticalTiny,
                    Text(
                      description,
                      style: context.textStyle(
                        FontSizeType.footnote,
                        color: AppColors.iosGray,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                CupertinoIcons.chevron_forward,
                color: AppColors.iosGray,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
