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
import 'package:imboy/theme/default/app_spacing.dart';
import 'package:imboy/theme/default/font_types.dart';
import 'package:imboy/store/repository/user_repo_local.dart';

class MorePage extends ConsumerStatefulWidget {
  const MorePage({super.key});

  @override
  ConsumerState<MorePage> createState() => _MorePageState();
}

class _MorePageState extends ConsumerState<MorePage> {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: isDark
          ? colorScheme.surface
          : AppColors.lightPageBackground,
      appBar: GlassAppBar(
        title: t.common.moreInfo,
        automaticallyImplyLeading: true,
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: AppSpacing.large),

            // 信息设置卡片组
            _buildMenuGroup(context, [
              // 性别设置项
              _buildInfoItem(
                context: context,
                icon: Icons.person_outline,
                iconColor: AppColors.iosBlue,
                title: t.account.gender,
                trailing: Text(
                  UserRepoLocal.to.current.genderTitle,
                  style: TextStyle(
                    fontSize: FontSizeType.medium.size,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                onPressed: () => _handleGenderUpdate(context),
              ),

              // 地区设置项
              _buildInfoItem(
                context: context,
                icon: Icons.location_on_outlined,
                iconColor: AppColors.iosGreen,
                title: t.account.region,
                trailing: Text(
                  _formatRegion(UserRepoLocal.to.current.region),
                  style: TextStyle(
                    fontSize: FontSizeType.medium.size,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                onPressed: () => _handleRegionUpdate(context),
              ),

              // 个性签名设置项
              _buildInfoItem(
                context: context,
                icon: Icons.edit_outlined,
                iconColor: AppColors.iosOrange,
                title: t.account.signature,
                trailing: Flexible(
                  child: Text(
                    UserRepoLocal.to.current.sign.isEmpty
                        ? t.common.notFilled
                        : UserRepoLocal.to.current.sign,
                    textAlign: TextAlign.right,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: FontSizeType.medium.size,
                      color: UserRepoLocal.to.current.sign.isEmpty
                          ? colorScheme.outline.withValues(alpha: 0.5)
                          : colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                onPressed: () => _handleSignatureUpdate(context),
              ),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuGroup(BuildContext context, List<Widget> children) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.regular),
      decoration: BoxDecoration(
        color: isDark
            ? colorScheme.surfaceContainerHighest
            : AppColors.lightSurface,
        borderRadius: AppRadius.borderRadiusMedium,
        boxShadow: [
          BoxShadow(
            color: isDark
                ? AppColors.lightTextPrimary.withValues(alpha: 0.2)
                : AppColors.lightTextPrimary.withValues(alpha: 0.05),
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
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.regular,
          vertical: AppSpacing.regular,
        ),
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
            const SizedBox(width: AppSpacing.regular),
            Text(
              title,
              style: TextStyle(
                fontSize: FontSizeType.medium.size,
                fontWeight: FontWeight.w500,
                color: colorScheme.onSurface,
              ),
            ),
            const Spacer(),
            trailing,
            const SizedBox(width: AppSpacing.small),
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

  String _formatRegion(String region) {
    if (region.isEmpty) return t.common.notFilled;
    if (region.length > 10) {
      return '${region.substring(0, 9)}...';
    }
    return region;
  }

  Future<void> _handleGenderUpdate(BuildContext context) async {
    await Navigator.push(
      context,
      CupertinoPageRoute<dynamic>(builder: (_) => const SetGenderPage()),
    );
    if (mounted) setState(() {});
  }

  Future<void> _handleRegionUpdate(BuildContext context) async {
    await Navigator.push(
      context,
      CupertinoPageRoute<dynamic>(
        builder: (_) => SetRegionPage(
          title: t.account.region,
          currentValue: UserRepoLocal.to.current.region,
          onSave: (val) async {
            final success = await ref
                .read(personalInfoProvider.notifier)
                .changeInfo({"field": "region", "value": val});
            if (success) {
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
    if (mounted) setState(() {});
  }

  Future<void> _handleSignatureUpdate(BuildContext context) async {
    await Navigator.push(
      context,
      CupertinoPageRoute<dynamic>(
        builder: (_) => UpdatePage(
          title: t.account.signature,
          value: UserRepoLocal.to.current.sign,
          field: 'input',
          maxLength: 200,
          callback: (val) async {
            final success = await ref
                .read(personalInfoProvider.notifier)
                .changeInfo({"field": "sign", "value": val});
            if (success) {
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
    if (mounted) setState(() {});
  }
}
