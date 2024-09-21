import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
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
import 'package:imboy/store/provider/user_provider.dart';
import 'package:imboy/store/repository/user_repo_local.dart';

/// 初始化 ice 配置信息
Future<bool> initIceServers({String from = 'incomingCallScreen'}) async {
  debugPrint(
      "> rtc initIceServers iceConfiguration == null: ${iceConfiguration == null}, ${UserRepoLocal.to.isLogin}, ${iceConfiguration.toString()}");

  if (iceConfiguration != null) {
    return true;
  }
  try {
    Map<String, dynamic> turnCredential = await UserProvider().turnCredential();
    debugPrint("getIceServers _turnCredential ${turnCredential.toString()}");
    if (turnCredential.isEmpty && from == 'openCallScreen') {
      EasyLoading.showError('failed_request_please_check_network'.tr);
      return false;
    } else if (turnCredential.isEmpty) {
      return false;
    }
    iceConfiguration = {
      'iceServers': [
        {
          'urls': turnCredential['stun_urls'], // stun urls
          'username': turnCredential['username'],
          'credential': turnCredential['credential']
        },
        {
          'urls': turnCredential['turn_urls'], // turn urls
          "ttl": turnCredential['ttl'] ?? 86400,
          'username': turnCredential['username'],
          'credential': turnCredential['credential']
        },
      ],
      // ceCandidatePoolSize默认值是0，表示不限制候选数量。5，来限制ICE候选的数量。
      "iceCandidatePoolSize": 3,
      "encodedInsertableStreams": false,
      // balanced：默认值，尝试在减少传输层连接数和保持足够的灵活性之间找到平衡。这通常意味着音频和视频流会捆绑在一起，但不会强制捆绑所有媒体类型。
      // max-bundle：尽可能地将所有媒体流捆绑到一个RTP会话中。这减少了建立的连接数，可以减少总体的连接建立时间，因为只需要进行一次ICE协商。
      // max-compat：不强制捆绑媒体流，以保持最大的兼容性。这可能会增加建立连接所需的时间，因为每个媒体流可能需要单独的ICE协商。
      "bundlePolicy": "balanced",
      // all:可以使用任何类型的候选者(表示host类型、srflx反射、relay中继都支持)
      // relay: 只使用中继候选者（在真实的网络情况下一般都使用 relay，因为Nat穿越在中国很困难）
      'iceTransportPolicy': 'relay',
      "rtcpMuxPolicy": "require",
      'sdpSemantics': 'unified-plan',
    };
    return true;
  } catch (e) {
    //
  }
  return false;
}

/// 发送WebRTC 消息
sendWebRTCMsg(String event, Map payload,
    {required String msgId, required String to, String? debug}) {
  Map request = {};
  request["ts"] = DateTimeHelper.utc();
  request["id"] = msgId;
  request["to"] = to;
  request["from"] = UserRepoLocal.to.currentUid; // currentUid
  request["type"] = "webrtc_$event";
  request["payload"] = payload;
  debugPrint(
      '> rtc _send $event, debug $debug, ${DateTime.now()} ${request.toString()}');
  WebSocketService.to.sendMessage(json.encode(request));
}

/// 排线两端，使得两端sessionId一致
String sessionId(String peerId) {
  List<String> li = [UserRepoLocal.to.currentUid, peerId];
  li.sort();
  return "${li[0]}-${li[1]}";
}

/// 接受暂存候选消息
Future<void> receiveCandidate(String peerId, Map<String, dynamic> data) async {
  RTCIceCandidate candidate = RTCIceCandidate(
    data['candidate'],
    data['sdpMid'],
    data['sdpMLineIndex'],
  );
  // String pid = data['from'];
  String sid = sessionId(peerId);
  var s = webRTCSessions[sid];
  if (s != null) {
    final description = await s.pc?.getRemoteDescription();
    if (description != null) {
      await s.pc?.addCandidate(candidate);
    } else {
      s.remoteCandidates.add(candidate);
    }
    webRTCSessions[sid] = s;
  } else {
    webRTCSessions[sid] = WebRTCSession(
      pid: peerId,
      sid: sid,
    )..remoteCandidates.add(candidate);
  }
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
  bool res = await initIceServers();
  iPrint("rtc_msg incomingCallScreen msgid $msgId, res $res,");
  if (res == false) {
    sleep(const Duration(seconds: 2));
    res = await initIceServers();
  }
  if (res == false) {
    return;
  }

  String sid = sessionId(peer.peerId);
  var s = webRTCSessions[sid];
  s ??= WebRTCSession(pid: peer.peerId, sid: sid);
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
  bool res = await initIceServers(from: 'openCallScreen');
  if (res == false) {
    return;
  }
  p2pCallScreenOn = true;

  String sid = sessionId(peer.peerId);
  session ??= WebRTCSession(pid: peer.peerId, sid: sid);
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
