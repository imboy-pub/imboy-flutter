import 'package:flutter/material.dart';
import 'package:flutter_chat_ui/flutter_chat_ui.dart';
import 'package:get/get.dart';
import 'package:imboy/component/ui/image_view.dart';
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
  /// 构建被引用消息Widget
  Widget? quoteMsgWidget(types.Message quoteMsg) {
    Widget? quoteMsgWidget;
    if (quoteMsg is types.TextMessage) {
      quoteMsgWidget = Text(
        quoteMsg.text,
        style: const TextStyle(
          color: AppColors.MainTextColor,
          fontSize: 13.0,
        ),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      );
    } else if (quoteMsg is types.FileMessage) {
      quoteMsgWidget = n.Column([
        n.Row([
          Text(
            "[${'文件'.tr}] (${formatBytes(quoteMsg.size.truncate())})",
            style: const TextStyle(color: AppColors.thirdElementText),
          ),
          // ImageView(img: message?.metadata?['thumb']['uri'], height: 40,),
        ]),
        n.Row([
          Expanded(
            child: Text(
              quoteMsg.name,
              style: const TextStyle(color: AppColors.thirdElementText),
            ),
          ),
          // ImageView(img: message?.metadata?['thumb']['uri'], height: 40,),
        ])
      ]);
    } else if (quoteMsg is types.ImageMessage) {
      quoteMsgWidget = ImageView(
        img: quoteMsg.uri,
        height: 160,
      );
    }
    String customType = quoteMsg.metadata?['custom_type'] ?? '';
    if (customType == 'video') {
      quoteMsgWidget = n.Row([
        Text(
          "[${'视频'.tr}] ",
          style: const TextStyle(color: AppColors.thirdElementText),
        ),
        ImageView(
          img: quoteMsg.metadata?['thumb']['uri'],
          height: 40,
        ),
      ]);
    }
    return quoteMsgWidget;
  }

  @override
  Widget build(BuildContext context) {
    Map<String, dynamic> quoteMsgMap = message.metadata?['quote_msg'] ?? {};
    types.Message quoteMsg = types.Message.fromJson(quoteMsgMap);
    bool userIsAuthor = user.id == message.author.id;

    // int now = DateTimeHelper.currentTimeMillis();
    String text = message.metadata?['quote_text'] ?? '';
    // 被引用消息背景色
    Color quoteMsgBgColor =
        userIsAuthor ? Colors.green : AppColors.ChatReceivedMessageBodyBgColor;
    return GestureDetector(
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
        // quoteMsgBgColorOpacity = 0.2.obs;
        // // 延时1s执行返回
        // Future.delayed(const Duration(milliseconds: 3000), (){
        //   quoteMsgBgColorOpacity = 0.1.obs;
        // });

      },
      child: n.Column([
        // 被引用消息
        n.Row([
          Obx(() {
            return Container(
              margin: const EdgeInsets.only(left: 6, top: 6, right: 6, bottom: 6),
              padding: const EdgeInsets.all(8),
              //设置 child 居中
              alignment: const Alignment(0, 0),
              // height: 50,
              width: Get.width - 96,
              //边框设置
              decoration: BoxDecoration(
                //背景
                color: quoteMsgBgColor.withOpacity(quoteMsgBgColorOpacity.value),
                //设置四周圆角 角度
                borderRadius: const BorderRadius.all(Radius.circular(16.0)),
                //设置四周边框
                border: Border.all(width: 0.4, color: Colors.lightGreen),
              ),
              // color: ,
              child: n.Column([
                n.Row([
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
                      // color: AppColors.LabelTextColor,
                      fontSize: 14.0,
                    ),
                  ),
                  const Expanded(child: SizedBox(width: 10)),
                  const Icon(Icons.vertical_align_top),
                ])
                  ..mainAxisAlignment = MainAxisAlignment.end,
                n.Row([
                  Expanded(
                      child: quoteMsgWidget(quoteMsg) ?? const SizedBox.shrink())
                ]),
              ]),
            );
          })
        ]),
        n.Row([
          Padding(
            padding: const EdgeInsets.all(10),
            child: Text(
              text,
              style: const TextStyle(
                // color: AppColors.MainTextColor,
                fontSize: 14.0,
              ),
            ),
          ),
        ])
      ]),
    );
  }
}
