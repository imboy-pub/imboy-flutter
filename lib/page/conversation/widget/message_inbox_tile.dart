import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

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
class MessageInboxTile extends StatefulWidget {
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

  @override
  State<MessageInboxTile> createState() => _MessageInboxTileState();
}

class _MessageInboxTileState extends State<MessageInboxTile> {
  bool _isPressed = false;

  void _setPressed(bool pressed) {
    if (_isPressed != pressed) setState(() => _isPressed = pressed);
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;
    final surface = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final background = widget.isPinned
        ? AppColors.getSurfaceGrouped(brightness)
        : surface;
    final hasTime = widget.timeLabel?.isNotEmpty ?? false;
    final hasStatus =
        widget.isPinned ||
        widget.isMuted ||
        widget.trailingStatus != null ||
        widget.unreadCount > 0;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      // Inbox taps give a quiet highlight, without triggering haptics.
      onTapDown: (_) => _setPressed(true),
      onTapUp: (_) => _setPressed(false),
      onTapCancel: () => _setPressed(false),
      child: AnimatedContainer(
        duration: AppDuration.respectReducedMotion(
          MediaQuery.disableAnimationsOf(context),
          AppDuration.buttonPress,
        ),
        color: _isPressed
            ? Color.alphaBlend(
                isDark ? AppColors.overlayWhite10 : AppColors.overlayBlack5,
                background,
              )
            : background,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.regular,
          vertical: AppSpacing.medium,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox.square(
              dimension: MessageInboxTile.avatarSize,
              child: widget.avatar,
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
                        widget.title,
                        AppSpacing.verticalTiny,
                        widget.preview,
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
                          children: [
                            widget.title,
                            AppSpacing.verticalTiny,
                            widget.preview,
                          ],
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
                              if (hasTime && hasStatus) AppSpacing.verticalTiny,
                              if (hasStatus) _buildStatus(context, brightness),
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
    );
  }

  Widget _buildTime(BuildContext context, Brightness brightness) => Text(
    widget.timeLabel!,
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
    textAlign: TextAlign.end,
    style: context
        .textStyle(
          FontSizeType.small,
          color: AppColors.getTextSecondary(brightness),
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
        if (widget.isPinned)
          Icon(
            CupertinoIcons.pin_fill,
            size: AppSpacing.medium,
            color: secondary,
            semanticLabel: context.t.chat.pinned,
          ),
        if (widget.isMuted)
          Icon(
            CupertinoIcons.bell_slash_fill,
            size: AppSpacing.medium,
            color: secondary,
            semanticLabel: context.t.common.muteNotifications,
          ),
        if (widget.trailingStatus != null) widget.trailingStatus!,
        if (widget.unreadCount > 0)
          Semantics(
            label: context.t.common.unreadCount(count: '${widget.unreadCount}'),
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
                color: widget.isMuted
                    ? (brightness == Brightness.dark
                          ? AppColors.iosGray3Dark
                          : AppColors.iosGray3)
                    : AppColors.getIosRed(brightness),
                borderRadius: BorderRadius.circular(AppRadius.circle),
              ),
              child: Text(
                widget.unreadCount > 99 ? '99+' : '${widget.unreadCount}',
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context
                    .textStyle(
                      FontSizeType.caption2,
                      fontWeight: FontWeight.w600,
                      color: widget.isMuted ? secondary : AppColors.onPrimary,
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
