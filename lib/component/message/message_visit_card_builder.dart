import 'package:bubble/bubble.dart';
import 'package:flutter/material.dart';

// ignore: depend_on_referenced_packages
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;
import 'package:get/get.dart';
import 'package:imboy/component/ui/avatar.dart';
import 'package:imboy/page/single/people_info.dart';
import 'package:niku/namespace.dart' as n;
import 'package:imboy/config/const.dart';

class VisitCardMessageBuilder extends StatelessWidget {
  const VisitCardMessageBuilder({
    Key? key,
    required this.user,
    required this.message,
  }) : super(key: key);

  final types.User user;
  final types.CustomMessage message;

  @override
  Widget build(BuildContext context) {
    bool userIsAuthor = user.id == message.author.id;

    return Bubble(
      // color: userIsAuthor
      //     ? AppColors.ChatSendMessageBgColor
      //     : AppColors.ChatReceivedMessageBodyBgColor,
      color: AppColors.ChatReceivedMessageBodyBgColor,
      nip:  userIsAuthor ? BubbleNip.rightBottom : BubbleNip.leftBottom,
      // style: const BubbleStyle(nipWidth: 16),
      nipRadius: 4,
      alignment: userIsAuthor ? Alignment.centerRight : Alignment.centerLeft,
      child: SizedBox(
        width: Get.width * 0.618,
        height: 96,
        child: n.Column(
          [
            Expanded(
              flex: 3,
              child: InkWell(
                onTap: () {
                  Get.to(()=>
                    PeopleInfoPage(
                        id: message.metadata?['uid'], scene: 'visit_card'),
                    transition: Transition.rightToLeft,
                    popGesture: true, // 右滑，返回上一页
                  );
                },
                child: n.Row(
                  [
                    n.Padding(
                      top: 4,
                      right: 4,
                      child: Avatar(imgUri: message.metadata?['avatar']),
                    ),
                    Expanded(
                      child: Align(
                          alignment: Alignment.center,
                          child: Text(
                            message.metadata?['title'],
                            // '大声道发生的发生的发生大发是打发大声道发生的发生的发生大发是打发大声道发生的发生的发生大发是打发大声道发生的发生的发生大发是打发大声道发生的发生的发生大发是打发大声道发生的发生的发生大发是打发大声道发生的发生的发生大发是打发大声道发生的发生的发生大发是打发',
                            textAlign: TextAlign.left,
                            style: const TextStyle(
                              color: AppColors.MainTextColor,
                              fontWeight: FontWeight.w500,
                              fontSize: 14.0,
                            ),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          )),
                    ),
                  ],
                  // 内容文本左对齐
                  crossAxisAlignment: CrossAxisAlignment.start,
                ),
              ),
            ),
            const Divider(),
            Expanded(
              flex: 1,
              child: Text(
                '个人名片'.tr,
                style: const TextStyle(color: AppColors.TipColor, fontSize: 12),
              ),
            ),
          ],
          // mainAxisSize: MainAxisSize.min,
          // mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
        ),
      ),
    );
  }
}
