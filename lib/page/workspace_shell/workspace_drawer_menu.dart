/// 企业壳左侧抽屉菜单（2026-10 飞书风格改版，参考稿①）。
///
/// 深海军蓝渐变面板：身份区（头像/昵称 → 个人资料、智能助理胶囊）、
/// 我的名片、当前企业带（品牌 logo + 企业名 + 选中对勾 → 企业主页）、
/// 底部功能簇（高级功能 → 企业工具聚合、创建/加入企业 → 企业选择器、
/// 设置）与「我」tab 移除后的兜底入口（切换到个人 / 退出登录）。
///
/// 「未认证」徽标为事实展示：Organization 模型尚无认证字段，所有企业
/// 均未认证；后端补字段后按真实状态渲染。
library;

import 'dart:async' show unawaited;

import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:imboy/component/helper/func.dart' show avatarImageProvider;
import 'package:imboy/component/ui/app_loading.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/modules/organization/presentation/organization_routes.dart';
import 'package:imboy/page/chat_shell/experience_provider.dart';
import 'package:imboy/page/workspace_shell/workspace_account_menu.dart'
    show currentOrgOrNull;
import 'package:imboy/page/workspace_shell/workspace_shell_provider.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:imboy/store/repository/user_repo_provider.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_spacing.dart';
import 'package:imboy/theme/default/font_types.dart';

class WorkspaceDrawerMenu extends ConsumerWidget {
  const WorkspaceDrawerMenu({super.key, required this.organizationId});

  /// 当前企业 id（由壳注入）；空时隐藏企业带与高级功能入口。
  final String organizationId;

  void _close(BuildContext context) => Scaffold.maybeOf(context)?.closeDrawer();

  void _closeAndPush(BuildContext context, String location) {
    _close(context);
    context.push(location);
  }

  Future<void> _switchToPersonal(BuildContext context, WidgetRef ref) async {
    // 与账户 Sheet 同序：先 select（成功后壳自动切换），再收抽屉；
    // 提前关闭会让 context unmount、select 被 mounted 守卫拦下。
    try {
      await ref
          .read(productExperienceProvider.notifier)
          .select(ProductExperience.personal);
      if (context.mounted) _close(context);
    } catch (_) {
      if (context.mounted) {
        AppLoading.showError(t.common.settingFailedPleaseTryAgain);
      }
    }
  }

