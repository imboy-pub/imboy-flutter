/// 壳级左侧抽屉菜单（2026-10 空间切换中心改版）。
///
/// 深海军蓝渐变面板：身份区（头像/昵称 → 个人资料）、我的名片 + 企业二维码
/// （出码是 owner/admin 治理动作，成员不显示）、空间切换区（个人空间行 +
/// 我的企业列表，当前项✓高亮，点击行内直接两阶段原子切换——个人↔企业、
/// 企业↔企业的统一入口，替代「我」页工作区胶囊与旧「切换到个人」行）、
/// 底部功能簇（高级功能 → 企业工具聚合、创建/加入企业 → 企业选择器、设置、
/// 退出登录）。个人壳与企业壳共用（organizationId 为空 = 个人上下文）。
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
import 'package:imboy/modules/organization/domain/organization_models.dart';
import 'package:imboy/modules/organization/infrastructure/current_organization_store.dart';
import 'package:imboy/modules/organization/infrastructure/organization_api.dart';
import 'package:imboy/modules/organization/infrastructure/organization_cache.dart';
import 'package:imboy/modules/organization/presentation/organization_entry_provider.dart'
    show organizationApiProvider;
import 'package:imboy/modules/organization/presentation/org_invite_qr_page.dart';
import 'package:imboy/modules/organization/presentation/organization_routes.dart';
import 'package:imboy/modules/organization/presentation/organization_switch_controller.dart';
import 'package:imboy/page/chat_shell/experience_provider.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:imboy/store/repository/user_repo_provider.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_spacing.dart';
import 'package:imboy/theme/default/font_types.dart';

class WorkspaceDrawerMenu extends ConsumerStatefulWidget {
  const WorkspaceDrawerMenu({super.key, this.organizationId = ''});

  /// 当前企业 id（由企业壳注入）；空（个人壳上下文）时隐藏高级功能入口。
  final String organizationId;

  @override
  ConsumerState<WorkspaceDrawerMenu> createState() =>
      _WorkspaceDrawerMenuState();
}

class _WorkspaceDrawerMenuState extends ConsumerState<WorkspaceDrawerMenu> {
  /// 个人空间切换目标哨兵（企业 id 均为 TSID 字符串，不与哨兵冲突）。
  static const Object _kPersonalTarget = '__personal__';

  /// 与企业壳同源的组织 API（provider 可覆写，壳测试注入伪造实现）。
  late final OrganizationApi _api = ref.read(organizationApiProvider);

  /// 账号 scope：优先 provider 注入的当前用户（壳/测试可控），回落本地
  /// 登录态；为空（未登录/冷启动）时不构造控制器、空间区只渲染个人行。
  late final String _account = _resolveAccount();
  OrganizationSwitchController? _switcher;

  /// 企业列表：打开时缓存播种即时渲染 + mine() 刷新真源（指针非真源）。
  List<Organization> _orgs = const [];
  bool _loading = false;

  /// 正在切换的目标（[_kPersonalTarget] 或企业 id）：行内 spinner 的
  /// 唯一真源；null=无进行中切换。
  Object? _switchingTarget;

  /// 抽屉创建时的会话代：登出/换号后旧抽屉的切换静默中止。
  late final int _sessionGeneration = UserRepoLocal.to.sessionGeneration;

  String _resolveAccount() {
    final uid = ref.read(currentUserProvider)?.uid ?? '';
    return uid.isNotEmpty ? uid : UserRepoLocal.to.currentUid;
  }

  void _close(BuildContext context) => Scaffold.maybeOf(context)?.closeDrawer();

  void _closeAndPush(BuildContext context, String location) {
    _close(context);
    context.push(location);
  }

  @override
  void initState() {
    super.initState();
    if (_account.isEmpty) return;
    _switcher = OrganizationSwitchController(
      ref: ref,
      accountKey: _account,
      isAlive: _sessionAlive,
      api: _api,
    );
    // 播种缓存（转场即时渲染）后异步刷新 membership 真源。
    _orgs = OrganizationCache.forAccount(_account).orgs;
    unawaited(_refresh());
  }

