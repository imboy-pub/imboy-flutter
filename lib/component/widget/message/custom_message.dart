import 'package:extended_text/extended_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;
import 'package:flutter_chat_ui/src/widgets/inherited_user.dart';
import 'package:get/get.dart';
import 'package:imboy/config/const.dart';

/// A class that represents text message widget with optional link preview
class CustomMessage extends StatelessWidget {
  /// Creates a text message widget from a [types.TextMessage] class
  CustomMessage({
    Key? key,
    required this.message,
    required this.messageWidth,
    this.showStatus = false,
  }) : super(key: key);

  /// [types.TextMessage]
  final types.CustomMessage message;

  /// Maximum message width
  final int messageWidth;

  /// Show message's status
  bool showStatus;

  Widget revokedMsg(BuildContext context) {
    final _user = InheritedUser.of(context).user;

    String nickname =
        _user.id == message.author.id ? '你' : '"${_user.firstName}"';

    this.showStatus = false;

    return GestureDetector(
      onTap: () {
        // Get.back();
      },
      child: Container(
        width: Get.width,
        // height: Get.height,
        // Creates insets from offsets from the left, top, right, and bottom.
        padding: EdgeInsets.all(16),
        alignment: Alignment.center,
        color: AppColors.ChatBg,
        child: ExtendedText(
          '${nickname}撤回了一条消息',
          style: TextStyle(
            color: AppColors.MainTextColor,
            backgroundColor: AppColors.ChatBg,
            fontSize: 14.0,
          ),
          textAlign: TextAlign.center,
          maxLines: 1,
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
      return revokedMsg(context);
    }
    return const SizedBox();
  }
}