  Future<void> _logout(BuildContext context, WidgetRef ref) async {
    final t = context.t;
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: Text(t.account.logOut),
        content: Text(t.account.areYouSureLogOut),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(t.common.buttonCancel),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(t.common.buttonConfirm),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    // router 先于 quitLogin 捕获（清全局状态后本 widget 可能随监听重建，
    // 再经 context 取会撞 unmounted；同账户 Sheet 的踩坑记录）。
    final router = GoRouter.of(context);
    await UserRepoLocal.to.quitLogin();
    if (context.mounted) _close(context);
    router.go('/welcome');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final org = currentOrgOrNull();
    final workspace = ref.watch(currentWorkspaceProvider);
    final orgName = (org != null && org.name.isNotEmpty)
        ? org.name
        : (workspace?.name ?? '');
    final logo = workspace?.logo ?? '';

    return Drawer(
      width: math.min(MediaQuery.sizeOf(context).width * 0.84, 360),
      backgroundColor: AppColors.transparent,
      elevation: 0,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: AlignmentDirectional.topStart,
            end: AlignmentDirectional.bottomEnd,
            colors: [AppColors.enterpriseNavy, AppColors.enterpriseNavyDeep],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsetsDirectional.fromSTEB(
                          AppSpacing.regular,
                          AppSpacing.large,
                          AppSpacing.regular,
                          0,
                        ),
                        child: _identity(
                          context,
                          nickname: user?.nickname ?? '',
                          account: user?.account ?? '',
                          avatar: user?.avatar ?? '',
                          orgName: orgName,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsetsDirectional.symmetric(
                          horizontal: AppSpacing.regular,
                          vertical: AppSpacing.large,
                        ),
                        child: Container(
                          height: 1,
                          color: AppColors.enterpriseNavyDivider,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsetsDirectional.symmetric(
                          horizontal: AppSpacing.regular,
                        ),
                        child: _DrawerRow(
                          icon: CupertinoIcons.qrcode,
                          label: t.workspace.myCard,
                          onTap: () => _closeAndPush(context, '/qrcode/user'),
                        ),
                      ),
                      AppSpacing.verticalRegular,
                      // 无工作区/无企业名（如冷启动尚未回填）时不渲染企业带，
                      // 不给空名字的假入口。
                      if (organizationId.isNotEmpty && orgName.isNotEmpty)
                        _EnterpriseBand(
                          name: orgName,
                          logo: logo,
                          onTap: () => _closeAndPush(
                            context,
                            '$kOrganizationHomePath/$organizationId',
                          ),
                        ),
                      const Spacer(),
                      Padding(
                        padding: const EdgeInsetsDirectional.symmetric(
                          horizontal: AppSpacing.regular,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (organizationId.isNotEmpty)
                              _DrawerRow(
                                icon: CupertinoIcons.wand_stars,
                                label: t.workspace.advancedFeatures,
                                onTap: () => _closeAndPush(
                                  context,
                                  '$kOrganizationHomePath/$organizationId/tools',
                                ),
                              ),
                            _hairline(),
                            _DrawerRow(
                              icon: CupertinoIcons.rectangle_stack_badge_plus,
                              label: t.workspace.createOrJoinEnterprise,
                              onTap: () => _closeAndPush(
                                context,
                                kOrganizationPickerPath,
                              ),
                            ),
                            _DrawerRow(
                              icon: CupertinoIcons.gear,
                              label: t.main.setting,
                              onTap: () =>
                                  _closeAndPush(context, '/mine/setting'),
                            ),
                            _hairline(),
                            _DrawerRow(
                              icon: CupertinoIcons.person_circle,
                              label: t.workspace.switchToPersonal,
                              muted: true,
                              onTap: () =>
                                  unawaited(_switchToPersonal(context, ref)),
                            ),
                            _DrawerRow(
                              icon: CupertinoIcons.square_arrow_right,
                              label: t.account.logOut,
                              destructive: true,
                              onTap: () => unawaited(_logout(context, ref)),
                            ),
                            AppSpacing.verticalXLarge,
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 身份区：头像 + 昵称行（→ 个人资料）+ 智能助理胶囊；第二行企业名
  /// + 未认证徽标。
  Widget _identity(
    BuildContext context, {
    required String nickname,
    required String account,
    required String avatar,
    required String orgName,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onTap: () => _closeAndPush(context, '/personal_info/profile'),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: SizedBox(
                  width: 68,
                  height: 68,
                  child: avatar.isNotEmpty
                      ? Image(
                          image: avatarImageProvider(avatar),
                          fit: BoxFit.cover,
                        )
                      : ColoredBox(
                          color: AppColors.enterpriseNavyLight,
                          child: Center(
                            child: Text(
                              nickname.isNotEmpty
                                  ? nickname.substring(0, 1)
                                  : '?',
                              style: context.textStyle(
                                FontSizeType.extraLarge,
                                fontWeight: FontWeight.w700,
                                color: AppColors.enterpriseOnNavy,
                              ),
                            ),
                          ),
                        ),
                ),
              ),
            ),
            AppSpacing.horizontalMedium,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () =>
                              _closeAndPush(context, '/personal_info/profile'),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(
                                child: Text(
                                  nickname.isEmpty ? account : nickname,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: context.textStyle(
                                    FontSizeType.title,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.enterpriseOnNavy,
                                  ),
                                ),
                              ),
                              AppSpacing.horizontalTiny,
                              const Icon(
                                CupertinoIcons.chevron_right,
                                size: 15,
                                color: AppColors.enterpriseOnNavyMuted,
                              ),
                            ],
                          ),
                        ),
                      ),
                      AppSpacing.horizontalRegular,
                      _AssistantPill(
                        onTap: () async {
                          await AppLoading.showToast(
                            t.workspace.featureComingSoon,
                          );
                        },
                      ),
                    ],
                  ),
                  AppSpacing.verticalTiny,
                  if (orgName.isNotEmpty)
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            orgName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: context.textStyle(
                              FontSizeType.footnote,
                              color: AppColors.enterpriseOnNavyMuted,
                            ),
                          ),
                        ),
                        AppSpacing.horizontalSmall,
                        _UnverifiedBadge(),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _hairline() => Container(
    height: 1,
    margin: const EdgeInsetsDirectional.symmetric(vertical: AppSpacing.tiny),
    color: AppColors.enterpriseNavyDivider,
  );
}

