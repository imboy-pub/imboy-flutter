import 'package:flutter/material.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:get/get.dart';
import 'package:imboy/component/helper/datetime.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/config/init.dart';
import 'package:imboy/store/model/contact_model.dart';
import 'package:imboy/store/model/message_model.dart';
import 'package:imboy/store/repository/contact_repo_sqlite.dart';
import 'package:niku/namespace.dart' as n;

class RevokedMessageBuilder extends StatelessWidget {
  const RevokedMessageBuilder({
    super.key,
    required this.user,
    required this.message,
  });

  final User user;
  final CustomMessage message;

  @override
  Widget build(BuildContext context) {
    final bool userIsAuthor = user.id == message.authorId;
    final String text = message.metadata?['text'] ?? '';
    final DateTime now = DateTimeHelper.now();
    bool canEdit = userIsAuthor &&
        (now.difference(message.createdAt!).inMilliseconds < 7200000);

    if (text.isEmpty) {
      canEdit = false;
    }

    Widget btn = canEdit
        ? GestureDetector(
      onTap: () {
        iPrint("on canEdit onTap text: $text");
        eventBus.fire(
          ReEditMessage(text: text),
        );
      },
      child: Text(
        're_edit'.tr,
        style: TextStyle(
          height: 1.5,
          color: Theme.of(context).colorScheme.onPrimary,
        ),
      ),
    )
        : const SizedBox.shrink();

    return FutureBuilder<ContactModel?>(
      future: userIsAuthor
          ? Future.value(null)
          : ContactRepo().findByUid(message.authorId),
      builder: (context, snapshot) {
        String authorName = '';
        if (!userIsAuthor) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            authorName = '...';
          } else {
            authorName = snapshot.data?.nickname ?? '';
          }
        }
        String nickname = userIsAuthor ? 'you'.tr : '"$authorName"';

        return GestureDetector(
          onTap: () {},
          child: Container(
            width: Get.width,
            padding: const EdgeInsets.all(12),
            alignment: Alignment.center,
            child: n.Row([
              Expanded(
                child: Padding(
                  padding: userIsAuthor
                      ? const EdgeInsets.only(right: 10, left: 0)
                      : const EdgeInsets.only(left: 50),
                  child: Text(
                    "$nickname ${'message_was_withdrawn'.tr}",
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onPrimary,
                      fontSize: 14.0,
                    ),
                    maxLines: 2,
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              btn,
            ])
              ..crossAxisAlignment = CrossAxisAlignment.center,
          ),
        );
      },
    );
  }
}