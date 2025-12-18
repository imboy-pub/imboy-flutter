import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:imboy/page/mine/feedback/feedback_view.dart';

import 'package:imboy/component/helper/func.dart';
import 'package:imboy/component/image_gallery/image_gallery.dart';

import 'package:imboy/page/mine/setting/setting_view.dart';
import 'package:imboy/page/mine/storage_space/storage_space_view.dart';
import 'package:imboy/page/mine/user_device/user_device_view.dart';
import 'package:imboy/page/personal_info/personal_info/personal_info_view.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:imboy/theme/default/app_colors.dart';

import '../denylist/denylist_view.dart';
import '../user_collect/user_collect_view.dart';
import 'mine_logic.dart';

// ignore: must_be_immutable
class MinePage extends StatelessWidget {
  final MineLogic logic = Get.put(MineLogic());

  MinePage({super.key});

  /// 构建个人信息卡片 - 支持黑暗模式
  Widget _buildProfileCard(BuildContext context, UserRepoLocal userRepo) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // 顶部 SafeArea 兼容
    final topPadding = MediaQuery.of(context).padding.top;

    return Container(
      padding: EdgeInsets.only(top: topPadding),
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        // color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black.withValues(alpha: 0.2) : Colors.black.withValues(alpha: 0.05),
            blurRadius: 0,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Get.to(
                  () => const PersonalInfoPage(),
              transition: Transition.rightToLeft,
              popGesture: true,
            );
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Row(
              children: [
                // 头像区域
                InkWell(
                  onTap: () {
                    if (userRepo.current.avatar.isEmpty) {
                      Get.to(
                            () => const PersonalInfoPage(),
                        transition: Transition.rightToLeft,
                        popGesture: true,
                      );
                    } else {
                      zoomInPhotoView(userRepo.current.avatar);
                    }
                  },
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(6),
                      image: dynamicAvatar(
                        userRepo.current.avatar,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // 用户信息区域
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 12),
                      // 用户昵称
                      Flexible(
                        fit: FlexFit.loose,
                        child: Text(
                          userRepo.current.nickname.isEmpty
                              ? '未设置昵称'
                              : userRepo.current.nickname,
                          // '这样修改后，整个顶部区域（包括状态栏和个人信息卡片）的背景色将保持一致，解决了在',
                        style: const TextStyle(
                            fontWeight: FontWeight.w500,
                            height: 1.2, // 行高统一
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          softWrap: true,
                        ),
                      ),
                      // 用户账号
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          "${'account'.tr}: ${userRepo.current.account}",
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),

                // 二维码和箭头
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.qr_code_2, size: 24),
                    const SizedBox(width: 8, height: 16),
                    Icon(
                      Icons.navigate_next,
                      color: isDark
                          ? const Color(0xFF8E8E93)
                          : const Color(0xFF999999),
                      size: 20,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 构建功能菜单项 - 支持黑暗模式
  Widget _buildMenuItem({
    required BuildContext context,
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    required Color iconColor,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
          child: Row(
            children: [
              // 图标
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),

              const SizedBox(width: 12),

              // 标题
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w400,
                    color: isDark ? Colors.white : const Color(0xFF1A1A1A),
                  ),
                ),
              ),

              // 箭头图标
              Icon(
                Icons.navigate_next,
                color: isDark
                    ? const Color(0xFF8E8E93)
                    : const Color(0xFF999999),
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 构建功能分组 - 支持黑暗模式
  Widget _buildMenuGroup(BuildContext context, List<Widget> children) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2C2C2E) : Colors.white,
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.2)
                : Colors.black.withValues(alpha: 0.03),
            blurRadius: 0.5,
            offset: const Offset(0, 0.5),
          ),
        ],
      ),
      child: Column(
        children: children.asMap().entries.map((entry) {
          int index = entry.key;
          Widget child = entry.value;

          return Column(
            children: [
              child,
              if (index < children.length - 1)
                Padding(
                  padding: const EdgeInsets.only(left: 48),
                  child: Container(
                    height: 0.3,
                    color: isDark
                        ? const Color(0xFF48484A)
                        : const Color(0xFFE5E5E5),
                  ),
                ),
            ],
          );
        }).toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(148.0),
        child: GetBuilder<UserRepoLocal>(
          builder: (userRepo) => _buildProfileCard(context, userRepo),
        ),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          children: [
            // 功能菜单分组1：收藏和黑名单
            _buildMenuGroup(context, [
              _buildMenuItem(
                context: context,
                icon: Icons.star_outline,
                title: 'my_favorites'.tr,
                iconColor: const Color(0xFFFF9500),
                onTap: () {
                  Get.to(
                        () => UserCollectPage(),
                    transition: Transition.rightToLeft,
                    popGesture: true,
                  );
                },
              ),
              _buildMenuItem(
                context: context,
                icon: Icons.block_outlined,
                title: 'denylist'.tr,
                iconColor: const Color(0xFFFF3B30),
                onTap: () {
                  Get.to(
                        () => DenylistPage(),
                    transition: Transition.rightToLeft,
                    popGesture: true,
                  );
                },
              ),
            ]),

            _buildMenuGroup(context, [
              // 存储空间
              _buildMenuItem(
                context: context,
                title: 'storage_space'.tr,
                icon: Icons.sd_storage_outlined,
                iconColor: AppColors.warning,
                onTap: () {
                  Get.to(
                        () => StorageSpacePage(),
                    transition: Transition.rightToLeft,
                    popGesture: true,
                  );
                },
              ),

              // 设备管理
              _buildMenuItem(
                context: context,
                title: 'device_list'.tr,
                icon: Icons.devices,
                iconColor: AppColors.info,
                onTap: () {
                  Get.to(
                        () => UserDevicePage(),
                    transition: Transition.rightToLeft,
                    popGesture: true,
                  );
                },
              ),
              _buildMenuItem(
                context: context,
                icon: Icons.settings_outlined,
                title: 'setting'.tr,
                iconColor: const Color(0xFF8E8E93),
                onTap: () {
                  Get.to(
                        () => const SettingPage(),
                    transition: Transition.rightToLeft,
                    popGesture: true,
                  );
                },
              ),
            ]),

            // 测试功能和反馈
            _buildMenuGroup(context, [
              _buildMenuItem(
                context: context,
                icon: Icons.feedback_outlined,
                title: 'feedback'.tr,
                iconColor: const Color(0xFF007AFF),
                onTap: () {
                  Get.to(
                        () => FeedbackPage(),
                    transition: Transition.rightToLeft,
                    popGesture: true,
                  );
                },
              ),
            ]),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
