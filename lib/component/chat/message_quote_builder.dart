import 'package:flutter/material.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:get/get.dart';

import 'package:imboy/page/chat/chat/chat_logic.dart';
import 'package:imboy/service/assets.dart';
import 'package:jiffy/jiffy.dart';

import 'package:imboy/component/image_gallery/image_gallery.dart';
import 'package:imboy/component/chat/message.dart';

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
  final User user;
  final CustomMessage message;

  RxDouble quoteMsgBgColorOpacity = 0.1.obs;

  @override
  Widget build(BuildContext context) {
    bool userIsAuthor = user.id == message.authorId;
    Map<String, dynamic> quoteMsgMap = message.metadata?['quote_msg'] ?? {};
    if (!quoteMsgMap.containsKey('authorId')) {
      quoteMsgMap['authorId'] = message.authorId;
    }
    Message quoteMsg = Message.fromJson(quoteMsgMap);

    // int now = DateTimeHelper.millisecond();
    String text = message.metadata?['quote_text'] ?? '';

    // 微信风格：左侧竖条，灰底，圆角，主内容和引用分开
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 当前消息的文字内容
        Padding(
          padding: const EdgeInsets.only(
            top: 10,
            left: 10,
            right: 10,
            bottom: 10,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(text, maxLines: 4, overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
        ),
        // 被引用消息区域
        Container(
          margin: const EdgeInsets.only(left: 10, right: 10, bottom: 8),
          decoration: BoxDecoration(
            color: userIsAuthor
                ? Colors.green.withValues(alpha: 0.15 * 255)
                : Theme.of(
                    context,
                  ).colorScheme.surface.withValues(alpha: 0.7 * 255),
            borderRadius: BorderRadius.circular(8.0),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 左侧竖线
              Container(
                width: 4,
                height: 56,
                margin: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.blueAccent.withValues(alpha: 0.8 * 255),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // 引用内容
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 6,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      InkWell(
                        onTap: () {
                          debugPrint("> on quoteMsg_onTap");
                          ChatLogic logic = Get.find();
                          logic.scrollToMessage(type, quoteMsg.id);
                        },
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Expanded(
                              flex: 2,
                              child: Text(
                                message.metadata?['quote_msg_author_name'] ??
                                    '',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                // style: TextStyle(
                                //   color: txtColor.withValues(alpha: 0.8 * 255),
                                //   fontWeight: FontWeight.w500,
                                //   fontSize: 13,
                                // ),
                              ),
                            ),
                            Expanded(
                              flex: 1,
                              child: Text(
                                _formatQuoteTime(
                                  message.metadata?['quote_msg']?['createdAt'],
                                ),
                                textAlign: TextAlign.right,
                              ),
                            ),
                            const Icon(
                              Icons.vertical_align_top,
                              size: 15,
                              color: Colors.grey,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 4),
                      InkWell(
                        onDoubleTap: () async {
                          if (quoteMsg is TextMessage) {
                            showTextMessage(quoteMsg.text);
                          } else if (quoteMsg is ImageMessage) {
                            final String uri = AssetsService.viewUrl(
                              quoteMsg.source,
                            ).toString();
                            zoomInPhotoView(uri);
                          } else if (quoteMsg is FileMessage) {
                            final String uri = AssetsService.viewUrl(
                              quoteMsg.source,
                            ).toString();
                            confirmOpenFile(uri);
                          } else if (quoteMsg is CustomMessage) {
                            String txt = quoteMsg.metadata?['quote_text'] ?? '';
                            if (txt.isNotEmpty) {
                              showTextMessage(txt);
                            }
                          }
                        },
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.start,
                          children: [
                            Flexible(
                              child: messageMsgWidget(
                                quoteMsg,
                                // txtColor: txtColor.withValues(alpha: 0.8 * 255),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatQuoteTime(dynamic timestamp) {
    if (timestamp == null) return '';
    int t = 0;
    if (timestamp is int) {
      t = timestamp;
    } else if (timestamp is String) {
      t = int.tryParse(timestamp) ?? 0;
    }
    if (t == 0) return '';
    return Jiffy.parseFromMillisecondsSinceEpoch(
      t + DateTime.now().timeZoneOffset.inMilliseconds,
    ).format(pattern: 'y-MM-dd\nHH:mm:ss');
  }
}
