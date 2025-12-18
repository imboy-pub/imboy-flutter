import 'package:flutter/material.dart';
import 'package:get/get.dart';

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

    logic.genderTitle.value = UserRepoLocal.to.current.genderTitle;
    logic.sign.value = UserRepoLocal.to.current.sign;
    logic.region.value = UserRepoLocal.to.current.region;

    return Scaffold(
      appBar: AppBar(
        title: Text('more_info'.tr),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // const SizedBox(height: 10),
            //
            // // 页面标题描述
            // Padding(
            //   padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            //   child: Text(
            //     'personal_info_desc'.tr,
            //     style: TextStyle(
            //       fontSize: 14,
            //       color: isDark
            //           ? const Color(0xFF8E8E93)
            //           : const Color(0xFF999999),
            //     ),
            //   ),
            // ),

            const SizedBox(height: 10),

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
                        fontSize: 17,
                        color: isDark 
                            ? const Color(0xFF8E8E93) 
                            : const Color(0xFF999999),
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
                        fontSize: 17,
                        color: isDark 
                            ? const Color(0xFF8E8E93) 
                            : const Color(0xFF999999),
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
                        logic.sign.value.isEmpty ? 'not_filled'.tr : logic.sign.value,
                        style: TextStyle(
                          fontSize: 17,
                          color: logic.sign.value.isEmpty
                              ? (isDark ? const Color(0xFF48484A) : const Color(0xFFCCCCCC))
                              : (isDark ? const Color(0xFF8E8E93) : const Color(0xFF999999)),
                        ),
                        textAlign: TextAlign.right,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      )),
                ),
                onPressed: () => _handleSignatureUpdate(logic),
              ),
            ]),

            // const SizedBox(height: 20),
            //
            // // 提示信息
            // Container(
            //   margin: const EdgeInsets.symmetric(horizontal: 16),
            //   padding: const EdgeInsets.all(16),
            //   decoration: BoxDecoration(
            //     color: isDark ? const Color(0xFF2C2C2E) : Colors.white,
            //     borderRadius: BorderRadius.circular(12),
            //     boxShadow: [
            //       BoxShadow(
            //         color: isDark
            //             ? Colors.black.withValues(alpha: 0.2)
            //             : Colors.black.withValues(alpha: 0.03),
            //         blurRadius: 0.5,
            //         offset: const Offset(0, 0.5),
            //       ),
            //     ],
            //   ),
            //   child: Row(
            //     children: [
            //       Container(
            //         padding: const EdgeInsets.all(6),
            //         decoration: BoxDecoration(
            //           color: const Color(0xFF007AFF).withValues(alpha: isDark ? 0.2 : 0.1),
            //           borderRadius: BorderRadius.circular(6),
            //         ),
            //         child: const Icon(
            //           Icons.info_outline,
            //           color: Color(0xFF007AFF),
            //           size: 20,
            //         ),
            //       ),
            //       const SizedBox(width: 12),
            //       Expanded(
            //         child: Text(
            //           'personal_info_tip'.tr,
            //           style: TextStyle(
            //             fontSize: 15,
            //             color: isDark ? Colors.white : const Color(0xFF1A1A1A),
            //           ),
            //         ),
            //       ),
            //     ],
            //   ),
            // ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  /// 构建功能分组 - 参考"我的"页面风格
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

  /// 构建信息项 - 参考"我的"页面风格
  Widget _buildInfoItem({
    required BuildContext context,
    required IconData icon,
    required Color iconColor,
    required String title,
    required Widget trailing,
    required VoidCallback onPressed,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
          child: Row(
            children: [
              // 图标
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: isDark ? 0.2 : 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),

              const SizedBox(width: 12),

              // 标题
              Text(
                title,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w400,
                  color: isDark ? Colors.white : const Color(0xFF1A1A1A),
                ),
              ),

              const SizedBox(width: 12),

              // 内容区域
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Flexible(child: trailing),
                  ],
                ),
              ),

              const SizedBox(width: 8),

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

  /// 格式化地区显示文本
  String _formatRegion(String region) {
    if (region.isEmpty) return 'not_filled'.tr;

    List<String> items = region.split(" ");
    if (items.length < 3) {
      return region;
    }
    return "${items[items.length - 2]} ${items[items.length - 1]}";
  }

  /// 处理性别更新
  void _handleGenderUpdate(PersonalInfoLogic logic) {
    Get.to(
      () => const SetGenderPage(),
      transition: Transition.rightToLeft,
      popGesture: true,
    )?.then((value) {
      if (value == true) {
        // 更新性别显示
        logic.genderTitle.value = UserRepoLocal.to.current.genderTitle;
      }
    });
  }

  /// 处理地区更新
  void _handleRegionUpdate(PersonalInfoLogic logic) {
    Get.to(
      () => SetRegionPage(
        title: 'set_param'.trArgs(['region'.tr]),
        currentValue: logic.region.value,
        onSave: (region) async {
          bool ok = await logic.changeInfo({
            "field": "region",
            "value": region,
          });
          if (ok) {
            Map<String, dynamic> payload = UserRepoLocal.to.current.toMap();
            payload["region"] = region;
            UserRepoLocal.to.changeInfo(payload);
            logic.region.value = region;
          }
          return ok;
        },
      ),
      transition: Transition.rightToLeft,
      popGesture: true,
    );
  }

  /// 处理个性签名更新
  void _handleSignatureUpdate(PersonalInfoLogic logic) {
    Get.to(
      () => UpdatePage(
        title: 'set_param'.trArgs(['signature'.tr]),
        value: UserRepoLocal.to.current.sign,
        field: 'text',
        callback: (sign) async {
          bool ok = await logic.changeInfo({
            "field": "sign",
            "value": sign,
          });
          if (ok) {
            Map<String, dynamic> payload = UserRepoLocal.to.current.toMap();
            payload["sign"] = sign;
            UserRepoLocal.to.changeInfo(payload);
            logic.sign.value = UserRepoLocal.to.current.sign;
          }
          return ok;
        },
      ),
      transition: Transition.rightToLeft,
      popGesture: true,
    );
  }
}