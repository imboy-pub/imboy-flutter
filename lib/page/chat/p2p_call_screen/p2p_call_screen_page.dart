import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:imboy/component/helper/datetime.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/component/ui/avatar.dart';
import 'package:imboy/component/webrtc/enum.dart';
import 'package:imboy/component/webrtc/session.dart';
import 'package:imboy/page/chat/p2p_call_screen/p2p_call_constants.dart';
import 'package:imboy/page/chat/p2p_call_screen/p2p_call_screen_provider.dart'
    show
        p2pCallScreenProvider,
        P2pCallScreenState,
        P2pCallScreenNotifier,
        snapFloatingLeft;
import 'package:imboy/modules/messaging/public.dart';
import 'package:imboy/service/event_bus.dart';
import 'package:imboy/service/events/common_events.dart';
import 'package:imboy/store/model/webrtc_signaling_model.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/call_tokens.dart';
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

class _P2pCallScreenPageState extends ConsumerState<P2pCallScreenPage>
    with SingleTickerProviderStateMixin {
  String msgId = '';
  String media = 'video';
  StreamSubscription<dynamic>? subscription;

  RTCVideoRenderer localRenderer = RTCVideoRenderer();
  RTCVideoRenderer remoteRenderer = RTCVideoRenderer();
  bool switchRenderer = true;

  // 悬浮窗拖拽时无动画(0)、松手吸附时有动画(250ms)。
  Duration _floatAnim = Duration.zero;

  // dispose() 中不能再用 ref（widget 已卸载，BuildContext 失效）。
  // 在 initState 缓存 notifier 引用，供 dispose 安全调用。
  late final P2pCallScreenNotifier _notifier;

  // 连接态头像“呼吸光环”动画
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _notifier = ref.read(p2pCallScreenProvider.notifier);
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    msgId = widget.option['msgId'] as String? ?? Xid().toString();
    _initData();
  }

  @override
  void dispose() {
    // 在 dispose 之前发送 bye 消息通知对方（用缓存的 notifier，勿用 ref）
    if (msgId.isNotEmpty) {
      _notifier.sendBye(msgId);
    }

    // 同步清理：必须在 super.dispose() 之前完成
    msgId = '';
    subscription?.cancel();
    _pulse.dispose();

    // 先调用父类 dispose
    super.dispose();

    // 异步清理：在 super.dispose() 之后执行
    // 注意：这些操作可能在 widget 已销毁后执行，需要内部检查 mounted 状态
    _disposeRenderer();
    _notifier.cleanUpP2P();
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
    media = widget.option['media'] as String? ?? 'video';

    await localRenderer.initialize();
    await remoteRenderer.initialize();

    final notifier = _notifier;

    // 设置回调
    notifier.onSignalingStateChange = (RTCSignalingState state) {};

    notifier.onCallStateChange =
        (WebRTCSession? s1, WebRTCCallState state) async {
          switch (state) {
            case WebRTCCallState.callStateInvite:
              break;
            case WebRTCCallState.callStateNew:
              if (mounted) {
                notifier.updateStateTips(t.common.waitingPeerAccept);
              }
              notifier.startAnswerTimer(() {
                if (mounted) {
                  notifier.updateStateTips(t.common.peerNoResponse);
                }
                Future<dynamic>.delayed(
                  const Duration(milliseconds: CallTimeoutConfig.hangupDelay),
                  () {
                    if (!mounted) return;
                    _hangUp(sendBye: false, callState: CallStateCode.rejected);
                  },
                );
              });
              break;
            case WebRTCCallState.callStateRinging:
              if (widget.caller && mounted) {
                notifier.updateStateTips(t.main.ringing);
              }
              break;
            case WebRTCCallState.callStateBye:
              if (mounted) {
                final state = ref.read(p2pCallScreenProvider);
                notifier.stopCallTimer();
                notifier.updateStateTips(t.main.peerHasHungUp);
                Future<dynamic>.delayed(
                  const Duration(milliseconds: CallTimeoutConfig.hangupDelay),
                  () {
                    if (!mounted) return;
                    _hangUp(
                      sendBye: false,
                      callState: state.connected
                          ? CallStateCode.connected
                          : CallStateCode.peerHungUp,
                      endAt:
                          DateTimeHelper.millisecond() -
                          CallTimeoutConfig.hangupDelay,
                    );
                  },
                );
              }
              break;
            case WebRTCCallState.callStateBusy:
              if (mounted) {
                notifier.updateStateTips(t.chat.busyTryAgainLater);
              }
              Future<dynamic>.delayed(
                const Duration(milliseconds: CallTimeoutConfig.hangupDelay),
                () {
                  if (!mounted) return;
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
      if (mounted) {
        setState(() {
          localRenderer.srcObject = stream;
        });
      }
    });

    notifier.onAddRemoteStream = ((_, stream) {
      if (mounted) {
        setState(() {
          remoteRenderer.srcObject = stream;
        });
      }
    });

    notifier.onRemoveRemoteStream = ((_, stream) {
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
      await MessagingFacade.instance.addLocalMsg(
        media: media,
        caller: widget.caller,
        msgId: msgId,
        peer: widget.peer,
      );
      await notifier.invitePeer(
        msgId: msgId,
        peer: widget.peer.peerId.toString(),
        media: media,
      );
    } else {
      await notifier.onMessageP2P(
        updatedSession,
        WebRTCSignalingModel(
          msgId: msgId,
          type: 'WEBRTC_OFFER',
          from: widget.peer.peerId.toString(),
          to: UserRepoLocal.to.currentUid,
          payload: widget.option,
        ),
      );
    }
  }

  void _connectedAfter() {
    final notifier = _notifier;
    final size = MediaQuery.of(context).size;
    notifier.stopAnswerTimer();
    notifier.updateConnected(true, width: size.width);
    MessagingFacade.instance.changeLocalMsgState(
      msgId,
      CallStateCode.connected,
      startAt: DateTimeHelper.millisecond(),
    );
    notifier.startCallTimer(() {
      if (mounted) setState(() {});
    });
  }

  void _hangUp({bool sendBye = true, int callState = 0, int endAt = 0}) {
    if (sendBye) {
      _notifier.sendBye(msgId);
    }
    if (callState > 0) {
      MessagingFacade.instance.changeLocalMsgState(
        msgId,
        callState,
        endAt: endAt > 0 ? endAt : DateTimeHelper.millisecond(),
      );
    }
    // 通话页是通过 OverlayEntry 插入的（见 webrtc/func.dart），
    // 必须用 closePage 回调移除 overlay；用 Navigator.pop 会弹掉底层
    // go_router 页面并触发 "popped the last page" 断言崩溃。
    widget.closePage?.call();
  }

  // ===========================================================================
  // 表现层 / Presentation  —— 主题感知，参考 FaceTime / 微信通话观感
  // ===========================================================================

  bool get _isDark => Theme.of(context).brightness == Brightness.dark;

  /// 背景：对方头像高斯模糊铺底 + 深色渐变压暗（FaceTime 景深观感）。
  /// 连接态、音频、远端视频未到达时显示。
  Widget _buildGradientBackground() {
    final colors = _isDark
        ? [CallTokens.blackA45, CallTokens.blackA55, CallTokens.blackA82]
        : [
            CallTokens.bg1C2B44.withValues(alpha: 0.5),
            CallTokens.bg121E33.withValues(alpha: 0.6),
            CallTokens.bg080E1A.withValues(alpha: 0.85),
          ];
    return Positioned.fill(
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image(
            image: avatarImageProvider(widget.peer.avatar, w: 600),
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) =>
                const ColoredBox(color: CallTokens.bgDeep),
          ),
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: colors,
                  stops: const [0.0, 0.55, 1.0],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 连接态 / 音频的中部信息：呼吸光环头像 + 昵称 + 状态文案。
  Widget _buildConnectingInfo(P2pCallScreenState state) {
    final size = MediaQuery.of(context).size;
    final String statusText = state.stateTips.isNotEmpty
        ? state.stateTips
        : (state.connected ? state.callDuration : t.common.calling);

    return Positioned.fill(
      child: Padding(
        padding: EdgeInsets.only(top: size.height * 0.16),
        child: Column(
          children: [
            // 呼吸光环 + 头像
            AnimatedBuilder(
              animation: _pulse,
              builder: (context, child) {
                final glow = 0.25 + _pulse.value * 0.35;
                final spread = 2.0 + _pulse.value * 10.0;
                return Container(
                  width: 116,
                  height: 116,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: CallTokens.white24, width: 3),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: glow),
                        blurRadius: 28,
                        spreadRadius: spread,
                      ),
                    ],
                  ),
                  child: child,
                );
              },
              child: ClipOval(
                child: Avatar(
                  imgUri: widget.peer.avatar,
                  width: 116,
                  height: 116,
                ),
              ),
            ),
            const SizedBox(height: 22),
            Text(
              widget.peer.nickname,
              style: const TextStyle(
                color: CallTokens.white,
                fontSize: CallTokens.fs26,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  media == 'video' ? Icons.videocam : Icons.call,
                  size: 16,
                  color: CallTokens.white60,
                ),
                const SizedBox(width: 6),
                // 状态文案切换时淡入淡出（呼出→响铃→接通过渡更顺滑）。
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: Text(
                    statusText,
                    key: ValueKey<String>(statusText),
                    style: const TextStyle(
                      color: CallTokens.white70,
                      fontSize: CallTokens.fs15,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 顶部“网络不佳，正在重连…”横幅（接通后 ICE Disconnected/Failed 时显示）。
  /// 数据源是真实 ICE 连接态，非伪造信号格，断连时不会误显“良好”。
  Widget _buildReconnectingBanner() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        bottom: false,
        child: Center(
          child: Container(
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              color: CallTokens.blackA55,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 13,
                  height: 13,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      CallTokens.white70,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  t.common.reconnecting,
                  style: const TextStyle(
                    color: CallTokens.white,
                    fontSize: CallTokens.fs13,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 接通的视频通话：点屏显示的顶部信息条（昵称 + 通话时长）。
  /// [visible] 控制淡入淡出（点屏切换控件）。
  Widget _buildVideoTopInfo(P2pCallScreenState state, {required bool visible}) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: IgnorePointer(
        ignoring: !visible,
        child: AnimatedOpacity(
          opacity: visible ? 1 : 0,
          duration: const Duration(milliseconds: 220),
          child: DecoratedBox(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [CallTokens.black54, Colors.transparent],
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Column(
                  children: [
                    Text(
                      widget.peer.nickname,
                      style: const TextStyle(
                        color: CallTokens.white,
                        fontSize: CallTokens.fs18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      state.callDuration.isNotEmpty
                          ? state.callDuration
                          : t.common.calling,
                      style: const TextStyle(
                        color: CallTokens.white70,
                        fontSize: CallTokens.fs13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 通话中控制条：呼出与接通都常驻，挂断键始终可见且最醒目（红色）。
  /// [visible] 控制淡入淡出（接通视频点屏切换）。
  Widget _buildControlBar(P2pCallScreenState state, {required bool visible}) {
    final notifier = _notifier;
    final isVideo = media == 'video';

    // 岛内图标无文字标签（更现代、对齐 WhatsApp 2024 悬浮岛）；
    // a11y 仍靠 Semantics label 保留。
    final List<Widget> island = [
      _circleButton(
        icon: state.micOff ? Icons.mic_off : Icons.mic,
        label: t.common.microphone,
        active: !state.micOff,
        showLabel: false,
        onTap: () {
          notifier.turnMicrophone();
          if (mounted) setState(() {});
        },
      ),
      // 摄像头开关：视频通话才显示，复用 notifier.turnCamera（已有，禁用视频轨）
      if (isVideo)
        _circleButton(
          icon: state.cameraOff ? Icons.videocam_off : Icons.videocam,
          label: t.chat.video,
          active: !state.cameraOff,
          showLabel: false,
          onTap: () {
            notifier.turnCamera();
            if (mounted) setState(() {});
          },
        ),
      _circleButton(
        icon: state.speakerOn ? Icons.volume_up : Icons.volume_off,
        label: t.main.loudspeaker,
        active: state.speakerOn,
        showLabel: false,
        onTap: () {
          notifier.switchSpeaker(!state.speakerOn);
          if (mounted) setState(() {});
        },
      ),
      if (isVideo)
        _circleButton(
          icon: Icons.cameraswitch,
          label: t.common.switchCamera,
          showLabel: false,
          onTap: notifier.switchCamera,
        ),
      // 挂断键：实心红、整合进岛内末位，最醒目
      _circleButton(
        icon: Icons.call_end,
        label: t.main.hangup,
        showLabel: false,
        background: AppColors.getIosRed(Theme.of(context).brightness),
        onTap: () {
          HapticFeedback.mediumImpact();
          _hangUp(
            callState: state.connected
                ? CallStateCode.connected
                : CallStateCode.localHungUp,
            endAt: DateTimeHelper.millisecond(),
          );
        },
      ),
    ];

    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: IgnorePointer(
        ignoring: !visible,
        child: AnimatedOpacity(
          opacity: visible ? 1 : 0,
          duration: const Duration(milliseconds: 220),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: Center(
                // 悬浮“岛”：圆角 + 毛玻璃 + 半透明描边，浮于视频之上。
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(40),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: CallTokens.blackA32,
                        borderRadius: BorderRadius.circular(40),
                        border: Border.all(color: CallTokens.whiteA12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (final w in island)
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                              ),
                              child: w,
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 毛玻璃圆形控制按钮（≥56pt，满足 44pt 触达），可选文字标签。
  Widget _circleButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool active = true,
    bool showLabel = true,
    Color? background,
  }) {
    final bool solid = background != null;
    final Color bg = solid
        ? background
        : (active ? CallTokens.whiteA22 : CallTokens.whiteA08);
    final Color fg = solid
        ? CallTokens.white
        : (active ? CallTokens.white : CallTokens.white54);
    return Semantics(
      button: true,
      label: label.isNotEmpty ? label : null,
      toggled: solid ? null : active,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipOval(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Material(
                color: bg,
                shape: const CircleBorder(),
                child: InkWell(
                  onTap: () {
                    // 实心主按钮（挂断）自带 mediumImpact，避免双重触感
                    if (!solid) HapticFeedback.selectionClick();
                    onTap();
                  },
                  customBorder: const CircleBorder(),
                  child: SizedBox(
                    width: 58,
                    height: 58,
                    child: Icon(icon, color: fg, size: 26),
                  ),
                ),
              ),
            ),
          ),
          if (showLabel && label.isNotEmpty) ...[
            const SizedBox(height: 7),
            Text(
              label,
              style: const TextStyle(
                color: CallTokens.white70,
                fontSize: CallTokens.fs12,
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// 接通后的本地摄像头小窗（可拖拽，圆角描边）。
  Widget _buildLocalVideo() {
    final state = ref.watch(p2pCallScreenProvider);
    final notifier = _notifier;
    final localWidth = LocalVideoConfig.width;
    final localHeight = LocalVideoConfig.height;

    return Positioned(
      right: state.localX,
      top: state.localY,
      child: GestureDetector(
        // 点小窗交换主次画面（FaceTime 同款：点自己的小窗 → 自己上大屏）
        onTap: () {
          HapticFeedback.selectionClick();
          if (mounted) setState(() => switchRenderer = !switchRenderer);
        },
        onPanUpdate: (details) {
          notifier.updateLocalPosition(
            state.localX + details.delta.dx,
            state.localY + details.delta.dy,
          );
        },
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Container(
            width: localWidth,
            height: localHeight,
            decoration: BoxDecoration(
              color: CallTokens.black,
              border: Border.all(color: CallTokens.white30, width: 1.0),
              borderRadius: BorderRadius.circular(14),
              boxShadow: const [
                BoxShadow(color: CallTokens.black54, blurRadius: 10),
              ],
            ),
            child: state.cameraOff
                ? const ColoredBox(
                    color: CallTokens.bg1A1A1A,
                    child: Center(
                      child: Icon(
                        Icons.videocam_off,
                        color: CallTokens.white38,
                        size: 28,
                      ),
                    ),
                  )
                : RTCVideoView(
                    switchRenderer ? localRenderer : remoteRenderer,
                    objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                  ),
          ),
        ),
      ),
    );
  }

  /// 接通后的远端视频（铺满，点屏切换控件显隐）。
  Widget _buildRemoteVideo() {
    return Positioned.fill(
      child: GestureDetector(
        onTap: () => _notifier.toggleShowTool(),
        child: RTCVideoView(
          switchRenderer ? remoteRenderer : localRenderer,
          objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
        ),
      ),
    );
  }

  /// 顶部左上角“最小化”按钮：缩成可拖拽悬浮窗，通话不中断（微信/FaceTime 观感）。
  /// [visible] 控制淡入淡出（接通视频点屏切换）。
  Widget _buildMinimizeButton({required bool visible}) {
    return Positioned(
      top: 0,
      left: 0,
      child: IgnorePointer(
        ignoring: !visible,
        child: AnimatedOpacity(
          opacity: visible ? 1 : 0,
          duration: const Duration(milliseconds: 220),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.only(left: 8, top: 4),
              child: Semantics(
                button: true,
                label: t.common.minimize,
                child: ClipOval(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Material(
                      color: CallTokens.whiteA18,
                      shape: const CircleBorder(),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: () {
                          HapticFeedback.selectionClick();
                          // 用 MediaQuery 算出右上角初始位（小窗宽 ~108）。
                          final size = MediaQuery.of(context).size;
                          _notifier.enterFloating(size.width - 118, 70);
                        },
                        child: const SizedBox(
                          width: 44,
                          height: 44,
                          child: Icon(
                            Icons.fullscreen_exit,
                            color: CallTokens.white,
                            size: 24,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 悬浮窗：最小化后的可拖拽小窗。视频显示远端画面，音频显示头像 + 时长；
  /// 点击复原全屏。渲染器实例保持存活，通话全程不中断。
  Widget _buildFloatingWindow(P2pCallScreenState state) {
    const double w = 108;
    const double h = 156;
    final bool showRemoteVideo = media == 'video' && state.connected;

    final Widget inner = showRemoteVideo
        ? RTCVideoView(
            remoteRenderer,
            objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
          )
        : DecoratedBox(
            decoration: const BoxDecoration(color: CallTokens.bg0E1A2B),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ClipOval(
                    child: Avatar(
                      imgUri: widget.peer.avatar,
                      width: 44,
                      height: 44,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    state.connected ? state.callDuration : t.common.calling,
                    style: const TextStyle(
                      color: CallTokens.white70,
                      fontSize: CallTokens.fs11,
                    ),
                  ),
                ],
              ),
            ),
          );

    // 透明 Stack：仅小窗拦截触摸，其余区域穿透到底层 app。
    return Stack(
      children: [
        AnimatedPositioned(
          duration: _floatAnim,
          curve: Curves.easeOutCubic,
          left: state.floatX,
          top: state.floatY,
          child: GestureDetector(
            onTap: () => _notifier.toggleMinimized(),
            onPanUpdate: (d) {
              if (_floatAnim != Duration.zero && mounted) {
                setState(() => _floatAnim = Duration.zero);
              }
              final size = MediaQuery.of(context).size;
              final nx = (state.floatX + d.delta.dx).clamp(0.0, size.width - w);
              final ny = (state.floatY + d.delta.dy).clamp(
                0.0,
                size.height - h,
              );
              _notifier.updateFloatPosition(nx, ny);
            },
            onPanEnd: (_) {
              // 松手吸附到最近的左/右边缘（FaceTime PiP 同款）。
              final size = MediaQuery.of(context).size;
              final snappedX = snapFloatingLeft(
                currentLeft: state.floatX,
                windowWidth: w,
                screenWidth: size.width,
              );
              if (mounted) {
                setState(() => _floatAnim = const Duration(milliseconds: 250));
              }
              _notifier.updateFloatPosition(snappedX, state.floatY);
            },
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Container(
                width: w,
                height: h,
                decoration: BoxDecoration(
                  color: CallTokens.black,
                  border: Border.all(color: CallTokens.white24, width: 1),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: const [
                    BoxShadow(color: CallTokens.black54, blurRadius: 14),
                  ],
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    inner,
                    // 右上角放大提示
                    const Positioned(
                      top: 4,
                      right: 4,
                      child: Icon(
                        Icons.fullscreen,
                        color: CallTokens.white70,
                        size: 18,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(p2pCallScreenProvider);

    // 最小化：仅渲染透明悬浮窗，让用户在底层 app 上继续操作（通话不挂断）。
    if (state.minimized) {
      return Material(
        type: MaterialType.transparency,
        child: _buildFloatingWindow(state),
      );
    }

    final isVideo = media == 'video';
    // 仅“接通的视频通话”才有远端画面铺满；其余（呼出 / 音频）走渐变 + 头像。
    final hasRemoteVideo = isVideo && state.connected;
    // 控件可见性：音频/呼出常驻；接通视频点屏切换。淡入淡出替代硬切。
    final bool toolsVisible = !hasRemoteVideo || state.showTool;

    return Scaffold(
      backgroundColor: CallTokens.black,
      body: Stack(
        children: [
          // 1. 背景层
          if (hasRemoteVideo)
            _buildRemoteVideo()
          else
            _buildGradientBackground(),

          // 2. 接通的视频：本地小窗
          if (hasRemoteVideo) _buildLocalVideo(),

          // 3. 呼出 / 音频：中部头像 + 昵称 + 状态
          if (!hasRemoteVideo) _buildConnectingInfo(state),

          // 4. 接通的视频：顶部昵称 + 时长（点屏淡入淡出）
          if (hasRemoteVideo)
            _buildVideoTopInfo(state, visible: state.showTool),

          // 5. 网络不佳横幅（接通后 ICE 重连中）——真实连接态驱动
          if (state.connected && state.reconnecting) _buildReconnectingBanner(),

          // 6. 顶部左上角最小化按钮（淡入淡出）
          _buildMinimizeButton(visible: toolsVisible),

          // 7. 底部控制条（淡入淡出）。挂断键始终可达。
          _buildControlBar(state, visible: toolsVisible),
        ],
      ),
    );
  }
}
