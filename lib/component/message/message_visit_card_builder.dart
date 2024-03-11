import 'package:flutter/material.dart';
// ignore: depend_on_referenced_packages
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;
import 'package:get/get.dart';
import 'package:imboy/component/ui/avatar.dart';

import 'package:imboy/page/single/people_info.dart';
import 'package:niku/namespace.dart' as n;

class VisitCardMessageBuilder extends StatelessWidget {
  const VisitCardMessageBuilder({
    super.key,
    required this.user,
    required this.message,
  });

  final types.User user;
  final types.CustomMessage message;

  @override
  Widget build(BuildContext context) {
    bool userIsAuthor = user.id == message.author.id;

    return SizedBox(
      width: Get.width * 0.618,
      height: 96,
      child: n.Padding(
          left: 8,
          top: 8,
          bottom: 8,
          child: n.Column([
            Expanded(
              flex: 3,
              child: InkWell(
                onTap: () {
                  Get.to(
                    () => PeopleInfoPage(
                        id: message.metadata?['uid'], scene: 'visit_card'),
                    transition: Transition.rightToLeft,
                    popGesture: true, // 右滑，返回上一页
                  );
                },
                child: n.Row([
                  n.Padding(
                    top: 4,
                    right: 4,
                    child: Avatar(imgUri: message.metadata?['avatar']),
                  ),
                  Expanded(
                    child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          message.metadata?['title'],
                          // '大声道发生的发生的发生大发是打发大声道发生的发生的发生大发是打发大声道发生的发生的发生大发是打发大声道发生的发生的发生大发是打发大声道发生的发生的发生大发是打发大声道发生的发生的发生大发是打发大声道发生的发生的发生大发是打发大声道发生的发生的发生大发是打发',
                          textAlign: TextAlign.left,
                          style: TextStyle(
                            color: Get.isDarkMode
                                ? (userIsAuthor
                                    ? Colors.black87
                                    : Theme.of(context).colorScheme.onPrimary)
                                : Theme.of(context).colorScheme.onPrimary,
                            fontWeight: FontWeight.w500,
                            fontSize: 14.0,
                          ),
                          maxLines: 4,
                          overflow: TextOverflow.ellipsis,
                        )),
                  ),
                ])
                  // 内容文本左对齐
                  ..crossAxisAlignment = CrossAxisAlignment.start,
              ),
            ),
            const Divider(),
            Expanded(
              flex: 1,
              child: Text(
                'personal_card'.tr,
                style: TextStyle(
                  fontSize: 12,
                  color: Get.isDarkMode
                      ? (userIsAuthor
                          ? Colors.black87
                          : Theme.of(context).colorScheme.onPrimary)
                      : Theme.of(context).colorScheme.onPrimary,
                ),
              ),
            ),
          ])
            ..crossAxisAlignment = CrossAxisAlignment.start),
    );
  }
}
