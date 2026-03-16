import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:imboy/component/helper/datetime.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/component/ui/avatar.dart';
import 'package:imboy/component/webrtc/dragable.dart';
import 'package:imboy/component/webrtc/enum.dart';
import 'package:imboy/component/webrtc/session.dart';
import 'package:imboy/page/chat/p2p_call_screen/p2p_call_constants.dart';
import 'package:imboy/page/chat/p2p_call_screen/p2p_call_screen_provider.dart'
    show p2pCallScreenProvider;
import 'package:imboy/modules/messaging/public.dart';
import 'package:imboy/service/event_bus.dart';
import 'package:imboy/service/events/common_events.dart';
import 'package:imboy/store/model/webrtc_signaling_model.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/theme/default/app_radius.dart';
import 'package:xid/xid.dart';

/// P2P 音视频通话页面
class P2pCallScreenPage extends ConsumerStatefulWidget {
  final ContactModel peer;
  final WebRTCSession session;
  final Map<String, dynamic> option;
  final bool caller;
  final Function? closePage;

  const P2pCallScreenPage({
    super.key,
    required this.peer,
    required this.session,
    required this.option,
    this.caller = true,
    this.closePage,
  });

  @override
  ConsumerState<P2pCallScreenPage> createState() => _P2pCallScreenPageState();
}

class _P2pCallScreenPageState extends ConsumerState<P2pCallScreenPage> {
  String msgId = '';
  String media = 'video';
  StreamSubscription? subscription;

  RTCVideoRenderer localRenderer = RTCVideoRenderer();
  RTCVideoRenderer remoteRenderer = RTCVideoRenderer();
  bool switchRenderer = true;

  @override
  void initState() {
    super.initState();
    msgId = widget.option['msgId'] ?? Xid().toString();
    _initData();
  }

  @override
  void dispose() {
    // 在 dispose 之前发送 bye 消息通知对方
    if (msgId.isNotEmpty) {
      ref.read(p2pCallScreenProvider.notifier).sendBye(msgId);
    }

    // 同步清理：必须在 super.dispose() 之前完成
    msgId = '';
    subscription?.cancel();

    // 先调用父类 dispose
    super.dispose();

    // 异步清理：在 super.dispose() 之后执行
    // 注意：这些操作可能在 widget 已销毁后执行，需要内部检查 mounted 状态
    _disposeRenderer();
    ref.read(p2pCallScreenProvider.notifier).cleanUpP2P();
  }

