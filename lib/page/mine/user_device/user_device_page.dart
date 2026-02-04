import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:imboy/component/helper/datetime.dart';
import 'package:imboy/component/ui/common_bar.dart';
import 'package:imboy/config/init.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/store/model/user_device_model.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_radius.dart';

import 'user_device_provider.dart';
import 'user_device_detail_page.dart';

/// 用户设备管理页面
class UserDevicePage extends ConsumerStatefulWidget {
  const UserDevicePage({super.key});

  @override
  ConsumerState<UserDevicePage> createState() => _UserDevicePageState();
}

class _UserDevicePageState extends ConsumerState<UserDevicePage> {
  @override
  void initState() {
    super.initState();
    // 加载数据
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final notifier = ref.read(userDeviceProvider.notifier);
      notifier.setCurrentDeviceId(deviceId);
      notifier.loadDevices(page: 1, size: 1000);
    });
  }

  @override
  Widget build(BuildContext context) {
    final deviceState = ref.watch(userDeviceProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark
          ? Theme.of(context).colorScheme.surface
          : const Color(0xFFF5F5F5),
      appBar: GlassAppBar(
        automaticallyImplyLeading: true,
        title: t.loginDeviceManagement,
      ),
      body: Column(
        children: [
          // 提示信息卡片
          _buildTipsCard(context, isDark),

          // 设备列表
          Expanded(
            child: deviceState.isLoading
                ? const Center(child: CircularProgressIndicator())
                : deviceState.deviceList.isEmpty
                ? _buildEmptyState(context)
                : _buildDeviceList(context, deviceState, isDark),
          ),
        ],
      ),
    );
  }

  /// 构建提示信息卡片
  Widget _buildTipsCard(BuildContext context, bool isDark) {
    return Container(
      margin: const EdgeInsets.all(16.0),
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: isDark
            ? Theme.of(context).colorScheme.surfaceContainerHighest
            : const Color(0xFFE1F5FE),
        borderRadius: AppRadius.borderRadiusMedium,
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: AppColors.info, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              t.loginDeviceManagementTips,
              style: TextStyle(
                color: isDark
                    ? Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.8)
                    : const Color(0xFF0277BD),
                height: 1.4,
                fontSize: 13,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  /// 构建空状态
  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: AppRadius.borderRadiusXLarge,
            ),
            child: Icon(
              Icons.devices_outlined,
              size: 40,
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            t.noData,
            style: TextStyle(
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.6),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  /// 构建设备列表
  Widget _buildDeviceList(
    BuildContext context,
    UserDeviceState deviceState,
    bool isDark,
  ) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      itemCount: deviceState.deviceList.length,
      separatorBuilder: (context, index) => const SizedBox(height: 10),
      itemBuilder: (BuildContext context, int index) {
        UserDeviceModel model = deviceState.deviceList[index];
        return _buildDeviceCard(
          context,
          model,
          deviceState.currentDeviceId,
          isDark,
        );
      },
    );
  }

  /// 构建设备卡片
  Widget _buildDeviceCard(
    BuildContext context,
    UserDeviceModel model,
    String currentDid,
    bool isDark,
  ) {
    final isCurrentDevice = currentDid == model.deviceId;

    return Slidable(
      key: ValueKey(model.deviceId),
      enabled: !isCurrentDevice, // 当前设备不允许滑动删除
      endActionPane: isCurrentDevice
          ? null
          : ActionPane(
              extentRatio: 0.5,
              motion: const ScrollMotion(),
              children: [
                SlidableAction(
                  onPressed: model.online
                      ? (_) => _showForceOfflineDialog(context, model)
                      : (_) {},
                  backgroundColor: model.online
                      ? AppColors.warning
                      : Theme.of(
                          context,
                        ).colorScheme.outline.withValues(alpha: 0.3),
                  foregroundColor: model.online
                      ? Colors.white
                      : Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.4),
                  icon: Icons.power_settings_new,
                  label: t.forceOffline,
                  borderRadius: AppRadius.borderRadiusMedium,
                ),
                SlidableAction(
                  onPressed: (_) => _showDeleteDialog(context, model),
                  backgroundColor: AppColors.lightError,
                  foregroundColor: Colors.white,
                  icon: Icons.delete_outline,
                  label: t.buttonDelete,
                  borderRadius: AppRadius.borderRadiusMedium,
                ),
              ],
            ),
      child: Container(
        decoration: BoxDecoration(
          color: isDark
              ? Theme.of(context).colorScheme.surfaceContainerHighest
              : Colors.white,
          borderRadius: AppRadius.borderRadiusMedium,
          border: isDark
              ? Border.all(
                  color: Theme.of(
                    context,
                  ).colorScheme.outline.withValues(alpha: 0.15),
                  width: 0.5,
                )
              : null,
          boxShadow: [
            BoxShadow(
              color: isDark
                  ? Colors.transparent
                  : Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: AppRadius.borderRadiusMedium,
            onTap: () {
              Navigator.push(
                context,
                CupertinoPageRoute(
                  builder: (context) => UserDeviceDetailPage(model: model),
                ),
              );
            },
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  // 设备图标
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: isCurrentDevice
                          ? AppColors.primaryAlpha20
                          : (isDark
                                ? Theme.of(
                                    context,
                                  ).colorScheme.outline.withValues(alpha: 0.1)
                                : const Color(0xFFF5F5F5)),
                      borderRadius: AppRadius.borderRadiusMedium,
                    ),
                    child: Icon(
                      _getDeviceIcon(model.deviceType),
                      size: 24,
                      color: isCurrentDevice
                          ? AppColors.primary
                          : Theme.of(
                              context,
                            ).colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(width: 16),

                  // 设备信息
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 设备名称和当前设备标签
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                model.deviceName,
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurface,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (isCurrentDevice) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.primaryAlpha20,
                                  borderRadius: AppRadius.borderRadiusSmall,
                                ),
                                child: Text(
                                  t.currentDevice,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w500,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 8),

                        // 在线状态和最后活跃时间
                        Row(
                          children: [
                            // 在线状态指示器
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: model.online
                                    ? AppColors.onlineIndicator
                                    : AppColors.offlineIndicator,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              model.online ? t.online : t.offline,
                              style: TextStyle(
                                color: model.online
                                    ? AppColors.onlineIndicator
                                    : Theme.of(context).colorScheme.onSurface
                                          .withValues(alpha: 0.6),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            if (model.lastActiveAt > 0) ...[
                              const SizedBox(width: 16),
                              Expanded(
                                child: Text(
                                  DateTimeHelper.lastTimeFmt(
                                    model.lastActiveAt,
                                  ),
                                  style: TextStyle(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withValues(alpha: 0.6),
                                  ),
                                  textAlign: TextAlign.right,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),

                  // 箭头图标
                  const SizedBox(width: 8),
                  Icon(
                    Icons.chevron_right,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.4),
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
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

  /// 显示删除确认对话框
  void _showDeleteDialog(BuildContext context, UserDeviceModel model) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.borderRadiusRegular,
        ),
        title: Text(
          t.buttonDelete,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        content: Text(
          t.deleteThisDeviceTips,
          style: TextStyle(
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.8),
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              t.buttonCancel,
              style: TextStyle(
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await _deleteDevice(model);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.lightError,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: AppRadius.borderRadiusSmall,
              ),
            ),
            child: Text(
              t.buttonDelete,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  /// 删除设备
  Future<void> _deleteDevice(UserDeviceModel model) async {
    EasyLoading.show(status: t.loading);
    try {
      bool res = await ref
          .read(userDeviceProvider.notifier)
          .deleteDevice(model.deviceId);
      EasyLoading.dismiss();

      if (res) {
        EasyLoading.showSuccess(t.tipSuccess);
      } else {
        EasyLoading.showError(t.tipFailed);
      }
    } catch (e) {
      EasyLoading.dismiss();
      EasyLoading.showError(t.tipFailed);
    }
  }

  /// 显示"让该设备下线"确认对话框
  void _showForceOfflineDialog(BuildContext context, UserDeviceModel model) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.borderRadiusRegular,
        ),
        title: Text(
          t.forceDeviceOffline,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        content: Text(
          t.forceDeviceOfflineConfirm,
          style: TextStyle(
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.8),
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              t.buttonCancel,
              style: TextStyle(
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await _forceOffline(model);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.warning,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: AppRadius.borderRadiusSmall,
              ),
            ),
            child: Text(
              t.confirmForceOffline,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  /// 调用后端接口下发"强制下线"S2C 指令
  Future<void> _forceOffline(UserDeviceModel model) async {
    EasyLoading.show(status: t.loading);
    try {
      final ok = await ref
          .read(userDeviceProvider.notifier)
          .forceOffline(model.deviceId);
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
}
