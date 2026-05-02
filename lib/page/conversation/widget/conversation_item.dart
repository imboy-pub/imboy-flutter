import 'package:badges/badges.dart' as badges;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:imboy/component/ui/avatar.dart';
import 'package:imboy/component/ui/imboy_icon.dart';
import 'package:imboy/component/helper/datetime.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/modules/group_collab/public.dart';
import 'package:imboy/page/conversation/conversation_provider.dart';
import 'package:imboy/store/model/conversation_model.dart';
import 'package:imboy/store/model/message_model.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_radius.dart';
import 'package:imboy/theme/default/font_types.dart' show FontSizeType;

/// 会话列表项组件 - Riverpod 版本
class ConversationItem extends ConsumerStatefulWidget {
  final ConversationModel model;
  final Function()? onTapAvatar;
  final Function()? onTap;

  const ConversationItem({
    super.key,
    required this.model,
    required this.onTapAvatar,
    this.onTap,
  });

  @override
  ConsumerState<ConversationItem> createState() => _ConversationItemState();
}

class _ConversationItemState extends ConsumerState<ConversationItem> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    // 使用 select 精确监听，避免整个会话列表变化时重建所有 item
    final int remindCounter = ref.watch(
      conversationProvider.select(
        (s) => s.conversationRemind[widget.model.uk3] ?? widget.model.unreadNum,
      ),
    );
    final ConversationModel currentModel = ref.watch(
      conversationProvider.select(
        (s) => s.conversationMap[widget.model.uk3] ?? widget.model,
      ),
    );

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    var icon = <Widget>[];

    if (currentModel.lastMsgStatus == IMBoyMessageStatus.sending) {
      icon.add(
        Padding(
          padding: const EdgeInsets.only(right: 6),
          child: Icon(IMBoyIcon.sending, color: AppColors.primary, size: 14),
        ),
      );
    }

    return AnimatedScale(
      scale: _isPressed ? 0.98 : 1.0,
      duration: const Duration(milliseconds: 100),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: AppRadius.borderRadiusRegular,
          boxShadow: [
            BoxShadow(
              color: isDark
                  ? Colors.black.withValues(alpha: 0.2)
                  : Colors.black.withValues(alpha: 0.04),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.05)
                : Colors.transparent,
            width: 0.5,
          ),
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: AppRadius.borderRadiusRegular,
          child: InkWell(
            borderRadius: AppRadius.borderRadiusRegular,
            onTap: widget.onTap,
            onTapDown: (_) => setState(() => _isPressed = true),
            onTapUp: (_) => setState(() => _isPressed = false),
            onTapCancel: () => setState(() => _isPressed = false),
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Avatar Area
                  badges.Badge(
                    position: badges.BadgePosition.topEnd(top: -2, end: -2),
                    showBadge: (remindCounter > 0),
                    badgeContent: Text(
                      "$remindCounter",
                      // DESIGN.md §3.4：数字优先等宽（未读徽章数字需对齐）
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: FontSizeType.tiny.size,
                        fontWeight: FontWeight.bold,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    badgeStyle: badges.BadgeStyle(
                      badgeColor: AppColors.messageFailed,
                      padding: const EdgeInsets.all(5),
                    ),
                    child: GestureDetector(
                      onTap: widget.onTapAvatar,
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: theme.scaffoldBackgroundColor,
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 5,
                            ),
                          ],
                        ),
                        child: widget.model.type == 'C2G'
                            ? SmartGroupAvatar(
                                avatar: widget.model.avatar,
                                groupId: widget.model.peerId.toString(),
                                onTap: widget.onTapAvatar,
                                size: 52,
                                avatarLoader: GroupListService().computeAvatar,
                                heroTag: 'avatar_${widget.model.peerId}',
                              )
                            : Avatar(
                                imgUri: widget.model.avatar,
                                width: 52,
                                height: 52,
                                heroTag: 'avatar_${widget.model.peerId}',
                              ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 14),

                  // Content Area
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Top Row: Title + Time
                        Flexible(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(child: _buildTitle(currentModel, theme)),
                              const SizedBox(width: 4),
                              _buildTime(currentModel, theme),
                            ],
                          ),
                        ),

                        const SizedBox(height: 6),

                        // Bottom Row: Message Preview
                        Flexible(
                          child: Row(
                            children: [
                              Column(children: icon),
                              Expanded(
                                child: _buildContent(currentModel, theme),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTitle(ConversationModel currentModel, ThemeData theme) {
    String displayTitle = '';

    if (currentModel.title.trim().isNotEmpty) {
      displayTitle = currentModel.title;
    } else if (currentModel.computeTitle.trim().isNotEmpty) {
      displayTitle = currentModel.computeTitle;
    } else {
      displayTitle = currentModel.peerId.toString();
    }

    return Row(
      children: [
        if (currentModel.isPinned)
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: Icon(
              Icons.push_pin_rounded,
              size: 14,
              color: theme.colorScheme.primary,
            ),
          ),
        // C7-α-2: 群免打扰铃铛（淡灰色，标示已静音）
        if (currentModel.isMuted > 0)
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: Icon(
              Icons.notifications_off_outlined,
              size: 14,
              color: theme.textTheme.bodySmall?.color
                      ?.withValues(alpha: 0.5) ??
                  Colors.grey,
            ),
          ),
        Expanded(
          child: Text(
            displayTitle,
            style: TextStyle(
              fontSize: FontSizeType.medium.size,
              fontWeight: FontWeight.w600,
              color: theme.textTheme.titleMedium?.color,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildTime(ConversationModel currentModel, ThemeData theme) {
    if (currentModel.lastTime > 0) {
      return Text(
        DateTimeHelper.lastTimeFmt(currentModel.lastTime),
        // DESIGN.md §3.4：时间戳数字等宽对齐
        style: TextStyle(
          fontSize: FontSizeType.small.size,
          color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.6),
          fontWeight: FontWeight.w500,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildContent(ConversationModel currentModel, ThemeData theme) {
    String content = currentModel.content;

    TextStyle contentStyle = TextStyle(
      fontSize: FontSizeType.small.size,
      color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.6),
      height: 1.2,
    );

    // 处理草稿内容的红色显示
    if (content.contains('_color_red_')) {
      List<String> parts = content.split('_color_red_');
      return RichText(
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        text: TextSpan(
          children: [
            TextSpan(
              text: "${parts[0]} ",
              style: contentStyle.copyWith(color: AppColors.primary),
            ),
            TextSpan(
              text: parts.length > 1 ? parts[1] : '',
              style: contentStyle,
            ),
          ],
        ),
      );
    }

    // C7-β-2c：独立 @ 未读提示 — 会话里有未读且当前用户被 @
    // 时在内容预览前显示红色 [@你]，让用户即使开了消息预览也能一眼
    // 看到自己被提及。与草稿 prefix 互斥（草稿已 return 上面）。
    if (currentModel.mentionUnread > 0) {
      return RichText(
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        text: TextSpan(
          children: [
            TextSpan(
              text: t.atMentionYouTag,
              style: contentStyle.copyWith(
                color: AppColors.unreadBadgeBackground,
                fontWeight: FontWeight.w600,
              ),
            ),
            TextSpan(text: content, style: contentStyle),
          ],
        ),
      );
    }

    return Text(
      content,
      style: contentStyle,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}
