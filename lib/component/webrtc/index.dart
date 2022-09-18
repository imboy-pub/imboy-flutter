import 'dart:core';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:imboy/component/ui/avatar.dart';
import 'package:imboy/component/webrtc/signaling.dart';
import 'package:imboy/config/init.dart';
import 'package:imboy/page/p2p_call_screen/p2p_call_screen_view.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:niku/namespace.dart' as n;

Future<void> incomingCallScreen(
  String peerId,
  String title,
  String avatar,
  String sign,
  Map<String, dynamic> option,
) async {
  // 已经在通话中，不需要调起通话了
  if (callScreenOn == true) {
    // 给对端发送消息，说真正通话中 TODO
    return;
  }

  WebRTCSignaling signaling = WebRTCSignaling(
    UserRepoLocal.to.currentUid,
    peerId,
  )..connect();

  // String sessionId = UserRepoLocal.to.currentUid + '-' + peerId;
  String sessionId = option['sid'];
  WebRTCSession session = await signaling.createSession(
    null,
    peerId: peerId,
    sessionId: sessionId,
    media: option['media'],
    screenSharing: false,
  );
  signaling.sessions[sessionId] = session;
  debugPrint(
      ">>> ws rtc cc ${DateTime.now()} incomingCallScreen ${signaling.toString()}");

  await signaling.reciveOffer(
    peerId,
    // sd = session description
    option['sd'],
    option['media'],
    option['sid'],
  );
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
                imgUri: avatar,
                width: 44,
                height: 44,
              ),
            ),
          ]),
          n.Column([
            n.Row([
              Expanded(
                child: Text(
                  title,
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
                child: const Icon(
                  Icons.call_end,
                  color: Colors.white,
                ),
                backgroundColor: Colors.red,
                // onPressed: () => _rejectCall(context, _callSession),
                onPressed: () {
                  signaling.close();
                  Get.close(0);
                },
              ),
            )
          ]),
          n.Column([
            Padding(
              padding: const EdgeInsets.only(left: 0),
              child: FloatingActionButton(
                mini: true,
                heroTag: "AcceptCall",
                child: const Icon(
                  Icons.video_camera_back,
                  color: Colors.white,
                ),
                backgroundColor: Colors.green,
                // onPressed: () => _acceptCall(context, _callSession),
                onPressed: () {
                  Get.close(0);
                  openCallScreen(
                    peerId,
                    title,
                    avatar,
                    sign,
                    media: option['media'],
                    callee: true,
                    signaling: signaling,
                    session: session,
                  );
                },
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
  String id,
  String title,
  String avatar,
  String sign, {
  //  被叫者
  bool callee = false,
  String media = 'video',
  WebRTCSignaling? signaling,
  WebRTCSession? session,
}) {
  if (callScreenOn == true) {
    // 已经在通话中，不需要调起通话了
    return;
  }
  debugPrint(
      ">>> ws rtc cc ${DateTime.now()} openCallScreen ${signaling.toString()}");

  OverlayEntry? _entry;
  final entry = OverlayEntry(builder: (context) {
    return P2pCallScreenPage(
      to: id,
      title: title,
      avatar: avatar,
      sign: sign,
      media: media,
      callee: callee,
      signaling: signaling,
      session: session,
      close: () {
        _entry?.remove();
        _entry = null;
      },
    );
  });
  _entry = entry;
  navigatorKey.currentState?.overlay?.insert(entry);
}
