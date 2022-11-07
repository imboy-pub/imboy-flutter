import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:imboy/component/ui/avatar.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/config/init.dart';
import 'package:imboy/page/p2p_call_screen/p2p_call_screen_view.dart';
import 'package:imboy/store/model/user_model.dart';
import 'package:imboy/store/provider/user_provider.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:niku/namespace.dart' as n;

import 'signaling.dart';

/// 初始化 ice 配置信息
initIceServers() async {
  debugPrint("getIceServers iceServers == null: ${iceServers == null}");
  if (iceServers == null) {
    try {
      var turnCredential = await UserProvider().turnCredential();
      debugPrint("getIceServers _turnCredential ${turnCredential.toString()}");
      iceServers = {
        'iceServers': [
          {
            'url': STUN_URL,
          },
          {
            'urls': turnCredential['uris'] ?? [TURN_URL],
            "ttl": turnCredential['ttl'] ?? 86400,
            'username': turnCredential['username'],
            'credential': turnCredential['credential']
          },
        ],
        'iceTransportPolicy': 'relay',
      };
    } catch (e) {
      //
    }
  }
}

Future<void> incomingCallScreen(
  UserModel peer,
  Map<String, dynamic> option,
) async {
  debugPrint("> rtc p2pCallScreenOn $p2pCallScreenOn");
  // 已经在通话中，不需要调起通话了
  if (p2pCallScreenOn == true) {
    // 给对端发送消息，说正在通话中 TODO
    return;
  }
  p2pCallScreenOn = true;
  // 被叫，初始化信令
  WebRTCSignaling signaling = Get.put(
      WebRTCSignaling(
        UserRepoLocal.to.currentUid,
        peer.uid,
        iceServers!,
      )..signalingConnect(),
      tag: 'p2psignaling');

  // String sessionId = UserRepoLocal.to.currentUid + '-' + peerId;
  String sessionId = option['sid'];
  WebRTCSession session = await signaling.createSession(
    null,
    peerId: peer.uid,
    sessionId: sessionId,
    media: option['media'],
    screenSharing: false,
  );
  signaling.sessions[sessionId] = session;
  debugPrint("> rtc incomingCallScreen ${signaling.toString()}");

  Get.defaultDialog(
    title: "",
    backgroundColor: Colors.black54,
    titlePadding: const EdgeInsets.all(0),
    barrierDismissible: false,
    radius: 10,
    content: SizedBox(
        width: Get.width,
        child: n.Row([
          n.Column([
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Avatar(
                imgUri: peer.avatar,
                width: 44,
                height: 44,
              ),
            ),
          ]),
          n.Column([
            n.Row([
              Expanded(
                child: Text(
                  peer.nickname,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12.0,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.left,
                ),
              ),
            ]),
            n.Row([
              Padding(
                padding: const EdgeInsets.only(
                  top: 10,
                ),
                child: Text(
                  "Incoming ${option['media']} call",
                  style: const TextStyle(
                    color: Colors.white60,
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
            Padding(
              padding: const EdgeInsets.only(right: 0),
              child: FloatingActionButton(
                mini: true,
                heroTag: "RejectCall",
                backgroundColor: Colors.red,
                // onPressed: () => _rejectCall(context, _callSession),
                onPressed: () {
                  p2pCallScreenOn = false;
                  signaling.close();
                  Get.close(0);
                },
                child: const Icon(
                  Icons.call_end,
                  color: Colors.white,
                ),
              ),
            )
          ]),
          n.Column([
            Padding(
              padding: const EdgeInsets.only(left: 0),
              child: FloatingActionButton(
                mini: true,
                heroTag: "AcceptCall",
                backgroundColor: Colors.green,
                // onPressed: () => _acceptCall(context, _callSession),
                onPressed: () {
                  Get.close(0);
                  openCallScreen(
                    peer,
                    option,
                    caller: false,
                  );
                },
                child: const Icon(
                  Icons.video_camera_back,
                  color: Colors.white,
                ),
              ),
            ),
          ]),
        ])
          ..mainAxisSize = MainAxisSize.min
          ..crossAxisAlignment = CrossAxisAlignment.start),
  );
}

/// 调起
void openCallScreen(
  UserModel peer,
  Map<String, dynamic> option, {
  //  默认是主叫者
  bool caller = true,
}) {
  if (caller) {
    // 主叫，初始化信令
    Get.put(
        WebRTCSignaling(
          UserRepoLocal.to.currentUid,
          peer.uid,
          iceServers!,
        )..signalingConnect(),
        tag: 'p2psignaling');
  }
  OverlayEntry? tempEntry;
  final entry = OverlayEntry(builder: (context) {
    return P2pCallScreenPage(
      peer: peer,
      option: option,
      caller: caller,
      closePage: () {
        debugPrint(">>> rtc closePage");
        tempEntry?.remove();
        tempEntry = null;
      },
    );
  });
  tempEntry = entry;
  navigatorKey.currentState?.overlay?.insert(entry);
}
