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

import '../channel_di_provider.dart';

import '../channel_detail_rules.dart';
import 'channel_role_badge.dart';
import 'channel_overflow_menu.dart';

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

  /// 是否渲染频道身份大标题（P1-01/D01）：详情路由的 AppBar（standalone
  /// 的 GlassAppBar 或 workspace 宿主 AppBar）已承载唯一的频道身份标题，
  /// 当前详情调用传 false 进入紧凑模式——仅保留头像/认证/角色/订阅数，
  /// 不再在元信息区重复大标题。默认 true，非详情入口不受影响。
  final bool showIdentityTitle;

  const ChannelHeaderBar({
    super.key,
    required this.channel,
    this.stats,
    this.onActionTap,
    this.isActionPending = false,
    this.onShareTap,
    this.onForwardTap,
    this.onManageTap,
    this.showIdentityTitle = true,
  });

  @override
  ConsumerState<ChannelHeaderBar> createState() => _ChannelHeaderBarState();
}

class _ChannelHeaderBarState extends ConsumerState<ChannelHeaderBar> {
  bool _isMuted = false;
  bool _muteKnown = false;
  int _muteRequest = 0;
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
    final request = ++_muteRequest;
    final id = widget.channel.id.toString();
    setState(() => _muteKnown = false);
    if (!widget.channel.isSubscribed) return;
    try {
      final sub = await ref.read(channelServiceProvider).getSubscription(id);
      if (mounted && request == _muteRequest) {
        setState(() {
          _muteKnown = sub != null;
          _isMuted = sub?.isMuted ?? false;
        });
      }
    } on Exception {
      // 未知状态显示重试入口，不冒充已开启通知。
    }
  }

  Future<void> _retryMuteState() async {
    final id = widget.channel.id;
    setState(() => _isLoadingMute = true);
    try {
      final service = ref.read(channelServiceProvider);
      final fresh = await service.refreshChannel(id.toString());
      if (!mounted || widget.channel.id != id) return;
      if (fresh?.isSubscribed != true) {
        AppLoading.showError(t.common.operationFailedAgainLater);
        return;
      }
      await service.syncSubscribedChannels(fromList: [fresh!]);
      if (mounted && widget.channel.id == id) await _loadMuteState();
    } on Exception {
      if (mounted) AppLoading.showError(t.common.operationFailedAgainLater);
    } finally {
      if (mounted) setState(() => _isLoadingMute = false);
    }
  }

  Future<void> _toggleMute() async {
    if (_isLoadingMute) return;
    if (!_muteKnown) {
      await _retryMuteState();
      return;
    }
    setState(() => _isLoadingMute = true);
    final channelId = widget.channel.id;
    try {
      final nextMute = !_isMuted;
      final success = await ref
          .read(channelServiceProvider)
          .setMuted(widget.channel.id.toString(), nextMute);
      if (success && mounted && widget.channel.id == channelId) {
        await _loadMuteState();
        if (!mounted || widget.channel.id != channelId || !_muteKnown) return;
        AppLoading.showToast(
          nextMute ? t.chat.chatSettingMuted : t.chat.chatSettingUnmuted,
        );
      } else if (mounted) {
        AppLoading.showError(t.common.operationFailedAgainLater);
      }
    } catch (_) {
      AppLoading.showError(t.common.operationFailedAgainLater);
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
    if (!widget.showIdentityTitle) return _compactHeader(subscriberCount);
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
                      // P1-01：详情路由 AppBar 已有唯一频道身份标题，
                      // 紧凑模式（showIdentityTitle=false）不再重复渲染
                      // 大标题；认证徽标移入元信息行保留。
                      if (widget.showIdentityTitle) ...[
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
                      ],
                      Wrap(
                        spacing: AppSpacing.small,
                        runSpacing: AppSpacing.tiny,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          if (widget.channel.isManaged)
                            ChannelRoleBadge(role: widget.channel.userRole),
                          // 统计未加载（含 embedded 模式 autoLoadStats=false）
                          // 时用频道自带订阅数兜底直显——骨架条在统计永不加载
                          // 的场景会成为永久占位灰条（2026-10-17 修复）。
                          Text(
                            '${formatChannelNumber(subscriberCount)} ${t.channel.subscribers}',
                            style: context.textStyle(
                              FontSizeType.small,
                              color: secondaryColor,
                            ),
                          ),
                          if (!widget.showIdentityTitle &&
                              widget.channel.isVerified)
                            const Icon(
                              CupertinoIcons.checkmark_seal_fill,
                              size: AppSpacing.large,
                              color: AppColors.iosGreen,
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

  Widget _compactHeader(int subscriberCount) {
    final channel = widget.channel;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.regular,
        vertical: AppSpacing.tiny,
      ),
      child: Row(
        children: [
          Expanded(
            child: CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: () => showChannelInfoDialog(
                context,
                channel,
                subscriberCount: subscriberCount,
              ),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: Wrap(
                  spacing: AppSpacing.small,
                  runSpacing: AppSpacing.tiny,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (channel.isManaged)
                      ChannelRoleBadge(role: channel.userRole),
                    Text(
                      '${channel.isPublic ? context.t.channel.typePublic : context.t.channel.typePrivate}'
                      ' · $subscriberCount ${context.t.channel.subscribers}',
                      style: context.textStyle(
                        FontSizeType.small,
                        color: AppColors.getTextColor(
                          Theme.of(context).brightness,
                          isSecondary: true,
                        ),
                      ),
                    ),
                    if (channel.isVerified)
                      const Icon(
                        CupertinoIcons.checkmark_seal_fill,
                        size: AppSpacing.regular,
                        color: AppColors.iosGreen,
                      ),
                  ],
                ),
              ),
            ),
          ),
          if (channel.isSubscribed)
            CupertinoButton(
              padding: const EdgeInsets.all(AppSpacing.small),
              onPressed: _isLoadingMute ? null : _toggleMute,
              child: Icon(
                !_muteKnown
                    ? CupertinoIcons.arrow_clockwise
                    : (_isMuted
                          ? CupertinoIcons.bell_slash
                          : CupertinoIcons.bell),
                semanticLabel: _muteKnown
                    ? context.t.chat.chatSettingMute
                    : context.t.common.retry,
              ),
            )
          else
            CupertinoButton(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.small),
              onPressed: widget.isActionPending ? null : widget.onActionTap,
              child: widget.isActionPending
                  ? const CupertinoActivityIndicator()
                  : Text(context.t.channel.subscribe),
            ),
        ],
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
            // P1-04：回调缺失即禁用（不再回退空函数造成假有效点击）
            onTap: widget.onManageTap ?? widget.onActionTap,
          ),

          // 2. Subscribe or Mute action for managers
          if (isSubscribed)
            _buildCircleActionItem(
              icon: !_muteKnown
                  ? CupertinoIcons.arrow_clockwise
                  : (_isMuted
                        ? CupertinoIcons.bell_slash_fill
                        : CupertinoIcons.bell_fill),
              label: _muteKnown ? t.chat.chatSettingMute : t.common.retry,
              onTap: _toggleMute,
              iconColor: _isMuted ? AppColors.iosGray : AppColors.primary,
              isActive: _muteKnown && !_isMuted,
            )
          else
            _buildCircleActionItem(
              icon: CupertinoIcons.bell,
              label: t.channel.subscribe,
              // pending 态与回调缺失都走禁用（onPressed=null）
              onTap: widget.onActionTap,
              isPending: widget.isActionPending,
            ),

          // 3. Forward
          _buildCircleActionItem(
            icon: CupertinoIcons.arrowshape_turn_up_right_fill,
            label: t.channel.shareToChat,
            onTap: widget.onForwardTap,
          ),

          // 4. Share
          _buildCircleActionItem(
            icon: CupertinoIcons.share,
            label: t.channel.share,
            onTap: widget.onShareTap,
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
                  backgroundColor: AppColors.primaryDark,
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
              icon: !_muteKnown
                  ? CupertinoIcons.arrow_clockwise
                  : (_isMuted
                        ? CupertinoIcons.bell_slash_fill
                        : CupertinoIcons.bell_fill),
              label: _muteKnown ? t.chat.chatSettingMute : t.common.retry,
              onTap: _toggleMute,
              iconColor: _isMuted ? AppColors.iosGray : AppColors.primary,
              isActive: _muteKnown && !_isMuted,
            ),

            // Forward Button
            _buildCircleActionItem(
              icon: CupertinoIcons.arrowshape_turn_up_right_fill,
              label: t.channel.shareToChat,
              onTap: widget.onForwardTap,
            ),

            // Share Button
            _buildCircleActionItem(
              icon: CupertinoIcons.share,
              label: t.channel.share,
              onTap: widget.onShareTap,
            ),

            // Subscribed / Following button (Dropdown-like grey background)
            _buildCircleActionItem(
              icon: CupertinoIcons.checkmark_seal_fill,
              label: t.channel.subscribed,
              onTap: widget.onActionTap,
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
    required VoidCallback? onTap,
    Color? iconColor,
    bool isActive = false,
    bool isPending = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final themePrimary = AppColors.primary;
    // 默认图标色用次级文本色（overlayBlack5 对比度不达标，灰底上近乎
    // 不可见——2026-10-17 a11y 修复）。
    final defaultIconColor = AppColors.getTextColor(
      Theme.of(context).brightness,
      isSecondary: true,
    );
    // P1-04：禁用=进行中或回调缺失（onPressed=null 走系统禁用语义），
    // 图标用次级弱化色区分「不可用」；与「静音已开启」的灰图标
    //（可点击切换）语义互不混淆——后者仍可点击。
    final bool disabled = isPending || onTap == null;
    final Color disabledColor = isDark
        ? AppColors.iosGray3Dark
        : AppColors.iosGray3;

    // 纯图标按钮必须有语义标签（DESIGN.md 11.4 / a11y 门）：label 即
    // 该动作的可读名（调用方传入）。
    return Semantics(
      label: label,
      button: true,
      child: CupertinoButton(
        padding: EdgeInsets.zero,
        onPressed: disabled ? null : onTap,
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
                          color: disabled
                              ? disabledColor
                              : (iconColor ??
                                    (isActive
                                        ? themePrimary
                                        : defaultIconColor)),
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
}
