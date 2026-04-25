import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:imboy/component/ui/common_bar.dart';

import '../update/update_page.dart';
import '../set_gender/set_gender_page.dart';
import '../set_region/set_region_page.dart';
import '../personal_info/personal_info_provider.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_radius.dart';
import 'package:imboy/store/repository/user_repo_local.dart';

class MorePage extends ConsumerWidget {
  const MorePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: isDark ? colorScheme.surface : const Color(0xFFF5F5F5),
      appBar: GlassAppBar(title: t.moreInfo, automaticallyImplyLeading: true),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),

            // 信息设置卡片组
            _buildMenuGroup(context, ref, [
              // 性别设置项
              _buildInfoItem(
                context: context,
                ref: ref,
                icon: Icons.person_outline,
                iconColor: AppColors.iosBlue,
                title: t.gender,
                trailing: Text(
                  UserRepoLocal.to.current.genderTitle,
                  style: TextStyle(
                    fontSize: 16,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                onPressed: () => _handleGenderUpdate(context, ref),
              ),

              // 地区设置项
              _buildInfoItem(
                context: context,
                ref: ref,
                icon: Icons.location_on_outlined,
                iconColor: AppColors.iosGreen,
                title: t.region,
                trailing: Text(
                  _formatRegion(UserRepoLocal.to.current.region),
                  style: TextStyle(
                    fontSize: 16,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                onPressed: () => _handleRegionUpdate(context, ref),
              ),

              // 个性签名设置项
              _buildInfoItem(
                context: context,
                ref: ref,
                icon: Icons.edit_outlined,
                iconColor: AppColors.iosOrange,
                title: t.signature,
                trailing: Expanded(
                  child: Text(
                    UserRepoLocal.to.current.sign.isEmpty
                        ? t.notFilled
                        : UserRepoLocal.to.current.sign,
                    textAlign: TextAlign.right,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 16,
                      color: UserRepoLocal.to.current.sign.isEmpty
                          ? colorScheme.outline.withValues(alpha: 0.5)
                          : colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                onPressed: () => _handleSignatureUpdate(context, ref),
              ),
            ]),
          ],
        ),
      ),
    );
  }

  /// 构建菜单组（仿iOS风格）
  Widget _buildMenuGroup(
    BuildContext context,
    WidgetRef ref,
    List<Widget> children,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: isDark ? colorScheme.surfaceContainerHighest : Colors.white,
        borderRadius: AppRadius.borderRadiusMedium,
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
    required WidgetRef ref,
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
                borderRadius: AppRadius.borderRadiusSmall,
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
    if (region.isEmpty) return t.notFilled;
    // 简单处理，如果太长可以截断
    if (region.length > 10) {
      return '${region.substring(0, 9)}...';
    }
    return region;
  }

  /// 处理性别更新
  Future<void> _handleGenderUpdate(BuildContext context, WidgetRef ref) async {
    await Navigator.push(
      context,
      CupertinoPageRoute(builder: (_) => const SetGenderPage()),
    );
  }

  /// 处理地区更新
  Future<void> _handleRegionUpdate(BuildContext context, WidgetRef ref) async {
    await Navigator.push(
      context,
      CupertinoPageRoute(
        builder: (_) => SetRegionPage(
          title: t.region,
          currentValue: UserRepoLocal.to.current.region,
          onSave: (val) async {
            final success = await ref
                .read(personalInfoProvider.notifier)
                .changeInfo({"field": "region", "value": val});
            if (success) {
              // 更新本地数据
              final payload = UserRepoLocal.to.current.toMap();
              payload['region'] = val;
              UserRepoLocal.to.changeInfo(payload);
              return true;
            }
            return false;
          },
        ),
      ),
    );
  }

  /// 处理个性签名更新
  Future<void> _handleSignatureUpdate(
    BuildContext context,
    WidgetRef ref,
  ) async {
    await Navigator.push(
      context,
      CupertinoPageRoute(
        builder: (_) => UpdatePage(
          title: t.signature,
          value: UserRepoLocal.to.current.sign,
          field: 'input',
          maxLength: 200, // 签名通常可以长一点
          callback: (val) async {
            final success = await ref
                .read(personalInfoProvider.notifier)
                .changeInfo({"field": "sign", "value": val});
            if (success) {
              // 更新本地数据
              final payload = UserRepoLocal.to.current.toMap();
              payload['sign'] = val;
              UserRepoLocal.to.changeInfo(payload);
              return true;
            }
            return false;
          },
        ),
      ),
    );
  }
}
