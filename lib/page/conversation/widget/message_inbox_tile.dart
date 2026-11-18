import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/semantics.dart' show CustomSemanticsAction;

import 'package:imboy/component/ui/cell_pressable.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_duration.dart';
import 'package:imboy/theme/default/app_radius.dart';
import 'package:imboy/theme/default/app_spacing.dart';
import 'package:imboy/theme/default/font_types.dart';

/// One visual grammar for chats, groups and subscribed channels in the inbox.
///
/// Content and avatar ownership stay with the caller so account badges, image
/// authorization and independent avatar actions retain their existing behavior.
class MessageInboxTile extends StatelessWidget {
  const MessageInboxTile({
    super.key,
    required this.avatar,
    required this.title,
    required this.preview,
    this.timeLabel,
    this.unreadCount = 0,
    this.isMuted = false,
    this.isPinned = false,
    this.trailingStatus,
    this.onTap,
    this.onLongPress,
    this.customSemanticsActions,
  });

  static const double avatarSize = AppSpacing.xxxLarge;
  static const double contentIndent =
      AppSpacing.regular + avatarSize + AppSpacing.medium;

  final Widget avatar;
  final Widget title;
  final Widget preview;
  final String? timeLabel;
  final int unreadCount;
  final bool isMuted;
  final bool isPinned;
  final Widget? trailingStatus;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final Map<CustomSemanticsAction, VoidCallback>? customSemanticsActions;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;
    final surface = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final background = isPinned
        ? (isDark
              ? Color.alphaBlend(AppColors.overlayLight, surface)
              : AppColors.lightSurfaceVariant)
        : surface;
    final hasTime = timeLabel?.isNotEmpty ?? false;
    final hasStatus =
        isPinned || isMuted || trailingStatus != null || unreadCount > 0;

    return CellPressable(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Semantics(
        // Keep inbox actions inside the named keyboard control's boundary.
        customSemanticsActions: customSemanticsActions,
        child: AnimatedContainer(
          duration: AppDuration.respectReducedMotion(
            MediaQuery.disableAnimationsOf(context),
            AppDuration.buttonPress,
          ),
          color: background,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.regular,
            vertical: AppSpacing.medium,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox.square(
                dimension: MessageInboxTile.avatarSize,
                child: Semantics(
                  container: true,
                  label: context.t.account.avatar,
                  child: ClipRRect(
                    borderRadius: AppRadius.borderRadiusMedium,
                    child: avatar,
                  ),
                ),
              ),
              AppSpacing.horizontalMedium,
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final bodySize = context
                        .textStyle(FontSizeType.body)
                        .fontSize!;
                    final largeText =
                        MediaQuery.textScalerOf(context).scale(bodySize) >
                        FontSizeType.title.size;
                    // Accessibility text keeps the full content width; metadata
                    // moves below the preview without reducing text scale.
                    if (largeText) {
                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          title,
                          AppSpacing.verticalTiny,
                          preview,
                          if (hasTime || hasStatus) ...[
                            AppSpacing.verticalSmall,
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: hasTime
                                      ? _buildTime(context, brightness)
                                      : const SizedBox.shrink(),
                                ),
                                if (hasStatus) ...[
                                  AppSpacing.horizontalSmall,
                                  ConstrainedBox(
                                    constraints: BoxConstraints(
                                      maxWidth: constraints.maxWidth * 0.65,
                                    ),
                                    child: _buildStatus(context, brightness),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ],
                      );
                    }
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [title, AppSpacing.verticalTiny, preview],
                          ),
                        ),
                        if (hasTime || hasStatus) ...[
                          AppSpacing.horizontalSmall,
                          // Reserve space for the title even at 320pt / large text.
                          // Status icons wrap instead of forcing a fixed row height.
                          ConstrainedBox(
                            constraints: BoxConstraints(
                              maxWidth: constraints.maxWidth * 0.36,
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                if (hasTime) _buildTime(context, brightness),
                                if (hasTime && hasStatus)
                                  AppSpacing.verticalTiny,
                                if (hasStatus)
                                  _buildStatus(context, brightness),
                              ],
                            ),
                          ),
                        ],
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTime(BuildContext context, Brightness brightness) => Text(
    timeLabel!,
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
    textAlign: TextAlign.end,
    style: context
        .textStyle(
          FontSizeType.small,
          fontWeight: FontWeight.w400,
          color: brightness == Brightness.dark
              ? AppColors.darkTextSecondary
              : AppColors.lightTextSecondary.withValues(alpha: 0.75),
        )
        .copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
  );

  Widget _buildStatus(BuildContext context, Brightness brightness) {
    final secondary = AppColors.getTextSecondary(brightness);
    return Wrap(
      alignment: WrapAlignment.end,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: AppSpacing.tiny,
      runSpacing: AppSpacing.tiny,
      children: [
        if (isPinned)
          Icon(
            CupertinoIcons.pin_fill,
            size: AppSpacing.medium,
            color: secondary,
            semanticLabel: context.t.chat.pinned,
          ),
        if (isMuted)
          Icon(
            CupertinoIcons.bell_slash_fill,
            size: AppSpacing.medium,
            color: secondary,
            semanticLabel: context.t.common.muteNotifications,
          ),
        ?trailingStatus,
        if (unreadCount > 0)
          Semantics(
            label: context.t.common.unreadCount(count: '$unreadCount'),
            excludeSemantics: true,
            child: Container(
              constraints: const BoxConstraints(
                minWidth: AppSpacing.large,
                minHeight: AppSpacing.large,
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.tiny,
                vertical: AppSpacing.tiny / 2,
              ),
              decoration: BoxDecoration(
                color: isMuted
                    ? (brightness == Brightness.dark
                          ? AppColors.iosGray3Dark
                          : AppColors.iosGray3)
                    : AppColors.getIosRed(brightness),
                borderRadius: BorderRadius.circular(AppRadius.circle),
              ),
              child: Text(
                unreadCount > 99 ? '99+' : '$unreadCount',
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context
                    .textStyle(
                      FontSizeType.caption2,
                      fontWeight: FontWeight.w600,
                      color: isMuted ? secondary : AppColors.onPrimary,
                    )
                    .copyWith(
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
              ),
            ),
          ),
      ],
    );
  }
}
