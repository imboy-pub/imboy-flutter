import 'package:badges/badges.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:imboy/component/ui/avatar.dart';
import 'package:imboy/component/ui/common.dart';
import 'package:imboy/config/const.dart';

import 'content_msg.dart';

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
    this.imgUri,
    this.onTapAvatar,
    this.title,
    this.payload,
    this.time,
    required this.remindCounter,
    this.status,
  });

  @override
  Widget build(BuildContext context) {
    var icon = <Widget>[];
    if (this.status == 10) {
      icon.add(
        Padding(
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
    // debugPrint(">>> on this.imgUri ${this.imgUri!}");
    return Container(
      padding: EdgeInsets.only(left: 10.0, right: 10),
      color: Colors.white,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Obx(
            () => Badge(
              position: BadgePosition.topEnd(top: -4, end: -4),
              showBadge: (this.remindCounter > 0 ? true : false),
              shape: BadgeShape.square,
              borderRadius: BorderRadius.circular(10),
              padding: EdgeInsets.fromLTRB(5, 3, 5, 3),
              animationDuration: Duration(milliseconds: 500),
              animationType: BadgeAnimationType.scale,
              badgeContent: Text(
                this.remindCounter.toString(),
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 8,
                ),
              ),
              child: Avatar(
                imgUri: this.imgUri!,
                onTap: this.onTapAvatar ?? null,
              ),
            ),
          ),
          Container(
            padding: EdgeInsets.only(right: 0, top: 10.0, bottom: 12.0),
            width: Get.width - 69,
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: AppColors.LineColor, width: 0.2),
              ),
            ),
            child: Row(
              children: <Widget>[
                Space(width: 6),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: [
                          Text(
                            this.title ?? '',
                            style: TextStyle(
                              fontSize: 18.0,
                              fontWeight: FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                      Padding(
                        padding: EdgeInsets.only(top: 4),
                        child: Row(
                          children: [
                            Column(
                              children: icon,
                            ),
                            Expanded(child: ContentMsg(this.payload)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                // Space(width: mainSpace),
                Column(
                  children: [
                    this.time!,
                    Icon(Icons.flag, color: Colors.transparent),
                  ],
                )
              ],
            ),
          )
        ],
      ),
    );
  }
}
