import 'package:flutter/material.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart';

import 'package:get/get.dart';
import 'package:imboy/component/ui/avatar.dart';
import 'package:imboy/page/contact/people_info/people_info_view.dart';

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
        return SizedBox(
          width: Get.width * 0.618,
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
                      Get.to(
                        () => PeopleInfoPage(
                          id: msg.metadata?['uid'],
                          scene: 'visit_card',
                        ),
                        transition: Transition.rightToLeft,
                        popGesture: true, // 右滑，返回上一页
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
        );
      },
    );
  }
}
