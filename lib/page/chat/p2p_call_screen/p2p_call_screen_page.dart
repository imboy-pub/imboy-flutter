import 'dart:async';
import 'dart:math' as math;

import 'package:imboy/theme/default/app_spacing.dart';

import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:imboy/component/helper/datetime.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/component/ui/avatar.dart';
import 'package:imboy/component/webrtc/enum.dart';
import 'package:imboy/component/webrtc/func.dart';
import 'package:imboy/component/webrtc/func.dart' as webrtc_func;
import 'package:imboy/config/init.dart' show p2pCallSignalingReady;
import 'package:imboy/component/webrtc/media_permission.dart';
import 'package:imboy/component/webrtc/session.dart';
import 'package:imboy/page/chat/p2p_call_screen/p2p_call_constants.dart';
import 'package:imboy/page/chat/p2p_call_screen/p2p_call_state_machine.dart';
import 'package:imboy/page/chat/p2p_call_screen/p2p_call_screen_provider.dart'
    show
        p2pCallScreenProvider,
        P2pCallScreenState,
        P2pCallScreenNotifier,
        snapFloatingLeft,
        shouldSwapVideoLayout;
import 'package:imboy/modules/messaging/public.dart';
import 'package:imboy/service/event_bus.dart';
import 'package:imboy/service/events/common_events.dart';
import 'package:imboy/store/model/webrtc_signaling_model.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/call_tokens.dart';
import 'package:imboy/theme/default/font_types.dart';
import 'package:xid/xid.dart';

