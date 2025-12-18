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

    // 如果引用消息数据为空，显示错误提示
    if (quoteMsgMap.isEmpty) {
      return _buildQuoteErrorWidget(context, userIsAuthor);
    }

    if (!quoteMsgMap.containsKey('authorId')) {
      quoteMsgMap['authorId'] = message.authorId;
    }

    late Message quoteMsg;
    try {
      quoteMsg = Message.fromJson(quoteMsgMap);
    } catch (e) {
      debugPrint("解析引用消息失败: $e");
      return _buildQuoteErrorWidget(context, userIsAuthor);
    }

    String text = message.metadata?['quote_text'] ?? '';

    //  左侧竖条，灰底，圆角，主内容和引用分开
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
                ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.15)
                : Theme.of(context).colorScheme.surface.withValues(alpha: 0.7),
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
                  color: Theme.of(
                    context,
                  ).colorScheme.primary.withValues(alpha: 0.8),
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
                        onTap: () async {
                          debugPrint("> on quoteMsg_onTap: ${quoteMsg.id}");
                          try {
                            ChatLogic logic = Get.find();

                            // 显示加载提示
                            // EasyLoading.showToast('正在定位消息...');

                            // 优化滚动体验：先尝试直接滚动，如果失败再加载历史消息
                            await logic.scrollToMessage(type, quoteMsg.id);

                            debugPrint("> quoteMsg scroll completed");
                          } catch (e) {
                            debugPrint("> quoteMsg scroll error: $e");
                            // EasyLoading.showError('定位消息失败');
                          }
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
                              // color: Theme.of(
                              //   context,
                              // ).colorScheme.onSurface.withValues(alpha: 0.6),
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
                              child: _buildQuoteMessageContent(quoteMsg),
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

  /// 构建引用消息错误提示组件
  Widget _buildQuoteErrorWidget(BuildContext context, bool userIsAuthor) {
    return Container(
      margin: const EdgeInsets.only(left: 10, right: 10, bottom: 8),
      decoration: BoxDecoration(
        color: userIsAuthor
            ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.15)
            : Theme.of(context).colorScheme.surface.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(8.0),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 左侧竖线
          Container(
            width: 4,
            height: 40,
            margin: const EdgeInsets.symmetric(vertical: 6),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.error.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // 错误提示内容
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 6,
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 16,
                    color: Theme.of(context).colorScheme.error.withValues(alpha: 0.8),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '引用的消息不可用',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error.withValues(alpha: 0.8),
                        fontSize: 12,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 构建引用消息内容显示组件
  Widget _buildQuoteMessageContent(Message quoteMsg) {
    if (quoteMsg is TextMessage) {
      return Text(
        quoteMsg.text,
        style: TextStyle(
          color: Theme.of(Get.context!).colorScheme.onSurface.withValues(alpha: 0.7),
          fontSize: 13,
        ),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      );
    } else if (quoteMsg is ImageMessage) {
      return Row(
        children: [
          Icon(
            Icons.image,
            size: 16,
            color: Theme.of(Get.context!).colorScheme.onSurface.withValues(alpha: 0.7),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              (quoteMsg.text != null) ? quoteMsg.text! : '图片',
              style: TextStyle(
                color: Theme.of(Get.context!).colorScheme.onSurface.withValues(alpha: 0.7),
                fontSize: 13,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      );
    } else if (quoteMsg is FileMessage) {
      return Row(
        children: [
          Icon(
            Icons.attach_file,
            size: 16,
            color: Theme.of(Get.context!).colorScheme.onSurface.withValues(alpha: 0.7),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              quoteMsg.name.isNotEmpty ? quoteMsg.name : '文件',
              style: TextStyle(
                color: Theme.of(Get.context!).colorScheme.onSurface.withValues(alpha: 0.7),
                fontSize: 13,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      );
    } else if (quoteMsg is CustomMessage) {
      String customType = quoteMsg.metadata?['custom_type'] ?? '';
      String displayText = '';
      IconData iconData = Icons.help_outline;

      switch (customType) {
        case 'voice':
        case 'audio':
          displayText = '语音消息';
          iconData = Icons.mic;
          break;
        case 'video':
          displayText = '视频消息';
          iconData = Icons.videocam;
          break;
        case 'location':
          displayText = quoteMsg.metadata?['title'] ?? '位置消息';
          iconData = Icons.location_on;
          break;
        case 'visit_card':
          displayText = quoteMsg.metadata?['title'] ?? '名片';
          iconData = Icons.person;
          break;
        case 'revoked':
          displayText = '消息已撤回';
          iconData = Icons.block;
          break;
        default:
          displayText = quoteMsg.metadata?['quote_text'] ?? '自定义消息';
          iconData = Icons.insert_drive_file;
      }

      return Row(
        children: [
          Icon(
            iconData,
            size: 16,
            color: Theme.of(Get.context!).colorScheme.onSurface.withValues(alpha: 0.7),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              displayText,
              style: TextStyle(
                color: Theme.of(Get.context!).colorScheme.onSurface.withValues(alpha: 0.7),
                fontSize: 13,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      );
    } else {
      return Text(
        '不支持的消息类型',
        style: TextStyle(
          color: Theme.of(Get.context!).colorScheme.onSurface.withValues(alpha: 0.7),
          fontSize: 13,
        ),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      );
    }
  }
}
