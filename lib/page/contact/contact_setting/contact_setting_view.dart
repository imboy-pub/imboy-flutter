import 'package:flutter/material.dart';
import 'package:imboy/component/ui/common_bar.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';
import 'package:imboy/component/helper/datetime.dart';
import 'package:imboy/page/bottom_navigation/bottom_navigation_view.dart';
import 'package:imboy/page/mine/denylist/denylist_logic.dart';
import 'package:imboy/store/model/denylist_model.dart';

import '../contact_setting_tag/contact_setting_tag_view.dart';
import 'contact_setting_logic.dart';

// ignore: must_be_immutable
class ContactSettingPage extends StatelessWidget {
  final String peerId; // 用户ID
  final String peerAccount;
  final String peerAvatar;
  final String peerTitle;
  final String peerNickname;
  final int peerGender;
  final String peerSign;
  final String peerRegion;
  final String peerSource;
  String peerRemark;
  final String peerTag;

  ContactSettingPage({
    super.key,
    required this.peerId,
    required this.peerAccount,
    required this.peerAvatar,
    required this.peerNickname,
    required this.peerGender,
    required this.peerTitle,
    required this.peerSign,
    required this.peerRegion,
    required this.peerSource,
    required this.peerRemark,
    required this.peerTag,
  });

  final logic = Get.put(ContactSettingLogic());
  RxBool inDenylist = false.obs;

  /// 初始化数据
  Future<void> initData() async {
    inDenylist.value = await DenylistLogic.inDenylist(peerId);
  }

  /// 构建设置项卡片
  Widget _buildSettingCard({
    required BuildContext context,
    required String title,
    required IconData icon,
    required VoidCallback onTap,
    Color? iconColor,
    Widget? trailing,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
          width: 0.5,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: iconColor ?? Theme.of(context).colorScheme.primary,
                  size: 24,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
                trailing ?? Icon(
                  Icons.chevron_right,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 构建开关设置项
  Widget _buildSwitchCard({
    required BuildContext context,
    required String title,
    required IconData icon,
    required bool value,
    ValueChanged<bool>? onChanged,
    Color? iconColor,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
          width: 0.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        child: Row(
          children: [
            Icon(
              icon,
              color: iconColor ?? Theme.of(context).colorScheme.primary,
              size: 24,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),
            Switch(
              value: value,
              onChanged: onChanged,
              activeColor: Theme.of(context).colorScheme.primary,
            ),
          ],
        ),
      ),
    );
  }

  /// 构建危险操作按钮
  Widget _buildDangerButton({
    required BuildContext context,
    required String title,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.errorContainer.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.error.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  color: Theme.of(context).colorScheme.error,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 显示删除确认对话框
  void _showDeleteConfirmation(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    Get.bottomSheet(
      Container(
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20.0),
            topRight: Radius.circular(20.0),
          ),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 顶部指示条
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(top: 12, bottom: 20),
                decoration: BoxDecoration(
                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              
              // 警告图标
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: colorScheme.errorContainer.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.warning_amber_rounded,
                  color: colorScheme.error,
                  size: 32,
                ),
              ),
              
              const SizedBox(height: 20),
              
              // 标题
              Text(
                'deleteContact'.tr,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface,
                ),
              ),
              
              const SizedBox(height: 12),
              
              // 描述文字
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Text(
                  'tipDeleteContact'.trArgs([peerRemark.isEmpty ? peerNickname : peerRemark]),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: colorScheme.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),
              ),
              
              const SizedBox(height: 32),
              
              // 按钮区域
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Column(
                  children: [
                    // 删除按钮
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: () async {
                          Get.back(); // 先关闭底部弹窗
                          EasyLoading.show(status: '删除中...'.tr);
                          bool res = await logic.deleteContact(peerId);
                          EasyLoading.dismiss();
                          if (res) {
                            EasyLoading.showSuccess("操作成功".tr);
                            Get.offAll(() => BottomNavigationPage(), arguments: {'index': 1});
                          } else {
                            EasyLoading.showError("操作失败".tr);
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: colorScheme.error,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(25),
                          ),
                        ),
                        child: Text(
                          'deleteContact'.tr,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 12),
                    
                    // 取消按钮
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: TextButton(
                        onPressed: () => Get.back(),
                        style: TextButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(25),
                          ),
                        ),
                        child: Text(
                          'buttonCancel'.tr,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
      isScrollControlled: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    initData();
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: GlassAppBar(
        titleWidget: Text(
          'profileSettings'.tr,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: colorScheme.onSurface,
          ),
        ),
        backgroundColor: colorScheme.surface,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios,
            color: colorScheme.onSurface,
          ),
          onPressed: () => Get.back(),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 8),
            
            // 设置备注和标签
            _buildSettingCard(
              context: context,
              title: 'setParam'.trArgs(['remarksTags'.tr]),
              icon: Icons.edit_outlined,
              onTap: () {
                Get.to(
                  () => ContactSettingTagPage(
                    peerId: peerId,
                    peerAvatar: peerAvatar,
                    peerAccount: peerAccount,
                    peerNickname: peerNickname,
                    peerGender: peerGender,
                    peerTitle: peerTitle,
                    peerSign: peerSign,
                    peerRegion: peerRegion,
                    peerSource: peerSource,
                    peerRemark: peerRemark,
                    peerTag: peerTag.obs,
                  ),
                  transition: Transition.rightToLeft,
                  popGesture: true,
                )?.then((value) {
                  if (value != null) {
                    peerRemark = value.toString();
                  }
                });
              },
            ),
            
            // 推荐给朋友
            _buildSettingCard(
              context: context,
              title: 'recommendToFriend'.tr,
              icon: Icons.share_outlined,
              onTap: () async {
                // 推荐给朋友的逻辑
                EasyLoading.showInfo('功能开发中...'.tr);
              },
            ),
            
            const SizedBox(height: 16),
            
            // 加入黑名单开关
            Obx(
              () => _buildSwitchCard(
                context: context,
                title: 'addToDenylist'.tr,
                icon: Icons.block_outlined,
                iconColor: inDenylist.value ? colorScheme.error : colorScheme.onSurfaceVariant,
                value: inDenylist.value,
                // 切换开关：true 加入黑名单；false 移出黑名单
                onChanged: (val) async {
                  EasyLoading.show(status: '处理中...'.tr);
                  bool res;
                  if (val) {
                    // 加入黑名单
                    DenylistModel model = DenylistModel(
                      deniedUid: peerId,
                      nickname: peerNickname,
                      account: peerAccount,
                      remark: peerRemark,
                      sign: peerSign,
                      source: peerSource,
                      avatar: peerAvatar,
                      region: peerRegion,
                      gender: peerGender,
                      createdAt: DateTimeHelper.millisecond(),
                    );
                    res = await DenylistLogic().addDenylist(model);
                  } else {
                    // 移出黑名单
                    res = await DenylistLogic().removeDenylist(peerId);
                  }
                  EasyLoading.dismiss();
                  if (res) {
                    inDenylist.value = val;
                    EasyLoading.showSuccess(val ? '已加入黑名单'.tr : '已移出黑名单'.tr);
                  } else {
                    EasyLoading.showError('操作失败'.tr);
                  }
                },
              ),
            ),
            
            const SizedBox(height: 32),
            
            // 删除联系人按钮
            _buildDangerButton(
              context: context,
              title: 'deleteContact'.tr,
              icon: Icons.person_remove_outlined,
              onTap: () => _showDeleteConfirmation(context),
            ),
            
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}