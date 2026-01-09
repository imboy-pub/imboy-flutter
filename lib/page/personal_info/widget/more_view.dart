import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:imboy/component/ui/common_bar.dart';
import 'package:imboy/store/repository/user_repo_local.dart';

import '../personal_info/personal_info_logic.dart';
import '../update/update_view.dart';
import '../set_gender/set_gender_view.dart';
import '../set_region/set_region_view.dart';

class MoreView extends StatelessWidget {
  const MoreView({super.key});

  @override
  Widget build(BuildContext context) {
    final logic = Get.put(PersonalInfoLogic());
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;

    logic.genderTitle.value = UserRepoLocal.to.current.genderTitle;
    logic.sign.value = UserRepoLocal.to.current.sign;
    logic.region.value = UserRepoLocal.to.current.region;

    return Scaffold(
      backgroundColor: isDark ? colorScheme.surface : const Color(0xFFF5F5F5),
      appBar: GlassAppBar(
        title: 'moreInfo'.tr,
        automaticallyImplyLeading: true,
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),

            // 信息设置卡片组
            _buildMenuGroup(context, [
              // 性别设置项
              _buildInfoItem(
                context: context,
                icon: Icons.person_outline,
                iconColor: const Color(0xFF007AFF),
                title: 'gender'.tr,
                trailing: Obx(() => Text(
                      logic.genderTitle.value,
                      style: TextStyle(
                        fontSize: 16,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    )),
                onPressed: () => _handleGenderUpdate(logic),
              ),

              // 地区设置项
              _buildInfoItem(
                context: context,
                icon: Icons.location_on_outlined,
                iconColor: const Color(0xFF34C759),
                title: 'region'.tr,
                trailing: Obx(() => Text(
                      _formatRegion(logic.region.value),
                      style: TextStyle(
                        fontSize: 16,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    )),
                onPressed: () => _handleRegionUpdate(logic),
              ),

              // 个性签名设置项
              _buildInfoItem(
                context: context,
                icon: Icons.edit_outlined,
                iconColor: const Color(0xFFFF9500),
                title: 'signature'.tr,
                trailing: Expanded(
                  child: Obx(() => Text(
                        logic.sign.value.isEmpty ? 'notFilled'.tr : logic.sign.value,
                        textAlign: TextAlign.right,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 16,
                          color: logic.sign.value.isEmpty
                              ? colorScheme.outline.withValues(alpha: 0.5)
                              : colorScheme.onSurfaceVariant,
                        ),
                      )),
                ),
                onPressed: () => _handleSignatureUpdate(logic),
              ),
            ]),
          ],
        ),
      ),
    );
  }

  /// 构建菜单组（仿iOS风格）
  Widget _buildMenuGroup(BuildContext context, List<Widget> children) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: isDark ? colorScheme.surfaceContainerHighest : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.2)
                : Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: children.asMap().entries.map((entry) {
          final index = entry.key;
          final child = entry.value;
          final isLast = index == children.length - 1;

          return Column(
            children: [
              child,
              if (!isLast)
                Padding(
                  padding: const EdgeInsets.only(left: 56),
                  child: Divider(
                    height: 0.5,
                    thickness: 0.5,
                    color: colorScheme.outlineVariant.withValues(alpha: 0.2),
                  ),
                ),
            ],
          );
        }).toList(),
      ),
    );
  }

  /// 构建信息项
  Widget _buildInfoItem({
    required BuildContext context,
    required IconData icon,
    required Color iconColor,
    required String title,
    required Widget trailing,
    required VoidCallback onPressed,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return InkWell(
      onTap: onPressed,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 20, color: iconColor),
            ),
            const SizedBox(width: 16),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: colorScheme.onSurface,
              ),
            ),
            const Spacer(),
            trailing,
            const SizedBox(width: 8),
            Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
            ),
          ],
        ),
      ),
    );
  }

  /// 格式化地区显示
  String _formatRegion(String region) {
    if (region.isEmpty) return 'notFilled'.tr;
    // 简单处理，如果太长可以截断
    if (region.length > 10) {
      return '${region.substring(0, 9)}...';
    }
    return region;
  }

  /// 处理性别更新
  void _handleGenderUpdate(PersonalInfoLogic logic) async {
    final result = await Get.to(() => const SetGenderPage());
    if (result != null) {
      // 刷新数据
      logic.genderTitle.value = UserRepoLocal.to.current.genderTitle;
    }
  }

  /// 处理地区更新
  void _handleRegionUpdate(PersonalInfoLogic logic) async {
    final result = await Get.to(
      () => SetRegionPage(
        title: 'region'.tr,
        currentValue: logic.region.value,
        onSave: (val) async {
          return await logic.changeInfo({
            "field": "region",
            "value": val,
          });
        },
      ),
    );
    if (result != null) {
      logic.region.value = UserRepoLocal.to.current.region;
    }
  }

  /// 处理个性签名更新
  void _handleSignatureUpdate(PersonalInfoLogic logic) async {
    final result = await Get.to(
      () => UpdatePage(
        title: 'signature'.tr,
        value: logic.sign.value,
        field: 'input',
        maxLength: 200, // 签名通常可以长一点
        callback: (val) async {
          return await logic.changeInfo({
            "field": "sign",
            "value": val,
          });
        },
      ),
    );
    if (result != null) {
      logic.sign.value = UserRepoLocal.to.current.sign;
    }
  }
}