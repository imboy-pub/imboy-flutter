import 'package:extended_text/extended_text.dart';
import 'package:flutter/material.dart';
import 'package:niku/namespace.dart' as n;
// ignore: depend_on_referenced_packages
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;
import 'package:get/get.dart';
import 'package:imboy/component/helper/datetime.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/config/init.dart';
import 'package:imboy/store/model/message_model.dart';

class RevokedMessageBuilder extends StatelessWidget {
  const RevokedMessageBuilder({
    Key? key,
    required this.user,
    required this.message,
  }) : super(key: key);

  final types.User user;
  final types.CustomMessage message;

  @override
  Widget build(BuildContext context) {
    bool userIsAuthor = user.id == message.author.id;

    String nickname = userIsAuthor ? '你' : '"${message.author.firstName}"';
    int now = DateTimeHelper.currentTimeMillis();
    bool canEdit = userIsAuthor && (now - message.createdAt!) < 300000;
    if (message.type != types.MessageType.text) {
      canEdit = false;
    }
    Widget btn = canEdit
        ? GestureDetector(
            onTap: () {
              eventBus.fire(
                ReEditMessage(text: message.metadata!['text']),
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
        // Get.back();
      },
      child: Container(
        width: Get.width,
        // height: Get.height,
        // Creates insets from offsets from the left, top, right, and bottom.
        padding: const EdgeInsets.all(12),
        alignment: Alignment.center,
        color: AppColors.ChatBg,
        child: n.Row([
            Padding(
              padding: userIsAuthor
                  ? const EdgeInsets.only(
                      right: 10,
                      left: 40,
                    )
                  : const EdgeInsets.only(left: 20),
              // padding: EdgeInsets.only(right: 10),
              child: ExtendedText(
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
            ),
            btn,
          ],
        )
          ..crossAxisAlignment = CrossAxisAlignment.center,
      ),
    );
  }
}
