import 'package:cached_network_image/cached_network_image.dart';
import 'package:extended_text/extended_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;
import 'package:flutter_chat_ui/src/widgets/inherited_user.dart';
import 'package:get/get.dart';
import 'package:imboy/component/helper/datetime.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/config/init.dart';
import 'package:imboy/page/chat_video/chat_video_view.dart';
import 'package:imboy/store/model/message_model.dart';

/// A class that represents text message widget with optional link preview
class CustomMessage extends StatelessWidget {
  /// Creates a text message widget from a [types.TextMessage] class
  CustomMessage({
    Key? key,
    required this.message,
    required this.messageWidth,
  }) : super(key: key);

  /// [types.TextMessage]
  final types.CustomMessage message;

  /// Maximum message width
  final int messageWidth;

  Widget revokedMsg(bool currentUserIsAuthor, BuildContext ctx) {
    String nickname =
        currentUserIsAuthor ? '你' : '"${message.author.firstName}"';
    int now = DateTimeHelper.currentTimeMillis();
    bool canEdit =
        currentUserIsAuthor && (now - this.message.createdAt!) < 300000;
    // canEdit = true;
    Widget btn = canEdit
        ? GestureDetector(
            onTap: () {
              eventBus
                  .fire(ReeditMessage(text: this.message.metadata!['text']));
            },
            child: Text(
              '重新编辑',
              style: TextStyle(
                height: 1.5,
                color: Color.fromRGBO(107, 110, 153, 1),
                // backgroundColor: Colors.white,
              ),
            ),
          )
        : const SizedBox.shrink();
    return GestureDetector(
      onTap: () {
        // Get.back();
      },
      child: Container(
        width: Get.width,
        // height: Get.height,
        // Creates insets from offsets from the left, top, right, and bottom.
        padding: EdgeInsets.all(12),
        alignment: Alignment.center,
        color: AppColors.ChatBg,
        child: Row(
          children: [
            Padding(
              padding: currentUserIsAuthor
                  ? EdgeInsets.only(
                      right: 10,
                      left: 40,
                    )
                  : EdgeInsets.only(left: 80),
              // padding: EdgeInsets.only(right: 10),
              child: ExtendedText(
                '${nickname}撤回了一条消息',
                // '${nickname},: ${_user.firstName},is: ${currentUserIsAuthor.toString()}',
                style: TextStyle(
                  color: AppColors.MainTextColor,
                  backgroundColor: AppColors.ChatBg,
                  fontSize: 14.0,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
              ),
            ),
            btn,
          ],
        ),
      ),
    );
  }

  Widget videoMsg(BuildContext ctx) {
    return Container(
      constraints: BoxConstraints(maxHeight: Get.height * 0.46),
      child: InkWell(
        onTap: () {
          Get.to(ChatVideoPage(url: this.message.metadata!['video']['uri']));
        },
        child: Stack(
          alignment: Alignment.centerRight,
          children: <Widget>[
            CachedNetworkImage(
              imageUrl: this.message.metadata!['thumb']['uri'],
              progressIndicatorBuilder: (context, url, downloadProgress) =>
                  CircularProgressIndicator(value: downloadProgress.progress),
              errorWidget: (context, url, error) => Icon(Icons.error),
              //cancelToken: cancellationToken,
            ),
            Positioned.fill(
              child: SizedBox(
                height: 100,
                child: Center(
                  child: Icon(
                    Icons.video_library,
                    color: Colors.white,
                    size: 40,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final _user = InheritedUser.of(context).user;
    final _currentUserIsAuthor = _user.id == message.author.id;

    debugPrint(">>> on CustomMessage/build ${message.toJson().toString()}");
    if (message.metadata!['custom_type'] == 'revoked') {
      return revokedMsg(_currentUserIsAuthor, context);
    } else if (message.metadata!['custom_type'] == 'video') {
      return videoMsg(context);
    }
    return const SizedBox.shrink();
  }
}
