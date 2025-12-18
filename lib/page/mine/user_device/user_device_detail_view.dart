import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';
import 'package:imboy/component/ui/common_bar.dart';
import 'package:imboy/store/model/user_device_model.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/config/init.dart';
import 'package:jiffy/jiffy.dart';

import 'change_name_view.dart';
import 'user_device_logic.dart';

// 设备详情页面

class UserDeviceDetailPage extends StatelessWidget {
  final logic = Get.find<UserDeviceLogic>();
  final state = Get.find<UserDeviceLogic>().state;

  final UserDeviceModel model;

  UserDeviceDetailPage({super.key, required this.model});

  void initData() async {
    state.deviceName.value = model.deviceName;
  }

  @override
  Widget build(BuildContext context) {
    initData();
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: NavAppBar(
        automaticallyImplyLeading: true,
        title: 'device_details'.tr,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 设备信息卡片
            _buildDeviceInfoCard(context),
            const SizedBox(height: 16),

            // 设备详情
            _buildDeviceDetailsCard(context),
            const SizedBox(height: 16),

            // 活跃时间提示
            _buildActiveTimeTips(context),
            const SizedBox(height: 24),

            // 下线设备按钮（仅非当前设备显示）
            if (model.deviceId != deviceId) _buildForceOfflineButton(context),
            if (model.deviceId != deviceId) const SizedBox(height: 12),

            // 删除设备按钮
            _buildDeleteButton(context),
          ],
        ),
      ),
    );
  }

  /// 构建设备信息卡片
  Widget _buildDeviceInfoCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.15),
          width: 0.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.shadow.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
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
                  color: AppColors.primaryGreenAlpha20,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  _getDeviceIcon(model.deviceType),
                  size: 32,
                  color: AppColors.primaryGreen,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Obx(
                      () => Text(
                        state.deviceName.value,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      model.showType,
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
                  color: model.online
                      ? AppColors.onlineIndicator
                      : AppColors.offlineIndicator,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                model.online ? 'online'.tr : 'offline'.tr,
                style: TextStyle(
                  color: model.online
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
  Widget _buildDeviceDetailsCard(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.15),
          width: 0.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.shadow.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // 设备名称
          Obx(
            () => _buildDetailItem(
              context,
              icon: Icons.edit_outlined,
              title: 'device_name'.tr,
              value: state.deviceName.value,
              onTap: () => _editDeviceName(context),
              showArrow: true,
            ),
          ),

          _buildDivider(context),

          // 设备类型
          _buildDetailItem(
            context,
            icon: Icons.devices_outlined,
            title: 'device_type'.tr,
            value: model.showType,
          ),

          _buildDivider(context),

          // 最后活跃时间
          _buildDetailItem(
            context,
            icon: Icons.access_time_outlined,
            title: 'last_active_time'.tr,
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
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
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
  Widget _buildActiveTimeTips(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: AppColors.info.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.info.withValues(alpha: 0.3),
          width: 0.5,
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: AppColors.info, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'last_active_tips'.tr,
              style: TextStyle(
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.8),
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
        label: Text('delete_this_device'.tr),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.lightError.withValues(alpha: 0.1),
          foregroundColor: AppColors.lightError,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: AppColors.lightError.withValues(alpha: 0.3),
              width: 0.5,
            ),
          ),
        ),
      ),
    );
  }

  /// 构建“让该设备下线”按钮（仅非当前设备显示）
  /// 用途：向目标设备下发 S2C“强制下线”指令，由对端 MessageS2CService 处理后退出登录
  /// 返回：按钮组件
  Widget _buildForceOfflineButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: model.online
            ? () async {
                // 确认对话框
                final ok =
                    await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        title: Row(
                          children: [
                            Icon(
                              Icons.power_settings_new,
                              color: AppColors.warning,
                              size: 22,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '让该设备下线',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                        content: Text(
                          '将向该设备发送下线指令，确认继续？',
                          style: TextStyle(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurface.withValues(alpha: 0.8),
                            height: 1.4,
                          ),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(ctx).pop(false),
                            child: Text(
                              'button_cancel'.tr,
                              style: TextStyle(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurface.withValues(alpha: 0.7),
                              ),
                            ),
                          ),
                          ElevatedButton(
                            onPressed: () => Navigator.of(ctx).pop(true),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.warning,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: Text(
                              '确认下线',
                              style: TextStyle(fontWeight: FontWeight.w500),
                            ),
                          ),
                        ],
                      ),
                    ) ??
                    false;
                if (ok) {
                  await _forceOffline(context);
                }
              }
            : null,
        icon: const Icon(Icons.power_settings_new),
        label: const Text('让该设备下线'),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.warning.withValues(alpha: 0.1),
          foregroundColor: AppColors.warning,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: AppColors.warning.withValues(alpha: 0.3),
              width: 0.5,
            ),
          ),
        ),
      ),
    );
  }

  /// 下发“强制下线”S2C 指令
  /// 用途：调用逻辑层 forceOffline 请求服务端对目标设备发送下线消息
  /// 成功：提示“已发送下线指令”，不移除设备
  /// 失败：统一失败提示
  Future<void> _forceOffline(BuildContext context) async {
    EasyLoading.show(status: '处理中...'.tr);
    try {
      final ok = await logic.forceOffline(model.deviceId);
      EasyLoading.dismiss();
      if (ok) {
        EasyLoading.showSuccess('已发送下线指令');
      } else {
        EasyLoading.showError('操作失败'.tr);
      }
    } catch (e) {
      EasyLoading.dismiss();
      EasyLoading.showError('操作失败'.tr);
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
    if (model.lastActiveAt <= 0) {
      return '未知';
    }
    return Jiffy.parseFromMillisecondsSinceEpoch(
      model.lastActiveAt,
    ).format(pattern: 'yyyy-MM-dd HH:mm:ss');
  }

  /// 编辑设备名称
  void _editDeviceName(BuildContext context) {
    Get.to(
      () => ChangeNamePage(
        title: 'set_param'.trArgs(['device_name'.tr]),
        value: model.deviceName,
        field: 'input',
        callback: (newName) async {
          bool ok = await logic.changeName(
            deviceId: model.deviceId,
            name: newName,
          );
          if (ok) {
            state.deviceName.value = newName;
            int i = state.deviceList.indexWhere(
              (e) => e.deviceId == model.deviceId,
            );
            if (i >= 0) {
              model.deviceName = newName;
              state.deviceList.replaceRange(i, i + 1, [model]);
            }
          }
          return ok;
        },
      ),
      transition: Transition.rightToLeft,
      popGesture: true,
    );
  }

  /// 显示删除确认对话框
  void _showDeleteDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(
              Icons.warning_amber_rounded,
              color: AppColors.warning,
              size: 24,
            ),
            const SizedBox(width: 12),
            Text(
              'delete_this_device'.tr,
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
        ),
        content: Text(
          'delete_this_device_tips'.tr,
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
              'button_cancel'.tr,
              style: TextStyle(
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => _deleteDevice(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.warning.withValues(alpha: 0.1),
              foregroundColor: AppColors.warning,
              disabledBackgroundColor: Theme.of(
                context,
              ).colorScheme.outline.withValues(alpha: 0.12),
              disabledForegroundColor: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.38),
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: AppColors.warning.withValues(alpha: 0.3),
                  width: 0.5,
                ),
              ),
            ),
            child: Text('button_delete'.tr),
          ),
        ],
      ),
    );
  }

  /// 删除设备
  Future<void> _deleteDevice(BuildContext context) async {
    Navigator.of(context).pop(); // 关闭对话框

    EasyLoading.show(status: '处理中...'.tr);
    try {
      bool res = await logic.deleteDevice(model.deviceId);
      EasyLoading.dismiss();

      if (res) {
        state.deviceList.removeWhere((e) => e.deviceId == model.deviceId);
        EasyLoading.showSuccess('tip_success'.tr);
        Get.back(); // 返回设备列表页
      } else {
        EasyLoading.showError('tip_failed'.tr);
      }
    } catch (e) {
      EasyLoading.dismiss();
      EasyLoading.showError('tip_failed'.tr);
    }
  }
}
