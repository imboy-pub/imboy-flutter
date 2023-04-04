import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:get/get.dart';
import 'package:imboy/component/helper/counter.dart';
import 'package:imboy/component/ui/avatar.dart';
import 'package:imboy/component/webrtc/dragable.dart';
import 'package:imboy/component/webrtc/enum.dart';
import 'package:imboy/component/webrtc/session.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/config/init.dart';
import 'package:imboy/store/model/user_model.dart';
import 'package:imboy/store/model/webrtc_signaling_model.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:niku/namespace.dart' as n;
// import 'package:permission_handler/permission_handler.dart';

import 'p2p_call_screen_logic.dart';

// ignore: must_be_immutable
class P2pCallScreenPage extends StatefulWidget {
  final UserModel peer;
  WebRTCSession session;
  final Map<String, dynamic> option;

  // option['media'] = video audio data

  final bool caller;
  final Function? closePage;

  P2pCallScreenPage({
    Key? key,
    required this.peer,
    required this.session,
    required this.option,
    // 主叫者，发起通话人
    this.caller = true,
    required this.closePage,
  }) : super(key: key);

  @override
  // ignore: library_private_types_in_public_api
  _P2pCallScreenPageState createState() => _P2pCallScreenPageState();
}

class _P2pCallScreenPageState extends State<P2pCallScreenPage> {
  final double localWidth = 114.0;
  final double localHeight = 72.0;
  String media = "";
  var stateTips = "";
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

  // final P2pCallScreenLogic logic = Get.find<P2pCallScreenLogic>();

  P2pCallScreenLogic? logic;
  StreamSubscription? subscription;

  RTCVideoRenderer localRenderer = RTCVideoRenderer();
  RTCVideoRenderer remoteRenderer = RTCVideoRenderer();

  Timer? answerTimer;

  @override
  void initState() {
    //监听Widget是否绘制完毕
    super.initState();
    counter.cleanUp();
    if (!mounted) {
      return;
    }
    initData();
  }

  @override
  Future<void> dispose() async {
    super.dispose();
    await logic?.cleanUpP2P();
    await subscription?.cancel();
    await disposeRenderer();
    counter.cleanUp();
    logic?.sendBye();
    logic = null;
  }

  Future<void> disposeRenderer() async {
    if (localRenderer.textureId != null) {
      localRenderer.srcObject = null;
      await localRenderer.dispose();
    }
    if (remoteRenderer.textureId != null) {
      remoteRenderer.srcObject = null;
      await remoteRenderer.dispose();
    }
  }

