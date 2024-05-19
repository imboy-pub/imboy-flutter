import 'package:flutter/material.dart';
import 'package:get/get.dart';

// ignore: depend_on_referenced_packages
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;
import 'package:flutter_chat_ui/flutter_chat_ui.dart';
import 'package:imboy/page/chat/chat/chat_logic.dart';
import 'package:imboy/service/assets.dart';
import 'package:jiffy/jiffy.dart';
import 'package:niku/namespace.dart' as n;

import 'package:imboy/component/image_gallery/image_gallery.dart';
import 'package:imboy/component/message/message.dart';

// ignore: must_be_immutable
class QuoteMessageBuilder extends StatelessWidget {
  QuoteMessageBuilder({
    super.key,
    required this.type,
    // 当前登录用户
    required this.user,
    required this.message,
  });

  final String type; // C2C C2G
  final types.User user;
  final types.CustomMessage message;

  RxDouble quoteMsgBgColorOpacity = 0.1.obs;

  @override
  Widget build(BuildContext context) {
    bool userIsAuthor = user.id == message.author.id;
    Map<String, dynamic> quoteMsgMap = message.metadata?['quote_msg'] ?? {};
    types.Message quoteMsg = types.Message.fromJson(quoteMsgMap);

    // int now = DateTimeHelper.utc();
    String text = message.metadata?['quote_text'] ?? '';
    Color txtColor = userIsAuthor
        ? (Get.isDarkMode
            ? const Color.fromRGBO(40, 40, 40, 1)
            : const Color.fromRGBO(240, 240, 240, 1))
        : (Get.isDarkMode
            ? const Color.fromRGBO(240, 240, 240, 1)
            : const Color.fromRGBO(40, 40, 40, 1));
    return n.Column([
      n.Padding(
          top: 10,
          left: 10,
          bottom: 10,
          child: n.Row([
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  color: txtColor,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
              ),
            )
          ])),
      // const HorizontalLine(),
      // 被引用消息
      Container(
        margin: const EdgeInsets.only(left: 10),
        padding: const EdgeInsets.only(
          left: 8,
          right: 8,
          top: 4.0,
          bottom: 8.0,
        ),
        // color: Theme.of(context).colorScheme.surface,
        // 用ink圆角矩形
        decoration: BoxDecoration(
          // 背景
          color: userIsAuthor
              ? Colors.green.withOpacity(0.15)
              : Theme.of(context).colorScheme.surface.withOpacity(0.7),
          // 设置四周圆角 角度
          borderRadius: const BorderRadius.all(Radius.circular(8.0)),
          // 设置四周边框
          border: Border.all(
            width: 1,
            color: userIsAuthor
                ? Colors.green.withOpacity(0.15)
                : Theme.of(context).colorScheme.surface.withOpacity(0.7),
          ),
        ),
        child: n.Column([
          InkWell(
            onTap: () {
              debugPrint("> on quoteMsg_onTap");
              ChatLogic loigc = Get.find();
              int msgIdIndex = chatMessageAutoScrollIndexById[quoteMsg.id] ?? 0;
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
                  style: TextStyle(color: txtColor),
                ),
              ),
              Expanded(
                flex: 1,
                child: Text(
                  Jiffy.parseFromMillisecondsSinceEpoch(
                    message.metadata?['quote_msg']['createdAt'] +
                        DateTime.now().timeZoneOffset.inMilliseconds,
                  ).format(pattern: 'y-MM-dd\nHH:mm:ss'),
                  style: TextStyle(
                    color: txtColor,
                    fontSize: 11.0,
                  ),
                ),
              ),
              const Expanded(child: Icon(Icons.vertical_align_top)),
            ])
              ..mainAxisAlignment = MainAxisAlignment.end,
          ),
          InkWell(
            onDoubleTap: () async {
              if (quoteMsg is types.TextMessage) {
                showTextMessage(quoteMsg.text);
              } else if (quoteMsg is types.ImageMessage) {
                final String uri =
                    AssetsService.viewUrl(quoteMsg.uri).toString();
                zoomInPhotoView(uri);
              } else if (quoteMsg is types.FileMessage) {
                final String uri =
                    AssetsService.viewUrl(quoteMsg.uri).toString();
                confirmOpenFile(uri);
              } else if (quoteMsg is types.CustomMessage) {
                String txt = quoteMsg.metadata?['quote_text'] ?? '';
                if (txt.isNotEmpty) {
                  showTextMessage(txt);
                }
              }
            },
            child: n.Row([
              Flexible(
                child: messageMsgWidget(quoteMsg, txtColor: txtColor),
              ),
            ])
              // 内容
              ..mainAxisAlignment = MainAxisAlignment.start,
          ),
        ])
          // 内容文本左对齐
          ..crossAxisAlignment = CrossAxisAlignment.start,
      )
    ]);
  }
}
