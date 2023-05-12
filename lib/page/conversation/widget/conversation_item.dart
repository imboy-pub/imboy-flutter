import 'package:badges/badges.dart' as badges;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:imboy/component/helper/datetime.dart';
import 'package:imboy/component/ui/avatar.dart';
import 'package:imboy/component/ui/common.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/store/model/conversation_model.dart';
import 'package:imboy/store/model/message_model.dart';
import 'package:niku/namespace.dart' as n;

// ignore: must_be_immutable
class ConversationItem extends StatelessWidget {
  final ConversationModel model;

  // 会话头像点击事件
  final Function()? onTapAvatar;

  // 当前会话未读消息数量
  RxInt remindCounter;

  ConversationItem({
    Key? key,
    required this.model,
    required this.onTapAvatar,
    required this.remindCounter,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    var icon = <Widget>[];
    if (model.lastMsgStatus == MessageStatus.sending) {
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
      padding: const EdgeInsets.only(left: 10.0, right: 10),
      color: Colors.white,
      child: n.Row(
        [
          Obx(
            () => badges.Badge(
              position: badges.BadgePosition.topEnd(top: -4, end: -4),
              showBadge: (remindCounter > 0 ? true : false),
              // shape: badges.BadgeShape.square,
              // borderRadius: BorderRadius.circular(10),
              // padding: const EdgeInsets.fromLTRB(5, 3, 5, 3),
              // animationDuration: const Duration(milliseconds: 500),
              // animationType: badges.BadgeAnimationType.scale,
              badgeContent: Text(
                remindCounter.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 8,
                ),
              ),
              // 会话头像
              child: Avatar(
                imgUri: model.avatar,
                onTap: onTapAvatar,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.only(right: 0, top: 10.0, bottom: 12.0),
            width: Get.width - 69,
            decoration: const BoxDecoration(
              border: Border(
                top: BorderSide(color: AppColors.LineColor, width: 0.2),
              ),
            ),
            child: n.Row([
              const Space(width: 6),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    n.Row([
                      Expanded(
                        child: Text(
                          // 会话对象标题
                          model.title,
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
                      child: n.Row(
                        [
                          n.Column(icon),
                          // 会话对象子标题
                          Expanded(
                            child: Text(
                              model.content,
                              style: const TextStyle(
                                color: AppColors.MainTextColor,
                                fontSize: 14.0,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // Space(width: mainSpace),
              n.Column(
                [
                  // 最近会话时间
                  Text(
                    DateTimeHelper.lastTimeFmt(model.lastTime),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.MainTextColor,
                      fontSize: 14.0,
                    ),
                  ),
                  const Icon(Icons.flag, color: Colors.transparent),
                ],
              )
            ]),
          )
        ],
      )..crossAxisAlignment = CrossAxisAlignment.center,
    );
  }
}
