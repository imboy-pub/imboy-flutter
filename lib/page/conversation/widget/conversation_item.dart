import 'package:badges/badges.dart' as badges;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:imboy/component/ui/avatar.dart';
import 'package:imboy/component/ui/imboy_icon.dart';

import 'package:imboy/component/helper/datetime.dart';

import 'package:imboy/page/conversation/conversation_logic.dart';
import 'package:imboy/store/model/conversation_model.dart';
import 'package:imboy/store/model/message_model.dart';
import 'package:imboy/theme/default/app_colors.dart';

// ignore: must_be_immutable
class ConversationItem extends StatelessWidget {
  final ConversationModel model;
  final RxInt? remindCounter;

  // 会话头像点击事件
  final Function()? onTapAvatar;
  final ConversationLogic logic = Get.find<ConversationLogic>();

  ConversationItem({
    super.key,
    required this.model,
    this.remindCounter,
    required this.onTapAvatar,
  });

  @override
  Widget build(BuildContext context) {
    // 当前会话未读消息数量
    RxInt remindCounter =
        this.remindCounter ?? RxInt(logic.conversationRemind[model.uk3] ?? 0);
    var icon = <Widget>[];
    // 获取最新的会话数据以检查消息状态
    ConversationModel? latestModel = logic.conversationMap[model.uk3];
    ConversationModel currentModel = latestModel ?? model;

    if (currentModel.lastMsgStatus == IMBoyMessageStatus.sending) {
      icon.add(
        Padding(
          padding: const EdgeInsets.only(right: 6),
          child: Icon(
            IMBoyIcon.sending,
            color: AppColors.primaryGreen,
            size: 14,
          ),
        ),
      );
    }

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
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
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap:
              null, // Tap is handled by the parent Slidable usually, but if needed here...
          // Wait, Slidable wraps this. The tap event in conversation_view.dart was on InkWell wrapping Slidable wrapping ConversationItem?
          // No, conversation_view.dart structure is: InkWell -> Slidable -> ConversationItem.
          // So this InkWell creates the visual ripple *inside* the card, but parent's InkWell handles navigation.
          // This might cause double ripple or conflict.
          // Ideally, the navigation tap should be inside here to fill the card.
          // However, changing navigation logic requires Changing conversation_view.
          // For visual safety now, I will omit InkWell here OR conversation_view needs update.
          // Let's keep it simple: Just Container for visuals. Parent handles tap.
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Avatar Area
                Obx(
                  () => badges.Badge(
                    position: badges.BadgePosition.topEnd(top: -2, end: -2),
                    showBadge: (remindCounter.value > 0 ? true : false),
                    badgeContent: Text(
                      "$remindCounter",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    badgeStyle: badges.BadgeStyle(
                      padding: const EdgeInsets.all(5),
                    ),
                    // 会话头像
                    child: GestureDetector(
                      onTap: onTapAvatar,
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: theme
                                .scaffoldBackgroundColor, // separating border
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
                                size: 52, // Slightly larger avatar
                                avatarLoader: logic.groupListLogic.computeAvatar,
                              )
                            : Avatar(imgUri: model.avatar, width: 52, height: 52),
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
                      Flexible(child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Obx(() {
                              ConversationModel? latestModel =
                              logic.conversationMap[model.uk3];
                              ConversationModel currentModel =
                                  latestModel ?? model;
                              String displayTitle = '';

                              if (currentModel.title.trim().isNotEmpty) {
                                displayTitle = currentModel.title;
                              } else if (currentModel.computeTitle
                                  .trim()
                                  .isNotEmpty) {
                                displayTitle = currentModel.computeTitle;
                              } else {
                                displayTitle = currentModel.peerId;
                              }

                              return Text(
                                displayTitle,
                                style: TextStyle(
                                  fontSize: 16.0,
                                  fontWeight: FontWeight.w600, // Bolder title
                                  color: theme.textTheme.titleMedium?.color,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              );
                            }),
                          ),
                          const SizedBox(width: 4),
                          Obx(() {
                            ConversationModel? latestModel =
                            logic.conversationMap[model.uk3];
                            ConversationModel currentModel =
                                latestModel ?? model;

                            if (currentModel.lastTime > 0) {
                              return Text(
                                DateTimeHelper.lastTimeFmt(
                                  currentModel.lastTime,
                                ),
                                style: TextStyle(
                                  fontSize: 12.0,
                                  color: theme.textTheme.bodySmall?.color
                                      ?.withValues(alpha: 0.6),
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              );
                            }
                            return const SizedBox.shrink();
                          }),
                        ],
                      )),

                      const SizedBox(height: 6),

                      // Bottom Row: Message Preview
                      Flexible(child: Row(
                        children: [
                          Column(children: icon),
                          Expanded(
                            child: Obx(() {
                              ConversationModel? latestModel =
                              logic.conversationMap[model.uk3];
                              ConversationModel currentModel =
                                  latestModel ?? model;
                              String content = currentModel.content;

                              TextStyle contentStyle = TextStyle(
                                fontSize: 13.0,
                                color: theme.textTheme.bodyMedium?.color
                                    ?.withValues(alpha: 0.6),
                                height: 1.2,
                              );

                              // 处理草稿内容的红色显示
                              if (content.contains('_color_red_')) {
                                List<String> parts = content.split(
                                  '_color_red_',
                                );
                                return RichText(
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  text: TextSpan(
                                    children: [
                                      TextSpan(
                                        text: "${parts[0]} ",
                                        style: contentStyle.copyWith(
                                          color: AppColors.primaryGreen,
                                        ), // Use brand color instead of red
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
                            }),
                          ),
                          // Optional: Add muted icon here if needed
                        ],
                      )),
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
}
