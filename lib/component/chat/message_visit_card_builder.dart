import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart';

import 'package:imboy/component/ui/avatar.dart';
import 'package:imboy/modules/social_graph/public.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_radius.dart';

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
        Color bgColor;
        if (userIsAuthor) {
          // 发送方：使用发送消息背景色
          bgColor = isDark
              ? AppColors.darkSentMessageBackground
              : AppColors.lightSentMessageBackground;
        } else {
          // 接收方：使用与语音消息相同的背景色
          bgColor = isDark
              ? AppColors.darkSurfaceVariant // 暗色模式：深灰色
              : Colors.black12; // 亮色模式：浅灰色
        }

        return Container(
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: AppRadius.borderRadiusLarge,
          ),
          child: SizedBox(
            width: MediaQuery.of(context).size.width * 0.618,
            height: 105,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 3,
                    child: InkWell(
                      onTap: () {
                        final uid = msg.metadata?['uid'];
                        if (uid == null || uid.toString().isEmpty) return;
                        Navigator.push(
                          context,
                          CupertinoPageRoute(
                            builder: (context) => PeopleInfoPage(
                              id: uid,
                              scene: 'visitCard',
                            ),
                          ),
                        );
                      },
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 4, right: 4),
                            child: Avatar(imgUri: msg.metadata?['avatar']),
                          ),
                          Expanded(
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                msg.metadata?['title'] ??
                                    (msg.metadata?['account'] ?? ''),
                                textAlign: TextAlign.left,
                                // style: TextStyle(
                                //   color:
                                //       userIsAuthor ? Colors.black87 : textColor,
                                //   fontWeight: FontWeight.w500,
                                //   fontSize: 14.0,
                                // ),
                                maxLines: 4,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Divider(),
                  Expanded(
                    flex: 1,
                    child: Text(
                      t.personalCard,
                      // style: TextStyle(
                      //   fontSize: 12,
                      //   color: userIsAuthor ? Colors.black87 : textColor,
                      // ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
