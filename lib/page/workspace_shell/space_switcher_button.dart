import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:imboy/component/helper/func.dart' show avatarImageProvider;
import 'package:imboy/component/ui/avatar_fallback.dart';
import 'package:imboy/component/ui/popover_menu.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/store/repository/user_repo_provider.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_duration.dart';
import 'package:imboy/theme/default/app_radius.dart';
import 'package:imboy/theme/default/app_shadows.dart';
import 'package:imboy/theme/default/app_sizes.dart';
import 'package:imboy/theme/default/app_spacing.dart';
import 'package:imboy/theme/default/font_types.dart';

import 'workspace_drawer_menu.dart';

/// 同一空间入口随壳布局移动：有侧栏时全局常驻，否则放在消息顶栏。
/// 个人头像与企业标识只表达当前空间，统一以「切换空间」操作语义呈现。
class SpaceSwitcherButton extends ConsumerStatefulWidget {
  const SpaceSwitcherButton({
    super.key,
    this.organizationId = '',
    this.spaceName,
    this.inRail = false,
    this.onTap,
  });

  final String organizationId;
  final String? spaceName;
  final bool inRail;

  /// 兼容既有个人头像按钮的回调契约；壳内默认走共享菜单。
  final VoidCallback? onTap;

  @override
  ConsumerState<SpaceSwitcherButton> createState() =>
      _SpaceSwitcherButtonState();
}

class _SpaceSwitcherButtonState extends ConsumerState<SpaceSwitcherButton> {
  bool _opening = false;

  Future<void> _open() async {
    if (_opening) return;
    if (widget.onTap != null) {
      widget.onTap!();
      return;
    }
    _opening = true;
    try {
      await showSpaceSwitcherMenu(
        context,
        organizationId: widget.organizationId,
        inRail: widget.inRail,
      );
    } finally {
      _opening = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final isPersonal = widget.organizationId.isEmpty;
    final hasAvatar = isPersonal && (user?.avatar.isNotEmpty ?? false);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final tint = dark ? AppColors.primaryContainer : AppColors.primaryDark;
    final label = context.t.organization.experienceUi.switchSpace;
    final space = widget.spaceName?.isNotEmpty == true
        ? widget.spaceName!
        : isPersonal
        ? context.t.organization.experienceUi.personalSpace
        : context.t.organization.experienceUi.enterpriseSpaces;
    return Semantics(
      label: label,
      value: space,
      child: Tooltip(
        message: '$label · $space',
        excludeFromSemantics: true,
        child: CupertinoButton(
          padding: EdgeInsets.zero,
          minimumSize: const Size.square(AppSizes.touchTarget),
          onPressed: _open,
          child: ExcludeSemantics(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: AppSizes.avatarSizeSmall,
                      height: AppSizes.avatarSizeSmall,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: dark
                            ? AppColors.primaryAlpha20
                            : AppColors.primaryLight,
                        borderRadius: AppRadius.borderRadiusSmall,
                        image: hasAvatar
                            ? DecorationImage(
                                image: avatarImageProvider(user!.avatar),
                                fit: BoxFit.cover,
                              )
                            : null,
                      ),
                      child: hasAvatar
                          ? null
                          : isPersonal
                          ? AvatarFallbackContent(
                              name: user?.nickname ?? context.t.common.unknown,
                              color: tint,
                              textStyle: context.textStyle(
                                FontSizeType.footnote,
                              ),
                            )
                          : Icon(
                              CupertinoIcons.building_2_fill,
                              size: AppSizes.iconSizeSmall,
                              color: tint,
                            ),
                    ),
                    AppSpacing.horizontalTiny,
                    Icon(
                      CupertinoIcons.chevron_down,
                      size: AppSizes.iconSizeXSmall,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ],
                ),
                if (widget.inRail) ...[
                  AppSpacing.verticalTiny,
                  SizedBox(
                    width: AppSizes.buttonHeightXLarge,
                    child: Text(
                      space,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: context.textStyle(
                        FontSizeType.caption2,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 复用空间菜单的数据、权限与切换事务，仅按实际导航布局选择容器。
Future<void> showSpaceSwitcherMenu(
  BuildContext context, {
  String organizationId = '',
  bool inRail = false,
}) {
  final navigator = Navigator.of(context, rootNavigator: true);
  final themes = InheritedTheme.capture(from: context, to: navigator.context);
  final container = ProviderScope.containerOf(context, listen: false);
  final router = GoRouter.maybeOf(context);
  final theme = Theme.of(context);

  Widget menu(BuildContext overlayContext) {
    final route = ModalRoute.of(overlayContext)!;
    Widget child = WorkspaceDrawerMenu(
      key: const ValueKey('space-switcher-menu'),
      organizationId: organizationId,
      compact: true,
      onClose: () {
        final owner = route.navigator;
        if (owner == null || !route.isActive) return;
        // 切换可能异步完成，上方若已有另一个页面，只移除自己的弹层。
        if (route.isCurrent) {
          owner.pop();
        } else {
          owner.removeRoute(route);
        }
      },
    );
    if (router != null) {
      child = InheritedGoRouter(goRouter: router, child: child);
    }
    return themes.wrap(
      UncontrolledProviderScope(container: container, child: child),
    );
  }

  if (inRail) {
    final box = context.findRenderObject()! as RenderBox;
    final anchor = box.localToGlobal(Offset.zero) & box.size;
    return showPopoverContent(
      context,
      anchor: anchor,
      builder: (overlayContext) => DecoratedBox(
        key: const ValueKey('space-switcher-popover'),
        decoration: BoxDecoration(
          borderRadius: AppRadius.borderRadiusLarge,
          boxShadow: AppShadows.cardForBrightness(theme.brightness),
        ),
        child: Material(
          color: theme.colorScheme.surface,
          borderRadius: AppRadius.borderRadiusLarge,
          clipBehavior: Clip.antiAlias,
          child: menu(overlayContext),
        ),
      ),
    );
  }

  final reduceMotion = MediaQuery.disableAnimationsOf(context);
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    useSafeArea: true,
    isScrollControlled: true,
    showDragHandle: true,
    barrierColor: AppColors.overlayBlack26,
    backgroundColor: theme.colorScheme.surface,
    shape: RoundedRectangleBorder(borderRadius: AppRadius.bottomSheet),
    clipBehavior: Clip.antiAlias,
    sheetAnimationStyle: reduceMotion
        ? AnimationStyle.noAnimation
        : const AnimationStyle(
            duration: AppDuration.modalSlide,
            reverseDuration: AppDuration.normal,
          ),
    builder: (overlayContext) {
      final media = MediaQuery.of(overlayContext);
      return ConstrainedBox(
        key: const ValueKey('space-switcher-sheet'),
        constraints: BoxConstraints(
          maxWidth: AppSizes.dialogMaxWidth,
          maxHeight: math.max(
            0.0,
            media.size.height -
                media.viewPadding.top -
                media.viewInsets.bottom -
                AppSpacing.xxxLarge,
          ),
        ),
        child: SafeArea(top: false, child: menu(overlayContext)),
      );
    },
  );
}
