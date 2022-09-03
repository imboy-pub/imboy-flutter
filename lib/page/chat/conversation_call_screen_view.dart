import 'dart:async';
import 'dart:core';

import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:get/get.dart';
import 'package:imboy/component/helper/counter.dart';
import 'package:imboy/component/ui/avatar.dart';
import 'package:imboy/component/webrtc/dragable.dart';
import 'package:imboy/component/webrtc/signaling.dart';
import 'package:imboy/config/init.dart';
import 'package:imboy/store/model/webrtc_signaling_model.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:niku/namespace.dart' as n;

void incomingCallCcreen(
  String peerId,
  String title,
  String avatar,
  String sign,
) {
  // 已经在通话中，不需要调起通话了
  if (callScreenOn == true) {
    // 给对端发送消息，说真正通话中 TODO
    return;
  }

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
            n.Row(const [
              Padding(
                padding: EdgeInsets.only(
                  top: 10,
                ),
                child: Text(
                  "Incoming video call",
                  style: TextStyle(
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
                    callee: true,
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
}) {
  if (callScreenOn == true) {
    // 已经在通话中，不需要调起通话了
    return;
  }
  debugPrint(">>> ws rtc state openCallScreen");

  OverlayEntry? _entry;
  final entry = OverlayEntry(builder: (context) {
    return ConversationCallScreenPage(
      to: id,
      title: title,
      avatar: avatar,
      sign: sign,
      callee: callee,
      close: () {
        _entry?.remove();
        _entry = null;
      },
    );
  });
  _entry = entry;
  navigatorKey.currentState?.overlay?.insert(entry);
}

class ConversationCallScreenPage extends StatefulWidget {
  final String to;
  final String title;
  final String avatar;
  final String sign;
  final bool callee;
  final Function close;

  const ConversationCallScreenPage({
    Key? key,
    required this.to,
    required this.title,
    required this.avatar,
    this.sign = "",
    // 被叫者
    this.callee = false,
    required this.close,
  }) : super(key: key);

  @override
  _CallScreenPageState createState() => _CallScreenPageState();
}

class _CallScreenPageState extends State<ConversationCallScreenPage> {
  WebRTCSignaling? signaling;
  String? selfId;
  final RTCVideoRenderer localRenderer = RTCVideoRenderer();
  final RTCVideoRenderer remoteRenderer = RTCVideoRenderer();
  bool inCalling = false;

  Session? session;

  bool waitAccept = false;

  //
  double localX = 0;
  double localY = 0;

  bool connected = false;
  bool showTool = true;
  bool switchRenderer = true;
  // 最小化的
  bool minimized = false;
  // 计时器
  Counter counter = Counter(count: 0);

  // ignore: unused_element
  _CallScreenPageState();

  @override
  initState() {
    super.initState();
    callScreenOn = true;
    selfId = UserRepoLocal.to.currentUid;
    counter.start((Timer tm) {
      // 更新界面
      setState(() {
        // 秒数+1，因为一秒回调一次
        counter.count += 1;
      });
    });

    initRenderers();
    _connect();

    // 接收到新的消息订阅
    eventBus
        .on<WebRTCSignalingModel>()
        .listen((WebRTCSignalingModel obj) async {
      debugPrint(">>> on rtc listen: " + obj.toJson().toString());
      signaling?.onMessage(obj);
    });
    _invitePeer(context, widget.to, false);
  }

  initRenderers() async {
    await localRenderer.initialize();
    await remoteRenderer.initialize();
  }

  @override
  deactivate() {
    super.deactivate();
    _close();
  }

  @override
  void dispose() {
    super.dispose();
    _close();
  }

  _close() {
    localRenderer.dispose();
    remoteRenderer.dispose();
    if (signaling != null) {
      signaling?.close();
    }
    counter.close();
    widget.close();
    callScreenOn = false;
  }

  void _connect() async {
    debugPrint(">>> ws rtc _connect ");
    String from = UserRepoLocal.to.currentUid;
    signaling ??= WebRTCSignaling(from, widget.to)..connect();
    signaling?.onSignalingStateChange = (SignalingState state) {
      debugPrint(">>> ws rtc state _connect ${state.toString()}");
      switch (state) {
        case SignalingState.ConnectionClosed:
          debugPrint(
              ">>> ws rtc state _connect ${SignalingState.ConnectionClosed}");
          break;
        case SignalingState.ConnectionError:
          debugPrint(
              ">>> ws rtc state _connect ${SignalingState.ConnectionError}");
          break;
        case SignalingState.ConnectionOpen:
          debugPrint(
              ">>> ws rtc state _connect ${SignalingState.ConnectionOpen}");
          break;
      }
    };

    signaling?.onCallStateChange = (Session s1, CallState state) async {
      debugPrint(
          ">>> ws rtc state _connect onCallStateChange ${state.toString()}; session: ${s1.sid} ${s1.pid}");
      switch (state) {
        case CallState.CallStateNew:
          setState(() {
            session = s1;
          });
          break;
        case CallState.CallStateRinging:
          _accept();
          setState(() {
            inCalling = true;
          });
          break;
        case CallState.CallStateBye:
          debugPrint('peer reject');
          if (waitAccept) {
            waitAccept = false;
            // Navigator.of(context).pop(false);
          }
          setState(() {
            localRenderer.srcObject = null;
            remoteRenderer.srcObject = null;
            inCalling = false;
            session = null;
          });
          _close();
          break;
        case CallState.CallStateInvite:
          waitAccept = true;
          break;
        case CallState.CallStateConnected:
          debugPrint(">>> ws rtc view s ${CallState.CallStateConnected}");

          if (waitAccept) {
            setState(() {
              waitAccept = false;
            });
          }
          setState(() {
            localX = Get.width - 90;
            localY = 30;
            connected = true;
            inCalling = true;
          });
          break;
      }
    };
    signaling?.onPeersUpdate = ((event) {
      debugPrint(">>> ws rtc _connect onPeersUpdate");
      setState(() {
        selfId = event['self'];
        // peers = event['peers'];
      });
    });

    signaling?.onLocalStream = ((stream) {
      debugPrint(">>> ws rtc _connect onLocalStream");
      localRenderer.srcObject = stream;
      setState(() {});
    });

    signaling?.onAddRemoteStream = ((_, stream) {
      debugPrint(">>> ws rtc _connect onAddRemoteStream");
      remoteRenderer.srcObject = stream;
      setState(() {});
    });

    signaling?.onRemoveRemoteStream = ((_, stream) {
      debugPrint(">>> ws rtc _connect onRemoveRemoteStream");
      remoteRenderer.srcObject = null;
    });
  }

  _invitePeer(BuildContext context, String peerId, bool useScreen) async {
    if (signaling != null && peerId != selfId) {
      signaling?.invite(peerId, 'video', useScreen);
      if (signaling?.localStream != null) {
        localRenderer.srcObject = signaling?.localStream;
      }
    }
  }

  _accept() {
    if (session != null) {
      signaling?.accept(session!.sid);
      setState(() {
        localX = Get.width - 90;
        localY = 30;
        connected = true;
      });
    }
  }

  _hangUp() {
    if (session != null) {
      signaling?.bye(session!.sid);
    }
    _close();
  }

  _switchCamera() {
    signaling?.switchCamera();
  }

  _muteMic() {
    signaling?.muteMic();
  }

  @override
  Widget build(BuildContext context) {
    return IndexedStack(index: minimized ? 1 : 0, children: [
      Scaffold(
        floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
        floatingActionButton: showTool
            ? SizedBox(
                width: 200.0,
                child: n.Row(
                  <Widget>[
                    FloatingActionButton(
                      heroTag: "switch_camera",
                      child: const Icon(Icons.switch_camera),
                      onPressed: _switchCamera,
                    ),
                    FloatingActionButton(
                      heroTag: "call_end",
                      onPressed: _hangUp,
                      tooltip: 'Hangup',
                      child: const Icon(Icons.call_end),
                      backgroundColor: Colors.pink,
                    ),
                    FloatingActionButton(
                      heroTag: "mic_off",
                      child: const Icon(Icons.mic_off),
                      onPressed: _muteMic,
                    )
                  ],
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                ),
              )
            : null,
        body: OrientationBuilder(
          builder: (context, orientation) {
            double w = orientation == Orientation.portrait ? 90.0 : 120.0;
            double h = orientation == Orientation.portrait ? 120.0 : 90.0;
            Widget localBox = Container(
              margin: const EdgeInsets.fromLTRB(0.0, 0.0, 0.0, 0.0),
              width: connected ? w : Get.width,
              height: connected ? h : Get.height,
              child: InkWell(
                child: RTCVideoView(
                  switchRenderer ? localRenderer : remoteRenderer,
                  objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                  mirror: true,
                ),
                onTap: () {
                  // 点击切换 本地和远端 RTCVideoRenderer
                  if (connected) {
                    setState(() {
                      switchRenderer = !switchRenderer;
                    });
                  }
                },
              ),
              // decoration: const BoxDecoration(color: Colors.black54),
            );
            return Stack(
              children: <Widget>[
                // remote
                Positioned(
                  left: 0.0,
                  right: 0.0,
                  top: 0.0,
                  bottom: 0.0,
                  child: Container(
                    margin: const EdgeInsets.fromLTRB(0.0, 0.0, 0.0, 0.0),
                    width: Get.width,
                    height: Get.height,
                    child: InkWell(
                      onTap: () {
                        // 切换工具栏
                        setState(() {
                          showTool = !showTool;
                        });
                      },
                      child: RTCVideoView(
                        switchRenderer ? remoteRenderer : localRenderer,
                        objectFit:
                            RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                      ),
                    ),
                    decoration: const BoxDecoration(color: Colors.black54),
                  ),
                ),
                // local
                Positioned(
                  left: localX,
                  top: localY,
                  child: connected
                      ? Draggable(
                          child: localBox,
                          feedback: localBox,
                          childWhenDragging: const SizedBox.shrink(),
                          // 拖动中的回调
                          onDragEnd: (details) {
                            if (connected) {
                              setState(() {
                                localX = details.offset.dx;
                                localY = details.offset.dy;
                              });
                            }
                          },
                        )
                      : localBox,
                ),
                if (showTool)
                  Positioned(
                    top: 30,
                    left: 8,
                    child: InkWell(
                      onTap: (() {
                        setState(() {
                          minimized = true;
                        });
                      }),
                      child: Image.asset(
                        'assets/images/chat/minization-window.png',
                        height: 32,
                      ),
                    ),
                  ),
                if (showTool)
                  Positioned(
                    top: 40,
                    left: (Get.width - 64) / 2,
                    width: 64,
                    child: Text(
                      counter.show(),
                      style: const TextStyle(
                        color: Colors.white,
                      ),
                    ),
                  ),

                if (!connected)
                  Center(
                    child: Padding(
                      padding: EdgeInsets.only(top: Get.height * 0.3),
                      child: n.Column([
                        Avatar(
                          imgUri: widget.avatar,
                          width: 80,
                          height: 80,
                        ),
                        Padding(
                          padding: const EdgeInsets.only(
                            top: 12,
                            left: 12,
                            right: 12,
                          ),
                          child: Text(
                            widget.title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                            ),
                          ),
                        ),
                      ]),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
      DragArea(
          child: InkWell(
        onTap: () {
          minimized = false;
          setState(() {});
        },
        child: Container(
          decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: const Color(0xFFE5E6E9), width: 7)),
          padding: const EdgeInsets.all(12),
          child: n.Row([
            n.Column([
              n.Row(const [
                Padding(
                  padding: EdgeInsets.only(
                    top: 4,
                    right: 4,
                  ),
                  child: Icon(
                    Icons.call,
                    color: Colors.green,
                  ),
                ),
              ])
                ..crossAxisAlignment = CrossAxisAlignment.center
                ..height = 20,
            ]),
            n.Column([
              n.Row([
                Text(
                  counter.show(),
                  style: const TextStyle(
                    color: Colors.green,
                  ),
                ),
              ]),
              n.Row(const [
                Text(
                  "正在通话",
                  style: TextStyle(color: Colors.green),
                ),
              ]),
            ]),
          ])
            ..crossAxisAlignment = CrossAxisAlignment.start,
        ),
      ))
    ]);
  }
}
