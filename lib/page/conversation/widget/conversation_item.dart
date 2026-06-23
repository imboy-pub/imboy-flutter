import 'package:imboy/component/ui/badge_widget.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:imboy/component/ui/avatar.dart';
import 'package:imboy/component/helper/datetime.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/modules/group_collab/public.dart';
import 'package:imboy/page/conversation/conversation_provider.dart';
import 'package:imboy/store/model/conversation_model.dart';
import 'package:imboy/store/model/message_model.dart';
import 'package:imboy/theme/default/app_colors.dart';

/// 会话列表项组件 - iOS 17 Premium 风格
class ConversationItem extends ConsumerStatefulWidget {
  final ConversationModel model;
  final void Function()? onTapAvatar;
  final void Function()? onTap;

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

    // 背景色处理：置顶会话使用淡灰背景
    final Color bgColor = currentModel.isPinned
        ? (isDark
              ? AppColors.darkSurfaceGrouped
              : AppColors.lightSurfaceGrouped.withValues(alpha: 0.5))
        : (isDark ? AppColors.darkSurface : Colors.white);

    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      behavior: HitTestBehavior.opaque,
      child: Container(
        color: _isPressed
            ? (isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05))
            : bgColor,
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // 头像区域 + 未读角标
            BadgeWidget(
              showBadge: (remindCounter > 0),
              content: Text(
                remindCounter > 99 ? '99+' : "$remindCounter",
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
              color: AppColors.iosRed,
              padding: const EdgeInsets.all(5),
              top: -4,
              left: -4,
              right: null,
              child: GestureDetector(
                onTap: widget.onTapAvatar,
                child: currentModel.type == 'C2G'
                    ? SmartGroupAvatar(
                        avatar: currentModel.avatar,
                        groupId: currentModel.peerId.toString(),
                        onTap: widget.onTapAvatar,
                        size: 56,
                        avatarLoader: GroupListService().computeAvatar,
                        heroTag: 'avatar_${currentModel.peerId}',
                      )
                    : Avatar(
                        imgUri: currentModel.avatar,
                        width: 56,
                        height: 56,
                        heroTag: 'avatar_${currentModel.peerId}',
                      ),
              ),
            ),

            const SizedBox(width: 14),

            // 内容区域
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 标题与时间
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(child: _buildTitle(currentModel, theme, isDark)),
                      _buildTime(currentModel, theme, isDark),
                    ],
                  ),
                  const SizedBox(height: 4),
                  // 消息预览
                  Row(
                    children: [
                      // 在制中（发送中 / 待重试）均显示进度指示，
                      // 待重试不再误显示为彻底失败。
                      if (IMBoyMessageStatus.isInFlightStatus(
                        currentModel.lastMsgStatus,
                      ))
                        const Padding(
                          padding: EdgeInsets.only(right: 4),
                          child: CupertinoActivityIndicator(radius: 6),
                        ),
                      Expanded(
                        child: _buildContent(currentModel, theme, isDark),
                      ),
                      if (currentModel.isMuted > 0)
                        const Padding(
                          padding: EdgeInsets.only(left: 8),
                          child: Icon(
                            CupertinoIcons.bell_slash_fill,
                            size: 12,
                            color: AppColors.iosGray3,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTitle(
    ConversationModel currentModel,
    ThemeData theme,
    bool isDark,
  ) {
    String displayTitle = currentModel.title.trim().isNotEmpty
        ? currentModel.title
        : (currentModel.computeTitle.trim().isNotEmpty
              ? currentModel.computeTitle
              : currentModel.peerId.toString());

    return Text(
      displayTitle,
      style: TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w600,
        color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
        letterSpacing: -0.4,
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _buildTime(
    ConversationModel currentModel,
    ThemeData theme,
    bool isDark,
  ) {
    if (currentModel.lastTime <= 0) return const SizedBox.shrink();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          DateTimeHelper.lastTimeFmt(currentModel.lastTime),
          style: TextStyle(
            fontSize: 13,
            color: AppColors.iosGray,
            fontWeight: FontWeight.w400,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        const SizedBox(width: 4),
        const Icon(
          CupertinoIcons.chevron_right,
          size: 12,
          color: AppColors.iosGray3,
        ),
      ],
    );
  }

  Widget _buildContent(
    ConversationModel currentModel,
    ThemeData theme,
    bool isDark,
  ) {
    String content = currentModel.content;
    TextStyle contentStyle = TextStyle(
      fontSize: 15,
      color: AppColors.iosGray,
      height: 1.3,
      letterSpacing: -0.2,
    );

    if (content.contains('_color_red_')) {
      List<String> parts = content.split('_color_red_');
      return RichText(
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        text: TextSpan(
          children: [
            TextSpan(
              text: "${parts[0]} ",
              style: contentStyle.copyWith(
                color: AppColors.iosRed,
                fontWeight: FontWeight.w500,
              ),
            ),
            TextSpan(
              text: parts.length > 1 ? parts[1] : '',
              style: contentStyle,
            ),
          ],
        ),
      );
    }

    if (currentModel.mentionUnread > 0) {
      return RichText(
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        text: TextSpan(
          children: [
            TextSpan(
              text: t.common.atMentionYouTag,
              style: contentStyle.copyWith(
                color: AppColors.iosRed,
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
