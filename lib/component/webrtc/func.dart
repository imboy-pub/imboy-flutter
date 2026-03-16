import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:imboy/theme/theme_manager.dart';

import 'package:imboy/component/helper/datetime.dart';
import 'package:imboy/component/ui/avatar.dart';
import 'package:imboy/component/webrtc/session.dart';

import 'package:imboy/config/init.dart';
import 'package:imboy/modules/messaging/public.dart';
import 'package:imboy/page/chat/p2p_call_screen/p2p_call_screen_page.dart';
import 'package:imboy/service/events/events.dart';
import 'package:imboy/service/network_monitor.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:imboy/i18n/strings.g.dart';

/// 发送WebRTC消息
Future<bool> sendWebRTCMsg(
  String event,
  Map payload, {
  required String msgId,
  required String to,
  String? debug,
}) async {
  // 使用 NetworkMonitorService 检查网络状态
  if (!NetworkMonitorService.to.hasNetwork) {
    debugPrint('WebRTC消息发送失败：无网络连接');
    return false;
  }

  Map request = {};
  request["ts"] = DateTimeHelper.millisecond();
  request["id"] = msgId;
  request["to"] = to;
  request["from"] = UserRepoLocal.to.currentUid;
  request["type"] = "webrtc_$event";
  request["payload"] = payload;

  // 解耦：通过事件发送消息
  AppEventBus.fire(
    WebSocketMessageSendRequestEvent(
      message: json.encode(request),
      messageId: msgId,
    ),
  );

  return true;
}

/// 生成会话ID
String sessionId(String peerId) {
  List<String> li = [UserRepoLocal.to.currentUid, peerId];
  li.sort();
  return "${li[0]}-${li[1]}";
}

/// 来电提示弹窗
Future<void> incomingCallScreen(
  BuildContext context,
  String msgId,
  ContactModel peer,
  Map<String, dynamic> option,
) async {
  if (p2pCallScreenOn) return;
  p2pCallScreenOn = true;

  final sid = sessionId(peer.peerId);
  WebRTCSession? s =
      webRTCSessions[sid] ?? WebRTCSession(peerId: peer.peerId, sid: sid);
  option['msgId'] = msgId;

  await MessageService.to.addLocalMsg(
    media: option['media'],
    caller: false,
    msgId: msgId,
    peer: peer,
  );

  gTimer = Timer(const Duration(seconds: 60), () {
    MessageService.to.changeLocalMsgState(msgId, 5);
    // Check if dialog is still open and close it
    if (navigatorKey.currentState?.overlay != null) {
      navigatorKey.currentState?.pop();
    }
    gTimer?.cancel();
    gTimer = null;
    p2pCallScreenOn = false;
  });

  await sendWebRTCMsg('ringing', {}, msgId: msgId, to: peer.peerId);

  // TODO(ChatLogic迁移): 标记消息已读
  // 需要在 ChatLogic 迁移到 Riverpod 后实现
  // 依赖 ChatLogic 的 markAsRead 方法
  // 目前暂时跳过此功能

  if (!context.mounted) return;

  final theme = Theme.of(context);
  final size = MediaQuery.of(context).size;

  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => Dialog(
      backgroundColor: ThemeManager.instance.isDarkMode
          ? const Color.fromRGBO(80, 80, 80, 1)
          : const Color.fromRGBO(240, 240, 240, 1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: SizedBox(
        width: size.width * 0.8,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(
                right: 6,
                left: 16,
                top: 16,
                bottom: 16,
              ),
              child: Avatar(imgUri: peer.avatar, width: 44, height: 44),
            ),
            SizedBox(
              width: 116,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 16),
                  Text(
                    peer.nickname,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Text(
                      t.incomingCall(
                        param: option['media'] == 'video' ? t.video : t.audio,
                      ),
                      style: TextStyle(
                        color: ThemeManager.instance.getThemeColor(
                          'textPrimary',
                        ),
                        fontSize: 12,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
            const Spacer(),
            FloatingActionButton(
              mini: true,
              heroTag: "RejectCall",
              backgroundColor: theme.colorScheme.error,
              onPressed: () async {
                // TODO(ChatLogic迁移): 标记消息已读
                // 依赖 ChatLogic 的 markAsRead 方法
                // 当前仅更新本地消息状态，未同步到服务端
                MessageService.to.changeLocalMsgState(msgId, 5);
                gTimer?.cancel();
                gTimer = null;
                await sendWebRTCMsg('busy', {}, msgId: msgId, to: peer.peerId);
                p2pCallScreenOn = false;
                if (dialogContext.mounted) {
                  Navigator.of(dialogContext).pop();
                }
              },
              child: Icon(Icons.call_end, color: theme.colorScheme.onError),
            ),
            const SizedBox(width: 8),
            FloatingActionButton(
              mini: true,
              heroTag: "AcceptCall",
              backgroundColor: theme.colorScheme.primary,
              onPressed: () async {
                // TODO(ChatLogic迁移): 标记消息已读
                // 依赖 ChatLogic 的 markAsRead 方法
                gTimer?.cancel();
                gTimer = null;
                if (dialogContext.mounted) {
                  Navigator.of(dialogContext).pop();
                }
                option['msgId'] = msgId;
                openCallScreen(
                  context,
                  peer,
                  session: s,
                  option,
                  caller: false,
                );
              },
              child: Icon(
                option['media'] == 'video' ? Icons.videocam : Icons.phone,
                color: ThemeManager.instance.getThemeColor('textPrimary'),
              ),
            ),
            const SizedBox(width: 16),
          ],
        ),
      ),
    ),
  );
}

/// 打开通话界面
Future<void> openCallScreen(
  BuildContext context,
  ContactModel peer,
  Map<String, dynamic> option, {
  WebRTCSession? session,
  bool caller = true,
}) async {
  if (p2pEntry != null) return;
  p2pCallScreenOn = true;

  final sid = sessionId(peer.peerId);
  session ??= WebRTCSession(peerId: peer.peerId, sid: sid);
  webRTCSessions[sid] = session;

  p2pEntry = OverlayEntry(
    builder: (context) => P2pCallScreenPage(
      peer: peer,
      session: session!,
      option: option,
      caller: caller,
      closePage: () {
        p2pEntry?.remove();
        p2pEntry = null;
        // Get.delete removed - cleanup is handled by closePage callback
        p2pCallScreenOn = false;
      },
    ),
  );

  navigatorKey.currentState?.overlay?.insert(p2pEntry!);
}
