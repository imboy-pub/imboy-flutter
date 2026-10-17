import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:imboy/theme/default/font_types.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/component/ui/avatar_fallback.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/store/model/channel_model.dart';
import 'package:imboy/store/model/channel_stats_model.dart';
import 'package:imboy/service/channel_service.dart';

import '../channel_detail_rules.dart';
import 'channel_role_badge.dart';

import 'package:imboy/theme/default/app_spacing.dart';

import 'package:imboy/component/ui/app_loading.dart';

class ChannelHeaderBar extends ConsumerStatefulWidget {
  final ChannelModel channel;
  final ChannelStatsModel? stats;

  /// 点击订阅/管理/退订按钮回调
  final VoidCallback? onActionTap;
  final bool isActionPending;

  /// 额外辅助操作
  final VoidCallback? onShareTap;
  final VoidCallback? onForwardTap;
  final VoidCallback? onManageTap;

  const ChannelHeaderBar({
    super.key,
    required this.channel,
    this.stats,
    this.onActionTap,
    this.isActionPending = false,
    this.onShareTap,
    this.onForwardTap,
    this.onManageTap,
  });

  @override
  ConsumerState<ChannelHeaderBar> createState() => _ChannelHeaderBarState();
}

class _ChannelHeaderBarState extends ConsumerState<ChannelHeaderBar> {
  bool _isMuted = false;
  bool _isLoadingMute = false;

  @override
  void initState() {
    super.initState();
    _loadMuteState();
  }