/// P2P 音视频通话页面（LiveKit SFU 媒体面，信令/状态机/UX 与 P2P 时代一致）
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
    with TickerProviderStateMixin {
  String msgId = '';
  String media = 'video';
  StreamSubscription<dynamic>? subscription;

  // 接通 / 结束收尾的一次性闩，见 _applySignal。
  bool _connectedHandled = false;
  bool _closeScheduled = false;
  // 默认对端主画面、本端小窗；点击小窗或上下滑动主画面可以交换。
  bool _localOnMain = false;

  // 拖拽过程中使用独立基准，避免 Provider 每次更新后闭包使用旧坐标，
  // 造成快速拖动时跳动或只应用最后一帧 delta。
  double? _videoDragRight;
  double? _videoDragTop;
  Duration _videoAnim = Duration.zero;

  // 悬浮窗拖拽时无动画(0)、松手吸附时有动画(250ms)。
  Duration _floatAnim = Duration.zero;

  // dispose() 中不能再用 ref（widget 已卸载，BuildContext 失效）。
  // 在 initState 缓存 notifier 引用，供 dispose 安全调用。
  late final P2pCallScreenNotifier _notifier;

  /// 已通过挂断路径发过 bye 的闩：dispose 不再补发。旧实现每次本地挂断
  /// 双发 bye（按钮一次 + dispose 一次），冗余流量且迟到 bye 有干扰风险。
  bool _byeSent = false;

  // 连接态头像“呼吸光环”动画
  late final AnimationController _pulse;

  // 入场淡入（FaceTime 进场观感），FadeTransition 复用同一 Animation 免每帧重建。
  late final AnimationController _entrance;
  late final Animation<double> _entranceOpacity;
  bool _entranceStarted = false;

  /// Room 未接入时 ListenableBuilder 的占位监听（不通知）。
  static final Listenable _idleListenable = ChangeNotifier();

  @override
  void initState() {
    super.initState();
    _notifier = ref.read(p2pCallScreenProvider.notifier);
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _entrance = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    );
    _entranceOpacity = CurvedAnimation(
      parent: _entrance,
      curve: Curves.easeOut,
    );
    msgId = widget.option['msgId'] as String? ?? Xid().toString();

    // Android 系统返回键 = 最小化通话（见 func.dart 的哑路由说明），
    // 而不是弹掉通话页下方的业务路由。
    webrtc_func.p2pCallSystemBackHandler = () {
      if (!mounted) return;
      final size = MediaQuery.sizeOf(context);
      _notifier.enterFloating(size.width - 118, 70);
    };

    _initData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 尊重系统“减弱动态效果”(WCAG 2.3.3): 关闭无限呼吸动画，定格稳态光环。
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    if (reduceMotion && _pulse.isAnimating) {
      _pulse.stop();
      _pulse.value = 0.5;
    } else if (!reduceMotion && !_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    }
    if (!_entranceStarted) {
      _entranceStarted = true;
      // Reduce Motion 时瞬时呈现，不做淡入。
      if (reduceMotion) {
        _entrance.value = 1;
      } else {
        _entrance.forward();
      }
    }
  }

  @override
  void dispose() {
    // 在 dispose 之前发送 bye 消息通知对方（用缓存的 notifier，勿用 ref）；
    // 挂断按钮路径已发过（_byeSent）则跳过，避免双发。sendBye 同时释放
    // LiveKit Room（离开房间 + 释放 track/连接）。
    if (msgId.isNotEmpty && !_byeSent) {
      _notifier.sendBye(msgId);
    }
    // 复位信令就绪标志，为下一通通话恢复 pending 排队语义。
    p2pCallSignalingReady = false;

    // 同步清理：必须在 super.dispose() 之前完成
    msgId = '';
    subscription?.cancel();
    _pulse.dispose();
    _entrance.dispose();

    // 先调用父类 dispose
    super.dispose();

    // 异步清理：在 super.dispose() 之后执行
    // 注意：这些操作可能在 widget 已销毁后执行，需要内部检查 mounted 状态
    _notifier.cleanUpP2P();
  }

  Future<void> _initData() async {
    media = widget.option['media'] as String? ?? 'video';

    final notifier = _notifier;

    // 会话角色接线：provider.caller/media/msgId 实例字段供信令路径使用。
    notifier.initSession(
      newSession: widget.session,
      newMedia: media,
      isCaller: widget.caller,
      newMsgId: msgId,
    );

    // 响铃等待期开本地预览（房外采集、不 joinRoom 不发布）：主叫确认
    // 自己的摄像头已工作；被叫响铃页同样显示自视图，未接通即可切换
    // 前后镜头（switchCamera 走预览轨分支）。接听 connect() / 挂断路径
    // 统一经 stopLocalPreview 释放，不与 Room 相机采集并发抢设备。
    if (media == 'video') {
      notifier.startLocalPreview();
    }

    // 设置回调
    notifier.onCallStateChange = (WebRTCSession? s1, WebRTCCallState s) async {
      switch (s) {
        // invite / new 只是“已发起”，状态机初值即 dialing，无需迁移。
        case WebRTCCallState.callStateInvite:
        case WebRTCCallState.callStateNew:
          break;
        case WebRTCCallState.callStateRinging:
          if (widget.caller) _applySignal(CallSignal.ringing);
          break;
        case WebRTCCallState.callStateAnswered:
          // 被叫已接听：主叫此刻才 joinRoom 接入 LiveKit 媒体房
          // （accept 前保持纯信令等待，不发布媒体、不建房）。
          await _joinRoomAfterAnswer();
          break;
        case WebRTCCallState.callStateBye:
          _applySignal(CallSignal.peerBye);
          break;
        case WebRTCCallState.callStateBusy:
          _applySignal(CallSignal.peerBusy);
          break;
        case WebRTCCallState.callStateFailed:
          _applySignal(CallSignal.failed);
          break;
        case WebRTCCallState.callStateConnected:
          _applySignal(CallSignal.connected);
          break;
      }
    };

    // 应答超时在此处统一起臂：被叫不接听、joinRoom 失败、信令不通等
    // 悬挂态都由它兜底，页面不会永久停在“呼叫中”。
    notifier.startAnswerTimer(() => _applySignal(CallSignal.answerTimeout));

    // 订阅信令消息。LiveKit 模式下无需先获取媒体权限/TURN 凭证，
    // 订阅可立即建立（原 getUserMedia 窗口期的 pending 排队机制保留兜底）。
    subscription = AppEventBus.on<WebRTCSignalingEvent>().listen((
      WebRTCSignalingEvent obj,
    ) async {
      await notifier.onMessageP2P(
        widget.session,
        WebRTCSignalingModel.fromJson(obj.data),
      );
    });
    // 订阅就绪：此后 handleWebRTC 不再排队信令。就绪前窗口期到达的
    // answer/bye 在此按序回放，此前它们会被 fire 到无监听者的事件总线
    // 而永久丢失。
    p2pCallSignalingReady = true;
    for (final data in takePendingWebRTCSignals(
      widget.peer.peerId.toString(),
    )) {
      if (!mounted) return;
      await notifier.onMessageP2P(
        widget.session,
        WebRTCSignalingModel.fromJson(data),
      );
    }
    if (!mounted) return;

    // 发起或接听通话
    if (widget.caller) {
      await MessagingFacade.instance.addLocalMsg(
        media: media,
        caller: widget.caller,
        msgId: msgId,
        peer: widget.peer,
      );
      // 只发邀请信令；媒体接入等对端 answer（_joinRoomAfterAnswer）。
      await notifier.invitePeer(
        msgId: msgId,
        peer: widget.peer.peerId.toString(),
        media: media,
      );
    } else {
      // 被叫已点接听：回 answer 信令（主叫收到后同样 joinRoom）→
      // joinRoom(kind=c2c) 连 LiveKit → 两端落同一 room。
      await notifier.answerInvite();
      final ok = await notifier.connect(peerId: widget.peer.peerId.toString());
      if (!mounted) return;
      if (!ok) {
        _applySignal(CallSignal.failed);
        return;
      }
      // 视频通话默认扬声器、音频通话默认听筒：必须在 Room 接入后立刻
      // 应用到硬件，否则 iOS 上 UI 显示“扩音开”而声音仍从听筒出。
      notifier.setInitialSpeaker(media == 'video');
      _applySignal(CallSignal.connected);
    }
  }

  /// accept 之后接入媒体房的统一入口（主叫经 answer 信令、被叫经接听动作）。
  Future<void> _joinRoomAfterAnswer() async {
    final ok = await _notifier.connect(peerId: widget.peer.peerId.toString());
    if (!mounted) return;
    if (!ok) {
      _applySignal(CallSignal.failed);
      return;
    }
    _notifier.setInitialSpeaker(media == 'video');
    _applySignal(CallSignal.connected);
  }

  /// 信令 / 本地事件统一入口：驱动状态机，并按迁移结果做一次性收尾。
  ///
  /// 幂等由两个闩控制而非状态比较——重复触发必须无害。
  void _applySignal(CallSignal signal) {
    if (!mounted) return;
    final status = _notifier.applySignal(signal);

    if (status.phase == CallPhase.connected) {
      _connectedAfter();
      return;
    }
    if (!status.isTerminal || _closeScheduled) return;
    _closeScheduled = true;
    _notifier.stopAnswerTimer();
    _notifier.stopCallTimer();
    // 结束时刻取“现在”，而不是延迟关页后的时刻，否则通话时长凭空多 2 秒。
    final endAt = DateTimeHelper.millisecond();
    Future<void>.delayed(
      const Duration(milliseconds: CallTimeoutConfig.hangupDelay),
      () {
        if (!mounted) return;
        _hangUp(
          sendBye: false,
          callState: status.recordStateCode,
          endAt: endAt,
        );
      },
    );
  }

  void _connectedAfter() {
    if (_connectedHandled) return;
    _connectedHandled = true;
    final notifier = _notifier;
    final size = MediaQuery.sizeOf(context);
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
      _byeSent = true;
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

  /// 状态机文案键 → i18n。逻辑层不认识 i18n，翻译只发生在这里。
  /// [CallTipKey.none] 表示“接通中”，此时展示通话时长而非任何提示语——
  /// 这正是原来 stateTips 从不清空导致音频通话看不到时长的那处缺陷。
  String _tipText(CallTipKey key, P2pCallScreenState state) {
    return switch (key) {
      CallTipKey.none =>
        state.callStatus.showsDuration ? state.callDuration : t.common.calling,
      CallTipKey.waitingPeerAccept => t.common.waitingPeerAccept,
      CallTipKey.ringing => t.main.ringing,
      CallTipKey.peerNoResponse => t.common.peerNoResponse,
      CallTipKey.peerHungUp => t.main.peerHasHungUp,
      CallTipKey.busy => t.chat.busyTryAgainLater,
      CallTipKey.networkError => t.common.errorNetwork,
      CallTipKey.callEnded => t.common.callEnded,
    };
  }

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
    final size = MediaQuery.sizeOf(context);
    final String statusText = _tipText(state.callStatus.tipKey, state);

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
              style: context
                  .textStyle(
                    // fs26(26) 最近档位 largeTitle(24)，差值2pt
                    FontSizeType.largeTitle,
                    fontWeight: FontWeight.w600,
                    color: CallTokens.white,
                  )
                  .copyWith(letterSpacing: 0.5),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  media == 'video'
                      ? CupertinoIcons.videocam_fill
                      : CupertinoIcons.phone_fill,
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
                    style: context.textStyle(
                      // fs15(15) 精确匹配 subheadline(15)
                      FontSizeType.subheadline,
                      color: CallTokens.white70,
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

  /// 接通前（主叫响铃等待）的本地摄像头预览：铺满主画面 + 上下轻压暗，
  /// 让用户在等待接听时确认自己的摄像头已工作（FaceTime 呼出同款）。
  Widget _buildSelfPreview(P2pCallScreenState state, VideoTrack track) {
    return Positioned.fill(
      child: Stack(
        fit: StackFit.expand,
        children: [
          VideoTrackRenderer(
            track,
            fit: VideoViewFit.cover,
            // 本地自视图镜像；切到后摄后不镜像。
            mirrorMode: state.isFrontCamera
                ? VideoViewMirrorMode.mirror
                : VideoViewMirrorMode.off,
          ),
          // 上下渐变压暗，保证昵称/状态与底部控制条可读。
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  CallTokens.blackA45,
                  Colors.transparent,
                  Colors.transparent,
                  CallTokens.blackA45,
                ],
                stops: [0.0, 0.18, 0.72, 1.0],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 接通前自视图上的顶部信息：昵称 + 状态（等待对方接受/响铃中…）。
  /// 不再叠中部大头像——那是用户自己的脸，放对方头像会造成混淆。
  Widget _buildSelfPreviewInfo(P2pCallScreenState state) {
    final String statusText = _tipText(state.callStatus.tipKey, state);
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.only(top: 18),
          child: Column(
            children: [
              Text(
                widget.peer.nickname,
                style: context
                    .textStyle(
                      FontSizeType.largeTitle,
                      fontWeight: FontWeight.w600,
                      color: CallTokens.white,
                    )
                    .copyWith(letterSpacing: 0.5),
              ),
              const SizedBox(height: 8),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: Text(
                  statusText,
                  key: ValueKey<String>(statusText),
                  style: context.textStyle(
                    FontSizeType.subheadline,
                    color: CallTokens.white70,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 顶部“网络不佳，正在重连…”横幅（接通后 Room Reconnecting/Resuming 时显示）。
  /// 数据源是真实连接态，非伪造信号格，断连时不会误显“良好”。
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
            decoration: BoxDecoration(color: CallTokens.blackA55),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 13,
                  height: 13,
                  child: CupertinoActivityIndicator(color: CallTokens.white70),
                ),
                AppSpacing.horizontalSmall,
                Text(
                  t.common.reconnecting,
                  style: context.textStyle(
                    // fs13(13) 精确匹配 footnote(13)
                    FontSizeType.footnote,
                    color: CallTokens.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMediaErrorBanner(P2pCallScreenState state) {
    final target = state.permissionTarget;
    return Positioned(
      left: 16,
      right: 16,
      bottom: 116,
      child: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
          decoration: BoxDecoration(
            color: CallTokens.blackA75,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: CallTokens.white24),
          ),
          child: Row(
            children: [
              const Icon(
                CupertinoIcons.exclamationmark_circle,
                color: CallTokens.white70,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  state.errorMessage,
                  style: context.textStyle(
                    FontSizeType.footnote,
                    color: CallTokens.white,
                  ),
                ),
              ),
              if (target != null)
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: () =>
                      unawaited(openMediaPermissionSettings(target)),
                  child: Text(
                    t.common.privacySettings,
                    style: context.textStyle(
                      FontSizeType.footnote,
                      color: CallTokens.white,
                    ),
                  ),
                ),
            ],
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
                      style: context.textStyle(
                        // fs18(18) 精确匹配 large(18)
                        FontSizeType.large,
                        fontWeight: FontWeight.w600,
                        color: CallTokens.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      state.callDuration.isNotEmpty
                          ? state.callDuration
                          : t.common.calling,
                      style: context.textStyle(
                        // fs13(13) 精确匹配 footnote(13)
                        FontSizeType.footnote,
                        color: CallTokens.white70,
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
        icon: state.micOff ? CupertinoIcons.mic_slash : CupertinoIcons.mic_fill,
        label: t.common.microphone,
        active: !state.micOff,
        showLabel: false,
        onTap: () {
          unawaited(notifier.turnMicrophone());
          if (mounted) setState(() {});
        },
      ),
      // 摄像头开关：视频通话才显示（LiveKit setCameraEnabled 开/关发布）
      if (isVideo)
        _circleButton(
          icon: state.cameraOff
              ? CupertinoIcons.videocam
              : CupertinoIcons.videocam_fill,
          label: t.chat.video,
          active: !state.cameraOff,
          showLabel: false,
          onTap: () {
            unawaited(notifier.turnCamera());
            if (mounted) setState(() {});
          },
        ),
      _circleButton(
        icon: state.speakerOn
            ? CupertinoIcons.volume_up
            : CupertinoIcons.volume_off,
        label: t.main.loudspeaker,
        active: state.speakerOn,
        showLabel: false,
        onTap: () {
          unawaited(notifier.switchSpeaker(!state.speakerOn));
          if (mounted) setState(() {});
        },
      ),
      if (isVideo)
        _circleButton(
          icon: CupertinoIcons.camera_rotate_fill,
          label: t.common.switchCamera,
          showLabel: false,
          onTap: () => unawaited(notifier.switchCamera()),
        ),
      // 挂断键：实心红、整合进岛内末位，最醒目
      _circleButton(
        icon: CupertinoIcons.phone_down_fill,
        label: t.main.hangup,
        showLabel: false,
        background: AppColors.getIosRed(Theme.of(context).brightness),
        onTap: () {
          HapticFeedback.mediumImpact();
          // 本机挂断立即关页（不走 _applySignal 的 2s 提示延迟），
          // 但状态码仍由状态机给出：接通过就记通话时长，没接通记已取消。
          _closeScheduled = true;
          final status = _notifier.applySignal(CallSignal.localHangUp);
          _hangUp(
            callState: status.recordStateCode,
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
                      // 窄屏下按钮总宽可能超出岛宽(如视频通话 5 键)，
                      // FittedBox 等比缩至可用宽度，避免右侧溢出且不裁剪
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
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
              child: GestureDetector(
                onTap: () {
                  if (!solid) HapticFeedback.selectionClick();
                  onTap();
                },
                child: Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: bg),
                  child: Icon(icon, color: fg, size: 26),
                ),
              ),
            ),
          ),
          if (showLabel && label.isNotEmpty) ...[
            const SizedBox(height: 7),
            Text(
              label,
              style: context.textStyle(
                // fs12(12) 精确匹配 small(12)
                FontSizeType.small,
                color: CallTokens.white70,
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _swapVideoLayout() {
    HapticFeedback.selectionClick();
    if (mounted) setState(() => _localOnMain = !_localOnMain);
  }

  void _startVideoDrag(P2pCallScreenState state) {
    _videoDragRight = state.localX;
    _videoDragTop = state.localY;
    if (_videoAnim != Duration.zero && mounted) {
      setState(() => _videoAnim = Duration.zero);
    }
  }

  void _updateVideoDrag(DragUpdateDetails details) {
    final right = _videoDragRight ?? CallUILayoutConfig.localVideoOffsetX;
    final top = _videoDragTop ?? CallUILayoutConfig.localVideoInitialY;
    final size = MediaQuery.sizeOf(context);
    final maxRight = math.max(12.0, size.width - LocalVideoConfig.width - 12.0);
    final maxTop = math.max(
      12.0,
      size.height - LocalVideoConfig.height - 136.0,
    );

    // localX 是 right 偏移，因此向右拖动时 right 需要减少。
    _videoDragRight = (right - details.delta.dx)
        .clamp(12.0, maxRight)
        .toDouble();
    _videoDragTop = (top + details.delta.dy).clamp(12.0, maxTop).toDouble();
    _notifier.updateLocalPosition(_videoDragRight!, _videoDragTop!);
  }

  void _finishVideoDrag(P2pCallScreenState state) {
    final size = MediaQuery.sizeOf(context);
    const margin = 12.0;
    final width = LocalVideoConfig.width;
    final height = LocalVideoConfig.height;
    final currentRight = _videoDragRight ?? state.localX;
    final currentTop = _videoDragTop ?? state.localY;
    final currentLeft = size.width - currentRight - width;
    final snappedLeft = snapFloatingLeft(
      currentLeft: currentLeft,
      windowWidth: width,
      screenWidth: size.width,
      margin: margin,
    );
    final maxTop = math.max(margin, size.height - height - 136.0);
    final snappedTop = currentTop.clamp(margin, maxTop).toDouble();
    final snappedRight = size.width - snappedLeft - width;

    _videoDragRight = snappedRight;
    _videoDragTop = snappedTop;
    if (mounted) {
      setState(() => _videoAnim = const Duration(milliseconds: 220));
    }
    _notifier.updateLocalPosition(snappedRight, snappedTop);
    Future<void>.delayed(const Duration(milliseconds: 260), () {
      if (mounted) setState(() => _videoAnim = Duration.zero);
    });
  }

  /// 远端（唯一对端）的 camera 视频轨；未发布/被 mute 时为 null。
  VideoTrack? _remoteVideoTrack(Room? room) {
    if (room == null) return null;
    for (final participant in room.remoteParticipants.values) {
      for (final pub in participant.videoTrackPublications) {
        if (pub.source == TrackSource.camera &&
            pub.track != null &&
            !pub.muted) {
          return pub.track as VideoTrack?;
        }
      }
    }
    return null;
  }

  /// 本端 camera 视频轨（悬浮窗/小窗自视图）。
  VideoTrack? _localVideoTrack(Room? room) {
    final pubs = room?.localParticipant?.videoTrackPublications ?? const [];
    for (final pub in pubs) {
      if (pub.source == TrackSource.camera && pub.track != null) {
        return pub.track as VideoTrack?;
      }
    }
    return null;
  }

  Widget _buildVideoContent({
    required P2pCallScreenState state,
    required bool isLocal,
    Room? room,
    VideoTrack? trackOverride,
  }) {
    final videoOff = isLocal ? state.cameraOff : state.remoteVideoOff;
    final track =
        trackOverride ??
        (isLocal ? _localVideoTrack(room) : _remoteVideoTrack(room));
    if (videoOff || track == null) {
      return const ColoredBox(
        color: CallTokens.bg1A1A1A,
        child: Center(
          child: Icon(
            CupertinoIcons.video_camera,
            color: CallTokens.white38,
            size: 28,
          ),
        ),
      );
    }

    return VideoTrackRenderer(
      track,
      fit: VideoViewFit.cover,
      // 只有本地自视图镜像；远端视频永远不镜像。
      mirrorMode: isLocal && state.isFrontCamera
          ? VideoViewMirrorMode.mirror
          : VideoViewMirrorMode.off,
    );
  }

  /// 接通后的视频小窗：本端/对端均可拖拽，点击交换主次位置。
  Widget _buildVideoMini(P2pCallScreenState state, Room? room) {
    final localWidth = LocalVideoConfig.width;
    final localHeight = LocalVideoConfig.height;
    final isLocal = !_localOnMain;

    return AnimatedPositioned(
      duration: _videoAnim,
      curve: Curves.easeOutCubic,
      right: state.localX,
      top: state.localY,
      child: Semantics(
        button: true,
        toggled: _localOnMain,
        label: t.common.enterFullscreen,
        child: GestureDetector(
          onTap: _swapVideoLayout,
          onPanStart: (_) => _startVideoDrag(state),
          onPanUpdate: _updateVideoDrag,
          onPanEnd: (details) {
            _finishVideoDrag(state);
            // 小窗也支持上下滑动交换，避免用户必须把手指移到主画面。
            if (shouldSwapVideoLayout(details.velocity.pixelsPerSecond.dy)) {
              _swapVideoLayout();
            }
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
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _buildVideoContent(
                    state: state,
                    isLocal: isLocal,
                    room: room,
                  ),
                  Positioned(
                    top: 4,
                    right: 4,
                    child: Semantics(
                      button: true,
                      label: t.common.enterFullscreen,
                      child: ClipOval(
                        child: GestureDetector(
                          onTap: _swapVideoLayout,
                          child: Container(
                            width: 28,
                            height: 28,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: CallTokens.black54,
                            ),
                            child: const Icon(
                              CupertinoIcons.arrow_up_arrow_down,
                              color: CallTokens.white,
                              size: 18,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 接通后的主画面。上下滑动主画面也可以交换本端/对端位置。
  Widget _buildVideoMain(P2pCallScreenState state, Room? room) {
    return Positioned.fill(
      child: Semantics(
        button: true,
        label: state.showTool ? t.common.collapse : t.common.expandFull,
        child: GestureDetector(
          onTap: () => _notifier.toggleShowTool(),
          onVerticalDragEnd: (details) {
            if (shouldSwapVideoLayout(details.primaryVelocity)) {
              _swapVideoLayout();
            }
          },
          child: _buildVideoContent(
            state: state,
            isLocal: _localOnMain,
            room: room,
          ),
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
                    child: GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        // 用 MediaQuery 算出右上角初始位（小窗宽 ~108）。
                        final size = MediaQuery.sizeOf(context);
                        _notifier.enterFloating(size.width - 118, 70);
                      },
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: CallTokens.whiteA18,
                        ),
                        child: const Icon(
                          CupertinoIcons.fullscreen_exit,
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
    );
  }

  /// 悬浮窗：最小化后的可拖拽小窗。视频显示当前主画面，音频显示头像 + 时长；
  /// 点击复原全屏。LiveKit 渲染轨道随 Room 变化自动重建，通话全程不中断。
  Widget _buildFloatingWindow(P2pCallScreenState state, Room? room) {
    const double w = 108;
    const double h = 156;
    // 接通显示远端主画面；未接通但有本地预览则显示自视图（响铃等待期）。
    VideoTrack? previewVideoTrack;
    if (!state.connected && state.localPreviewReady) {
      previewVideoTrack = _notifier.previewTrack?.videoTrack;
    }
    final bool showRemoteVideo =
        media == 'video' && state.connected && _remoteVideoTrack(room) != null;
    final bool showSelfVideo =
        media == 'video' && !state.connected && previewVideoTrack != null;

    final Widget inner = showRemoteVideo
        ? _buildVideoContent(state: state, isLocal: _localOnMain, room: room)
        : showSelfVideo
        ? _buildVideoContent(
            state: state,
            isLocal: true,
            room: room,
            trackOverride: previewVideoTrack,
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
                  AppSpacing.verticalSmall,
                  Text(
                    state.connected ? state.callDuration : t.common.calling,
                    style: context.textStyle(
                      // fs11(11) 精确匹配 caption2(11)
                      FontSizeType.caption2,
                      color: CallTokens.white70,
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
          child: Semantics(
            button: true,
            label: t.common.expandFull,
            child: GestureDetector(
              onTap: () => _notifier.toggleMinimized(),
              onPanUpdate: (d) {
                if (_floatAnim != Duration.zero && mounted) {
                  setState(() => _floatAnim = Duration.zero);
                }
                final size = MediaQuery.sizeOf(context);
                final nx = (state.floatX + d.delta.dx).clamp(
                  0.0,
                  size.width - w,
                );
                final ny = (state.floatY + d.delta.dy).clamp(
                  0.0,
                  size.height - h,
                );
                _notifier.updateFloatPosition(nx, ny);
              },
              onPanEnd: (_) {
                // 松手吸附到最近的左/右边缘（FaceTime PiP 同款）。
                final size = MediaQuery.sizeOf(context);
                final snappedX = snapFloatingLeft(
                  currentLeft: state.floatX,
                  windowWidth: w,
                  screenWidth: size.width,
                );
                if (mounted) {
                  setState(
                    () => _floatAnim = const Duration(milliseconds: 250),
                  );
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
                          CupertinoIcons.fullscreen,
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
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(p2pCallScreenProvider);

    // LiveKit Room 是 ChangeNotifier：参与者/轨道到达、mute 等变化都会
    // 通知重建，页面据此重取渲染轨道（Room 未接入时用静默占位监听）。
    final room = _notifier.room;
    return ListenableBuilder(
      listenable: room ?? _idleListenable,
      builder: (context, _) => _buildScaffold(state, room),
    );
  }

  Widget _buildScaffold(P2pCallScreenState state, Room? room) {
    // 最小化：仅渲染透明悬浮窗，让用户在底层 app 上继续操作（通话不挂断）。
    if (state.minimized) {
      return Container(child: _buildFloatingWindow(state, room));
    }

    final isVideo = media == 'video';
    // 仅“接通的视频通话”才有远端画面铺满；其余（呼出 / 音频）走渐变 + 头像。
    final remoteTrack = _remoteVideoTrack(room);
    final hasRemoteVideo = isVideo && state.connected && remoteTrack != null;
    // 接通前的本地自视图（响铃等待期）：预览轨已就绪则铺满主画面；
    // 不可用（权限拒绝/失败）回退渐变 + 头像。
    VideoTrack? previewVideoTrack;
    if (!state.connected && state.localPreviewReady) {
      previewVideoTrack = _notifier.previewTrack?.videoTrack;
    }
    final showSelfPreview = isVideo && previewVideoTrack != null;
    // 控件可见性：音频/呼出常驻；接通视频点屏切换。淡入淡出替代硬切。
    final bool toolsVisible = !hasRemoteVideo || state.showTool;

    final scaffold = CupertinoPageScaffold(
      child: Stack(
        children: [
          // 1. 背景层
          if (hasRemoteVideo)
            _buildVideoMain(state, room)
          else if (showSelfPreview)
            _buildSelfPreview(state, previewVideoTrack)
          else
            _buildGradientBackground(),

          // 2. 接通的视频：本地小窗
          if (hasRemoteVideo) _buildVideoMini(state, room),

          // 3. 呼出 / 音频：中部头像 + 昵称 + 状态；本地预览时改为顶部轻量信息
          if (!hasRemoteVideo)
            previewVideoTrack != null
                ? _buildSelfPreviewInfo(state)
                : _buildConnectingInfo(state),

          // 4. 接通的视频：顶部昵称 + 时长（点屏淡入淡出）
          if (hasRemoteVideo)
            _buildVideoTopInfo(state, visible: state.showTool),

          // 5. 网络不佳横幅（接通后 Room 重连中）——真实连接态驱动
          if (state.connected && state.reconnecting) _buildReconnectingBanner(),

          // 6. 摄像头/麦克风权限或设备错误：明确告知，不再伪装成“等待中”。
          if (state.errorMessage.isNotEmpty) _buildMediaErrorBanner(state),

          // 7. 顶部左上角最小化按钮（淡入淡出）
          _buildMinimizeButton(visible: toolsVisible),

          // 8. 底部控制条（淡入淡出）。挂断键始终可达。
          _buildControlBar(state, visible: toolsVisible),
        ],
      ),
    );

    // 入场淡入（FaceTime 进场观感）；Reduce Motion 时瞬时呈现（见 didChangeDependencies）。
    return FadeTransition(opacity: _entranceOpacity, child: scaffold);
  }
}
