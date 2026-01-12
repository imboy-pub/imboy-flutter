import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:get/get.dart';
import 'package:imboy/component/helper/counter.dart';
import 'package:imboy/component/helper/datetime.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/component/ui/avatar.dart';
import 'package:imboy/component/webrtc/dragable.dart';
import 'package:imboy/component/webrtc/enum.dart';
import 'package:imboy/component/webrtc/session.dart';

import 'package:imboy/service/event_bus.dart';
import 'package:imboy/service/events/common_events.dart';
import 'package:imboy/service/message.dart';
import 'package:imboy/store/model/contact_model.dart';
import 'package:imboy/store/model/webrtc_signaling_model.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:xid/xid.dart';

import 'p2p_call_screen_logic.dart';
import 'package:imboy/i18n/strings.g.dart';

// ignore: must_be_immutable
class P2pCallScreenPage extends StatefulWidget {
  final ContactModel peer;
  WebRTCSession session;
  final Map<String, dynamic> option;

  // option['media'] = video audio data

  final bool caller;
  final Function? closePage;

  P2pCallScreenPage({
    super.key,
    required this.peer,
    required this.session,
    required this.option,
    // 主叫者，发起通话人
    this.caller = true,
    required this.closePage,
  });

  @override
  // ignore: library_private_types_in_public_api
  _P2pCallScreenPageState createState() => _P2pCallScreenPageState();
}

class _P2pCallScreenPageState extends State<P2pCallScreenPage> {
  String msgId = '';

  final double localWidth = 114.0;
  final double localHeight = 72.0;

  // option['media'] = video audio data
  String media = 'video';
  var stateTips = '';
  double localX = 0.0;
  double localY = 0.0;

  // 计时器
  Counter counter = Counter(count: 0);

  bool switchRenderer = true;
  bool showTool = true;

  // 最小化的
  bool minimized = false;
  bool connected = false;
  bool microphoneOff = false;
  bool speakerOn = true;

  P2pCallScreenLogic? logic;
  StreamSubscription? subscription;

  RTCVideoRenderer localRenderer = RTCVideoRenderer();
  RTCVideoRenderer remoteRenderer = RTCVideoRenderer();

  Timer? answerTimer;

  @override
  void initState() {
    //监听Widget是否绘制完毕
    super.initState();
    msgId = widget.option['msgId'] ?? Xid().toString();
    counter.cleanUp();
    initData();
  }

  @override
  Future<void> dispose() async {
    msgId = '';
    super.dispose();
    await logic?.cleanUpP2P();
    await subscription?.cancel();
    await disposeRenderer();
    counter.cleanUp();
    logic?.sendBye(msgId);
    logic = null;
  }

  Future<void> disposeRenderer() async {
    try {
      if (localRenderer.textureId != null) {
        localRenderer.srcObject = null;
        await localRenderer.dispose();
      }
      if (remoteRenderer.textureId != null) {
        remoteRenderer.srcObject = null;
        await remoteRenderer.dispose();
      }
    } catch (e, s) {
      iPrint("disposeRenderer $e, $s");
    }
  }

