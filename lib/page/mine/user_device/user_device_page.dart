import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:imboy/component/helper/datetime.dart';
import 'package:imboy/component/ui/ios_settings_ui.dart';
import 'package:imboy/config/init.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/store/model/user_device_model.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_radius.dart';

import 'user_device_provider.dart';
import 'user_device_detail_page.dart';

/// 用户设备管理页面 - 像素级对齐 iOS 设置风
class UserDevicePage extends ConsumerStatefulWidget {
  const UserDevicePage({super.key});

  @override
  ConsumerState<UserDevicePage> createState() => _UserDevicePageState();
}

class _UserDevicePageState extends ConsumerState<UserDevicePage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final notifier = ref.read(userDeviceProvider.notifier);
      notifier.setCurrentDeviceId(deviceId);
      notifier.loadDevices(page: 1, size: 1000);
    });
  }

  @override
  Widget build(BuildContext context) {
    final deviceState = ref.watch(userDeviceProvider);
    final brightness = Theme.of(context).brightness;

    return IosPageTemplate(
      title: t.account.loginDeviceManagement,
      useLargeTitle: false,
      slivers: [
        // 提示信息 Section
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: _buildTipsCard(context, brightness == Brightness.dark),
          ),
        ),

        // 设备列表 Section
        if (deviceState.isLoading)
          const SliverFillRemaining(child: Center(child: CupertinoActivityIndicator()))
        else if (deviceState.deviceList.isEmpty)
          SliverFillRemaining(child: _buildEmptyState(context))
        else
          SliverToBoxAdapter(
            child: ImBoySettingsSection(
              header: Text(t.account.loginDeviceManagement.toUpperCase()),
              children: deviceState.deviceList.asMap().entries.map((entry) {
                return _buildDeviceItem(context, entry.value, deviceState.currentDeviceId, brightness);
              }).toList(),
            ),
          ),
      ],
    );
  }

  Widget _buildTipsCard(BuildContext context, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: AppColors.getIosBlue(Theme.of(context).brightness).withValues(alpha: 0.1),
        borderRadius: AppRadius.borderRadiusCell,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(CupertinoIcons.info, color: AppColors.getIosBlue(Theme.of(context).brightness), size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              t.common.loginDeviceManagementTips,
              style: TextStyle(
                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                height: 1.4,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(CupertinoIcons.device_phone_portrait, size: 60, color: AppColors.iosGray.withValues(alpha: 0.3)),
          const SizedBox(height: 16),
          Text(t.common.noData, style: const TextStyle(color: AppColors.iosGray, fontSize: 15)),
        ],
      ),
    );
  }

  Widget _buildDeviceItem(BuildContext context, UserDeviceModel model, String currentDid, Brightness brightness) {
    final isCurrentDevice = currentDid == model.deviceId;

    final itemTile = ImBoySettingsTile(
      onTap: () => Navigator.push(context, CupertinoPageRoute(builder: (context) => UserDeviceDetailPage(model: model))),
      leading: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: isCurrentDevice ? AppColors.getIosBlue(brightness) : AppColors.iosGray,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(_getDeviceIcon(model.deviceType), size: 20, color: Colors.white),
      ),
      title: Row(
        children: [
          Expanded(child: Text(model.deviceName, maxLines: 1, overflow: TextOverflow.ellipsis)),
          if (isCurrentDevice) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: AppColors.getIosBlue(brightness).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
              child: Text(t.account.currentDevice, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.getIosBlue(brightness))),
            ),
          ],
        ],
      ),
      subtitle: Row(
        children: [
          Container(width: 6, height: 6, decoration: BoxDecoration(color: model.online ? AppColors.iosGreen : AppColors.iosGray, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text(model.online ? t.chat.online : t.chat.offline, style: const TextStyle(fontSize: 12, color: AppColors.iosGray)),
          if (model.lastActiveAt > 0) ...[
            const SizedBox(width: 8),
            Text(DateTimeHelper.lastTimeFmt(model.lastActiveAt), style: const TextStyle(fontSize: 12, color: AppColors.iosGray)),
          ],
        ],
      ),
    );

    if (isCurrentDevice) return itemTile;

    return Slidable(
      key: ValueKey(model.deviceId),
      endActionPane: ActionPane(
        extentRatio: 0.5,
        motion: const ScrollMotion(),
        children: [
          SlidableAction(
            onPressed: model.online ? (_) => _showForceOfflineDialog(context, model) : null,
            backgroundColor: AppColors.iosOrange,
            foregroundColor: Colors.white,
            icon: CupertinoIcons.power,
            label: t.common.forceOffline,
          ),
          SlidableAction(
            onPressed: (_) => _showDeleteDialog(context, model),
            backgroundColor: AppColors.getIosRed(brightness),
            foregroundColor: Colors.white,
            icon: CupertinoIcons.delete,
            label: t.common.buttonDelete,
          ),
        ],
      ),
      child: itemTile,
    );
  }

  IconData _getDeviceIcon(String deviceType) {
    switch (deviceType.toLowerCase()) {
      case 'ios': case 'iphone': return Icons.phone_iphone;
      case 'android': return Icons.phone_android;
      case 'macos': return Icons.laptop_mac;
      case 'windows': return Icons.laptop_windows;
      case 'web': return Icons.web;
      case 'desktop': return Icons.desktop_mac;
      default: return Icons.devices;
    }
  }

  void _showDeleteDialog(BuildContext context, UserDeviceModel model) {
    showCupertinoDialog<void>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text(t.common.buttonDelete),
        content: Text(t.common.deleteThisDeviceTips),
        actions: [
          CupertinoDialogAction(onPressed: () => Navigator.pop(context), child: Text(t.common.buttonCancel)),
          CupertinoDialogAction(isDestructiveAction: true, onPressed: () async { Navigator.pop(context); await _deleteDevice(model); }, child: Text(t.common.buttonDelete)),
        ],
      ),
    );
  }

  Future<void> _deleteDevice(UserDeviceModel model) async {
    EasyLoading.show(status: t.common.loading);
    try {
      if (await ref.read(userDeviceProvider.notifier).deleteDevice(model.deviceId)) EasyLoading.showSuccess(t.common.tipSuccess);
      else EasyLoading.showError(t.common.tipFailed);
    } catch (_) { EasyLoading.dismiss(); EasyLoading.showError(t.common.tipFailed); }
  }

  void _showForceOfflineDialog(BuildContext context, UserDeviceModel model) {
    showCupertinoDialog<void>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text(t.common.forceDeviceOffline),
        content: Text(t.common.forceDeviceOfflineConfirm),
        actions: [
          CupertinoDialogAction(onPressed: () => Navigator.pop(context), child: Text(t.common.buttonCancel)),
          CupertinoDialogAction(isDestructiveAction: true, onPressed: () async { Navigator.pop(context); await _forceOffline(model); }, child: Text(t.common.confirmForceOffline)),
        ],
      ),
    );
  }

  Future<void> _forceOffline(UserDeviceModel model) async {
    EasyLoading.show(status: t.common.loading);
    try {
      if (await ref.read(userDeviceProvider.notifier).forceOffline(model.deviceId)) EasyLoading.showSuccess(t.common.forceOfflineCommandSent);
      else EasyLoading.showError(t.common.tipFailed);
    } catch (_) { EasyLoading.dismiss(); EasyLoading.showError(t.common.tipFailed); }
  }
}
