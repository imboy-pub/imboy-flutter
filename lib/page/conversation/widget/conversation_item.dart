import 'package:badges/badges.dart' as badges;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:imboy/component/ui/avatar.dart';
import 'package:imboy/component/ui/imboy_icon.dart';
import 'package:imboy/component/helper/datetime.dart';
import 'package:imboy/modules/group_collab/public.dart';
import 'package:imboy/page/conversation/conversation_provider.dart';
import 'package:imboy/store/model/conversation_model.dart';
import 'package:imboy/store/model/message_model.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_radius.dart';
import 'package:imboy/theme/default/font_types.dart' show FontSizeType;

/// 会话列表项组件 - Riverpod 版本
class ConversationItem extends ConsumerWidget {
  final ConversationModel model;
  final Function()? onTapAvatar;

  const ConversationItem({
    super.key,
    required this.model,
    required this.onTapAvatar,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 使用 select 精确监听，避免整个会话列表变化时重建所有 item
    final int remindCounter = ref.watch(
      conversationProvider.select(
        (s) => s.conversationRemind[model.uk3] ?? model.unreadNum,
      ),
    );
    final ConversationModel currentModel = ref.watch(
      conversationProvider.select((s) => s.conversationMap[model.uk3] ?? model),
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

    return Container(
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
          onTap: null,
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
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: FontSizeType.tiny.size,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  badgeStyle: badges.BadgeStyle(
                    padding: const EdgeInsets.all(5),
                  ),
                  child: GestureDetector(
                    onTap: onTapAvatar,
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
                      child: model.type == 'C2G'
                          ? SmartGroupAvatar(
                              avatar: model.avatar,
                              groupId: model.peerId,
                              onTap: onTapAvatar,
                              size: 52,
                              avatarLoader: GroupListService().computeAvatar,
                            )
                          : Avatar(imgUri: model.avatar, width: 52, height: 52),
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
                            Expanded(child: _buildContent(currentModel, theme)),
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
    );
  }

  Widget _buildTitle(ConversationModel currentModel, ThemeData theme) {
    String displayTitle = '';

    if (currentModel.title.trim().isNotEmpty) {
      displayTitle = currentModel.title;
    } else if (currentModel.computeTitle.trim().isNotEmpty) {
      displayTitle = currentModel.computeTitle;
    } else {
      displayTitle = currentModel.peerId;
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
        style: TextStyle(
          fontSize: FontSizeType.small.size,
          color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.6),
          fontWeight: FontWeight.w500,
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

    return Text(
      content,
      style: contentStyle,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}