  void initData() async {
    media = widget.option['media'] ?? 'video';
    debugPrint("> rtc initData view ${DateTime.now()}");

    // 设置Renderers
    await localRenderer.initialize();
    await remoteRenderer.initialize();

    logic = P2pCallScreenLogic(
      widget.session,
      caller: widget.caller,
      media: media,
    )..initState();

    if (widget.caller && (media == 'video' || media == 'audio')) {
      // 需要放在前面，避免更新的时候插入没有成功，导致消息状态异常
      await MessageService.to.addLocalMsg(
        media: media,
        caller: widget.caller,
        msgId: msgId,
        peer: widget.peer,
      );
    }

    debugPrint(
      "> rtc initData view pc ${widget.session.pc.toString()} ${DateTime.now()}",
    );

    logic?.onSignalingStateChange = (RTCSignalingState state) {
      debugPrint(
        "> rtc onSignalingStateChange view ${state.toString()} ${DateTime.now()}",
      );
    };

    logic
        ?.onCallStateChange = (WebRTCSession? s1, WebRTCCallState state) async {
      debugPrint(
        "> rtc onCallStateChange view ${state.toString()} ${DateTime.now()}",
      );
      switch (state) {
        case WebRTCCallState.CallStateInvite:
          break;
        case WebRTCCallState.CallStateNew:
          if (mounted) {
            setState(() {
              stateTips = t.waitingPeerAccept;
            });
          }
          answerTimer = Timer(const Duration(seconds: 60), () {
            if (mounted) {
              setState(() {
                stateTips = t.peerNoResponse;
              });
            }
            Future.delayed(const Duration(seconds: 2), () {
              _hangUp(sendBye: false, state: 2);
            });
          });
          break;
        case WebRTCCallState.CallStateRinging:
          // 呼入= Ringing
          if (widget.caller && mounted) {
            setState(() {
              stateTips = t.ringing;
            });
          }
          break;
        case WebRTCCallState.CallStateBye:
          if (mounted) {
            setState(() {
              counter.cleanUp();
              stateTips = t.peerHasHungUp;
            });
          }

          Future.delayed(const Duration(seconds: 2), () {
            _hangUp(
              sendBye: false,
              state: connected ? 1 : 3,
              endAt: DateTimeHelper.millisecond() - 2000,
            );
          });

          break;
        case WebRTCCallState.CallStateBusy:
          if (mounted) {
            setState(() {
              stateTips = t.busyTryAgainLater;
            });
          }
          Future.delayed(const Duration(seconds: 2), () {
            _hangUp(sendBye: false, state: 2);
          });
          break;
        case WebRTCCallState.CallStateConnected:
          debugPrint(
            "> rtc onCallStateChange view showTool $showTool; ${DateTime.now()}",
          );
          connectedAfter();
          break;
      }
    };

    logic?.onLocalStream = ((stream) {
      debugPrint(
        "> rtc stream onLocalStream view ${localRenderer.srcObject.toString()} ${DateTime.now()}",
      );

      if (mounted) {
        setState(() {
          localRenderer.srcObject = stream;
        });
      }
    });

    logic?.onAddRemoteStream = ((_, stream) {
      debugPrint(
        "> rtc stream onAddRemoteStream view $mounted, ${stream.toString()} ${DateTime.now()}",
      );
      debugPrint(
        "> rtc stream onAddRemoteStream view ${DateTime.now()}, ${remoteRenderer.srcObject.toString()}",
      );

      setState(() {
        remoteRenderer.srcObject = stream;
      });
    });

    logic?.onRemoveRemoteStream = ((_, stream) {
      debugPrint("> rtc onRemoveRemoteStream ${DateTime.now()}");
      if (mounted) {
        setState(() {
          remoteRenderer.srcObject = null;
        });
      }
    });

    debugPrint(
      "> rtc initData view pc ${widget.session.pc.toString()} ${DateTime.now()}",
    );

    widget.session = await logic!.createSession(
      widget.session,
      msgId: msgId,
      media: widget.option['media'] ?? 'video',
      screenSharing: false,
    );

    // 接收到新的消息订阅
    subscription = AppEventBus.on<WebRTCSignalingEvent>().listen((
      WebRTCSignalingEvent obj,
    ) async {
      await logic?.onMessageP2P(widget.session, WebRTCSignalingModel.fromJson(obj.data));
    });

    debugPrint("> rtc view widget.caller ${widget.caller} ${DateTime.now()}");

    if (widget.caller) {
      // 发起通话
      await logic?.invitePeer(
        msgId: msgId,
        peer: widget.peer.peerId,
        media: media,
      );
    } else {
      await logic?.onMessageP2P(
        widget.session,
        WebRTCSignalingModel(
          msgId: msgId,
          type: 'WEBRTC_OFFER',
          from: widget.peer.peerId,
          to: UserRepoLocal.to.currentUid,
          payload: widget.option,
        ),
      );
    }
  }

  /// WebRTCCallState.CallStateConnected 的时候触发
  void connectedAfter() {
    answerTimer?.cancel();
    setState(() {
      connected = true;
      localX = Get.width - 90;
      localY = 30;
    });
    debugPrint("> rtc CallStateConnected view $connected ; msgId $msgId;");
    MessageService.to.changeLocalMsgState(
      msgId,
      1,
      startAt: DateTimeHelper.millisecond(),
    );
    counter.start((Timer tm) {
      // 秒数+1，因为一秒回调一次
      counter.count += 1;
      // 更新界面
      stateTips = counter.show();
      if (mounted) setState(() {});
    });
  }

