import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/config/init.dart';
import 'package:imboy/component/ui/common_bar.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'storage_space_logic.dart';
import 'storage_space_state.dart';
import 'package:imboy/i18n/strings.g.dart';

class StorageSpacePage extends StatelessWidget {
  StorageSpacePage({super.key});

  final StorageSpaceLogic logic = Get.put(StorageSpaceLogic());
  final StorageSpaceState state = Get.find<StorageSpaceLogic>().state;

  @override
  Widget build(BuildContext context) {
    // 初始化数据
    logic.initData();

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
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
              _buildStorageOverview(context),
              const SizedBox(height: 24),
              _buildAppUsageSection(context),
              const SizedBox(height: 24),
              _buildStorageDetailCards(context),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStorageOverview(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).shadowColor.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Storage progress bar
          LayoutBuilder(
            builder: (context, constraints) {
              return Obx(() {
                final totalWidth = constraints.maxWidth;
                final totalSpace = state.totalDiskSpace.value;
                final usedSpace = state.usedDiskSpace.value;
                final freeSpace = state.freeDiskSpace.value;
                final appBytes = state.appAllBytes.value;

                // Calculate ratios with safety checks
                final usedRatio = totalSpace > 0 ? usedSpace / totalSpace : 0.0;
                final appRatio = usedSpace > 0
                    ? (appBytes / usedSpace).clamp(0.01, 1.0)
                    : 0.01;

                // Ensure free space width is non-negative
                double freeWidth = totalSpace > 0
                    ? (totalWidth * (freeSpace / totalSpace)).clamp(
                        0,
                        totalWidth,
                      )
                    : 0.0;

                return ClipRRect(
                  borderRadius: BorderRadius.circular(10),
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
                              AppColors.primaryGreen,
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
              });
            },
          ),
          const SizedBox(height: 16),
          // Legend
          Obx(
            () => Wrap(
              spacing: 16,
              runSpacing: 10,
              children: [
                _buildLegendItem(
                  AppColors.primaryGreen,
                  '$appName${t.usedSpace}${formatBytes(state.appAllBytes.value, num: 1000)}',
                ),
                _buildLegendItem(
                  Colors.amber,
                  t.deviceUsedSpace +
                      formatBytes(state.usedDiskSpace.value, num: 1000),
                ),
                _buildLegendItem(
                  Colors.grey,
                  t.deviceAvailableSpace +
                      formatBytes(state.freeDiskSpace.value, num: 1000),
                ),
              ],
            ),
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
            borderRadius: BorderRadius.circular(3),
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

  Widget _buildAppUsageSection(BuildContext context) {
    return Container(
      width: Get.width,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).shadowColor.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Obx(
        () => Column(
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
              formatBytes(state.appAllBytes.value, num: 1000),
              style: TextStyle(
                fontSize: 42,
                fontWeight: FontWeight.bold,
                color: AppColors.primaryGreen,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              t.tipDeviceSpace.replaceAll('{s}',
                  state.totalDiskSpace.value > 0
                      ? ((state.appAllBytes.value / state.totalDiskSpace.value) *
                                1000)
                            .toStringAsFixed(3)
                      : '0')
                  .replaceAll('{s}',
                      formatBytes(state.totalDiskSpace.value, num: 1000)),
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStorageDetailCards(BuildContext context) {
    return Obx(
      () => Column(
        children: [
          _buildStorageCard(
            context,
            title: appName + t.cache,
            value: state.cacheBytes.value,
            description: t.cacheTips,
            icon: Icons.cached_rounded,
            iconColor: AppColors.warning,
            action: Container(
              decoration: BoxDecoration(
                color: AppColors.primaryGreen,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryGreen.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () async {
                    bool res = await logic.clearAllCache();
                    if (res) {
                      EasyLoading.showSuccess(t.tipSuccess);
                    } else {
                      EasyLoading.showError(t.tipFailed);
                    }
                  },
                  borderRadius: BorderRadius.circular(20),
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
            value: state.dataBytes.value,
            description: t.userDataTips,
            icon: Icons.folder_rounded,
            iconColor: AppColors.info,
          ),
          const SizedBox(height: 12),
          _buildStorageCard(
            context,
            title: t.appSize,
            value: state.appBytes.value,
            description: t.appSizeTips,
            icon: Icons.apps_rounded,
            iconColor: AppColors.success,
          ),
        ],
      ),
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
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).shadowColor.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
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
                  borderRadius: BorderRadius.circular(12),
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