  Future<void> _disposeRenderer() async {
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

  Future<void> _initData() async {
    media = widget.option['media'] ?? 'video';
    debugPrint("> rtc initData view ${DateTime.now()}");

    await localRenderer.initialize();
    await remoteRenderer.initialize();

    final notifier = ref.read(p2pCallScreenProvider.notifier);

    // 设置回调
    notifier.onSignalingStateChange = (RTCSignalingState state) {
      debugPrint("> rtc onSignalingStateChange view ${state.toString()}");
    };

    notifier.onCallStateChange =
        (WebRTCSession? s1, WebRTCCallState state) async {
          debugPrint("> rtc onCallStateChange view ${state.toString()}");
          switch (state) {
            case WebRTCCallState.callStateInvite:
              break;
            case WebRTCCallState.callStateNew:
              if (mounted) {
                notifier.updateStateTips(t.waitingPeerAccept);
              }
              notifier.startAnswerTimer(() {
                if (mounted) {
                  notifier.updateStateTips(t.peerNoResponse);
                }
                Future.delayed(
                  const Duration(milliseconds: CallTimeoutConfig.hangupDelay),
                  () {
                    _hangUp(
                      sendBye: false,
                      callState: CallStateCode.rejected,
                    );
                  },
                );
              });
              break;
            case WebRTCCallState.callStateRinging:
              if (widget.caller && mounted) {
                notifier.updateStateTips(t.ringing);
              }
              break;
            case WebRTCCallState.callStateBye:
              if (mounted) {
                final state = ref.read(p2pCallScreenProvider);
                notifier.stopCallTimer();
                notifier.updateStateTips(t.peerHasHungUp);
                Future.delayed(
                  const Duration(milliseconds: CallTimeoutConfig.hangupDelay),
                  () {
                    _hangUp(
                      sendBye: false,
                      callState: state.connected
                          ? CallStateCode.connected
                          : CallStateCode.peerHungUp,
                      endAt: DateTimeHelper.millisecond() -
                          CallTimeoutConfig.hangupDelay,
                    );
                  },
                );
              }
              break;
            case WebRTCCallState.callStateBusy:
              if (mounted) {
                notifier.updateStateTips(t.busyTryAgainLater);
              }
              Future.delayed(
                const Duration(milliseconds: CallTimeoutConfig.hangupDelay),
                () {
                  _hangUp(sendBye: false, callState: CallStateCode.busy);
                },
              );
              break;
            case WebRTCCallState.callStateConnected:
              _connectedAfter();
              break;
          }
        };

    notifier.onLocalStream = ((stream) {
      debugPrint("> rtc stream onLocalStream view ${DateTime.now()}");
      if (mounted) {
        setState(() {
          localRenderer.srcObject = stream;
        });
      }
    });

    notifier.onAddRemoteStream = ((_, stream) {
      debugPrint("> rtc stream onAddRemoteStream view ${DateTime.now()}");
      if (mounted) {
        setState(() {
          remoteRenderer.srcObject = stream;
        });
      }
    });

    notifier.onRemoveRemoteStream = ((_, stream) {
      debugPrint("> rtc onRemoveRemoteStream ${DateTime.now()}");
      if (mounted) {
        setState(() {
          remoteRenderer.srcObject = null;
        });
      }
    });

    // 初始化会话
    final updatedSession = await notifier.createSession(
      widget.session,
      msgId: msgId,
      media: media,
      screenSharing: false,
    );

    // 订阅信令消息
    subscription = AppEventBus.on<WebRTCSignalingEvent>().listen((
      WebRTCSignalingEvent obj,
    ) async {
      await notifier.onMessageP2P(
        updatedSession,
        WebRTCSignalingModel.fromJson(obj.data),
      );
    });

    // 发起或接听通话
    if (widget.caller) {
      await MessageService.to.addLocalMsg(
        media: media,
        caller: widget.caller,
        msgId: msgId,
        peer: widget.peer,
      );
      await notifier.invitePeer(
        msgId: msgId,
        peer: widget.peer.peerId,
        media: media,
      );
    } else {
      await notifier.onMessageP2P(
        updatedSession,
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

  void _connectedAfter() {
    final notifier = ref.read(p2pCallScreenProvider.notifier);
    final size = MediaQuery.of(context).size;
    notifier.stopAnswerTimer();
    notifier.updateConnected(true, width: size.width);
    MessageService.to.changeLocalMsgState(
      msgId,
      CallStateCode.connected,
      startAt: DateTimeHelper.millisecond(),
    );
    notifier.startCallTimer(() {
      if (mounted) setState(() {});
    });
  }

  Widget _buildPeerInfo() {
    return Center(
      child: Padding(
        padding: EdgeInsets.only(
          top: MediaQuery.of(context).size.height *
              CallUILayoutConfig.peerInfoTopRatio,
        ),
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
    final state = ref.watch(p2pCallScreenProvider);
    final notifier = ref.read(p2pCallScreenProvider.notifier);
    return SizedBox(
      width: 200.0,
      height: 180.0,
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              FloatingActionButton(
                heroTag: 'microphone',
                tooltip: t.microphone,
                onPressed: () {
                  final res = notifier.turnMicrophone();
                  if (res != null && mounted) {
                    // 状态会通过 notifier 内部更新
                    setState(() {});
                  }
                },
                child: state.micOff
                    ? const Icon(Icons.mic_off, color: Colors.white)
                    : const Icon(Icons.mic, color: Colors.white),
              ),
              if (media == 'audio')
                FloatingActionButton(
                  heroTag: 'hangup',
                  tooltip: t.hangup,
                  onPressed: () {
                    _hangUp(
                      callState: state.connected
                          ? CallStateCode.connected
                          : CallStateCode.localHungUp,
                      endAt: DateTimeHelper.millisecond(),
                    );
                  },
                  backgroundColor: Colors.pink,
                  child: const Icon(Icons.call_end, color: Colors.white),
                ),
              FloatingActionButton(
                heroTag: 'loudspeaker',
                tooltip: t.loudspeaker,
                onPressed: () {
                  final newSpeakerOn = !state.speakerOn;
                  notifier.switchSpeaker(newSpeakerOn);
                  if (mounted) {
                    setState(() {
                      // 触发重建以获取最新状态
                    });
                  }
                },
                child: state.speakerOn
                    ? const Icon(Icons.volume_up, color: Colors.white)
                    : const Icon(Icons.volume_off, color: Colors.white),
              ),
              if (media == 'video')
                FloatingActionButton(
                  heroTag: "switch_camera",
                  onPressed: notifier.switchCamera,
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
                    callState: state.connected
                        ? CallStateCode.connected
                        : CallStateCode.localHungUp,
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
    final state = ref.watch(p2pCallScreenProvider);
    return DragArea(
      child: InkWell(
        onTap: ref.read(p2pCallScreenProvider.notifier).toggleMinimized,
        child: Container(
          constraints: const BoxConstraints(
            minWidth: LocalVideoConfig.minWidth,
            minHeight: LocalVideoConfig.minHeight,
          ),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.onPrimaryContainer,
            borderRadius: AppRadius.borderRadiusMedium,
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
                    state.callDuration,
                    style: const TextStyle(color: Colors.green),
                  ),
                  Text(t.calling, style: const TextStyle(color: Colors.green)),
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
        width: MediaQuery.of(context).size.width,
        height: MediaQuery.of(context).size.height,
        child: InkWell(
          onTap: () =>
              ref.read(p2pCallScreenProvider.notifier).toggleShowTool(),
          child: RTCVideoView(
            switchRenderer ? remoteRenderer : localRenderer,
            objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
          ),
        ),
      ),
    );
  }

  Widget _buildLocalVideo() {
    final state = ref.watch(p2pCallScreenProvider);
    final notifier = ref.read(p2pCallScreenProvider.notifier);
    final localWidth = LocalVideoConfig.width;
    final localHeight = LocalVideoConfig.height;

    return Positioned(
      right: state.localX,
      top: state.localY,
      child: GestureDetector(
        onPanUpdate: (details) {
          notifier.updateLocalPosition(
            state.localX + details.delta.dx,
            state.localY + details.delta.dy,
          );
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

  void _hangUp({bool sendBye = true, int callState = 0, int endAt = 0}) {
    final notifier = ref.read(p2pCallScreenProvider.notifier);
    if (sendBye) {
      notifier.sendBye(msgId);
    }
    if (callState > 0) {
      MessageService.to.changeLocalMsgState(
        msgId,
        callState,
        endAt: endAt > 0 ? endAt : DateTimeHelper.millisecond(),
      );
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(p2pCallScreenProvider);
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          _buildRemoteVideo(),
          if (media == 'video') _buildLocalVideo(),
          if (state.showTool) _buildPeerInfo(),
          if (state.showTool && state.stateTips.isNotEmpty)
            Center(
              child: Padding(
                padding: EdgeInsets.only(
                  top: MediaQuery.of(context).size.height *
                      CallUILayoutConfig.stateTipsTopRatio,
                ),
                child: Text(
                  state.stateTips,
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                ),
              ),
            ),
          if (state.showTool && state.connected)
            Positioned(
              bottom: CallUILayoutConfig.toolbarBottomSpacing,
              left: 0,
              right: 0,
              child: _buildTools(),
            ),
          if (!state.minimized)
            Positioned(
              top: CallUILayoutConfig.dragAreaTopSpacing,
              left: CallUILayoutConfig.dragAreaLeftSpacing,
              child: _buildDragArea(),
            ),
        ],
      ),
    );
  }
}
