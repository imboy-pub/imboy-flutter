import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:material_ui/material_ui.dart';
import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:imboy/component/ui/detail_settings_tile.dart';
import 'package:imboy/component/ui/common_bar.dart';

import '../update/update_page.dart';
import '../set_gender/set_gender_page.dart';
import '../set_region/set_region_page.dart';

import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_radius.dart';
import 'package:imboy/theme/default/app_spacing.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:imboy/store/repository/user_repo_provider.dart';
import 'package:imboy/store/service/user_profile_service.dart';

class MorePage extends ConsumerStatefulWidget {
  const MorePage({super.key, this.readOnly = kIsWeb});

  final bool readOnly;

  @override
  ConsumerState<MorePage> createState() => _MorePageState();
}

class _MorePageState extends ConsumerState<MorePage> {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;
    final user = ref.watch(currentUserProvider);
    if (user == null) {
      return Scaffold(
        appBar: GlassAppBar(
          title: t.common.moreInfo,
          automaticallyImplyLeading: true,
        ),
        body: Center(child: Text(t.common.notLoggedIn)),
      );
    }

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
                icon: CupertinoIcons.person,
                iconColor: AppColors.iosBlue,
                title: t.account.gender,
                value: user.genderTitle,
                onPressed: widget.readOnly
                    ? null
                    : () => _handleGenderUpdate(context),
              ),

              // 地区设置项
              _buildInfoItem(
                context: context,
                icon: CupertinoIcons.location,
                iconColor: AppColors.iosGreen,
                title: t.account.region,
                value: user.region.isEmpty ? t.common.notFilled : user.region,
                onPressed: widget.readOnly
                    ? null
                    : () => _handleRegionUpdate(context),
              ),

              // 个性签名设置项
              _buildInfoItem(
                context: context,
                icon: CupertinoIcons.pencil,
                iconColor: AppColors.iosOrange,
                title: t.account.signature,
                value: user.sign.isEmpty ? t.common.notFilled : user.sign,
                onPressed: widget.readOnly
                    ? null
                    : () => _handleSignatureUpdate(context),
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
    required String value,
    required VoidCallback? onPressed,
  }) {
    return DetailSettingsTile(
      title: Text(title),
      value: value,
      leading: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: iconColor.withValues(alpha: 0.1),
          borderRadius: AppRadius.borderRadiusSmall,
        ),
        child: Icon(icon, size: 20, color: iconColor),
      ),
      onTap: onPressed,
    );
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
          // 统一走 UserProfileService：PUT + 账号保存围栏 + 本地缓存同步 +
          // 后端错误透出，消除与 ProfilePage 的双入口漂移。
          // 资产树地区列表没有数据集身份（pathIds），按合同仍写 legacy
          // `region` 字段；结构化 regionSelection 只能由 geo_regions 选择器发起。
          onSave: (val) => UserProfileService.updateField('region', val),
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
          // 同上：围栏统一在 UserProfileService.updateField。
          callback: (val) => UserProfileService.updateField('sign', val),
        ),
      ),
    );
    if (mounted) setState(() {});
  }
}
