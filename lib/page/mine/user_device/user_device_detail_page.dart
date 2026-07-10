import 'dart:async';
import 'package:imboy/theme/default/app_spacing.dart';

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:imboy/component/ui/app_loading.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:imboy/component/ui/cell_pressable.dart';
import 'package:imboy/component/ui/common_bar.dart';
import 'package:imboy/config/init.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/store/model/user_device_model.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_radius.dart';
import 'package:imboy/theme/default/font_types.dart';
import 'package:imboy/component/helper/datetime.dart';

import 'change_name_page.dart';
import 'user_device_provider.dart';

/// 设备详情页面
class UserDeviceDetailPage extends ConsumerStatefulWidget {
  final UserDeviceModel model;

  const UserDeviceDetailPage({super.key, required this.model});

  @override
  ConsumerState<UserDeviceDetailPage> createState() =>
      _UserDeviceDetailPageState();
}

class _UserDeviceDetailPageState extends ConsumerState<UserDeviceDetailPage> {
  StreamSubscription<dynamic>? _localeSubscription;
  String _deviceName = '';

  @override
  void initState() {
    super.initState();
    _deviceName = widget.model.deviceName;
    _localeSubscription = LocaleSettings.getLocaleStream().listen((_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _localeSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: AppColors.getSurfaceGrouped(
        Theme.of(context).brightness,
      ),
      appBar: GlassAppBar(
        automaticallyImplyLeading: true,
        title: t.common.deviceDetails,
      ),
      body: SingleChildScrollView(
        padding: AppSpacing.allRegular,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 设备信息卡片
            _buildDeviceInfoCard(context, isDark),
            AppSpacing.verticalRegular,

            // 设备详情
            _buildDeviceDetailsCard(context, isDark),
            AppSpacing.verticalRegular,

            // 活跃时间提示
            _buildActiveTimeTips(context, isDark),
            AppSpacing.verticalXLarge,

            // 下线设备按钮（仅非当前设备显示）
            if (widget.model.deviceId != deviceId)
              _buildForceOfflineButton(context),
            if (widget.model.deviceId != deviceId) AppSpacing.verticalMedium,

            // 删除设备按钮
            _buildDeleteButton(context),
          ],
        ),
      ),
    );
  }

  /// 构建设备信息卡片
  Widget _buildDeviceInfoCard(BuildContext context, bool isDark) {
    return Container(
      padding: AppSpacing.allLarge,
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: AppRadius.borderRadiusRegular,
      ),
      child: Column(
        children: [
          // 设备图标和名称
          Row(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.primaryAlpha20
                      : AppColors.successBackground,
                  borderRadius: AppRadius.borderRadiusRegular,
                ),
                child: Icon(
                  _getDeviceIcon(widget.model.deviceType),
                  size: 32,
                  color: AppColors.primary,
                ),
              ),
              AppSpacing.horizontalRegular,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _deviceName,
                      style: context.textStyle(
                        FontSizeType.large,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    AppSpacing.verticalTiny,
                    Text(
                      widget.model.showType,
                      style: TextStyle(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          AppSpacing.verticalRegular,

          // 在线状态
          Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: widget.model.online
                      ? AppColors.onlineIndicator
                      : AppColors.offlineIndicator,
                  shape: BoxShape.circle,
                ),
              ),
              AppSpacing.horizontalSmall,
              Text(
                widget.model.online ? t.chat.online : t.chat.offline,
                style: TextStyle(
                  color: widget.model.online
                      ? AppColors.onlineIndicator
                      : Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.6),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 构建设备详情卡片
  Widget _buildDeviceDetailsCard(BuildContext context, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: AppRadius.borderRadiusRegular,
      ),
      child: Column(
        children: [
          // 设备名称
          _buildDetailItem(
            context,
            icon: Icons.edit_outlined,
            title: t.account.deviceName,
            value: _deviceName,
            onTap: () => _editDeviceName(context),
            showArrow: true,
          ),

          _buildDivider(context),

          // 设备类型
          _buildDetailItem(
            context,
            icon: Icons.devices_outlined,
            title: t.account.deviceType,
            value: widget.model.showType,
          ),

          _buildDivider(context),

          // 最后活跃时间
          _buildDetailItem(
            context,
            icon: Icons.access_time_outlined,
            title: t.main.lastActiveTime,
            value: _formatLastActiveTime(),
          ),
        ],
      ),
    );
  }

  /// 构建详情项
  Widget _buildDetailItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String value,
    VoidCallback? onTap,
    bool showArrow = false,
  }) {
    return ClipRRect(
      borderRadius: AppRadius.borderRadiusRegular,
      child: CellPressable(
        onTap: onTap,
        child: Padding(
          padding: AppSpacing.allRegular,
          child: Row(
            children: [
              Icon(
                icon,
                size: 20,
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.7),
              ),
              AppSpacing.horizontalMedium,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                    AppSpacing.verticalTiny,
                    Text(
                      value,
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (showArrow) ...[
                AppSpacing.horizontalSmall,
                Icon(
                  Icons.chevron_right,
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.4),
                  size: 20,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// 构建分割线
  Widget _buildDivider(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16.0),
      height: 0.5,
      color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
    );
  }

  /// 构建活跃时间提示
  Widget _buildActiveTimeTips(BuildContext context, bool isDark) {
    return Container(
      padding: AppSpacing.allRegular,
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.info.withValues(alpha: 0.1)
            : AppColors.infoBlueContainer,
        borderRadius: AppRadius.borderRadiusMedium,
        border: isDark
            ? Border.all(
                color: AppColors.info.withValues(alpha: 0.3),
                width: 0.5,
              )
            : null,
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: AppColors.info, size: 20),
          AppSpacing.horizontalMedium,
          Expanded(
            child: Text(
              t.common.lastActiveTips,
              style: TextStyle(
                color: isDark
                    ? Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.8)
                    : AppColors.infoBlue,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 构建删除按钮
  Widget _buildDeleteButton(BuildContext context) {
    final errorColor = AppColors.getIosRed(Theme.of(context).brightness);
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () => _showDeleteDialog(context),
        icon: const Icon(Icons.delete_outline),
        label: Text(t.common.deleteThisDevice),
        style: ElevatedButton.styleFrom(
          backgroundColor: errorColor.withValues(alpha: 0.1),
          foregroundColor: errorColor,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: AppRadius.borderRadiusMedium,
            side: BorderSide(
              color: errorColor.withValues(alpha: 0.3),
              width: 0.5,
            ),
          ),
        ),
      ),
    );
  }

  /// 构建"让该设备下线"按钮（仅非当前设备显示）
  Widget _buildForceOfflineButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: widget.model.online
            ? () async {
                // 确认对话框
                final ok =
                    await showCupertinoDialog<bool>(
                      context: context,
                      builder: (ctx) => CupertinoAlertDialog(
                        title: Text(t.common.forceDeviceOffline),
                        content: Text(t.common.forceDeviceOfflineConfirm),
                        actions: [
                          CupertinoDialogAction(
                            onPressed: () => Navigator.of(ctx).pop(false),
                            child: Text(t.common.buttonCancel),
                          ),
                          CupertinoDialogAction(
                            isDestructiveAction: true,
                            onPressed: () => Navigator.of(ctx).pop(true),
                            child: Text(t.common.confirmForceOffline),
                          ),
                        ],
                      ),
                    ) ??
                    false;
                if (ok) {
                  await _forceOffline();
                }
              }
            : null,
        icon: const Icon(Icons.power_settings_new),
        label: Text(t.common.forceDeviceOffline),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.warning.withValues(alpha: 0.1),
          foregroundColor: AppColors.warning,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: AppRadius.borderRadiusMedium,
            side: BorderSide(
              color: AppColors.warning.withValues(alpha: 0.3),
              width: 0.5,
            ),
          ),
        ),
      ),
    );
  }

  /// 下发"强制下线"S2C 指令
  Future<void> _forceOffline() async {
    AppLoading.show(status: t.common.loading);
    try {
      final ok = await ref
          .read(userDeviceProvider.notifier)
          .forceOffline(widget.model.deviceId);
      AppLoading.dismiss();
      if (ok) {
        AppLoading.showSuccess(t.common.forceOfflineCommandSent);
      } else {
        AppLoading.showError(t.common.tipFailed);
      }
    } catch (e) {
      AppLoading.dismiss();
      AppLoading.showError(t.common.tipFailed);
    }
  }

  /// 获取设备类型对应的图标
  IconData _getDeviceIcon(String deviceType) {
    switch (deviceType.toLowerCase()) {
      case 'ios':
      case 'iphone':
        return Icons.phone_iphone;
      case 'android':
        return Icons.phone_android;
      case 'macos':
        return Icons.laptop_mac;
      case 'windows':
        return Icons.laptop_windows;
      case 'web':
        return Icons.web;
      case 'desktop':
        return Icons.desktop_mac;
      default:
        return Icons.devices;
    }
  }

  /// 格式化最后活跃时间
  String _formatLastActiveTime() {
    if (widget.model.lastActiveAt <= 0) {
      return t.common.unknown;
    }
    final dt = DateTime.fromMillisecondsSinceEpoch(widget.model.lastActiveAt);
    return DateTimeHelper.dateTimeFmt(
      dt,
      pattern: 'yyyy-MM-dd HH:mm:ss',
      relative: false,
    );
  }

  /// 编辑设备名称
  void _editDeviceName(BuildContext context) {
    Navigator.push(
      context,
      CupertinoPageRoute<dynamic>(
        builder: (context) => ChangeNamePage(
          title: t.main.setParam(param: t.account.deviceName),
          value: widget.model.deviceName,
          field: 'input',
          callback: (newName) async {
            AppLoading.show(status: t.common.loading);
            try {
              final result = await ref
                  .read(userDeviceProvider.notifier)
                  .changeName(deviceId: widget.model.deviceId, name: newName);
              AppLoading.dismiss();

              final success = result['success'] as bool;
              if (success) {
                setState(() {
                  _deviceName = newName;
                });
                return true;
              } else {
                // 显示具体错误消息
                final errorMsg = result['errorMsg'] as String?;
                AppLoading.showError(errorMsg ?? t.common.tipFailed);
                return false;
              }
            } catch (e) {
              AppLoading.dismiss();
              AppLoading.showError(t.common.tipFailed);
              return false;
            }
          },
        ),
      ),
    );
  }

  /// 显示删除确认对话框
  void _showDeleteDialog(BuildContext context) {
    showCupertinoDialog<void>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text(t.common.deleteThisDevice),
        content: Text(t.common.deleteThisDeviceTips),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(t.common.buttonCancel),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => _deleteDevice(ctx),
            child: Text(t.common.buttonDelete),
          ),
        ],
      ),
    );
  }

  /// 删除设备
  Future<void> _deleteDevice(BuildContext context) async {
    Navigator.of(context).pop(); // 关闭对话框

    AppLoading.show(status: t.common.loading);
    try {
      bool res = await ref
          .read(userDeviceProvider.notifier)
          .deleteDevice(widget.model.deviceId);
      AppLoading.dismiss();

      if (res && context.mounted) {
        AppLoading.showSuccess(t.common.tipSuccess);
        Navigator.of(context).pop(); // 返回设备列表页
      } else {
        AppLoading.showError(t.common.tipFailed);
      }
    } catch (e) {
      AppLoading.dismiss();
      AppLoading.showError(t.common.tipFailed);
    }
  }
}
