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

  /// 构建个人信息卡片 - 现代化渐变头部
  Widget _buildProfileCard(BuildContext context, UserRepoLocal userRepo) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final topPadding = MediaQuery.of(context).padding.top;

    return Container(
      padding: EdgeInsets.only(top: topPadding + 20, bottom: 30),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  const Color(0xFF1A2980),
                  const Color(0xFF26D0CE),
                ] // Dark mode: Deep Blue -> Teal
              : [
                  const Color(0xFFE0C3FC),
                  const Color(0xFF8EC5FC),
                ], // Light mode: Soft Purple -> Blue (Mesh-like)
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
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
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                // 头像区域 - 带光晕
                Expanded(child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: GestureDetector(
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
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3),
                        image: dynamicAvatar(userRepo.current.avatar),
                      ),
                    ),
                  ),
                )),
                const SizedBox(width: 20),

                // 用户信息区域
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        userRepo.current.nickname.isEmpty
                            ? '未设置昵称'
                            : userRepo.current.nickname,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: isDark
                              ? Colors.white
                              : const Color(0xFF333333),
                          height: 1.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.1)
                              : Colors.white.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          "${'account'.tr}: ${userRepo.current.account}",
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark
                                ? Colors.white70
                                : const Color(0xFF555555),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),

                // 二维码
                Expanded(child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.qr_code_2,
                    color: isDark ? Colors.white : const Color(0xFF333333),
                  ),
                )),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 构建功能菜单项
  Widget _buildMenuItem({
    required BuildContext context,
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    required Color iconColor,
  }) {

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Row(
            children: [
              // 图标
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconColor.withValues(
                    alpha: 0.1,
                  ), // Gentle background for icon
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 22),
              ),

              const SizedBox(width: 12),

              // 标题
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ),

              const SizedBox(width: 4),

              // 箭头图标
              Icon(
                Icons.arrow_forward_ios_rounded,
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.3),
                size: 14,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 构建功能分组 - Card Style
  Widget _buildMenuGroup(BuildContext context, List<Widget> children) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16), // Fully rounded cards
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.2)
                : Colors.black.withValues(alpha: 0.04), // Soft shadow
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias, // Ensure children don't bleed
      child: Column(
        children: children.asMap().entries.map((entry) {
          int index = entry.key;
          Widget child = entry.value;

          return Column(
            children: [
              child,
              if (index < children.length - 1)
                Padding(
                  padding: const EdgeInsets.only(left: 60), // Indented divider
                  child: Container(
                    height: 0.5, // Thinner divider
                    color: Theme.of(
                      context,
                    ).dividerColor.withValues(alpha: 0.5),
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
      // Remove AppBar to use the custom gradient header as the top area
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            // Header
            GetBuilder<UserRepoLocal>(
              builder: (userRepo) => _buildProfileCard(context, userRepo),
            ),

            // Adjust overlap/spacing if needed, or just standard list
            const SizedBox(height: 20),

            // 功能菜单分组1
            _buildMenuGroup(context, [
              _buildMenuItem(
                context: context,
                icon: Icons.star_rounded,
                title: 'myFavorites'.tr,
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
                icon: Icons.remove_circle_outline,
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
                title: 'storageSpace'.tr,
                icon: Icons.cloud_queue_rounded,
                iconColor: AppColors.primaryGreen,
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
                title: 'deviceList'.tr,
                icon: Icons.devices_rounded,
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
                icon: Icons.settings_rounded,
                title: 'setting'.tr,
                iconColor: const Color(0xFF6366F1),
                onTap: () {
                  Get.to(
                    () => const SettingPage(),
                    transition: Transition.rightToLeft,
                    popGesture: true,
                  );
                },
              ),
            ]),

            // 反馈
            _buildMenuGroup(context, [
              _buildMenuItem(
                context: context,
                icon: Icons.feedback_rounded,
                title: 'feedback'.tr,
                iconColor: const Color(0xFF10B981),
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