  initData() async {
    media = widget.option['media'] ?? 'video';
    debugPrint("> rtc initData view ${DateTime.now()}");
    // 设置Renderers
    await localRenderer.initialize();
    await remoteRenderer.initialize();
    logic ??= P2pCallScreenLogic(
      widget.session,
      iceConfiguration!,
      caller: widget.caller,
      media: media,
    )..signalingConnect();

    switchRenderer = widget.caller ? false : true;

    logic!.onSignalingStateChange = (RTCSignalingState state) {
      debugPrint(
          "> rtc onSignalingStateChange view ${state.toString()} ${DateTime.now()}");
      // switch (state) {
      //   case SignalingState.ConnectionClosed:
      //   case SignalingState.ConnectionError:
      //   case SignalingState.ConnectionOpen:
      //     break;
      // }
    };

    logic?.onCallStateChange =
        (WebRTCSession? s1, WebRTCCallState state) async {
      debugPrint(
          "> rtc onCallStateChange view ${state.toString()} ${DateTime.now()}");
      switch (state) {
        case WebRTCCallState.CallStateInvite:
          break;
        case WebRTCCallState.CallStateNew:
          setState(() {
            stateTips = '等待对方接受邀请...'.tr;
          });
          answerTimer = Timer(const Duration(seconds: 60), () {
            if (!mounted) {
              return;
            }
            setState(() {
              stateTips = '对方无应答...'.tr;
            });
            Future.delayed(const Duration(seconds: 2), () {
              _hangUp(sendBye: false);
            });
          });
          break;
        case WebRTCCallState.CallStateRinging:
          // 呼入= Ringing
          if (widget.caller) {
            setState(() {
              stateTips = '已响铃...'.tr;
            });
          }
          answerTimer?.cancel();
          break;
        case WebRTCCallState.CallStateBye:
          setState(() {
            counter.cleanUp();
            stateTips = '对方已挂断'.tr;
          });
          Future.delayed(const Duration(seconds: 2), () {
            _hangUp(sendBye: false);
          });

          break;
        case WebRTCCallState.CallStateBusy:
          setState(() {
            stateTips = '对方正忙，请稍后重试'.tr;
          });
          Future.delayed(const Duration(seconds: 2), () {
            _hangUp(sendBye: false);
          });
          break;
        case WebRTCCallState.CallStateConnected:
          debugPrint(
              "> rtc onCallStateChange view showTool $showTool; ${DateTime.now()}");
          connectedAfter();
          break;
      }
    };

    logic?.onLocalStream = ((stream) {
      debugPrint(
          "> rtc stream onLocalStream view ${localRenderer.srcObject.toString()} ${DateTime.now()}");

      setState(() {
        localRenderer.srcObject = stream;
      });
    });

    logic?.onAddRemoteStream = ((_, stream) {
      debugPrint(
          "> rtc stream onAddRemoteStream view ${stream.toString()} ${DateTime.now()}");
      debugPrint(
          "> rtc stream onAddRemoteStream view ${remoteRenderer.srcObject.toString()}");
      remoteRenderer.srcObject = stream;
      setState(() {});
    });

    logic?.onRemoveRemoteStream = ((_, stream) {
      debugPrint("> rtc onRemoveRemoteStream ${DateTime.now()}");
      setState(() {
        remoteRenderer.srcObject = null;
      });
    });

    debugPrint(
        "> rtc initData view pc ${widget.session.pc.toString()} ${DateTime.now()}");
    if (widget.session.pc == null) {
      widget.session = await logic!.createSession(
        widget.session,
        media: widget.option['media'] ?? 'video',
        screenSharing: false,
      );
    }
    debugPrint(
        "> rtc initData view pc ${widget.session.pc.toString()} ${DateTime.now()}");

    // 接收到新的消息订阅
    subscription ??= eventBus
        .on<WebRTCSignalingModel>()
        .listen((WebRTCSignalingModel obj) async {
      await logic?.onMessageP2P(obj);
    });

    debugPrint("> rtc view widget.caller ${widget.caller} ${DateTime.now()}");
    // createSession 一定要放在 绑定时间的后面
    if (widget.caller) {
      // 发起通话
      await logic?.invitePeer(
        widget.peer.uid,
        widget.option['media'] ?? 'video',
      );
    } else {
      await logic?.onMessageP2P(
        WebRTCSignalingModel(
          type: 'WEBRTC_OFFER',
          from: widget.peer.uid,
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
    debugPrint("> rtc CallStateConnected view $connected ;");
    counter.start((Timer tm) {
      setState(() {
        // 秒数+1，因为一秒回调一次
        counter.count += 1;
        // 更新界面
        stateTips = counter.show();
      });
    });
  }

  Widget _buildPeerInfo() {
    return Center(
      child: Padding(
        padding: EdgeInsets.only(top: Get.height * 0.3),
        child: n.Column([
          Avatar(
            imgUri: widget.peer.avatar,
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
              widget.peer.nickname,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
              ),
            ),
          ),
        ]),
      ),
    );
  }

  //tools
  Widget _buildTools() {
    return SizedBox(
      width: 200.0,
      height: 180.0,
      child: n.Column([
        n.Row(
          [
            // 麦克风
            FloatingActionButton(
              heroTag: "microphone",
              tooltip: "microphone".tr,
              onPressed: () {
                var res = logic?.turnMicrophone();
                if (res != null) {
                  setState(() {
                    microphoneOff = res;
                  });
                }
              },
              child: microphoneOff
                  ? const Icon(Icons.mic_off)
                  : const Icon(Icons.mic),
            ),
            if (media == 'audio')
              FloatingActionButton(
                heroTag: "hangup",
                tooltip: 'hangup'.tr,
                onPressed: _hangUp,
                backgroundColor: Colors.pink,
                child: const Icon(Icons.call_end),
              ),
            // 扬声器开关
            FloatingActionButton(
              heroTag: "loudspeaker",
              tooltip: "loudspeaker".tr,
              onPressed: () {
                setState(() {
                  speakerOn != speakerOn;
                  logic?.switchSpeaker(speakerOn);
                });
              },
              // child: const Icon(Icons.volume_up),
              child: speakerOn
                  ? const Icon(Icons.volume_up)
                  : const Icon(Icons.volume_off),
            ),
            if (media == 'video')
              FloatingActionButton(
                heroTag: "switch_camera",
                onPressed: logic?.switchCamera,
                child: const Icon(Icons.switch_camera),
              ),
          ],
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
        ),
        if (media == 'video')
          n.Row(
            [
              n.Padding(
                left: 72,
                top: 20,
                child: FloatingActionButton(
                  heroTag: "hangup",
                  tooltip: 'hangup'.tr,
                  onPressed: _hangUp,
                  backgroundColor: Colors.pink,
                  child: const Icon(Icons.call_end),
                ),
              ),
            ],
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
          ),
      ]),
    );
  }

  Widget _buildDragArea() {
    return DragArea(
      child: InkWell(
        onTap: _zoom,
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.AppBarColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white10, width: 2),
          ),
          padding: const EdgeInsets.all(12),
          child: n.Row([
            n.Column([
              n.Row([
                Padding(
                  padding: const EdgeInsets.only(
                    top: 4,
                    right: 4,
                  ),
                  child: Icon(
                    media == 'video' ? Icons.videocam : Icons.phone,
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
                )
              ]),
              n.Row([
                Text(
                  "正在通话".tr,
                  style: const TextStyle(color: Colors.green),
                ),
              ]),
            ]),
          ])
            ..crossAxisAlignment = CrossAxisAlignment.start,
        ),
      ),
    );
  }

  Widget _buildRemoteVideo() {
    return Positioned(
      left: 0.0,
      right: 0.0,
      top: 0.0,
      bottom: 0.0,
      child: Container(
        margin: const EdgeInsets.fromLTRB(0.0, 0.0, 0.0, 0.0),
        width: Get.width,
        height: Get.height,
        decoration: const BoxDecoration(color: Colors.black54),
        child: InkWell(
          onTap: switchTools,
          child: RTCVideoView(
            switchRenderer ? remoteRenderer : localRenderer,
            objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
            mirror: true,
          ),
        ),
      ),
    );
  }

  Widget _buildLocalVideo(double w, double h) {
    return Container(
      margin: const EdgeInsets.fromLTRB(0.0, 0.0, 0.0, 0.0),
      width: connected ? w : Get.width,
      height: connected ? h : Get.height,
      child: InkWell(
        child: RTCVideoView(
          switchRenderer ? localRenderer : remoteRenderer,
          // localRenderer,
          objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
          mirror: true,
        ),
        onTap: () {
          switchTools();
          // 点击切换 本地和远端 RTCVideoRenderer
          if (connected && media == 'video') {
            setState(() {
              switchRenderer = !switchRenderer;
            });
          }
        },
      ),
    );
  }

  /// 切换工具栏
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

  Future<void> _hangUp({bool sendBye = true}) async {
    debugPrint("> rtc hangUp 1");
    if (sendBye) {
      logic?.sendBye();
    }
    logic?.cleanUpP2P();
    await disposeRenderer();
    widget.closePage?.call();
  }

  @override
  Widget build(BuildContext context) {
    return IndexedStack(index: minimized ? 1 : 0, children: [
      Scaffold(
        floatingActionButtonLocation:
            FloatingActionButtonLocation.miniCenterFloat,
        floatingActionButton: showTool ? _buildTools() : null,
        body: OrientationBuilder(
          builder: (context, Orientation orientation) {
            double w = orientation == Orientation.portrait ? 90.0 : 120.0;
            double h = orientation == Orientation.portrait ? 120.0 : 90.0;

            Widget localVideo = _buildLocalVideo(w, h);
            return n.Stack(
              [
                // remote video
                _buildRemoteVideo(),

                // local video
                Positioned(
                  left: connected ? localX : 0,
                  top: connected ? localY : 0,
                  child: connected
                      ? Draggable(
                          feedback: localVideo,
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
                          child: localVideo,
                        )
                      : localVideo,
                ),

                if (showTool)
                  Positioned(
                    top: 32,
                    left: 8,
                    child: InkWell(
                      onTap: _zoom,
                      child: const Icon(
                        Icons.fullscreen_exit_rounded,
                        color: Colors.white,
                        size: 30.0,
                      ),
                      // child: const Icon(Icons.zoom_in_map_rounded, color:Colors.white,),
                    ),
                  ),
                if (showTool)
                  Positioned(
                    top: 40,
                    left: (Get.width - 160) / 2,
                    width: 160,
                    child: Text(
                      stateTips,
                      style: const TextStyle(
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),

                if ((connected == false && showTool) || media == 'audio')
                  _buildPeerInfo(),
              ],
            );
          },
        ),
      ),
      _buildDragArea(),
    ]);
  }
}
