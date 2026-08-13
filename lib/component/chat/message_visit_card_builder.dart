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

class VisitCardMessageBuilder extends StatefulWidget {
  const VisitCardMessageBuilder({
    super.key,
    required this.user,
    this.message,
    this.info,
  });

  final User user;
  final CustomMessage? message;
  final Map<String, dynamic>? info;

  @override
  VisitCardMessageBuilderState createState() => VisitCardMessageBuilderState();
}

class VisitCardMessageBuilderState extends State<VisitCardMessageBuilder> {
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
        // 骨架与成品名片同宽（240）同高，原来用居中 spinner，尺寸对不上，
        // 加载完成时整条气泡会跳一下。
        if (snapshot.connectionState != ConnectionState.done) {
          return const _VisitCardSkeleton();
        }
        final msg = snapshot.data;
        if (msg == null) {
          return const _VisitCardSkeleton();
        }

        // 判断是否为发送方
        final bool userIsAuthor = widget.user.id == msg.authorId;
        final isDark = Theme.of(context).brightness == Brightness.dark;

        // 统一背景色走 AppColors getChatBubbleBackground，对齐 DESIGN.md 第 9/10 章
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
                    final uid = parseModelString(msg.metadata?['uid']);
                    if (uid.isEmpty) return;
                    // 统一走 GoRouter，对齐 /people_info/:id 路由（pathParameters 解析 id）
                    context.push('/people_info/$uid?scene=visitCard');
                  },
                  child: Row(
                    children: [
                      Avatar(
                        imgUri: parseModelString(msg.metadata?['avatar']),
                        width: 48,
                        height: 48,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          parseModelString(
                            msg.metadata?['title'] ?? msg.metadata?['account'],
                          ),
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
                  t.common.personalCard,
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

/// 名片骨架：与成品名片同尺寸（240 宽 + 头像行 + 分隔线 + 副标题）
class _VisitCardSkeleton extends StatelessWidget {
  const _VisitCardSkeleton();

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