  bool _sessionAlive() =>
      mounted &&
      !UserRepoLocal.to.isClearingSession &&
      UserRepoLocal.to.isCurrentSession(_sessionGeneration);

  Future<void> _refresh() async {
    final account = _account;
    if (account.isEmpty) return;
    setState(() => _loading = true);
    try {
      final orgs = await _api.allMine();
      if (!mounted || account != _resolveAccount()) return;
      OrganizationCache.forAccount(account).replaceMineOrgs(orgs);
      setState(() => _orgs = orgs);
    } on Object {
      // 列表拉取失败：保留缓存播种（抽屉其余功能不受影响），下次打开重试。
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _selectPersonal() async {
    final switcher = _switcher;
    if (switcher == null || _switchingTarget != null) return;
    setState(() => _switchingTarget = _kPersonalTarget);
    final outcome = await switcher.selectPersonal();
    // 成功/中止时壳随体验模式销毁重建，抽屉随之 unmount，无需收尾。
    if (!mounted) return;
    setState(() => _switchingTarget = null);
    if (outcome.status == SpaceSwitchStatus.failed) {
      await AppLoading.showError(
        outcome.message ?? t.common.settingFailedPleaseTryAgain,
      );
    }
  }

  Future<void> _switchTo(Organization org) async {
    final switcher = _switcher;
    if (switcher == null || _switchingTarget != null) return;
    setState(() => _switchingTarget = org.id);
    final outcome = await switcher.switchToOrganization(org);
    if (!mounted) return;
    setState(() => _switchingTarget = null);
    if (outcome.status == SpaceSwitchStatus.failed) {
      await AppLoading.showError(
        outcome.message ?? t.common.settingFailedPleaseTryAgain,
      );
    }
  }

  /// 当前企业（壳注入）且本人可治理时返回该企业，否则 null。
  /// 角色来自 mine() 真源行（指针不是 membership 真源）。
  Organization? _governableCurrentOrg() {
    if (widget.organizationId.isEmpty) return null;
    for (final org in _orgs) {
      if (org.id == widget.organizationId) return org.canGovern ? org : null;
    }
    return null;
  }

  void _openOrgQrcode(BuildContext context, Organization org) {
    _close(context);
    // 出码页不是 go_router 路由（既有页面均 Navigator push）；走根导航器
    // 盖住整壳，避免落进当前 tab 的分支导航器。
    Navigator.of(context, rootNavigator: true).push(
      CupertinoPageRoute<void>(
        builder: (_) => OrgInviteQrPage(orgId: org.id, orgName: org.name),
      ),
    );
  }

  Future<void> _logout(BuildContext context) async {
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
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final experience = ref.watch(productExperienceProvider);
    final pointedOrgId = _account.isEmpty
        ? ''
        : CurrentOrganizationStore.forAccount(_account).value?.id ?? '';
    final governableOrg = _governableCurrentOrg();

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
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _DrawerRow(
                              icon: CupertinoIcons.qrcode,
                              label: t.workspace.myCard,
                              onTap: () =>
                                  _closeAndPush(context, '/qrcode/user'),
                            ),
                            // 企业二维码（邀请码出码页）与「我的名片」并列；出码是
                            // owner/admin 治理动作，成员不展示（避免进页即 403）。
                            if (governableOrg != null)
                              _DrawerRow(
                                key: const ValueKey('drawer-org-qrcode'),
                                icon: CupertinoIcons.qrcode_viewfinder,
                                label: t.organization.inviteQr.orgQrcode,
                                onTap: () =>
                                    _openOrgQrcode(context, governableOrg),
                              ),
                          ],
                        ),
                      ),
                      AppSpacing.verticalRegular,
                      _spacesArea(experience, pointedOrgId),
                      const Spacer(),
                      _footerActions(context),
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

