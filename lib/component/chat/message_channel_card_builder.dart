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

        final channelId = parseModelString(msg.metadata?['channel_id']);
        final channelName = parseModelString(
          msg.metadata?['channel_name'] ?? msg.metadata?['content'],
        );
        final channelAvatar = parseModelString(msg.metadata?['channel_avatar']);

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
                InkWell(
                  onTap: () {
                    if (channelId.isEmpty) return;
                    context.push('/channel/$channelId');
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
      highlightColor: AppColors.shimmerHighlight,
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
