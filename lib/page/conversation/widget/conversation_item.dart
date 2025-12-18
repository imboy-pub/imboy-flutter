import 'package:badges/badges.dart' as badges;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:imboy/component/ui/avatar.dart';
import 'package:imboy/component/ui/imboy_icon.dart';

import 'package:imboy/component/helper/datetime.dart';
import 'package:imboy/component/ui/common.dart';

import 'package:imboy/page/conversation/conversation_logic.dart';
import 'package:imboy/store/model/conversation_model.dart';
import 'package:imboy/store/model/message_model.dart';

// ignore: must_be_immutable
class ConversationItem extends StatelessWidget {
  final ConversationModel model;
  final RxInt? remindCounter;

  // 会话头像点击事件
  final Function()? onTapAvatar;
  final ConversationLogic logic = Get.find<ConversationLogic>();

  ConversationItem({super.key, required this.model, this.remindCounter, required this.onTapAvatar});

  @override
  Widget build(BuildContext context) {
    // 当前会话未读消息数量
    RxInt remindCounter = this.remindCounter ?? RxInt(logic.conversationRemind[model.uk3] ?? 0);
    var icon = <Widget>[];
    // 获取最新的会话数据以检查消息状态
    ConversationModel? latestModel = logic.conversationMap[model.uk3];
    ConversationModel currentModel = latestModel ?? model;
    
    if (currentModel.lastMsgStatus == IMBoyMessageStatus.sending) {
      icon.add(
        Padding(
          padding: const EdgeInsets.only(right: 4),
          child: Icon(
            IMBoyIcon.sending,
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.6),
            size: 15,
          ),
        ),
      );
    }
    // debugPrint("> on imgUri ${imgUri!}");
    return Container(
      padding: const EdgeInsets.only(left: 10.0, top: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Obx(
            () => badges.Badge(
              position: badges.BadgePosition.topEnd(top: -4, end: -4),
              showBadge: (remindCounter.value > 0 ? true : false),
              // shape: badges.BadgeShape.square,
              // borderRadius: BorderRadius.circular(10),
              // padding: const EdgeInsets.fromLTRB(5, 3, 5, 3),
              // animationDuration: const Duration(milliseconds: 500),
              // animationType: badges.BadgeAnimationType.scale,
              badgeContent: Text(
                "$remindCounter",
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onPrimary,
                  fontSize: 8,
                ),
              ),
              // 会话头像
              child: model.type == 'C2G'
                  ? SmartGroupAvatar(
                      avatar: model.avatar,
                      groupId: model.peerId,
                      onTap: onTapAvatar,
                    )
                  : Avatar(imgUri: model.avatar),
            ),
          ),
          Container(
            margin: const EdgeInsets.only(left: 8),
            padding: const EdgeInsets.only(
              left: 0,
              right: 0,
              top: 10.0,
              bottom: 10,
            ),
            width: Get.width - 78,
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  // color: AppColors.LineColor,
                  width: 0.25,
                  color: Theme.of(
                    context,
                  ).colorScheme.outline.withValues(alpha: 0.2),
                ),
              ),
            ),
            child: Row(
              children: [
                const Space(width: 6),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Obx(() {
                              // 获取最新的会话数据
                              ConversationModel? latestModel = logic.conversationMap[model.uk3];
                              ConversationModel currentModel = latestModel ?? model;
                              String displayTitle = '';
                              
                              if (currentModel.title.trim().isNotEmpty) {
                                displayTitle = currentModel.title;
                              } else if (currentModel.computeTitle.trim().isNotEmpty) {
                                displayTitle = currentModel.computeTitle;
                              } else {
                                displayTitle = currentModel.peerId;
                              }
                              
                              return Text(
                                displayTitle,
                                style: const TextStyle(
                                  fontSize: 18.0,
                                  fontWeight: FontWeight.normal,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              );
                            }),
                          ),
                        ],
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Row(
                          children: [
                            Column(children: icon),
                            if (model.content.contains('_color_red_'))
                              Text(
                                "${model.content.split('_color_red_')[0]} ",
                                style: const TextStyle(
                                  color: Colors.red,
                                  fontSize: 14.0,
                                ),
                              ),
                            // 会话对象子标题
                            Expanded(
                              child: Obx(() {
                                // 获取最新的会话数据
                                ConversationModel? latestModel = logic.conversationMap[model.uk3];
                                ConversationModel currentModel = latestModel ?? model;
                                String content = currentModel.content;
                                
                                // 处理草稿内容的红色显示
                                if (content.contains('_color_red_')) {
                                  List<String> parts = content.split('_color_red_');
                                  return RichText(
                                    text: TextSpan(
                                      children: [
                                        TextSpan(
                                          text: "${parts[0]} ",
                                          style: const TextStyle(
                                            color: Colors.red,
                                            fontSize: 14.0,
                                          ),
                                        ),
                                        TextSpan(
                                          text: parts.length > 1 ? parts[1] : '',
                                          style: const TextStyle(
                                            fontSize: 14.0,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }
                                
                                return Text(
                                  content,
                                  style: const TextStyle(
                                    fontSize: 14.0,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                );
                              }),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                // Space(width: mainSpace),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      // 最近会话时间
                      Obx(() {
                        // 获取最新的会话数据
                        ConversationModel? latestModel = logic.conversationMap[model.uk3];
                        ConversationModel currentModel = latestModel ?? model;
                        
                        if (currentModel.lastTime > 0) {
                          return Text(
                            DateTimeHelper.lastTimeFmt(currentModel.lastTime),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.right,
                            style: const TextStyle(
                              fontSize: 14.0,
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      }),
                      const Icon(Icons.flag, color: Colors.transparent),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
