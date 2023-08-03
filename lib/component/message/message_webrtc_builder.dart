import 'package:bubble/bubble.dart';
import 'package:flutter/material.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
// ignore: depend_on_referenced_packages
import 'package:intl/intl.dart' show DateFormat;
// ignore: depend_on_referenced_packages
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;
import 'package:niku/namespace.dart' as n;
import 'package:get/get.dart';

import 'package:imboy/component/webrtc/func.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/store/model/contact_model.dart';
import 'package:imboy/store/model/user_model.dart';
import 'package:imboy/store/repository/contact_repo_sqlite.dart';

class WebRTCMessageBuilder extends StatelessWidget {
  const WebRTCMessageBuilder({
    Key? key,
    required this.user,
    required this.message,
  }) : super(key: key);

  final types.User user;
  final types.CustomMessage message;

  Widget _buildBody(String customType, String title, bool userIsAuthor) {
    Widget row;
    if (userIsAuthor) {
      row = n.Row([
        n.Padding(
          top: 2,
          right: 4,
          child: Text(
            // '通话时长 10:48'.tr,
            title,
            textAlign: TextAlign.left,
            style: const TextStyle(
              color: AppColors.primaryText,
              fontSize: 15.0,
            ),
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        customType == 'webrtc_video'
            ? const Icon(Icons.video_camera_back_outlined)
            : const Icon(Icons.phone),
      ])
        ..mainAxisSize = MainAxisSize.min
        // 内容文本左对齐
        ..crossAxisAlignment = CrossAxisAlignment.start
        ..mainAxisAlignment = MainAxisAlignment.start;
    } else {
      row = n.Row([
        customType == 'webrtc_video'
            ? const Icon(Icons.video_camera_back_outlined)
            : const Icon(Icons.phone),
        n.Padding(
          top: 2,
          left: 4,
          child: Text(
            // '通话时长 10:48'.tr,
            title,
            textAlign: TextAlign.left,
            style: const TextStyle(
              color: AppColors.primaryText,
              fontSize: 15.0,
            ),
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ])
        ..mainAxisSize = MainAxisSize.min
        // 内容文本左对齐
        ..crossAxisAlignment = CrossAxisAlignment.start
        ..mainAxisAlignment = MainAxisAlignment.start;
    }
    return row;
  }

  @override
  Widget build(BuildContext context) {
    bool userIsAuthor = UserRepoLocal.to.currentUid == message.author.id;
    String peerId = userIsAuthor ? message.remoteId! : message.author.id;
    int state = message.metadata?['state'] ?? 0;
    String media = message.metadata?['media'] ?? 'audio';
    String customType = message.metadata?['custom_type'] ?? '';
    int startAt = message.metadata?['start_at'] ?? 0;
    int endAt = message.metadata?['end_at'] ?? 0;
    String callCuration = '';
    if (startAt > 0 && endAt > startAt) {
      DateTime date = DateTime.fromMillisecondsSinceEpoch(
        endAt - startAt,
        isUtc: true,
      );
      callCuration = DateFormat('mm:ss.SSS').format(date);
      // callCuration = DateFormat('mm:ss').format(date);
    }
    String title = '';
    if (state == 0) {
      title = '';
    } else if (state == 1) {
      // 已连接
    } else if (state == 2) {
      title = '未应答'.tr;
    } else if (state == 3) {
      title = '对方已挂断'.tr;
    } else if (state == 4) {
      title = '已取消'.tr;
    } else if (state == 5) {}

    if (title.isEmpty && callCuration.isNotEmpty) {
      title = "${'通话时长'.tr} $callCuration";
    }

    return Bubble(
      color: userIsAuthor
          ? AppColors.ChatSendMessageBgColor
          : AppColors.ChatReceivedMessageBodyBgColor,
      // color: AppColors.ChatReceivedMessageBodyBgColor,
      nip: userIsAuthor ? BubbleNip.rightBottom : BubbleNip.leftBottom,
      // style: const BubbleStyle(nipWidth: 16),
      nipRadius: 4,
      alignment: userIsAuthor ? Alignment.centerRight : Alignment.centerLeft,
      child: InkWell(
        onTap: () async {
          ContactModel? c = await ContactRepo().findByUid(peerId);
          UserModel peer = UserModel(
            uid: peerId,
            account: c!.account,
            nickname: c.nickname,
            avatar: c.avatar,
          );
          openCallScreen(
            peer,
            // session: s,
            {
              'media': media,
            },
            caller: true,
          );
        },
        child: _buildBody(
          customType,
          title,
          userIsAuthor,
        ),
      ),
    );
  }
}
