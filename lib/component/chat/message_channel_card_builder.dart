import 'package:flutter/material.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:imboy/store/model/model_parse_utils.dart';

import 'package:go_router/go_router.dart';
import 'package:imboy/component/ui/avatar.dart';
import 'package:imboy/component/ui/shimmer_box.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_spacing.dart';
import 'package:imboy/theme/default/font_types.dart';
import 'package:imboy/component/chat/message_spacing.dart';

import 'package:imboy/store/model/message_model.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/modules/messaging/infrastructure/message_model_mapper.dart';

class ChannelCardMessageBuilder extends StatefulWidget {
  const ChannelCardMessageBuilder({
    super.key,
    required this.user,
    this.message,
    this.info,
  });

  final User user;
  final CustomMessage? message;
  final Map<String, dynamic>? info;

  @override
  ChannelCardMessageBuilderState createState() =>
      ChannelCardMessageBuilderState();
}

/// 把 metadata 摊平：业务字段优先取顶层，缺失时回落到嵌套的 `payload`。
///
/// 历史（≤2026-10-30）频道卡片是通过 `/chat/send_to` 的 `extra['msg']`
/// 发出的，业务字段被包在 `payload` 里再落库（`buildForwardPayload` 原样
/// 展开），而卡片渲染器只读顶层 —— 于是卡片点不动（`channel_id` 为空时
/// 直接 return）。新发送已改为扁平形状（见 channel_share_payload.dart），
/// 这里保留嵌套兜底，让**已发出的历史消息**同样可点可跳。
Map<String, dynamic> _flatten(Map<String, dynamic>? metadata) {
  if (metadata == null) return const <String, dynamic>{};
  final nested = metadata['payload'];
  if (nested is! Map) return metadata;
  return <String, dynamic>{...Map<String, dynamic>.from(nested), ...metadata};
}

class ChannelCardMessageBuilderState extends State<ChannelCardMessageBuilder> {
  late Future<CustomMessage?> messageFuture;

  @override
  void initState() {
    super.initState();
    messageFuture = _getMessage();
  }

  Future<CustomMessage?> _getMessage() async {
    if (widget.message != null) {
      return widget.message;
    }
    if (widget.info != null) {
      return await MessageModel.fromJson(widget.info!).toTypeMessage()
          as CustomMessage;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<CustomMessage?>(
      future: messageFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const _ChannelCardSkeleton();
        }
        final msg = snapshot.data;
        if (msg == null) {
          return const _ChannelCardSkeleton();
        }

        final bool userIsAuthor = widget.user.id == msg.authorId;
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final meta = _flatten(msg.metadata);

        final Color bgColor = AppColors.getChatBubbleBackground(
          userIsAuthor,
          false,
          Theme.of(context).brightness,
        );

        Color textColor, subTextColor;
        if (userIsAuthor) {
          textColor = AppColors.sentMessageText;
          subTextColor = AppColors.overlayWhite70;
        } else {
          textColor = isDark
              ? AppColors.darkTextPrimary
              : AppColors.lightTextPrimary;
          subTextColor = isDark
              ? AppColors.darkTextSecondary
              : AppColors.lightTextSecondary;
        }

        final channelId = parseModelString(meta['channel_id']);
        final channelName = parseModelString(
          meta['channel_name'] ?? meta['content'],
        );
        final channelAvatar = parseModelString(meta['channel_avatar']);

        return Container(
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: MessageSpacing.getBubbleBorderRadius(userIsAuthor),
            border: !userIsAuthor && !isDark
                ? Border.all(color: AppColors.iosGray5, width: 0.5)
                : null,
          ),
          child: Container(
            width: 240,
            padding: const EdgeInsets.all(AppSpacing.medium),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: () {
                    if (channelId.isEmpty) return;
                    final messageId = meta['message_id']?.toString();
                    final article =
                        messageId != null &&
                        RegExp(r'^[1-9][0-9]*$').hasMatch(messageId);
                    context.push(
                      article
                          ? '/channel/$channelId/article/$messageId'
                          : '/channel/$channelId',
                    );
                  },
                  child: Row(
                    children: [
                      Avatar(imgUri: channelAvatar, width: 48, height: 48),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          channelName,
                          style: context.textStyle(
                            FontSizeType.medium,
                            color: textColor,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: AppSpacing.small,
                  ),
                  child: Divider(
                    height: 1,
                    color: subTextColor.withValues(alpha: 0.2),
                  ),
                ),
                Text(
                  t.channel.title,
                  style: context.textStyle(
                    FontSizeType.small,
                    color: subTextColor,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ChannelCardSkeleton extends StatelessWidget {
  const _ChannelCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return ShimmerBox(
      baseColor: AppColors.shimmerBase,
      child: Container(
        width: 240,
        height: 116,
        decoration: BoxDecoration(
          color: AppColors.shimmerBase,
          borderRadius: MessageSpacing.getBubbleBorderRadius(false),
        ),
      ),
    );
  }
}
