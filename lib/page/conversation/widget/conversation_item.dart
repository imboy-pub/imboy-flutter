import 'package:badges/badges.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:imboy/component/ui/avatar.dart';
import 'package:imboy/component/ui/common.dart';
import 'package:imboy/config/const.dart';
import 'package:niku/namespace.dart' as n;

import 'content_msg.dart';

// ignore: must_be_immutable
class ConversationItem extends StatelessWidget {
  // 会话头像
  final String? imgUri;
  // 会话头像点击事件
  final Function()? onTapAvatar;
  // 会话对象标题
  final String? title;
  // 会话简述
  final dynamic payload;
  // 最近会话时间
  final Widget? time;
  // 当前会话未读消息数量
  RxInt remindCounter;
  // 最近会话消息状态
  final int? status; // lastMsgStatus

  ConversationItem({
    Key? key,
    this.imgUri,
    this.onTapAvatar,
    this.title,
    this.payload,
    this.time,
    required this.remindCounter,
    this.status,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    var icon = <Widget>[];
    if (status == 10) {
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
    // debugPrint(">>> on imgUri ${imgUri!}");
    return Container(
      padding: const EdgeInsets.only(left: 10.0, right: 10),
      color: Colors.white,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Obx(
            () => Badge(
              position: BadgePosition.topEnd(top: -4, end: -4),
              showBadge: (remindCounter > 0 ? true : false),
              shape: BadgeShape.square,
              borderRadius: BorderRadius.circular(10),
              padding: const EdgeInsets.fromLTRB(5, 3, 5, 3),
              animationDuration: const Duration(milliseconds: 500),
              animationType: BadgeAnimationType.scale,
              badgeContent: Text(
                remindCounter.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 8,
                ),
              ),
              child: Avatar(
                imgUri: imgUri!,
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
                          title ?? '',
                          style: const TextStyle(
                            fontSize: 18.0,
                            fontWeight: FontWeight.normal,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ]),
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: n.Row(
                        [
                          n.Column(icon),
                          Expanded(child: ContentMsg(payload)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // Space(width: mainSpace),
              n.Column(
                [
                  time!,
                  const Icon(Icons.flag, color: Colors.transparent),
                ],
              )
            ]),
          )
        ],
      ),
    );
  }
}
