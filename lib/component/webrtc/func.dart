import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:niku/namespace.dart' as n;

import 'package:imboy/component/helper/datetime.dart';
import 'package:imboy/component/ui/avatar.dart';
import 'package:imboy/component/webrtc/session.dart';

import 'package:imboy/config/init.dart';
import 'package:imboy/page/chat/chat/chat_logic.dart';
import 'package:imboy/page/chat/p2p_call_screen/p2p_call_screen_view.dart';
import 'package:imboy/service/message.dart';
import 'package:imboy/service/websocket.dart';
import 'package:imboy/store/model/contact_model.dart';
import 'package:imboy/store/repository/user_repo_local.dart';

/// 发送WebRTC 消息
void sendWebRTCMsg(String event, Map payload,
    {required String msgId, required String to, String? debug}) {
  Map request = {};
  request["ts"] = DateTimeHelper.millisecond();
  request["id"] = msgId;
  request["to"] = to;
  request["from"] = UserRepoLocal.to.currentUid; // currentUid
  request["type"] = "webrtc_$event";
  request["payload"] = payload;
  // debugPrint(
  //     '> rtc _send $event, debug $debug, ${DateTime.now()} ${request.toString()}');
  WebSocketService.to.sendMessage(json.encode(request));
}

/// 排线两端，使得两端sessionId一致
String sessionId(String peerId) {
  List<String> li = [UserRepoLocal.to.currentUid, peerId];
  li.sort();
  return "${li[0]}-${li[1]}";
}

/// 音视频会话弹窗
Future<void> incomingCallScreen(
  String msgId,
  ContactModel peer,
  Map<String, dynamic> option,
) async {
  iPrint(
      "rtc_msg incomingCallScreen msgid $msgId, peer ${peer.peerId} , option ${option.toString()}");
  if (p2pCallScreenOn == true) {
    return;
  }
  p2pCallScreenOn = true;

  final sid = sessionId(peer.peerId);
  WebRTCSession? s = webRTCSessions[sid];
  // 在 openCallScreen 方法有把 session 放入 webRTCSessions 中
  s ??= WebRTCSession(peerId: peer.peerId, sid: sid);
  option['msgId'] = msgId;
  await MessageService.to.addLocalMsg(
    media: option['media'],
    caller: false,
    msgId: msgId,
    peer: peer,
  );

  gTimer = Timer(const Duration(seconds: 60), () {
    MessageService.to.changeLocalMsgState(msgId, 5);
    if (Get.isDialogOpen ?? false) {
      Get.closeAllDialogs();
    }
    gTimer?.cancel();
    gTimer = null;
    p2pCallScreenOn = false;
  });

  sendWebRTCMsg('ringing', {}, msgId: msgId, to: peer.peerId);
  Get.defaultDialog(
    title: '',
    backgroundColor: Get.isDarkMode
        ? const Color.fromRGBO(80, 80, 80, 1)
        : const Color.fromRGBO(240, 240, 240, 1),
    // backgroundColor: const Color.fromRGBO(80, 80, 80, 1),
    titlePadding: const EdgeInsets.all(0),
    barrierDismissible: false,
    radius: 10,
    content: SizedBox(
        width: Get.width,
        child: n.Row([
          n.Column([
            n.Padding(
              right: 6,
              child: Avatar(imgUri: peer.avatar, width: 44, height: 44),
            ),
          ]),
          n.Column([
            n.Row([
              Expanded(
                child: Text(
                  peer.nickname,
                  style: const TextStyle(
                    fontSize: 12.0,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.left,
                ),
              ),
            ]),
            n.Row([
              n.Padding(
                top: 10,
                child: Text(
                  // "Incoming ${option['media']} call".tr,
                  'incoming_call'.trArgs([
                    option['media'] == 'video'
                        ? 'video'.tr
                        : (option['media'] == 'audio'
                            ? 'audio'.tr
                            : option['media'])
                  ]),
                  style: TextStyle(
                    color: Theme.of(Get.context!).colorScheme.onPrimary,
                    fontSize: 12,
                  ),
                  textAlign: TextAlign.left,
                ),
              ),
            ]),
          ])
            ..width = 116
            ..crossAxisAlignment = CrossAxisAlignment.start,
          n.Column([
            n.Padding(
              right: 0,
              child: FloatingActionButton(
                mini: true,
                heroTag: "RejectCall",
                backgroundColor: Colors.red,
                onPressed: () async {
                  try {
                    await Get.find<ChatLogic>().markAsRead(
                      'C2C',
                      peer.peerId,
                      [msgId],
                    );
                  } catch (e) {
                    //
                  }
                  MessageService.to.changeLocalMsgState(
                    msgId,
                    5,
                  );
                  gTimer?.cancel();
                  gTimer = null;
                  sendWebRTCMsg('busy', {}, msgId: msgId, to: peer.peerId);
                  p2pCallScreenOn = false;
                  Get.closeAllDialogs();
                },
                child: const Icon(Icons.call_end, color: Colors.white),
              ),
            )
          ]),
          n.Column([
            n.Padding(
              left: 0,
              child: FloatingActionButton(
                mini: true,
                heroTag: "AcceptCall",
                backgroundColor: Colors.green,
                onPressed: () async {
                  try {
                    await Get.find<ChatLogic>().markAsRead(
                      'C2C',
                      peer.peerId,
                      [msgId],
                    );
                  } catch (e) {
                    //
                  }
                  gTimer?.cancel();
                  gTimer = null;
                  Get.closeAllDialogs();
                  option['msgId'] = msgId;
                  //
                  openCallScreen(peer, session: s, option, caller: false);
                },
                child: option['media'] == 'video'
                    ? Icon(Icons.videocam,
                        color: Theme.of(Get.context!).colorScheme.onPrimary)
                    : Icon(Icons.phone,
                        color: Theme.of(Get.context!).colorScheme.onPrimary),
              ),
            ),
          ]),
        ])
          ..mainAxisSize = MainAxisSize.min
          ..crossAxisAlignment = CrossAxisAlignment.start),
  );
}

/// 调起
Future<void> openCallScreen(
  ContactModel peer,
  Map<String, dynamic> option, {
  WebRTCSession? session,
  //  默认是主叫者
  bool caller = true,
}) async {
  if (p2pEntry != null) {
    return;
  }

  p2pCallScreenOn = true;

  final sid = sessionId(peer.peerId);
  session ??= WebRTCSession(peerId: peer.peerId, sid: sid);
  webRTCSessions[sid] = session;
  p2pEntry = OverlayEntry(builder: (context) {
    return P2pCallScreenPage(
      peer: peer,
      session: session!,
      option: option,
      caller: caller,
      closePage: () {
        debugPrint("> rtc closePage");
        if (p2pEntry != null) {
          p2pEntry?.remove();
          p2pEntry = null;
        }
        Get.delete<P2pCallScreenPage>(force: true);
        p2pCallScreenOn = false;
      },
    );
  });
  navigatorKey.currentState?.overlay?.insert(p2pEntry!);
}