  /// 空间切换区：个人空间行 + 我的企业列表（当前项✓，点击行内切换）。
  Widget _spacesArea(ProductExperience experience, String pointedOrgId) {
    final isPersonal = experience == ProductExperience.personal;
    final switching = _switchingTarget != null;
    return Padding(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: AppSpacing.regular,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SpaceRow(
            key: const ValueKey('drawer-space-personal'),
            icon: CupertinoIcons.person_circle,
            label: t.organization.experienceUi.personalSpace,
            selected: isPersonal,
            switching: _switchingTarget == _kPersonalTarget,
            onTap: isPersonal || switching
                ? null
                : () => unawaited(_selectPersonal()),
          ),
          for (final org in _orgs)
            _SpaceRow(
              key: ValueKey('drawer-space-${org.id}'),
              icon: CupertinoIcons.building_2_fill,
              label: org.name,
              selected: !isPersonal && org.id == pointedOrgId,
              switching: _switchingTarget == org.id,
              onTap: switching ? null : () => unawaited(_switchTo(org)),
            ),
          if (_loading && _orgs.isEmpty)
            const Padding(
              padding: EdgeInsetsDirectional.symmetric(
                vertical: AppSpacing.medium,
              ),
              child: Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _footerActions(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: AppSpacing.regular,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.organizationId.isNotEmpty) ...[
            _DrawerRow(
              icon: CupertinoIcons.wand_stars,
              label: t.workspace.advancedFeatures,
              onTap: () => _closeAndPush(
                context,
                '$kOrganizationHomePath/${widget.organizationId}/tools',
              ),
            ),
            _hairline(),
          ],
          _DrawerRow(
            icon: CupertinoIcons.rectangle_stack_badge_plus,
            label: t.workspace.createOrJoinEnterprise,
            onTap: () => _closeAndPush(context, kOrganizationPickerPath),
          ),
          _DrawerRow(
            icon: CupertinoIcons.gear,
            label: t.main.setting,
            onTap: () => _closeAndPush(context, '/mine/setting'),
          ),
          _hairline(),
          _DrawerRow(
            icon: CupertinoIcons.square_arrow_right,
            label: t.account.logOut,
            destructive: true,
            onTap: () => unawaited(_logout(context)),
          ),
          AppSpacing.verticalXLarge,
        ],
      ),
    );
  }

  Widget _hairline() => Container(
    height: 1,
    margin: const EdgeInsetsDirectional.symmetric(vertical: AppSpacing.tiny),
    color: AppColors.enterpriseNavyDivider,
  );

  /// 身份区：头像 + 昵称行（→ 个人资料）。
  Widget _identity(
    BuildContext context, {
    required String nickname,
    required String account,
    required String avatar,
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
}

/// 空间行：图标 + 名称 + 行尾（✓当前 / 切换 spinner）；当前项通栏高亮。
class _SpaceRow extends StatelessWidget {
  const _SpaceRow({
    super.key,
    required this.icon,
    required this.label,
    required this.selected,
    required this.switching,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final bool switching;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = AppColors.enterpriseOnNavy;
    return CupertinoButton(
      padding: EdgeInsets.zero,
      minimumSize: const Size(0, 52),
      pressedOpacity: 0.55,
      onPressed: onTap,
      child: ColoredBox(
        color: selected ? AppColors.enterpriseNavyLight : AppColors.transparent,
        child: Padding(
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: AppSpacing.small,
          ),
          child: Row(
            children: [
              Icon(icon, size: 24, color: color),
              AppSpacing.horizontalMedium,
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.textStyle(
                    FontSizeType.medium,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                    color: color,
                  ),
                ),
              ),
              if (switching)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else if (selected)
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

/// 抽屉功能行。
class _DrawerRow extends StatelessWidget {
  const _DrawerRow({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.destructive = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final color = destructive ? AppColors.iosRed : AppColors.enterpriseOnNavy;
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