  @override
  void didUpdateWidget(covariant ChannelHeaderBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.channel.isSubscribed != widget.channel.isSubscribed ||
        oldWidget.channel.id != widget.channel.id) {
      _loadMuteState();
    }
  }

  Future<void> _loadMuteState() async {
    if (widget.channel.isSubscribed) {
      try {
        final sub = await ChannelService.to.getSubscription(
          widget.channel.id.toString(),
        );
        if (mounted) {
          setState(() {
            _isMuted = sub?.isMuted ?? false;
          });
        }
      } catch (_) {}
    } else {
      if (mounted) {
        setState(() {
          _isMuted = false;
        });
      }
    }
  }

  Future<void> _toggleMute() async {
    if (_isLoadingMute) return;
    setState(() => _isLoadingMute = true);
    try {
      final nextMute = !_isMuted;
      final success = await ChannelService.to.setMuted(
        widget.channel.id.toString(),
        nextMute,
      );
      if (success && mounted) {
        setState(() {
          _isMuted = nextMute;
        });
        AppLoading.showToast(
          nextMute ? t.chat.chatSettingMuted : t.chat.chatSettingUnmuted,
        );
      }
    } catch (_) {
    } finally {
      if (mounted) {
        setState(() => _isLoadingMute = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final secondaryColor = AppColors.getTextColor(
      Theme.of(context).brightness,
      isSecondary: true,
    );
    final subscriberCount =
        widget.stats?.subscriberCount ?? widget.channel.subscriberCount;
    return Container(
      color: Theme.of(context).colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.regular),
        child: Column(
          children: [
            Row(
              children: [
                _buildAvatar(context),
                AppSpacing.horizontalMedium,
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              widget.channel.name,
                              style: context.textStyle(
                                FontSizeType.large,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (widget.channel.isVerified)
                            const Icon(
                              CupertinoIcons.checkmark_seal_fill,
                              size: AppSpacing.large,
                              color: AppColors.iosGreen,
                            ),
                        ],
                      ),
                      AppSpacing.verticalTiny,
                      Wrap(
                        spacing: AppSpacing.small,
                        runSpacing: AppSpacing.tiny,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          if (widget.channel.isManaged)
                            ChannelRoleBadge(role: widget.channel.userRole),
                          if (widget.stats == null)
                            _buildStatsSkeleton(context, secondaryColor)
                          else
                            Text(
                              '${formatChannelNumber(subscriberCount)} ${t.channel.subscribers}',
                              style: context.textStyle(
                                FontSizeType.small,
                                color: secondaryColor,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            AppSpacing.verticalMedium,
            _buildActionRow(context),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar(BuildContext context) {
    final fallback = Center(
      child: AvatarFallbackContent(
        name: widget.channel.name,
        color: AppColors.primary,
        emptyIcon: CupertinoIcons.speaker_2,
        iconSize: AppSpacing.xLarge,
        textStyle: context.textStyle(FontSizeType.large),
      ),
    );
    final avatar = widget.channel.avatar;
    return ClipOval(
      child: SizedBox.square(
        dimension: AppSpacing.xxxLarge,
        child: avatar != null && avatar.isNotEmpty
            ? Image(
                image: cachedImageProvider(avatar, w: 256),
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => fallback,
              )
            : fallback,
      ),
    );
  }

  Widget _buildActionRow(BuildContext context) {
    final t = context.t;
    final isSubscribed = widget.channel.isSubscribed;
    final isManaged = widget.channel.isManaged;

    return Wrap(
      alignment: WrapAlignment.center,
      spacing: AppSpacing.medium,
      runSpacing: AppSpacing.small,
      children: [
        if (isManaged) ...[
          // 1. Manage Button (Always first for managers/admins)
          _buildCircleActionItem(
            icon: CupertinoIcons.gear_solid,
            label: t.main.manage,
            onTap: widget.onManageTap ?? widget.onActionTap ?? () {},
          ),

          // 2. Subscribe or Mute action for managers
          if (isSubscribed)
            _buildCircleActionItem(
              icon: _isMuted
                  ? CupertinoIcons.bell_slash_fill
                  : CupertinoIcons.bell_fill,
              label: t.chat.chatSettingMute,
              onTap: _toggleMute,
              iconColor: _isMuted ? AppColors.iosGray : AppColors.primary,
              isActive: !_isMuted,
            )
          else
            _buildCircleActionItem(
              icon: CupertinoIcons.bell,
              label: t.channel.subscribe,
              onTap: widget.isActionPending
                  ? () {}
                  : (widget.onActionTap ?? () {}),
              isPending: widget.isActionPending,
            ),

          // 3. Forward
          _buildCircleActionItem(
            icon: CupertinoIcons.arrowshape_turn_up_right_fill,
            label: t.channel.shareToChat,
            onTap: widget.onForwardTap ?? () {},
          ),

          // 4. Share
          _buildCircleActionItem(
            icon: CupertinoIcons.share,
            label: t.channel.share,
            onTap: widget.onShareTap ?? () {},
          ),
        ] else ...[
          // Non-managed channels (standard visitors / subscribers)
          if (!isSubscribed) ...[
            // Prominent Subscribe CTA
            SizedBox(
              width: 140,
              child: FilledButton.icon(
                onPressed: widget.isActionPending ? null : widget.onActionTap,
                icon: widget.isActionPending
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CupertinoActivityIndicator(
                          color: AppColors.onPrimary,
                        ),
                      )
                    : const Icon(CupertinoIcons.add, size: 18),
                label: Text(
                  t.channel.subscribe,
                  semanticsLabel: t.channel.subscribe,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  minimumSize: const Size(0, 50),
                  shape: RoundedRectangleBorder(),
                ),
              ),
            ),
            _buildCircleActionItem(
              icon: CupertinoIcons.share,
              label: t.channel.share,
              onTap: widget.onShareTap ?? () {},
            ),
            _buildCircleActionItem(
              icon: CupertinoIcons.arrowshape_turn_up_right_fill,
              label: t.channel.shareToChat,
              onTap: widget.onForwardTap ?? () {},
            ),
          ] else ...[
            // Mute / Unmute Bell Button
            _buildCircleActionItem(
              icon: _isMuted
                  ? CupertinoIcons.bell_slash_fill
                  : CupertinoIcons.bell_fill,
              label: t.chat.chatSettingMute,
              onTap: _toggleMute,
              iconColor: _isMuted ? AppColors.iosGray : AppColors.primary,
              isActive: !_isMuted,
            ),

            // Forward Button
            _buildCircleActionItem(
              icon: CupertinoIcons.arrowshape_turn_up_right_fill,
              label: t.channel.shareToChat,
              onTap: widget.onForwardTap ?? () {},
            ),

            // Share Button
            _buildCircleActionItem(
              icon: CupertinoIcons.share,
              label: t.channel.share,
              onTap: widget.onShareTap ?? () {},
            ),

            // Subscribed / Following button (Dropdown-like grey background)
            _buildCircleActionItem(
              icon: CupertinoIcons.checkmark_seal_fill,
              label: t.channel.subscribed,
              onTap: widget.isActionPending
                  ? () {}
                  : (widget.onActionTap ?? () {}),
              iconColor: AppColors.iosGreen,
              isPending: widget.isActionPending,
            ),
          ],
        ],
      ],
    );
  }

  Widget _buildCircleActionItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? iconColor,
    bool isActive = false,
    bool isPending = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final themePrimary = AppColors.primary;

    // 纯图标按钮必须有语义标签（DESIGN.md 11.4 / a11y 门）：label 即
    // 该动作的可读名（调用方传入）。
    return Semantics(
      label: label,
      button: true,
      child: CupertinoButton(
        padding: EdgeInsets.zero,
        onPressed: isPending ? null : onTap,
        child: Container(
          width: 64,
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.tiny),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: AppSpacing.xxxLarge,
                height: AppSpacing.xxxLarge,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isPending
                      ? Colors.transparent
                      : (isActive
                            ? themePrimary.withValues(alpha: 0.12)
                            : (isDark
                                  ? AppColors.overlayLight
                                  : AppColors.overlayBlack5)),
                ),
                child: Center(
                  child: isPending
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CupertinoActivityIndicator(),
                        )
                      : Icon(
                          icon,
                          size: 20,
                          color:
                              iconColor ??
                              (isActive
                                  ? themePrimary
                                  : (isDark
                                        ? AppColors.overlayWhite70
                                        : AppColors.overlayBlack5)),
                        ),
                ),
              ),
              AppSpacing.verticalTiny,
              Text(
                label,
                style: context.textStyle(
                  FontSizeType.tiny,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatsSkeleton(BuildContext context, Color color) {
    return Container(
      width: 80,
      height: AppSpacing.medium,
      color: color.withValues(alpha: 0.12),
    );
  }
}
