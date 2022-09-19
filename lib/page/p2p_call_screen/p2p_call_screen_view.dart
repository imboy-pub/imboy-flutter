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

class P2pCallScreenPage extends StatefulWidget {
  final String to;
  final String title;
  final String avatar;
  final String sign;
  // video audio data
  final String media;
  final bool callee;
  final Function close;

  WebRTCSignaling? signaling;
  WebRTCSession? session;

  P2pCallScreenPage({
    Key? key,
    required this.to,
    required this.title,
    required this.avatar,
    this.sign = "",
    this.media = 'video',
    // 被叫者
    this.callee = false,
    required this.close,
    this.signaling,
    this.session,
  }) : super(key: key);

  @override
  _P2pCallScreenState createState() => _P2pCallScreenState();
}

class _P2pCallScreenState extends State<P2pCallScreenPage> {
  WebRTCSignaling? signaling;
  WebRTCSession? session;
  final RTCVideoRenderer localRenderer = RTCVideoRenderer();
  final RTCVideoRenderer remoteRenderer = RTCVideoRenderer();

  //
  double localX = 0;
  double localY = 0;

  bool connected = false;
  bool showTool = true;
  bool switchRenderer = true;
  //麦克风 默认开启的
  bool micoff = false;
  // 最小化的
  bool minimized = false;
  // 计时器
  Counter counter = Counter(count: 0);

  // ignore: unused_element
  _P2pCallScreenState();

  @override
  initState() {
    super.initState();
    callScreenOn = true;
    initRenderers();
    signaling = widget.signaling;
    session = widget.session;
    _connect();
    if (widget.callee) {
      _accept();
    } else {
      _invitePeer(context, widget.to, widget.media);
    }
    // 接收到新的消息订阅
    eventBus
        .on<WebRTCSignalingModel>()
        .listen((WebRTCSignalingModel obj) async {
      debugPrint(">>> on rtc listen: " + obj.toJson().toString());
      signaling?.onMessage(obj);
    });
  }

  initRenderers() async {
    await localRenderer.initialize();
    await remoteRenderer.initialize();
  }

  @override
  deactivate() async {
    await _close();
    super.deactivate();
  }

  _close() async {
    if (remoteRenderer != null) {
      if (remoteRenderer.srcObject != null) remoteRenderer.srcObject = null;
      await remoteRenderer.dispose();
    }
    if (localRenderer != null) {
      if (localRenderer.srcObject != null) localRenderer.srcObject = null;
      await localRenderer.dispose();
    }
    if (signaling != null) {
      await signaling?.close();
    }
    counter.close();

    callScreenOn = false;
    widget.close();
  }

  void _connect() async {
    signaling ??= WebRTCSignaling(
      UserRepoLocal.to.currentUid,
      widget.to,
    )..connect();
    debugPrint(">>> ws rtc _connect ");
    signaling?.onSignalingStateChange = (WebRTCSignalingState state) {
      debugPrint(">>> ws rtc state _connect ${state.toString()}");
      switch (state) {
        case WebRTCSignalingState.ConnectionClosed:
          debugPrint(
              ">>> ws rtc state _connect ${WebRTCSignalingState.ConnectionClosed}");
          break;
        case WebRTCSignalingState.ConnectionError:
          debugPrint(
              ">>> ws rtc state _connect ${WebRTCSignalingState.ConnectionError}");
          break;
        case WebRTCSignalingState.ConnectionOpen:
          debugPrint(
              ">>> ws rtc cc state _connect ${WebRTCSignalingState.ConnectionOpen}");
          break;
      }
    };

    signaling?.onCallStateChange =
        (WebRTCSession s1, WebRTCCallState state) async {
      debugPrint(
          ">>> ws rtc cc onCallStateChange ${state.toString()}; session: ${s1.sid} ${s1.pid}");
      switch (state) {
        case WebRTCCallState.CallStateNew:
          setState(() {
            session = s1;
          });
          break;
        case WebRTCCallState.CallStateRinging:
          break;
        case WebRTCCallState.CallStateBye:
          _close();
          break;
        case WebRTCCallState.CallStateInvite:
          break;
        case WebRTCCallState.CallStateConnected:
          setState(() {
            localX = Get.width - 90;
            localY = 30;
            connected = true;

            debugPrint(
                ">>> ws rtc ccc2 ${DateTime.now()} _accept ${session.toString()} sid: ${session!.sid}");
          });
          counter.start((Timer tm) {
            if (!mounted) {
              return;
            }
            // 更新界面
            setState(() {
              // 秒数+1，因为一秒回调一次
              counter.count += 1;
            });
          });
          break;
      }
    };
    signaling?.onPeersUpdate = ((event) {
      debugPrint(">>> ws rtc _connect onPeersUpdate");
      setState(() {
        // peers = event['peers'];
      });
    });

    await localRenderer.initialize();
    signaling?.onLocalStream = ((stream) {
      debugPrint(">>> ws rtc _connect onLocalStream");
      localRenderer.srcObject = stream;
      if (mounted) {
        setState(() {});
      }
    });

    await remoteRenderer.initialize();
    signaling?.onAddRemoteStream = ((_, stream) {
      debugPrint(">>> ws rtc _connect onAddRemoteStream ${stream.toString()}");
      remoteRenderer.srcObject = stream;
      if (mounted) {
        setState(() {});
      }
    });

    signaling?.onRemoveRemoteStream = ((_, stream) {
      debugPrint(">>> ws rtc _connect onRemoveRemoteStream");
      remoteRenderer.srcObject = null;
    });
  }

  _invitePeer(BuildContext context, String peerId, String media) async {
    debugPrint(
        ">>> ws rtc cc ${DateTime.now()} _invitePeer ${signaling.toString()} ");
    if (signaling != null && peerId != UserRepoLocal.to.currentUid) {
      signaling?.invite(peerId, media);
      if (signaling?.localStream != null) {
        localRenderer.srcObject = signaling?.localStream;
      }
    }
  }

  _accept() async {
    debugPrint(
        ">>> ws rtc cc ${DateTime.now()} _accept ${session.toString()} sid: ${session!.sid}");
    if (session != null) {
      signaling?.accept(session!.sid);
      if (signaling?.localStream != null) {
        await localRenderer.initialize();
        localRenderer.srcObject = signaling?.localStream;
      }

      if (signaling!.remoteStreams.isNotEmpty) {
        await remoteRenderer.initialize();
        remoteRenderer.srcObject = signaling!.remoteStreams.first;
      }
      setState(() {
        localRenderer;
        remoteRenderer;
        // localRenderer 右上角
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
    deactivate();
  }

  _switchCamera() {
    signaling?.switchCamera();
  }

  _muteMic() {
    signaling?.muteMic();
    setState(() {
      micoff = !micoff;
    });
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
                      child: micoff
                          ? const Icon(Icons.mic_off)
                          : const Icon(Icons.mic),
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
                    left: (Get.width - 160) / 2,
                    width: 160,
                    child: Text(
                      connected ? counter.show() : '等待对方接受邀请...'.tr,
                      style: const TextStyle(
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.center,
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
