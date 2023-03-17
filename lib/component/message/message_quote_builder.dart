import 'package:flutter/material.dart';
import 'package:flutter_chat_ui/flutter_chat_ui.dart';
import 'package:get/get.dart';
import 'package:imboy/component/message/message.dart';
import 'package:imboy/page/chat/chat_logic.dart';
import 'package:niku/namespace.dart' as n;

// ignore: depend_on_referenced_packages
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;
import 'package:imboy/component/helper/datetime.dart';
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
    Map<String, dynamic> quoteMsgMap = message.metadata?['quote_msg'] ?? {};
    types.Message quoteMsg = types.Message.fromJson(quoteMsgMap);

    // int now = DateTimeHelper.currentTimeMillis();
    String text = message.metadata?['quote_text'] ?? '';
    // 被引用消息背景色
    return n.Column([
      n.Row([
        n.Padding(
          top: 10,
          left: 10,
          bottom: 10,
          child: Text(
            text,
            style: const TextStyle(
              color: AppColors.MainTextColor,
              fontWeight: FontWeight.w400,
            ),
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ]),

      // 被引用消息
      Container(
        color: AppColors.AppBarColor,
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
                // quoteMsgBgColorOpacity = 0.2.obs;
                // // 延时1s执行返回
                // Future.delayed(const Duration(milliseconds: 3000), (){
                //   quoteMsgBgColorOpacity = 0.1.obs;
                // });
              },
              child: n.Row([
                Expanded(
                    child: Text(
                  message.metadata?['quote_msg_author_name'] ?? '',
                  style: const TextStyle(
                      // color: AppColors.MainTextColor,
                      // fontSize: 14.0,
                      ),
                  overflow: TextOverflow.ellipsis,
                )),
                Text(
                  DateTimeHelper.lastConversationFmt(
                    message.metadata?['quote_msg']['createdAt'] ?? 0,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.LabelTextColor,
                    fontSize: 14.0,
                  ),
                ),
                const Expanded(child: SizedBox(width: 10)),
                const Icon(Icons.vertical_align_top),
              ])
                ..mainAxisAlignment = MainAxisAlignment.end,
            ),
          ),
          n.Padding(
            bottom: 10,
            child: n.Row([messageMsgWidget(quoteMsg)])
              ..mainAxisAlignment = MainAxisAlignment.center,
          ),
        ]),
      ),
    ]);
  }
}
