import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:imboy/theme/theme_manager.dart';

import 'package:imboy/component/helper/datetime.dart';
import 'package:imboy/component/ui/avatar.dart';
import 'package:imboy/component/webrtc/session.dart';

import 'package:imboy/config/init.dart';
import 'package:imboy/page/chat/chat/chat_logic.dart';
import 'package:imboy/page/chat/p2p_call_screen/p2p_call_screen_view.dart';
import 'package:imboy/service/message.dart';
import 'package:imboy/service/events/events.dart';
import 'package:imboy/service/network_monitor.dart';
import 'package:imboy/store/model/contact_model.dart';
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
  AppEventBus.fire(WebSocketMessageSendRequestEvent(
    message: json.encode(request),
    messageId: msgId,
  ));

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
    if (Get.isDialogOpen ?? false) Get.closeAllDialogs();
    gTimer?.cancel();
    gTimer = null;
    p2pCallScreenOn = false;
  });

  await sendWebRTCMsg('ringing', {}, msgId: msgId, to: peer.peerId);

  Get.defaultDialog(
    title: '',
    backgroundColor: ThemeManager.instance.isDarkMode
        ? const Color.fromRGBO(80, 80, 80, 1)
        : const Color.fromRGBO(240, 240, 240, 1),
    titlePadding: EdgeInsets.zero,
    barrierDismissible: false,
    radius: 10,
    content: SizedBox(
      width: Get.width,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: Avatar(imgUri: peer.avatar, width: 44, height: 44),
          ),
          SizedBox(
            width: 116,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                    t.incomingCall.replaceAll('{s}',
                        option['media'] == 'video' ? t.video : t.audio),
                    style: TextStyle(
                      color: ThemeManager.instance.getThemeColor('textPrimary'),
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
          FloatingActionButton(
            mini: true,
            heroTag: "RejectCall",
            backgroundColor: Get.theme.colorScheme.error,
            onPressed: () async {
              try {
                await Get.find<ChatLogic>().markAsRead('C2C', peer.peerId, [
                  msgId,
                ]);
              } catch (e) {
                // Ignore marking error, continue with call rejection
              }
              MessageService.to.changeLocalMsgState(msgId, 5);
              gTimer?.cancel();
              gTimer = null;
              await sendWebRTCMsg('busy', {}, msgId: msgId, to: peer.peerId);
              p2pCallScreenOn = false;
              Get.closeAllDialogs();
            },
            child: Icon(Icons.call_end, color: Get.theme.colorScheme.onError),
          ),
          const SizedBox(width: 8),
          FloatingActionButton(
            mini: true,
            heroTag: "AcceptCall",
            backgroundColor: Get.theme.colorScheme.primary,
            onPressed: () async {
              try {
                await Get.find<ChatLogic>().markAsRead('C2C', peer.peerId, [
                  msgId,
                ]);
              } catch (e) {
                // Ignore marking error, continue with call acceptance
              }
              gTimer?.cancel();
              gTimer = null;
              Get.closeAllDialogs();
              option['msgId'] = msgId;
              openCallScreen(peer, session: s, option, caller: false);
            },
            child: Icon(
              option['media'] == 'video' ? Icons.videocam : Icons.phone,
              color: ThemeManager.instance.getThemeColor('textPrimary'),
            ),
          ),
        ],
      ),
    ),
  );
}

/// 打开通话界面
Future<void> openCallScreen(
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
        Get.delete<P2pCallScreenPage>(force: true);
        p2pCallScreenOn = false;
      },
    ),
  );

  navigatorKey.currentState?.overlay?.insert(p2pEntry!);
}
