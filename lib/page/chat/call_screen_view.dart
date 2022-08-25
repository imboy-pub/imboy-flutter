import 'dart:core';

import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:get/get.dart';
import 'package:imboy/component/ui/avatar.dart';
import 'package:imboy/component/webrtc/dragable.dart';
import 'package:imboy/component/webrtc/signaling.dart';
import 'package:imboy/config/init.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:niku/namespace.dart' as n;

class CallScreenPage extends StatefulWidget {
  static String tag = 'call_sample';
  final String to;
  final String title;
  final String avatar;
  final String sign;
  final Function close;

  const CallScreenPage({
    Key? key,
    required this.to,
    required this.title,
    required this.avatar,
    this.sign = "",
    required this.close,
  }) : super(key: key);

  @override
  _CallScreenPageState createState() => _CallScreenPageState();
}

class _CallScreenPageState extends State<CallScreenPage> {
  Signaling? signaling;
  List<dynamic> peers = [];
  String? selfId;
  final RTCVideoRenderer localRenderer = RTCVideoRenderer();
  final RTCVideoRenderer remoteRenderer = RTCVideoRenderer();
  bool inCalling = true;

  Session? session;

  bool waitAccept = false;

  //
  double localX = 0;
  double localY = 30;

  bool connected = false;
  bool showTool = true;
  bool renderLocalRemote = true;

  bool isMinized = false;

  // ignore: unused_element
  _CallScreenPageState();

  @override
  initState() {
    super.initState();
    initRenderers();
    _connect();

    // 接收到新的消息订阅
    eventBus.on<Map>().listen((Map data) async {
      debugPrint(">>> ws rtc CallScreenPage initState: " + data.toString());
      signaling?.onMessage(data);
    });
    selfId = UserRepoLocal.to.currentUid;
    _invitePeer(context, widget.to, false);
  }

  initRenderers() async {
    await localRenderer.initialize();
    await remoteRenderer.initialize();
  }

  @override
  deactivate() {
    super.deactivate();
    localRenderer.dispose();
    remoteRenderer.dispose();
    if (signaling != null) {
      signaling?.close();
    }
    // if (floating != null) {
    //   floating?.close();
    // }
  }

  void _connect() async {
    debugPrint(">>> ws rtc _connect ");
    String from = UserRepoLocal.to.currentUid;
    signaling ??= Signaling(from, widget.to)..connect();
    signaling?.onSignalingStateChange = (SignalingState state) {
      debugPrint(
          ">>> ws rtc _connect onSignalingStateChange state ${state.toString()}");
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
          if (waitAccept) {
            debugPrint('peer reject');
            waitAccept = false;
            Navigator.of(context).pop(false);
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
            localX = 8;
            localY = 8;
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
        peers = event['peers'];
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
        localX = 8;
        localY = 30;
        connected = true;
      });
    }
  }

  // _reject() {
  //   if (session != null) {
  //     signaling?.reject(session!.sid);
  //   }
  // }

  _hangUp() {
    if (session != null) {
      signaling?.bye(session!.sid);
    }
    _close();
  }

  _close() {
    widget.close();
  }

  _switchCamera() {
    signaling?.switchCamera();
  }

  _muteMic() {
    signaling?.muteMic();
  }

  _buildRow(context, peer) {
    var self = (peer['id'] == selfId);
    return ListBody(children: <Widget>[
      ListTile(
        title: Text(self
            ? peer['name'] + ', ID: ${peer['id']} ' + ' [Your self]'
            : peer['name'] + ', ID: ${peer['id']} '),
        onTap: null,
        trailing: SizedBox(
          width: 100.0,
          child: n.Row(
            [
              IconButton(
                icon: Icon(self ? Icons.close : Icons.videocam,
                    color: self ? Colors.grey : Colors.black),
                onPressed: () => _invitePeer(context, peer['id'], false),
                tooltip: 'Video calling',
              ),
              IconButton(
                icon: Icon(self ? Icons.close : Icons.screen_share,
                    color: self ? Colors.grey : Colors.black),
                onPressed: () => _invitePeer(context, peer['id'], true),
                tooltip: 'Screen sharing',
              )
            ],
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
          ),
        ),
        subtitle: Text('[' + peer['user_agent'] + ']'),
      ),
      const Divider()
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return IndexedStack(index: isMinized ? 1 : 0, children: [
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
                  renderLocalRemote ? localRenderer : remoteRenderer,
                  objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                  mirror: true,
                ),
                onTap: () {
                  // 点击切换 本地和远端 RTCVideoRenderer
                  if (connected) {
                    setState(() {
                      renderLocalRemote = !renderLocalRemote;
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
                        renderLocalRemote ? remoteRenderer : localRenderer,
                        objectFit:
                            RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                      ),
                    ),
                    decoration: const BoxDecoration(color: Colors.black54),
                  ),
                ),
                // local
                Positioned(
                  right: localX,
                  top: localY,
                  child: Draggable(
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
                  ),
                ),
                Positioned(
                  top: 30,
                  left: 8,
                  child: InkWell(
                    onTap: (() {
                      setState(() {
                        isMinized = true;
                      });
                    }),
                    child: Image.asset(
                      'assets/images/chat/minization-window.png',
                      height: 32,
                    ),
                  ),
                ),
                Positioned(
                  top: 30,
                  left: Get.width / 2,
                  child: const Text(
                    "11:59",
                    style: TextStyle(
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
          isMinized = false;
          setState(() {});
        },
        child: Container(
          decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: const Color(0xFFE5E6E9), width: 7)),
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              const Icon(
                Icons.call,
                color: Colors.green,
              ),
              const Text(
                "正在通话",
                style: const TextStyle(color: Colors.green),
              )
            ],
          ),
        ),
      ))
    ]);
  }
}
