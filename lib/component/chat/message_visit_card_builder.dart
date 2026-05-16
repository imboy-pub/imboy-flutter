import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart';

import 'package:imboy/component/ui/avatar.dart';
import 'package:imboy/modules/social_graph/public.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_radius.dart';
import 'package:imboy/component/chat/message_spacing.dart';

import 'package:imboy/store/model/message_model.dart';
import 'package:imboy/i18n/strings.g.dart';

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
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        final msg = snapshot.data;
        if (msg == null) {
          return Container(); // 或者一些错误提示
        }

        // 判断是否为发送方
        final bool userIsAuthor = widget.user.id == msg.authorId;
        final isDark = Theme.of(context).brightness == Brightness.dark;

        // 使用与语音消息相同的背景色
        Color bgColor, textColor, subTextColor;
        if (userIsAuthor) {
          bgColor = isDark
              ? AppColors.darkSentMessageBackground
              : AppColors.lightSentMessageBackground;
          textColor = Colors.white;
          subTextColor = Colors.white70;
        } else {
          bgColor = isDark
              ? AppColors.darkReceivedMessageBackground
              : AppColors.lightSurfaceContainer;
          textColor = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
          subTextColor = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
        }

        return Container(
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(MessageSpacing.bubbleBorderRadius),
          ),
          child: Container(
            width: 240,
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InkWell(
                  onTap: () {
                    final uid = msg.metadata?['uid'];
                    if (uid == null || uid.toString().isEmpty) return;
                    Navigator.push(
                      context,
                      CupertinoPageRoute<dynamic>(
                        builder: (context) => PeopleInfoPage(
                          id: uid as String,
                          scene: 'visitCard',
                        ),
                      ),
                    );
                  },
                  child: Row(
                    children: [
                      Avatar(
                        imgUri: (msg.metadata?['avatar'] ?? '') as String,
                        width: 48,
                        height: 48,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          (msg.metadata?['title'] ??
                                  (msg.metadata?['account'] ?? ''))
                              as String,
                          style: TextStyle(
                            color: textColor,
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Divider(
                    height: 1,
                    color: subTextColor.withValues(alpha: 0.2),
                  ),
                ),
                Text(
                  t.common.personalCard,
                  style: TextStyle(
                    fontSize: 12,
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
