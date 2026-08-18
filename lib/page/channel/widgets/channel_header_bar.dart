import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:imboy/theme/default/app_spacing.dart';
import 'package:imboy/theme/default/font_types.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_radius.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/component/ui/avatar_fallback.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/store/model/channel_model.dart';
import 'package:imboy/store/model/channel_stats_model.dart';
import 'package:imboy/service/channel_service.dart';

import '../channel_detail_rules.dart';

/// 频道头部信息条（对标 WhatsApp 频道详情设计）
///
/// 采用大面积居中化 Profile 设计：
/// 1. 顶部居中超大圆形头像 (96x96 px)
/// 2. 居中频道名 + 绿色官方认证角标
/// 3. 居中精炼粉丝数统计
/// 4. 居中横向多功能高保真 Action Row（Follow, Mute/Unmute, Forward, Share）
/// 5. “关于此频道”独立信息卡片，包含描述、Tags 标签包装
/// 6. 高拟真度“安全与隐私承诺卡片”（Public channel & Phone number private）
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              nextMute ? t.chat.chatSettingMuted : t.chat.chatSettingUnmuted,
            ),
            duration: const Duration(seconds: 2),
          ),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final secondaryColor = AppColors.getTextColor(
      Theme.of(context).brightness,
      isSecondary: true,
    );
    final textPrimary = AppColors.getTextColor(Theme.of(context).brightness);
    final surface = Theme.of(context).colorScheme.surface;

    // 格式化订阅人数（优先使用统计包，若无则使用频道基本属性）
    final subscriberCount =
        widget.stats?.subscriberCount ?? widget.channel.subscriberCount;
    final formattedSubscribers = formatChannelNumber(subscriberCount);

    return Container(
      color: surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 24),
          // 1. 居中圆形超大头像
          _buildCenteredAvatar(context),
          const SizedBox(height: 16),

          // 2. 居中频道名 + 绿色 verified checkmark
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    widget.channel.name,
                    style: context.textStyle(
                      FontSizeType.largeTitle,
                      fontWeight: FontWeight.w800,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (widget.channel.isVerified)
                  const Padding(
                    padding: EdgeInsets.only(left: 6),
                    child: Icon(
                      Icons.verified,
                      size: 20,
                      color: Color(0xFF25D366), // WhatsApp 标志性绿色安全徽标
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 6),

          // 2.5 居中精美管理员/创建者身份徽标
          if (widget.channel.isManaged) ...[
            _buildRoleBadge(context),
            const SizedBox(height: 6),
          ],

          // 3. 居中精炼粉丝数统计
          widget.stats == null
              ? _buildStatsSkeleton(context, secondaryColor)
              : Text(
                  '$formattedSubscribers ${t.channel.subscribers}',
                  style: context.textStyle(
                    FontSizeType.medium,
                    color: secondaryColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
          const SizedBox(height: 20),

          // 4. 横向高保真 Action Row
          _buildActionRow(context),
          const SizedBox(height: 12),

          // 5. 拟真安全与隐私承诺卡片
          _buildPrivacyCard(context),

          // 6. 独立“关于此频道”卡片描述
          _buildAboutCard(context, secondaryColor, textPrimary),

          const Divider(height: 1),
        ],
      ),
    );
  }

  Widget _buildCenteredAvatar(BuildContext context) {
    final hasAvatar =
        widget.channel.avatar != null && widget.channel.avatar!.isNotEmpty;
    return Container(
      width: 96,
      height: 96,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.primary.withValues(alpha: 0.1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: hasAvatar
          ? Image(
              image: cachedImageProvider(widget.channel.avatar!, w: 256),
              fit: BoxFit.cover,
              width: 96,
              height: 96,
              errorBuilder: (context, error, stackTrace) => Center(
                child: AvatarFallbackContent(
                  name: widget.channel.name,
                  color: AppColors.primary,
                  emptyIcon: Icons.campaign_outlined,
                  iconSize: 44,
                  textStyle: context.textStyle(
                    FontSizeType.extraLarge,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            )
          : Center(
              child: AvatarFallbackContent(
                name: widget.channel.name,
                color: AppColors.primary,
                emptyIcon: Icons.campaign_outlined,
                iconSize: 44,
                textStyle: context.textStyle(
                  FontSizeType.extraLarge,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
    );
  }

  Widget _buildRoleBadge(BuildContext context) {
    final role = widget.channel.userRole;
    final isChinese = Localizations.localeOf(context).languageCode == 'zh';

    String label = '';
    Color color = AppColors.iosGray;

    switch (role) {
      case ChannelUserRole.creator:
        label = isChinese ? '创建者' : 'Creator';
        color = AppColors.primary;
        break;
      case ChannelUserRole.admin:
        label = isChinese ? '管理员' : 'Admin';
        color = AppColors.iosOrange;
        break;
      case ChannelUserRole.editor:
        label = isChinese ? '编辑' : 'Editor';
        color = AppColors.iosBlue;
        break;
      default:
        return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            role == ChannelUserRole.creator
                ? Icons.star_rounded
                : Icons.admin_panel_settings_rounded,
            size: 14,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: FontSizeType.small.size,
              fontWeight: FontWeight.bold,
              color: color,
              fontFamily: 'PingFang SC',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionRow(BuildContext context) {
    final t = context.t;
    final isSubscribed = widget.channel.isSubscribed;
    final isManaged = widget.channel.isManaged;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 12,
        runSpacing: 8,
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
                height: 40,
                child: FilledButton.icon(
                  onPressed: widget.isActionPending ? null : widget.onActionTap,
                  icon: widget.isActionPending
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.onPrimary,
                          ),
                        )
                      : const Icon(Icons.add, size: 18),
                  label: Text(
                    t.channel.subscribe,
                    semanticsLabel: t.channel.subscribe,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
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
                iconColor: _isMuted ? Colors.grey : AppColors.primary,
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
                iconColor: const Color(0xFF25D366),
                isPending: widget.isActionPending,
              ),
            ],
          ],
        ],
      ),
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

    return InkWell(
      onTap: isPending ? null : onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 64,
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isPending
                    ? Colors.transparent
                    : (isActive
                          ? themePrimary.withValues(alpha: 0.12)
                          : (isDark
                                ? Colors.white.withValues(alpha: 0.08)
                                : Colors.black.withValues(alpha: 0.05))),
              ),
              child: Center(
                child: isPending
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(
                        icon,
                        size: 20,
                        color:
                            iconColor ??
                            (isActive
                                ? themePrimary
                                : (isDark ? Colors.white70 : Colors.black87)),
                      ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: context.textStyle(
                FontSizeType.tiny,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPrivacyCard(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final localeCode = Localizations.localeOf(context).languageCode;
    final isChinese = localeCode == 'zh';

    // 拟真 WhatsApp 隐私文案
    final String privacyTitle = isChinese
        ? "公开频道与隐私保护"
        : "Public channel & privacy";
    final String privacyDesc = isChinese
        ? "任何人都可查找并关注此频道。你的电话号码对其他订阅者或频道管理员完全保密。"
        : "Anyone can find and follow this channel. Your phone number remains completely hidden from other followers and the channel admin.";

    final cardBg = isDark
        ? const Color(0xFF1F2C34).withValues(alpha: 0.5) // 经典暗色 WhatsApp 背景微调
        : const Color(0xFFE7F3EF).withValues(alpha: 0.8); // 经典 WhatsApp 浅绿蓝背景

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.06)
              : const Color(0xFF25D366).withValues(alpha: 0.12),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            CupertinoIcons.shield_fill,
            color: Color(0xFF25D366),
            size: 22,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  privacyTitle,
                  style: context.textStyle(
                    FontSizeType.small,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  privacyDesc,
                  style: context
                      .textStyle(FontSizeType.tiny)
                      .copyWith(
                        height: 1.35,
                        color: isDark ? Colors.white60 : Colors.black54,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAboutCard(
    BuildContext context,
    Color secondaryColor,
    Color textPrimary,
  ) {
    final t = context.t;
    final hasDesc =
        widget.channel.description != null &&
        widget.channel.description!.isNotEmpty;
    final hasTags =
        widget.channel.tags != null && widget.channel.tags!.isNotEmpty;

    if (!hasDesc && !hasTags) return const SizedBox.shrink();

    final isChinese = Localizations.localeOf(context).languageCode == 'zh';
    final sectionTitle = isChinese ? "关于此频道" : "About this channel";

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            sectionTitle,
            style: context.textStyle(
              FontSizeType.medium,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (hasDesc) ...[
            const SizedBox(height: 8),
            Text(
              widget.channel.description!,
              style: context
                  .textStyle(FontSizeType.small)
                  .copyWith(
                    height: 1.45,
                    color: textPrimary.withValues(alpha: 0.85),
                  ),
            ),
          ],
          if (hasTags) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: widget.channel.tags!
                  .take(6)
                  .map(
                    (tag) => Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '#$tag',
                        style: context.textStyle(
                          FontSizeType.tiny,
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatsSkeleton(BuildContext context, Color color) {
    return SizedBox(
      height: 20,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 12,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
            ),
          ),
        ],
      ),
    );
  }
}
