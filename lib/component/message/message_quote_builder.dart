import 'package:bubble/bubble.dart';
import 'package:flutter/material.dart';
import 'package:flutter_chat_ui/flutter_chat_ui.dart';
import 'package:get/get.dart';
import 'package:imboy/component/image_gallery/image_gallery.dart';
import 'package:imboy/component/message/message.dart';
import 'package:imboy/page/chat/chat_logic.dart';
import 'package:jiffy/jiffy.dart';
import 'package:niku/namespace.dart' as n;

// ignore: depend_on_referenced_packages
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;
import 'package:imboy/config/const.dart';

// ignore: must_be_immutable
class QuoteMessageBuilder extends StatelessWidget {
  QuoteMessageBuilder({
    Key? key,
    // 当前登录用户
    required this.user,
    required this.message,
  }) : super(key: key);

  final types.User user;
  final types.CustomMessage message;

  RxDouble quoteMsgBgColorOpacity = 0.1.obs;

  @override
  Widget build(BuildContext context) {
    bool userIsAuthor = user.id == message.author.id;
    Map<String, dynamic> quoteMsgMap = message.metadata?['quote_msg'] ?? {};
    types.Message quoteMsg = types.Message.fromJson(quoteMsgMap);

    // int now = DateTimeHelper.currentTimeMillis();
    String text = message.metadata?['quote_text'] ?? '';
    return n.Column([
      n.Row([
        Bubble(
          color: AppColors.ChatSendMessageBgColor,
          nip: userIsAuthor ? BubbleNip.rightBottom : BubbleNip.leftBottom,
          nipRadius: 4,
          style: const BubbleStyle(nipWidth: 16),
          margin: const BubbleEdges.only(top: 16, bottom: 0),
          padding: const BubbleEdges.only(top: 8, bottom: 8),
          child: Text(
            text,
            style: const TextStyle(
              color: AppColors.MainTextColor,
              fontSize: 15,
              fontWeight: FontWeight.w400,
            ),
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ])
        ..mainAxisAlignment =
            userIsAuthor ? MainAxisAlignment.end : MainAxisAlignment.start,

      // 被引用消息
      Bubble(
        color: AppColors.AppBarColor,
        margin: const BubbleEdges.only(top: 4),
        padding: const BubbleEdges.only(bottom: 10),
        child: n.Column([
          n.Padding(
            left: 10,
            top: 10,
            bottom: 10,
            child: InkWell(
              onTap: () {
                debugPrint("> on quoteMsg_onTap");
                ChatLogic loigc = Get.find();
                int msgIdIndex =
                    chatMessageAutoScrollIndexById[quoteMsg.id] ?? 0;
                if (msgIdIndex > 0) {
                  loigc.state.scrollController.scrollToIndex(
                    msgIdIndex,
                    duration: const Duration(milliseconds: 250),
                  );
                } else {
                  // 数据不存在，有可能是没有从数据库加载，待优化之 TODO leeyi 2023-01-28 00:01:18
                }
              },
              child: n.Row([
                Expanded(
                  flex: 2,
                  child: Text(
                    message.metadata?['quote_msg_author_name'] ?? '',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: Text(
                    Jiffy.parseFromMillisecondsSinceEpoch(
                      message.metadata?['quote_msg']['createdAt'],
                    ).format(pattern: 'y-MM-dd\nHH:mm:ss'),
                    style: const TextStyle(
                      color: AppColors.LabelTextColor,
                      fontSize: 11.0,
                    ),
                  ),
                ),
                const Expanded(child: Icon(Icons.vertical_align_top)),
              ])
                ..mainAxisAlignment = MainAxisAlignment.end,
            ),
          ),
          InkWell(
            onDoubleTap: () async {
              if (quoteMsg is types.TextMessage) {
                showTextMessage(quoteMsg.text);
              } else if (quoteMsg is types.ImageMessage) {
                String thumb = quoteMsg.uri;
                zoomInPhotoView(thumb);
              } else if (quoteMsg is types.FileMessage) {
                confirmOpenFile(quoteMsg.uri);
              } else if (quoteMsg is types.CustomMessage) {
                String txt = quoteMsg.metadata?['quote_text'] ?? '';
                if (txt.isNotEmpty) {
                  showTextMessage(txt);
                }
              }
            },
            child: n.Row([
              SizedBox(
                width: Get.width * 0.618,
                child: messageMsgWidget(quoteMsg),
              ),
            ])
              // 内容居中
              ..mainAxisAlignment = MainAxisAlignment.center,
          ),
        ]),
      ),
      const SizedBox(
        height: 16,
      ),
    ]);
  }
}