/// 当前企业带（通栏高亮）：白底圆角 logo 位 + 企业名 + 选中对勾。
class _EnterpriseBand extends StatelessWidget {
  const _EnterpriseBand({
    required this.name,
    required this.logo,
    required this.onTap,
  });

  final String name;
  final String logo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: ColoredBox(
        color: AppColors.enterpriseNavyLight,
        child: Padding(
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: AppSpacing.regular,
            vertical: AppSpacing.regular,
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: 44,
                  height: 44,
                  child: logo.isNotEmpty
                      ? Image(
                          image: avatarImageProvider(logo),
                          fit: BoxFit.cover,
                        )
                      : const ColoredBox(
                          color: AppColors.enterpriseOnNavy,
                          child: Center(
                            child: Icon(
                              CupertinoIcons.building_2_fill,
                              size: 24,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                ),
              ),
              AppSpacing.horizontalMedium,
              Expanded(
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.textStyle(
                    FontSizeType.extraLarge,
                    fontWeight: FontWeight.w700,
                    color: AppColors.enterpriseOnNavy,
                  ),
                ),
              ),
              AppSpacing.horizontalSmall,
              const Icon(
                CupertinoIcons.check_mark,
                size: 18,
                color: AppColors.enterpriseOnNavy,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 「智能助理」胶囊：半透明白底 + 蓝渐变圆点。
class _AssistantPill extends StatelessWidget {
  const _AssistantPill({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: 10,
          vertical: 5,
        ),
        decoration: BoxDecoration(
          color: AppColors.overlayLightStrong,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 14,
              height: 14,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: AlignmentDirectional.topStart,
                  end: AlignmentDirectional.bottomEnd,
                  colors: [AppColors.enterpriseSkyBlue, AppColors.primary],
                ),
              ),
            ),
            AppSpacing.horizontalTiny,
            Text(
              t.workspace.assistantEntry,
              style: context.textStyle(
                FontSizeType.tiny,
                fontWeight: FontWeight.w600,
                color: AppColors.enterpriseOnNavy,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 「未认证」徽标：问号 + 灰蓝胶囊。
class _UnverifiedBadge extends StatelessWidget {
  const _UnverifiedBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: 7,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: AppColors.overlayLight,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            CupertinoIcons.question_circle_fill,
            size: 12,
            color: AppColors.enterpriseOnNavyMuted,
          ),
          AppSpacing.horizontalTiny,
          Text(
            t.workspace.orgUnverified,
            style: context.textStyle(
              FontSizeType.tiny,
              color: AppColors.enterpriseOnNavyMuted,
            ),
          ),
        ],
      ),
    );
  }
}

/// 抽屉功能行。
class _DrawerRow extends StatelessWidget {
  const _DrawerRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.muted = false,
    this.destructive = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool muted;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final color = destructive
        ? AppColors.iosRed
        : muted
        ? AppColors.enterpriseOnNavyMuted
        : AppColors.enterpriseOnNavy;
    return CupertinoButton(
      padding: EdgeInsets.zero,
      minimumSize: const Size(0, 52),
      pressedOpacity: 0.55,
      onPressed: onTap,
      child: Row(
        children: [
          Icon(icon, size: 24, color: color),
          AppSpacing.horizontalMedium,
          Expanded(
            child: Text(
              label,
              style: context.textStyle(
                FontSizeType.medium,
                fontWeight: FontWeight.w500,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
