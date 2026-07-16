import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:imboy/component/ui/app_loading.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/component/ui/async_state_view.dart';
import 'package:imboy/component/ui/ios_settings_ui.dart';
import 'package:imboy/config/init.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_radius.dart';
import 'package:imboy/theme/default/app_spacing.dart';
import 'package:imboy/theme/default/font_types.dart';

import 'storage_space_provider.dart';

/// 存储空间页面 - 像素级对齐 iOS 设置风
class StorageSpacePage extends ConsumerStatefulWidget {
  const StorageSpacePage({super.key});

  @override
  ConsumerState<StorageSpacePage> createState() => _StorageSpacePageState();
}

class _StorageSpacePageState extends ConsumerState<StorageSpacePage> {
  Object? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      await ref.read(storageSpaceProvider.notifier).initData();
    } on Exception catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final storageState = ref.watch(storageSpaceProvider);
    final t = context.t;

    return IosPageTemplate(
      title: t.main.storageSpace,
      useLargeTitle: false,
      child: AsyncStateView(
        isLoading: storageState.isLoading && storageState.totalDiskSpace == 0,
        error: _error,
        isEmpty: storageState.totalDiskSpace == 0,
        onRetry: _load,
        emptyIcon: Icons.storage,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.regular,
            vertical: AppSpacing.medium,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildStorageOverview(context, storageState, t),
              const SizedBox(height: AppSpacing.xLarge),
              _buildAppUsageSection(context, storageState, t),
              const SizedBox(height: AppSpacing.xLarge),
              _buildStorageDetailCards(context, storageState, t),
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
      padding: const EdgeInsets.all(AppSpacing.regular),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: AppRadius.borderRadiusCell,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final totalWidth = constraints.maxWidth;
              final totalSpace = state.totalDiskSpace;
              final usedSpace = state.usedDiskSpace;
              final freeSpace = state.freeDiskSpace;
              final appBytes = state.appAllBytes;

              final usedRatio = totalSpace > 0 ? usedSpace / totalSpace : 0.0;
              final appRatio = usedSpace > 0
                  ? (appBytes / usedSpace).clamp(0.01, 1.0)
                  : 0.01;
              double freeWidth = totalSpace > 0
                  ? (totalWidth * (freeSpace / totalSpace)).clamp(0, totalWidth)
                  : 0.0;

              return ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: SizedBox(
                  width: totalWidth,
                  height: 12,
                  child: Stack(
                    children: [
                      SizedBox(
                        height: 12,
                        width: totalWidth * usedRatio,
                        child: LinearProgressIndicator(
                          value: appRatio,
                          backgroundColor: AppColors.iosOrange.withValues(
                            alpha: 0.5,
                          ),
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            AppColors.primary,
                          ),
                        ),
                      ),
                      Positioned(
                        right: 0,
                        child: SizedBox(
                          height: 12,
                          width: freeWidth,
                          child: LinearProgressIndicator(
                            value: 1,
                            backgroundColor: AppColors.iosGray5,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              AppColors.iosGray5,
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
          const SizedBox(height: AppSpacing.regular),
          Wrap(
            spacing: 16,
            runSpacing: 10,
            children: [
              _buildLegendItem(
                context,
                AppColors.primary,
                '$appName: ${formatBytes(state.appAllBytes, num: 1000)}',
              ),
              _buildLegendItem(
                context,
                AppColors.iosOrange,
                '${t.account.deviceUsedSpace}: ${formatBytes(state.usedDiskSpace, num: 1000)}',
              ),
              _buildLegendItem(
                context,
                AppColors.iosGray,
                '${t.account.deviceAvailableSpace}: ${formatBytes(state.freeDiskSpace, num: 1000)}',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(BuildContext context, Color color, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          text,
          style: context.textStyle(
            FontSizeType.small,
            color: AppColors.iosGray,
          ),
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
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.large),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: AppRadius.borderRadiusCell,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            appName + t.main.usedSpace,
            style: context.textStyle(
              FontSizeType.subheadline,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.small),
          Text(
            formatBytes(state.appAllBytes, num: 1000),
            style: context.textStyle(
              FontSizeType.extraLargeTitle,
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: AppSpacing.tiny),
          Text(
            t.common.tipDeviceSpace(
              param1: state.totalDiskSpace > 0
                  ? ((state.appAllBytes / state.totalDiskSpace) * 100)
                        .toStringAsFixed(1)
                  : '0',
              param2: formatBytes(state.totalDiskSpace, num: 1000),
            ),
            style: context.textStyle(
              FontSizeType.footnote,
              color: AppColors.iosGray,
            ),
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
          title: appName + t.main.cache,
          value: state.cacheBytes,
          description: t.common.cacheTips,
          icon: Icons.cached,
          iconColor: AppColors.iosOrange,
          action: CupertinoButton(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.regular,
              vertical: AppSpacing.tiny,
            ),
            color: AppColors.getIosBlue(Theme.of(context).brightness),
            borderRadius: BorderRadius.circular(20),
            onPressed: () async {
              bool res = await ref
                  .read(storageSpaceProvider.notifier)
                  .clearAllCache();
              if (res) AppLoading.showSuccess(t.common.tipSuccess);
            },
            child: Text(
              t.main.clean,
              style: context.textStyle(
                FontSizeType.footnote,
                fontWeight: FontWeight.bold,
                color: AppColors.onPrimary,
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.medium),
        _buildStorageCard(
          context,
          title: t.chat.userData,
          value: state.dataBytes,
          description: t.common.userDataTips,
          icon: Icons.folder,
          iconColor: AppColors.iosBlue,
        ),
        const SizedBox(height: AppSpacing.medium),
        _buildStorageCard(
          context,
          title: t.main.appSize,
          value: state.appBytes,
          description: t.common.appSizeTips,
          icon: Icons.apps,
          iconColor: AppColors.iosGreen,
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
      padding: const EdgeInsets.all(AppSpacing.regular),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: AppRadius.borderRadiusCell,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: iconColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: AppColors.onPrimary, size: 20),
              ),
              const SizedBox(width: AppSpacing.medium),
              Expanded(
                child: Text(
                  title,
                  style: context.textStyle(
                    FontSizeType.body,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              ?action,
            ],
          ),
          const SizedBox(height: AppSpacing.regular),
          Text(
            formatBytes(value, num: 1000),
            style: context.textStyle(
              FontSizeType.extraLargeTitle,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            description,
            style: context.textStyle(
              FontSizeType.footnote,
              color: AppColors.iosGray,
            ),
          ),
        ],
      ),
    );
  }
}
