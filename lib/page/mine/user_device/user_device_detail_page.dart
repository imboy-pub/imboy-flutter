import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:imboy/component/ui/cell_pressable.dart';
import 'package:imboy/component/ui/common_bar.dart';
import 'package:imboy/config/init.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/store/model/user_device_model.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_radius.dart';
import 'package:intl/intl.dart';

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
        title: t.deviceDetails,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 设备信息卡片
            _buildDeviceInfoCard(context, isDark),
            const SizedBox(height: 16),

            // 设备详情
            _buildDeviceDetailsCard(context, isDark),
            const SizedBox(height: 16),

            // 活跃时间提示
            _buildActiveTimeTips(context, isDark),
            const SizedBox(height: 24),

            // 下线设备按钮（仅非当前设备显示）
            if (widget.model.deviceId != deviceId)
              _buildForceOfflineButton(context),
            if (widget.model.deviceId != deviceId) const SizedBox(height: 12),

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
      padding: const EdgeInsets.all(20.0),
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
                      : const Color(0xFFE8F5E9),
                  borderRadius: AppRadius.borderRadiusRegular,
                ),
                child: Icon(
                  _getDeviceIcon(widget.model.deviceType),
                  size: 32,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _deviceName,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onSurface,
                        fontSize: 18,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
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
          const SizedBox(height: 16),

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
              const SizedBox(width: 8),
              Text(
                widget.model.online ? t.online : t.offline,
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
            title: t.deviceName,
            value: _deviceName,
            onTap: () => _editDeviceName(context),
            showArrow: true,
          ),

          _buildDivider(context),

          // 设备类型
          _buildDetailItem(
            context,
            icon: Icons.devices_outlined,
            title: t.deviceType,
            value: widget.model.showType,
          ),

          _buildDivider(context),

          // 最后活跃时间
          _buildDetailItem(
            context,
            icon: Icons.access_time_outlined,
            title: t.lastActiveTime,
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
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Icon(
                icon,
                size: 20,
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.7),
              ),
              const SizedBox(width: 12),
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
                    const SizedBox(height: 4),
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
                const SizedBox(width: 8),
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
      padding: const EdgeInsets.all(16.0),
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
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              t.lastActiveTips,
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
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () => _showDeleteDialog(context),
        icon: const Icon(Icons.delete_outline),
        label: Text(t.deleteThisDevice),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.lightError.withValues(alpha: 0.1),
          foregroundColor: AppColors.lightError,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: AppRadius.borderRadiusMedium,
            side: BorderSide(
              color: AppColors.lightError.withValues(alpha: 0.3),
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
                        title: Text(t.forceDeviceOffline),
                        content: Text(t.forceDeviceOfflineConfirm),
                        actions: [
                          CupertinoDialogAction(
                            onPressed: () => Navigator.of(ctx).pop(false),
                            child: Text(t.buttonCancel),
                          ),
                          CupertinoDialogAction(
                            isDestructiveAction: true,
                            onPressed: () => Navigator.of(ctx).pop(true),
                            child: Text(t.confirmForceOffline),
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
        label: Text(t.forceDeviceOffline),
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
    EasyLoading.show(status: t.loading);
    try {
      final ok = await ref
          .read(userDeviceProvider.notifier)
          .forceOffline(widget.model.deviceId);
      EasyLoading.dismiss();
      if (ok) {
        EasyLoading.showSuccess(t.forceOfflineCommandSent);
      } else {
        EasyLoading.showError(t.tipFailed);
      }
    } catch (e) {
      EasyLoading.dismiss();
      EasyLoading.showError(t.tipFailed);
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
      return t.unknown;
    }
    final dt = DateTime.fromMillisecondsSinceEpoch(widget.model.lastActiveAt);
    return DateFormat('yyyy-MM-dd HH:mm:ss').format(dt);
  }

  /// 编辑设备名称
  void _editDeviceName(BuildContext context) {
    Navigator.push(
      context,
      CupertinoPageRoute<dynamic>(
        builder: (context) => ChangeNamePage(
          title: t.setParam(param: t.deviceName),
          value: widget.model.deviceName,
          field: 'input',
          callback: (newName) async {
            EasyLoading.show(status: t.loading);
            try {
              final result = await ref
                  .read(userDeviceProvider.notifier)
                  .changeName(deviceId: widget.model.deviceId, name: newName);
              EasyLoading.dismiss();

              final success = result['success'] as bool;
              if (success) {
                setState(() {
                  _deviceName = newName;
                });
                return true;
              } else {
                // 显示具体错误消息
                final errorMsg = result['errorMsg'] as String?;
                EasyLoading.showError(errorMsg ?? t.tipFailed);
                return false;
              }
            } catch (e) {
              EasyLoading.dismiss();
              EasyLoading.showError(t.tipFailed);
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
        title: Text(t.deleteThisDevice),
        content: Text(t.deleteThisDeviceTips),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(t.buttonCancel),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => _deleteDevice(ctx),
            child: Text(t.buttonDelete),
          ),
        ],
      ),
    );
  }

  /// 删除设备
  Future<void> _deleteDevice(BuildContext context) async {
    Navigator.of(context).pop(); // 关闭对话框

    EasyLoading.show(status: t.loading);
    try {
      bool res = await ref
          .read(userDeviceProvider.notifier)
          .deleteDevice(widget.model.deviceId);
      EasyLoading.dismiss();

      if (res && mounted) {
        EasyLoading.showSuccess(t.tipSuccess);
        Navigator.of(context).pop(); // 返回设备列表页
      } else {
        EasyLoading.showError(t.tipFailed);
      }
    } catch (e) {
      EasyLoading.dismiss();
      EasyLoading.showError(t.tipFailed);
    }
  }
}
