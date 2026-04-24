import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/component/ui/common_bar.dart';
import 'package:imboy/config/init.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_radius.dart';

import 'storage_space_provider.dart';

/// 存储空间页面
class StorageSpacePage extends ConsumerStatefulWidget {
  const StorageSpacePage({super.key});

  @override
  ConsumerState<StorageSpacePage> createState() => _StorageSpacePageState();
}

class _StorageSpacePageState extends ConsumerState<StorageSpacePage> {
  @override
  void initState() {
    super.initState();
    // 初始化数据
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(storageSpaceProvider.notifier).initData();
    });
  }

  @override
  Widget build(BuildContext context) {
    final storageState = ref.watch(storageSpaceProvider);
    final t = context.t;

    final brightness = Theme.of(context).brightness;
    return Scaffold(
      backgroundColor: AppColors.getSurfaceGrouped(brightness),
      appBar: GlassAppBar(
        automaticallyImplyLeading: true,
        title: t.storageSpace,
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              _buildStorageOverview(context, storageState, t),
              const SizedBox(height: 24),
              _buildAppUsageSection(context, storageState, t),
              const SizedBox(height: 24),
              _buildStorageDetailCards(context, storageState, t),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStorageOverview(
    BuildContext context,
    StorageSpaceState state,
    Translations t,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: AppRadius.borderRadiusRegular,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Storage progress bar
          LayoutBuilder(
            builder: (context, constraints) {
              final totalWidth = constraints.maxWidth;
              final totalSpace = state.totalDiskSpace;
              final usedSpace = state.usedDiskSpace;
              final freeSpace = state.freeDiskSpace;
              final appBytes = state.appAllBytes;

              // Calculate ratios with safety checks
              final usedRatio = totalSpace > 0 ? usedSpace / totalSpace : 0.0;
              final appRatio = usedSpace > 0
                  ? (appBytes / usedSpace).clamp(0.01, 1.0)
                  : 0.01;

              // Ensure free space width is non-negative
              double freeWidth = totalSpace > 0
                  ? (totalWidth * (freeSpace / totalSpace)).clamp(0, totalWidth)
                  : 0.0;

              return ClipRRect(
                borderRadius: AppRadius.borderRadiusMedium,
                child: SizedBox(
                  width: totalWidth,
                  height: 24,
                  child: Stack(
                    children: [
                      // Used space (with app portion)
                      SizedBox(
                        height: 24,
                        width: totalWidth * usedRatio,
                        child: LinearProgressIndicator(
                          value: appRatio,
                          backgroundColor: Colors.amber,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            AppColors.primary,
                          ),
                        ),
                      ),
                      // Free space
                      Positioned(
                        right: 0,
                        child: SizedBox(
                          height: 24,
                          width: freeWidth,
                          child: const LinearProgressIndicator(
                            value: 1,
                            backgroundColor: Colors.grey,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.black12,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          // Legend
          Wrap(
            spacing: 16,
            runSpacing: 10,
            children: [
              _buildLegendItem(
                AppColors.primary,
                '$appName${t.usedSpace}${formatBytes(state.appAllBytes, num: 1000)}',
              ),
              _buildLegendItem(
                Colors.amber,
                t.deviceUsedSpace + formatBytes(state.usedDiskSpace, num: 1000),
              ),
              _buildLegendItem(
                Colors.grey,
                t.deviceAvailableSpace +
                    formatBytes(state.freeDiskSpace, num: 1000),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(Color color, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: AppRadius.borderRadiusTiny,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          text,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  Widget _buildAppUsageSection(
    BuildContext context,
    StorageSpaceState state,
    Translations t,
  ) {
    return Container(
      width: MediaQuery.of(context).size.width,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: AppRadius.borderRadiusRegular,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            appName + t.usedSpace,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            formatBytes(state.appAllBytes, num: 1000),
            style: TextStyle(
              fontSize: 42,
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            t.tipDeviceSpace(
              param1: state.totalDiskSpace > 0
                  ? ((state.appAllBytes / state.totalDiskSpace) * 1000)
                        .toStringAsFixed(3)
                  : '0',
              param2: formatBytes(state.totalDiskSpace, num: 1000),
            ),
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildStorageDetailCards(
    BuildContext context,
    StorageSpaceState state,
    Translations t,
  ) {
    return Column(
      children: [
        _buildStorageCard(
          context,
          title: appName + t.cache,
          value: state.cacheBytes,
          description: t.cacheTips,
          icon: Icons.cached_rounded,
          iconColor: AppColors.warning,
          action: Container(
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: AppRadius.borderRadiusLarge,
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () async {
                  bool res = await ref
                      .read(storageSpaceProvider.notifier)
                      .clearAllCache();
                  if (res) {
                    EasyLoading.showSuccess(t.tipSuccess);
                  } else {
                    EasyLoading.showError(t.tipFailed);
                  }
                },
                borderRadius: AppRadius.borderRadiusLarge,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Text(
                    t.clean,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        _buildStorageCard(
          context,
          title: t.userData,
          value: state.dataBytes,
          description: t.userDataTips,
          icon: Icons.folder_rounded,
          iconColor: AppColors.info,
        ),
        const SizedBox(height: 12),
        _buildStorageCard(
          context,
          title: t.appSize,
          value: state.appBytes,
          description: t.appSizeTips,
          icon: Icons.apps_rounded,
          iconColor: AppColors.success,
        ),
      ],
    );
  }

  Widget _buildStorageCard(
    BuildContext context, {
    required String title,
    required int value,
    required String description,
    required IconData icon,
    required Color iconColor,
    Widget? action,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: AppRadius.borderRadiusRegular,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.1),
                  borderRadius: AppRadius.borderRadiusMedium,
                ),
                child: Icon(icon, color: iconColor, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              // ignore: use_null_aware_elements
              if (action != null) action,
            ],
          ),
          const SizedBox(height: 16),
          Text(
            formatBytes(value, num: 1000),
            style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            description,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }
}
