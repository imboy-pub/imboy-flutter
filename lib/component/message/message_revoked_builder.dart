import 'package:flutter/material.dart';

// ignore: depend_on_referenced_packages
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;
import 'package:get/get.dart';
import 'package:imboy/component/helper/datetime.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/config/init.dart';
import 'package:imboy/store/model/message_model.dart';
import 'package:niku/namespace.dart' as n;

class RevokedMessageBuilder extends StatelessWidget {
  const RevokedMessageBuilder({
    super.key,
    // 当前登录用户
    required this.user,
    required this.message,
  });

  final types.User user;
  final types.CustomMessage message;

  @override
  Widget build(BuildContext context) {
    bool userIsAuthor = user.id == message.author.id;

    String nickname = userIsAuthor ? '你' : '"${message.author.firstName}"';
    int now = DateTimeHelper.utc();
    bool canEdit = userIsAuthor && (now - message.createdAt!) < 300000;
    String text = message.metadata?['text'] ?? '';
    if (text.isEmpty) {
      canEdit = false;
    }
    debugPrint(
        "> on canEdit $canEdit; ${message.type} , userIsAuthor: $userIsAuthor, text: $text, msg: ${message.toJson().toString()}");
    Widget btn = canEdit
        ? GestureDetector(
            onTap: () {
              eventBus.fire(
                ReEditMessage(text: text),
              );
            },
            child: Text(
              '重新编辑'.tr,
              style: const TextStyle(
                height: 1.5,
                color: Color.fromRGBO(107, 110, 153, 1),
                // backgroundColor: Colors.white,
              ),
            ),
          )
        : const SizedBox.shrink();
    return GestureDetector(
      onTap: () {
      },
      child: Container(
        width: Get.width,
        // Creates insets from offsets from the left, top, right, and bottom.
        padding: const EdgeInsets.all(12),
        alignment: Alignment.center,
        color: AppColors.ChatBg,
        child: n.Row(
          [
            Expanded(
                child: Padding(
              padding: userIsAuthor
                  ? const EdgeInsets.only(
                      right: 10,
                      left: 0,
                    )
                  : const EdgeInsets.only(left: 50),
              // padding: EdgeInsets.only(right: 10),
              child: Text(
                nickname + '撤回了一条消息'.tr,
                style: const TextStyle(
                  color: AppColors.MainTextColor,
                  backgroundColor: AppColors.ChatBg,
                  fontSize: 14.0,
                ),
                maxLines: 2,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
              ),
            )),
            btn,
          ],
        )..crossAxisAlignment = CrossAxisAlignment.center,
      ),
    );
  }
}
