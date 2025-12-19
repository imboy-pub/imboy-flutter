import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:get/get.dart';
import 'package:imboy/component/helper/datetime.dart';
import 'package:imboy/component/ui/common_bar.dart';
import 'package:imboy/component/ui/nodata_view.dart';
import 'package:imboy/config/init.dart';
import 'package:imboy/store/model/user_device_model.dart';
import 'package:imboy/theme/default/app_colors.dart';

import 'user_device_detail_view.dart';
import 'user_device_logic.dart';

// ignore: must_be_immutable
class UserDevicePage extends StatelessWidget {
  int page = 1;
  int size = 1000;

  final logic = Get.put(UserDeviceLogic());
  final state = Get.find<UserDeviceLogic>().state;
  RxString currentDid = "".obs;

  UserDevicePage({super.key});

  void initData() async {
    currentDid.value = deviceId;
    var list = await logic.page(page: page, size: size);
    state.deviceList.value = list;
  }

  @override
  Widget build(BuildContext context) {
    initData();
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: NavAppBar(
        automaticallyImplyLeading: true,
        title: 'loginDeviceManagement'.tr,
      ),
      body: Column(
        children: [
          // 提示信息卡片
          _buildTipsCard(context),
          
          // 设备列表
          Expanded(
            child: Obx(() {
              return state.deviceList.isEmpty
                  ? _buildEmptyState(context)
                  : _buildDeviceList(context);
            }),
          ),
        ],
      ),
    );
  }

  /// 构建提示信息卡片
  Widget _buildTipsCard(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16.0),
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
          width: 0.5,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline,
            color: AppColors.info,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'loginDeviceManagementTips'.tr,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
                height: 1.4,
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
              borderRadius: BorderRadius.circular(40),
            ),
            child: Icon(
              Icons.devices_outlined,
              size: 40,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'noData'.tr,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  /// 构建设备列表
  Widget _buildDeviceList(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      itemCount: state.deviceList.length,
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (BuildContext context, int index) {
        UserDeviceModel model = state.deviceList[index];
        return _buildDeviceCard(context, model, index);
      },
    );
  }

  /// 构建设备卡片
  Widget _buildDeviceCard(BuildContext context, UserDeviceModel model, int index) {
    final isCurrentDevice = currentDid.value == model.deviceId;
    
    return Slidable(
      key: ValueKey(model.deviceId),
      enabled: !isCurrentDevice, // 当前设备不允许滑动删除
      endActionPane: isCurrentDevice ? null : ActionPane(
        extentRatio: 0.5,
        motion: const ScrollMotion(),
        children: [
          SlidableAction(
            onPressed: model.online ? (_) => _showForceOfflineDialog(context, model) : (_) {},
            backgroundColor: model.online
                ? AppColors.warning
                : Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
            foregroundColor: model.online
                ? Colors.white
                : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
            icon: Icons.power_settings_new,
            label: '下线',
            borderRadius: BorderRadius.circular(12),
          ),
          SlidableAction(
            onPressed: (_) => _showDeleteDialog(context, model),
            backgroundColor: AppColors.lightError,
            foregroundColor: Colors.white,
            icon: Icons.delete_outline,
            label: 'buttonDelete'.tr,
            borderRadius: BorderRadius.circular(12),
          ),
        ],
      ),
      child: Container(
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
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () {
              Get.to(
                () => UserDeviceDetailPage(model: model),
                transition: Transition.rightToLeft,
                popGesture: true,
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
                          ? AppColors.primaryGreenAlpha20
                          : Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      _getDeviceIcon(model.deviceType),
                      size: 24,
                      color: isCurrentDevice 
                          ? AppColors.primaryGreen
                          : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
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
                                  color: Theme.of(context).colorScheme.onSurface,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (isCurrentDevice) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppColors.primaryGreenAlpha20,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'currentDevice'.tr,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w500,
                                    color: AppColors.primaryGreen,
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
                              model.online ? 'online'.tr : 'offline'.tr,
                              style: TextStyle(
                                color: model.online 
                                    ? AppColors.onlineIndicator
                                    : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            if (model.lastActiveAt > 0) ...[
                              const SizedBox(width: 16),
                              Expanded(
                                child: Text(
                                  DateTimeHelper.lastTimeFmt(model.lastActiveAt),
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
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
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
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
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text(
          'buttonDelete'.tr,
          style: TextStyle(
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Text(
          'deleteThisDeviceTips'.tr,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'buttonCancel'.tr,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
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
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              'buttonDelete'.tr,
              style: TextStyle(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 删除设备
  Future<void> _deleteDevice(UserDeviceModel model) async {
    EasyLoading.show(status: '处理中...'.tr);
    try {
      bool res = await logic.deleteDevice(model.deviceId);
      EasyLoading.dismiss();
      
      if (res) {
        state.deviceList.removeWhere((e) => e.deviceId == model.deviceId);
        EasyLoading.showSuccess('tipSuccess'.tr);
      } else {
        EasyLoading.showError('tipFailed'.tr);
      }
    } catch (e) {
      EasyLoading.dismiss();
      EasyLoading.showError('tipFailed'.tr);
    }
  }

  /// 显示“让该设备下线”确认对话框
  /// 仅对非当前设备使用；确认后调用后端下发 S2C 指令
  void _showForceOfflineDialog(BuildContext context, UserDeviceModel model) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text(
          '让该设备下线',
          style: TextStyle(
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Text(
          '将向该设备发送下线指令，确认继续？',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'buttonCancel'.tr,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
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
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              '确认下线',
              style: TextStyle(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 调用后端接口下发“强制下线”S2C 指令
  /// 成功仅提示“已发送下线指令”，不从列表移除设备
  Future<void> _forceOffline(UserDeviceModel model) async {
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
}
