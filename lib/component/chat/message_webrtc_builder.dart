import 'package:flutter/material.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart';

import 'package:imboy/component/webrtc/func.dart';

import 'package:imboy/plugins/contracts/message_type_plugin.dart';
import 'package:imboy/service/message_type_constants.dart';
import 'package:imboy/store/model/contact_model.dart';
import 'package:imboy/store/repository/contact_repo_sqlite.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:imboy/i18n/strings.g.dart';

class WebRTCMessageBuilder extends StatelessWidget {
  const WebRTCMessageBuilder({
    super.key,
    required this.user,
    required this.message,
  });

  final User user;
  final CustomMessage message;

  Widget _buildBody(
    BuildContext context,
    String messageType,
    String title,
    bool userIsAuthor,
  ) {
    Widget row;
    // 根据 messageType 判断是否为视频通话（仅支持 v2 规范）
    final isVideo = messageType == MessageType.webrtcVideo;

    if (userIsAuthor) {
      row = Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2, right: 4),
            child: Text(
              // '通话时长 10:48',
              title,
              textAlign: TextAlign.left,
              style: TextStyle(
                // color: Theme.of(context).colorScheme.onPrimary,
                color: Color.fromRGBO(34, 34, 34, 1.0),
                fontSize: 14.0, // 使用固定字体大小
              ),
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // 根据类型显示不同图标
          isVideo
              ? const Icon(
                  Icons.videocam,
                  color: Color.fromRGBO(34, 34, 34, 1.0),
                )
              : const Icon(Icons.call, color: Color.fromRGBO(34, 34, 34, 1.0)),
        ],
      );
    } else {
      row = Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          // 根据类型显示不同图标
          isVideo ? const Icon(Icons.videocam) : const Icon(Icons.call),
          Padding(
            padding: const EdgeInsets.only(top: 2, left: 4),
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
        ],
      );
    }
    return row;
  }

  @override
  Widget build(BuildContext context) {
    bool userIsAuthor = UserRepoLocal.to.currentUid == message.authorId;
    String peerId = userIsAuthor
        ? (message.metadata?['peer_id'] ?? '')
        : message.authorId;
    int state = message.metadata?['state'] ?? 0;

    // 优先使用 msg_type 判断（WebSocket API v2.0）
    final msgType = message.metadata?['msg_type'] ?? '';

    // 新格式：msg_type = 'webrtcAudio' 或 'webrtcVideo'
    // 统一使用 msg_type = webrtcAudio / webrtcVideo
    final isVideo = msgType == MessageType.webrtcVideo;
    String media = isVideo ? 'video' : 'audio';

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
      title = t.cancelled;
    } else if (state == 1) {
      // 已连接
    } else if (state == 2) {
      title = t.unanswered; // 发送者收到未应答
    } else if (state == 3) {
      title = t.peerHasHungUp;
    } else if (state == 4) {
      title = t.cancelled;
    } else if (state == 5) {
      title = t.unanswered; // 接收人未应答
    }

    if (title.isEmpty && callCuration.isNotEmpty) {
      title = "${t.callDuration} $callCuration";
    }
    if (title.isEmpty) {
      return const SizedBox.shrink();
    }
    return InkWell(
      onTap: peerId.isEmpty
          ? null
          : () async {
              ContactModel? peer = await ContactRepo().findByUid(peerId);
              // UserModel peer = UserModel(
              //   uid: peerId,
              //   account: c!.account,
              //   nickname: c.nickname,
              //   avatar: c.avatar,
              // );
              if (peer != null) {
                openCallScreen(
                  context,
                  peer,
                  // session: s,
                  {'media': media},
                  caller: true,
                );
              }
            },
      child: Padding(
        padding: const EdgeInsets.only(left: 10, right: 10, top: 8, bottom: 8),
        child: _buildBody(context, msgType, title, userIsAuthor),
      ),
    );
  }
}

class WebrtcAudioMessageTypePlugin implements MessageTypePlugin {
  const WebrtcAudioMessageTypePlugin();

  @override
  String get id => 'builtin:${MessageType.webrtcAudio}';

  @override
  bool get isEnabled => true;

  @override
  MessagePluginSurface get surface => MessagePluginSurface.bubble;

  @override
  String get type => MessageType.webrtcAudio;

  @override
  Widget build(MessageViewModel message, MessageRenderContext context) {
    return WebRTCMessageBuilder(message: message, user: context.user);
  }
}

class WebrtcVideoMessageTypePlugin implements MessageTypePlugin {
  const WebrtcVideoMessageTypePlugin();

  @override
  String get id => 'builtin:${MessageType.webrtcVideo}';

  @override
  bool get isEnabled => true;

  @override
  MessagePluginSurface get surface => MessagePluginSurface.bubble;

  @override
  String get type => MessageType.webrtcVideo;

  @override
  Widget build(MessageViewModel message, MessageRenderContext context) {
    return WebRTCMessageBuilder(message: message, user: context.user);
  }
}