  Widget _buildPeerInfo() {
    return Center(
      child: Padding(
        padding: EdgeInsets.only(top: Get.height * 0.3),
        child: Column(
          children: [
            Avatar(imgUri: widget.peer.avatar, width: 80, height: 80),
            Padding(
              padding: const EdgeInsets.only(top: 12, left: 12, right: 12),
              child: Text(
                widget.peer.nickname,
                style: const TextStyle(color: Colors.white, fontSize: 24),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTools() {
    return SizedBox(
      width: 200.0,
      height: 180.0,
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // 麦克风
              FloatingActionButton(
                heroTag: 'microphone',
                tooltip: t.microphone,
                onPressed: () {
                  var res = logic?.turnMicrophone();
                  if (res != null) {
                    if (mounted) {
                      setState(() {
                        microphoneOff = res;
                      });
                    }
                  }
                },
                child: microphoneOff
                    ? const Icon(Icons.mic_off, color: Colors.white)
                    : const Icon(Icons.mic, color: Colors.white),
              ),
              if (media == 'audio')
                FloatingActionButton(
                  heroTag: 'hangup',
                  tooltip: t.hangup,
                  onPressed: () {
                    _hangUp(
                      state: connected ? 1 : 4,
                      endAt: DateTimeHelper.millisecond(),
                    );
                  },
                  backgroundColor: Colors.pink,
                  child: const Icon(Icons.call_end, color: Colors.white),
                ),
              // 扬声器开关
              FloatingActionButton(
                heroTag: 'loudspeaker',
                tooltip: t.loudspeaker,
                onPressed: () {
                  if (mounted) {
                    setState(() {
                      speakerOn = !speakerOn;
                      logic?.switchSpeaker(speakerOn);
                    });
                  }
                },
                child: speakerOn
                    ? const Icon(Icons.volume_up, color: Colors.white)
                    : const Icon(Icons.volume_off, color: Colors.white),
              ),
              if (media == 'video')
                FloatingActionButton(
                  heroTag: "switch_camera",
                  onPressed: logic?.switchCamera,
                  child: const Icon(Icons.switch_camera, color: Colors.white),
                ),
            ],
          ),
          if (media == 'video')
            Padding(
              padding: const EdgeInsets.only(left: 72, top: 20),
              child: FloatingActionButton(
                heroTag: "hangup",
                tooltip: t.hangup,
                onPressed: () {
                  _hangUp(
                    state: connected ? 1 : 4,
                    endAt: DateTimeHelper.millisecond(),
                  );
                },
                backgroundColor: Colors.pink,
                child: const Icon(Icons.call_end, color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDragArea() {
    return DragArea(
      child: InkWell(
        onTap: _zoom,
        child: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.onPrimaryContainer,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white10, width: 2),
          ),
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  SizedBox(
                    height: 20,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 4, right: 4),
                          child: Icon(
                            media == 'video' ? Icons.videocam : Icons.phone,
                            color: Colors.green,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              Column(
                children: [
                  Text(
                    counter.show(),
                    style: const TextStyle(color: Colors.green),
                  ),
                  Text(
                    t.calling,
                    style: const TextStyle(color: Colors.green),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRemoteVideo() {
    return Positioned(
      left: 0.0,
      top: 0.0,
      child: Container(
        margin: const EdgeInsets.fromLTRB(0.0, 0.0, 0.0, 0.0),
        width: Get.width,
        height: Get.height,
        child: InkWell(
          onTap: switchTools,
          child: RTCVideoView(
            switchRenderer ? remoteRenderer : localRenderer,
            objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
          ),
        ),
      ),
    );
  }

  Widget _buildLocalVideo() {
    return Positioned(
      right: localX,
      top: localY,
      child: GestureDetector(
        onPanUpdate: (details) {
          setState(() {
            localX += details.delta.dx;
            localY += details.delta.dy;
          });
        },
        child: Container(
          width: localWidth,
          height: localHeight,
          decoration: BoxDecoration(
            color: Colors.black,
            border: Border.all(color: Colors.white, width: 1.0),
          ),
          child: RTCVideoView(
            switchRenderer ? localRenderer : remoteRenderer,
            objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
          ),
        ),
      ),
    );
  }

  void switchTools() {
    setState(() {
      showTool = !showTool;
    });
  }

  void _zoom() {
    setState(() {
      minimized = !minimized;
    });
  }

  void _hangUp({bool sendBye = true, int state = 0, int endAt = 0}) {
    if (sendBye) {
      logic?.sendBye(msgId);
    }
    if (state > 0) {
      MessageService.to.changeLocalMsgState(
        msgId,
        state,
        endAt: endAt > 0 ? endAt : DateTimeHelper.millisecond(),
      );
    }
    Get.back();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          _buildRemoteVideo(),
          if (media == 'video') _buildLocalVideo(),
          if (showTool) _buildPeerInfo(),
          if (showTool && stateTips.isNotEmpty)
            Center(
              child: Padding(
                padding: EdgeInsets.only(top: Get.height * 0.2),
                child: Text(
                  stateTips,
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                ),
              ),
            ),
          if (showTool && connected)
            Positioned(bottom: 20, left: 0, right: 0, child: _buildTools()),
          if (!minimized)
            Positioned(top: 30, left: 10, child: _buildDragArea()),
        ],
      ),
    );
  }
}
