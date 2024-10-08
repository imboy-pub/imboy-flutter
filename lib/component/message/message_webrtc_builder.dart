import 'package:flutter/material.dart';

// ignore: depend_on_referenced_packages
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;
import 'package:get/get.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/component/webrtc/func.dart';

import 'package:imboy/store/model/contact_model.dart';
import 'package:imboy/store/repository/contact_repo_sqlite.dart';
import 'package:imboy/store/repository/user_repo_local.dart';

// ignore: depend_on_referenced_packages
import 'package:intl/intl.dart' show DateFormat;
import 'package:niku/namespace.dart' as n;

class WebRTCMessageBuilder extends StatelessWidget {
  const WebRTCMessageBuilder({
    super.key,
    required this.user,
    required this.message,
  });

  final types.User user;
  final types.CustomMessage message;

  Widget _buildBody(BuildContext context, String customType, String title,
      bool userIsAuthor) {
    Widget row;
    if (userIsAuthor) {
      row = n.Row([
        n.Padding(
          top: 2,
          right: 4,
          child: Text(
            // '通话时长 10:48',
            title,
            textAlign: TextAlign.left,
            style: const TextStyle(
              // color: Theme.of(context).colorScheme.onPrimary,
              color: Color.fromRGBO(34, 34, 34, 1.0),
              fontSize: 15.0,
            ),
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        customType == 'webrtc_video'
            ? const Icon(
                Icons.videocam,
                color: Color.fromRGBO(34, 34, 34, 1.0),
              )
            : const Icon(
                Icons.call_end,
                color: Color.fromRGBO(34, 34, 34, 1.0),
              ),
      ])
        ..mainAxisSize = MainAxisSize.min
        // 内容文本左对齐
        ..crossAxisAlignment = CrossAxisAlignment.start
        ..mainAxisAlignment = MainAxisAlignment.start;
    } else {
      row = n.Row([
        customType == 'webrtc_video'
            ? const Icon(Icons.videocam)
            : const Icon(Icons.call_end),
        n.Padding(
          top: 2,
          left: 4,
          child: Text(
            // '通话时长 10:48',
            title,
            textAlign: TextAlign.left,
            style: const TextStyle(
              // color: AppColors.primaryText,
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
      title = 'cancelled'.tr;
    } else if (state == 1) {
      // 已连接
    } else if (state == 2) {
      title = 'unanswered'.tr; // 发送者收到未应答
    } else if (state == 3) {
      title = 'peer_has_hung_up'.tr;
    } else if (state == 4) {
      title = 'cancelled'.tr;
    } else if (state == 5) {
      title = 'unanswered'.tr; // 接收人未应答
    }

    if (title.isEmpty && callCuration.isNotEmpty) {
      title = "${'call_duration'.tr} $callCuration";
    }
    iPrint("message_webrtc_builder $title; $state; $customType;");
    if (title.isEmpty) {
      return const SizedBox.shrink();
    }
    return InkWell(
      onTap: () async {
        ContactModel? peer = await ContactRepo().findByUid(peerId);
        // UserModel peer = UserModel(
        //   uid: peerId,
        //   account: c!.account,
        //   nickname: c.nickname,
        //   avatar: c.avatar,
        // );
        openCallScreen(
          peer!,
          // session: s,
          {
            'media': media,
          },
          caller: true,
        );
      },
      child: n.Padding(
        left: 10,
        right: 10,
        top: 8,
        bottom: 8,
        child: _buildBody(
          context,
          customType,
          title,
          userIsAuthor,
        ),
      ),
    );
    /*
    return Bubble(
      // color: userIsAuthor
      //     ? AppColors.ChatSendMessageBgColor
      //     : AppColors.ChatReceivedMessageBodyBgColor,
      // color: AppColors.ChatReceivedMessageBodyBgColor,
      nip: userIsAuthor ? BubbleNip.rightBottom : BubbleNip.leftBottom,
      // style: const BubbleStyle(nipWidth: 16),
      nipRadius: 4,
      alignment: userIsAuthor ? Alignment.centerRight : Alignment.centerLeft,
      child: InkWell(
        onTap: () async {
          ContactModel? peer = await ContactRepo().findByUid(peerId);
          // UserModel peer = UserModel(
          //   uid: peerId,
          //   account: c!.account,
          //   nickname: c.nickname,
          //   avatar: c.avatar,
          // );
          openCallScreen(
            peer!,
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
    */
  }
}
