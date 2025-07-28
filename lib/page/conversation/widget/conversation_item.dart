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

  // 会话头像点击事件
  final Function()? onTapAvatar;
  final ConversationLogic logic = Get.find<ConversationLogic>();

  ConversationItem({
    super.key,
    required this.model,
    required this.onTapAvatar,
  });

  @override
  Widget build(BuildContext context) {
    // 当前会话未读消息数量
    RxInt remindCounter = RxInt(logic.conversationRemind[model.uk3] ?? 0);
    var icon = <Widget>[];
    if (model.lastMsgStatus == IMBoyMessageStatus.sending) {
      icon.add(
        const Padding(
            padding: EdgeInsets.only(right: 4),
            child: Icon(
              IMBoyIcon.sending,
              color: Colors.grey,
              size: 15,
            )),
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
              style: const TextStyle(
                color: Colors.white,
                fontSize: 8,
              ),
            ),
            // 会话头像
            child: model.type == 'C2G' ? SmartGroupAvatar(
              avatar: model.avatar,
              groupId: model.peerId,
              onTap: onTapAvatar,
            ): Avatar(imgUri: model.avatar),
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
          decoration: const BoxDecoration(
            border: Border(
              bottom: BorderSide(
                // color: AppColors.LineColor,
                width: 0.25,
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
                    child: Text(
                      // 会话对象标题
                      model.title.trim().isEmpty
                          ? model.computeTitle
                          : model.title,
                      style: const TextStyle(
                        fontSize: 18.0,
                        fontWeight: FontWeight.normal,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ]),
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(
                    children: [
                    Column(
                      children: icon,
                    ),
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
                      child: Text(
                        model.content.contains('_color_red_')
                            ? model.content.split('_color_red_')[1]
                            : model.content,
                        style: const TextStyle(
                          // color: AppColors.MainTextColor,
                          fontSize: 14.0,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ]),
                ),
              ]
              ),
            ),
            // Space(width: mainSpace),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                // 最近会话时间
                if (model.lastTime > 0)
                  Text(
                    DateTimeHelper.lastTimeFmt(model.lastTime),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      // color: AppColors.MainTextColor,
                      fontSize: 14.0,
                    ),
                  ),
                const Icon(Icons.flag, color: Colors.transparent),
              ],
            )),
          ]),
        )
      ]),
    );
  }
}
