import 'package:badges/badges.dart' as badges;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:niku/namespace.dart' as n;

import 'package:imboy/component/helper/datetime.dart';
import 'package:imboy/component/ui/avatar.dart';
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
    RxInt remindCounter = logic.conversationRemind[model.uk3] ?? 0.obs;
    var icon = <Widget>[];
    if (model.lastMsgStatus == IMBoyMessageStatus.sending) {
      icon.add(
        const Padding(
          padding: EdgeInsets.only(right: 4),
          child: Image(
            image: AssetImage('assets/images/conversation/sending.png'),
            width: 15,
            height: 14,
            fit: BoxFit.fill,
          ),
        ),
      );
    }
    // debugPrint("> on imgUri ${imgUri!}");
    return Container(
      padding: const EdgeInsets.only(left: 10.0, top: 2),
      child: n.Row([
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
            child: ComputeAvatar(
              imgUri: model.avatar,
              computeAvatar: model.computeAvatar,
              onTap: onTapAvatar,
            ),
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
          child: n.Row([
            const Space(width: 6),
            Expanded(
              child: n.Column([
                n.Row([
                  Expanded(
                    child: Text(
                      // 会话对象标题
                      model.title.trim().isEmpty ? model.computeTitle : model.title,
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
                  child: n.Row([
                    n.Column(icon),
                    // 会话对象子标题
                    Expanded(
                      child: Text(
                        model.content,
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
              ])
                ..crossAxisAlignment = CrossAxisAlignment.start,
            ),
            // Space(width: mainSpace),
            n.Column([
              // 最近会话时间
              if (model.lastTime > 0)
                Text(
                  DateTimeHelper.lastTimeFmt(model.lastTimeLocal),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    // color: AppColors.MainTextColor,
                    fontSize: 14.0,
                  ),
                ),
              const Icon(Icons.flag, color: Colors.transparent),
            ])
          ]),
        )
      ])
        ..crossAxisAlignment = CrossAxisAlignment.center,
    );
  }
}
