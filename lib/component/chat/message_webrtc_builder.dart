import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart';

import 'package:imboy/component/webrtc/func.dart';

import 'package:imboy/plugins/contracts/message_type_plugin.dart';
import 'package:imboy/service/message_type_constants.dart';
import 'package:imboy/store/model/contact_model.dart';
import 'package:imboy/store/repository/contact_repo_sqlite.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_spacing.dart';
import 'package:imboy/theme/default/font_types.dart';

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
    final theme = Theme.of(context);
    final isVideo = messageType == MessageType.webrtcVideo;

    // 发送气泡背景为品牌色，文字/图标统一白色；接收方用主题主文字色
    final fgColor = userIsAuthor
        ? AppColors.sentMessageText
        : AppColors.getTextColor(theme.brightness);

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(
          isVideo ? CupertinoIcons.videocam_fill : CupertinoIcons.phone_fill,
          color: fgColor,
          size: 18,
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            title,
            style: context.textStyle(
              FontSizeType.normal,
              color: fgColor,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    bool userIsAuthor = UserRepoLocal.to.currentUid == message.authorId;
    String peerId = userIsAuthor
        ? (message.metadata?['peer_id'] as String? ?? '')
        : message.authorId;
    int state = message.metadata?['state'] as int? ?? 0;

    // 优先使用 msg_type 判断（WebSocket API v2.0）
    final msgType = (message.metadata?['msg_type'] ?? '') as String;

    // 新格式：msg_type = 'webrtcAudio' 或 'webrtcVideo'
    // 统一使用 msg_type = webrtcAudio / webrtcVideo
    final isVideo = msgType == MessageType.webrtcVideo;
    String media = isVideo ? 'video' : 'audio';

    int startAt = message.metadata?['start_at'] as int? ?? 0;
    int endAt = message.metadata?['end_at'] as int? ?? 0;
    String callCuration = '';
    if (startAt > 0 && endAt > startAt) {
      DateTime date = DateTime.fromMillisecondsSinceEpoch(
        endAt - startAt,
        isUtc: true,
      );
      callCuration = DateFormat('mm:ss.SSS').format(date);
    }
    String title = '';
    if (state == 0) {
      title = t.common.cancelled;
    } else if (state == 1) {
      // 已连接
    } else if (state == 2) {
      title = t.main.unanswered; // 发送者收到未应答
    } else if (state == 3) {
      title = t.main.peerHasHungUp;
    } else if (state == 4) {
      title = t.common.cancelled;
    } else if (state == 5) {
      title = t.main.unanswered; // 接收人未应答
    }

    if (title.isEmpty && callCuration.isNotEmpty) {
      title = "${t.common.callDuration} $callCuration";
    }
    if (title.isEmpty) {
      return const SizedBox.shrink();
    }
    return InkWell(
      onTap: peerId.isEmpty
          ? null
          : () async {
              ContactModel? peer = await ContactRepo().findByUid(peerId);
              if (!context.mounted) return;
              if (peer != null) {
                openCallScreen(context, peer, {'media': media}, caller: true);
              }
            },
      child: Padding(
        padding: const EdgeInsets.only(
          left: 10,
          right: 10,
          top: AppSpacing.small,
          bottom: AppSpacing.small,
        ),
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
