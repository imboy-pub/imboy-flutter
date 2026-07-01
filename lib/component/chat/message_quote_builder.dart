import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/plugins/contracts/message_type_plugin.dart';
import 'package:imboy/service/message_type_constants.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/font_types.dart';

/// 引用消息构建器 - iOS 17 Premium 风格重构
class QuoteMessageBuilder extends StatelessWidget {
  const QuoteMessageBuilder({
    super.key,
    required this.type,
    required this.user,
    required this.message,
    this.onQuoteTap,
  });

  final String type;
  final User user;
  final CustomMessage message;
  final void Function(String quoteMessageId)? onQuoteTap;

  @override
  Widget build(BuildContext context) {
    bool userIsAuthor = user.id == message.authorId;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    Map<String, dynamic> quoteMsgMap =
        message.metadata?['quote_msg'] as Map<String, dynamic>? ?? {};

    if (quoteMsgMap.isEmpty) {
      return _buildQuoteErrorWidget(context, userIsAuthor, isDark);
    }
    if (!quoteMsgMap.containsKey('authorId')) {
      quoteMsgMap['authorId'] = message.authorId;
    }

    late Message quoteMsg;
    try {
      quoteMsg = Message.fromJson(quoteMsgMap);
    } catch (e) {
      return _buildQuoteErrorWidget(context, userIsAuthor, isDark);
    }

    String text = message.metadata?['quote_text'] as String? ?? '';
    final bubbleColor = userIsAuthor
        ? Colors.white.withValues(alpha: 0.15)
        : (isDark
              ? Colors.white.withValues(alpha: 0.05)
              : Colors.black.withValues(alpha: 0.05));
    final textColor = userIsAuthor
        ? Colors.white
        : (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary);
    final barColor = userIsAuthor ? Colors.white70 : AppColors.primary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
          child: Text(
            text,
            style: context
                .textStyle(FontSizeType.medium, color: textColor)
                .copyWith(height: 1.3),
          ),
        ),
        GestureDetector(
          onTap: () => onQuoteTap?.call(quoteMsg.id),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: bubbleColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: IntrinsicHeight(
              child: Row(
                children: [
                  Container(
                    width: 3,
                    decoration: BoxDecoration(
                      color: barColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                (message.metadata?['quote_msg_author_name'] ??
                                        '')
                                    as String,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: context.textStyle(
                                  FontSizeType.small,
                                  color: barColor,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _formatQuoteTime(
                                message.metadata?['quote_msg']?['createdAt'],
                              ),
                              style: context.textStyle(
                                FontSizeType.tiny,
                                color: textColor.withValues(alpha: 0.5),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        _buildQuoteMessageContent(
                          context,
                          quoteMsg,
                          textColor.withValues(alpha: 0.8),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  String _formatQuoteTime(dynamic timestamp) {
    if (timestamp == null) return '';
    int t = timestamp is int
        ? timestamp
        : (int.tryParse(timestamp.toString()) ?? 0);
    if (t == 0) return '';
    return DateFormat(
      'MM-dd HH:mm',
    ).format(DateTime.fromMillisecondsSinceEpoch(t));
  }

  Widget _buildQuoteErrorWidget(
    BuildContext context,
    bool userIsAuthor,
    bool isDark,
  ) {
    final errorColor = AppColors.getIosRed(Theme.of(context).brightness);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: errorColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            CupertinoIcons.exclamationmark_circle,
            size: 16,
            color: errorColor,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              t.common.quoteMessageNotAvailable,
              style: context.textStyle(
                FontSizeType.small,
                color: errorColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuoteMessageContent(
    BuildContext context,
    Message quoteMsg,
    Color color,
  ) {
    TextStyle style = context
        .textStyle(FontSizeType.footnote, color: color)
        .copyWith(height: 1.2);
    if (quoteMsg is TextMessage) {
      return Text(
        quoteMsg.text,
        style: style,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      );
    }

    IconData icon = CupertinoIcons.doc;
    String label = t.chat.customMessage;

    if (quoteMsg is ImageMessage) {
      icon = CupertinoIcons.photo;
      label = t.chat.image;
    } else if (quoteMsg is FileMessage) {
      icon = CupertinoIcons.doc_text;
      label = quoteMsg.name;
    } else if (quoteMsg is CustomMessage) {
      String msgType = quoteMsg.metadata?['msg_type'] as String? ?? '';
      switch (msgType) {
        case 'voice':
          icon = CupertinoIcons.mic;
          label = t.chat.voiceMessage;
          break;
        case 'video':
          icon = CupertinoIcons.videocam;
          label = t.chat.videoMessage;
          break;
        case 'location':
          icon = CupertinoIcons.location;
          label =
              quoteMsg.metadata?['title'] as String? ??
              t.common.locationMessage;
          break;
        case 'visitCard':
          icon = CupertinoIcons.person_crop_circle;
          label = t.chat.card;
          break;
        case 'revoked':
          icon = CupertinoIcons.slash_circle;
          label = t.common.messageRevoked;
          break;
      }
    }
    return Row(
      children: [
        Icon(icon, size: 14, color: color.withValues(alpha: 0.7)),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            label,
            style: style,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class QuoteMessageTypePlugin implements MessageTypePlugin {
  const QuoteMessageTypePlugin();
  @override
  String get id => 'builtin:${MessageType.quote}';
  @override
  bool get isEnabled => true;
  @override
  MessagePluginSurface get surface => MessagePluginSurface.bubble;
  @override
  String get type => MessageType.quote;
  @override
  Widget build(MessageViewModel message, MessageRenderContext context) =>
      QuoteMessageBuilder(
        type: context.type,
        message: message,
        user: context.user,
      );
}
