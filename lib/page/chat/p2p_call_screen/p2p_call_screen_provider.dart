import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:imboy/component/helper/func.dart';
import 'package:imboy/component/webrtc/enum.dart';
import 'package:imboy/component/webrtc/func.dart';
import 'package:imboy/component/webrtc/media_permission.dart';
import 'package:imboy/component/webrtc/session.dart';
import 'package:imboy/config/init.dart' show deviceId, p2pCallScreenOn;
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/chat/p2p_call_screen/p2p_call_constants.dart';
import 'package:imboy/page/chat/p2p_call_screen/p2p_call_state_machine.dart';
import 'package:imboy/store/api/rtc_room_api.dart';
import 'package:imboy/store/model/webrtc_signaling_model.dart';

part 'p2p_call_screen_provider.g.dart';

/// 悬浮窗松手吸附：按当前窗口中心落在屏幕左/右半区，吸附到对应边缘（FaceTime PiP 同款）。
/// 返回吸附后的 left 像素值。
double snapFloatingLeft({
  required double currentLeft,
  required double windowWidth,
  required double screenWidth,
  double margin = 10,
}) {
  final center = currentLeft + windowWidth / 2;
  final rightEdge = screenWidth - windowWidth - margin;
  return center < screenWidth / 2 ? margin : rightEdge;
}

/// 主画面上下滑动交换本端/对端视频的最小速度阈值。
bool shouldSwapVideoLayout(double? verticalVelocity, {double threshold = 280}) {
  return (verticalVelocity ?? 0).abs() > threshold;
}

/// 通话时长格式化：<1h 显示 mm:ss，≥1h 显示 hh:mm:ss（FaceTime 同款）。
String formatCallDuration(int totalSeconds) {
  final h = totalSeconds ~/ 3600;
  final m = (totalSeconds % 3600) ~/ 60;
  final s = totalSeconds % 60;
  String two(int v) => v.toString().padLeft(2, '0');
  return h > 0 ? '${two(h)}:${two(m)}:${two(s)}' : '${two(m)}:${two(s)}';
}

/// 接通前本地预览轨的薄抽象：屏蔽 livekit 轨道类型。LocalVideoTrack 的
/// 构造函数是 @internal，测试包内无法构造，替身经由本接口注入。
abstract interface class LocalPreviewTrack {
  /// 可渲染的自视图轨（VideoTrackRenderer 输入）。
  VideoTrack? get videoTrack;

  Future<void> stop();

  Future<void> setCameraPosition(CameraPosition position);
}

class _LiveKitPreviewTrack implements LocalPreviewTrack {
  _LiveKitPreviewTrack(this.track);

  final LocalVideoTrack track;

  @override
  VideoTrack get videoTrack => track;

  @override
  Future<void> stop() => track.stop();

  @override
  Future<void> setCameraPosition(CameraPosition position) =>
      track.setCameraPosition(position);
}

/// P2P Call Screen 状态
class P2pCallScreenState {
  final bool cameraOff;
  final bool isFrontCamera;
  final bool micOff;
  final bool speakerOn;
  final bool connected;
  final bool showTool;
  final bool minimized;

  /// 通话阶段 + 结束原因（唯一真值源，见 [CallStatus]）。
  final CallStatus callStatus;
  final String callDuration;
  final double localX;
  final double localY;

  /// 悬浮窗位置（最小化后的小窗，left/top 像素坐标）。
  final double floatX;
  final double floatY;

  /// 网络重连中（LiveKit Room Reconnecting/Resuming）。用于顶部“网络不佳”横幅。
  final bool reconnecting;

  /// 对端已关闭摄像头（track_state 信令同步）。用于主画面占位提示，
  /// 否则对端关摄像头后本端只看到黑屏、无从分辨。
  final bool remoteVideoOff;
  final String errorMessage;
  final MediaPermissionTarget? permissionTarget;

  /// 接通前本地预览是否已就绪（房外自视图轨已创建）。仅用于触发 UI
  /// 重建；真实轨道经 notifier.previewTrack 获取。
  final bool localPreviewReady;

  const P2pCallScreenState({
    this.cameraOff = false,
    this.isFrontCamera = true,
    this.micOff = false,
    this.speakerOn = true,
    this.connected = false,
    this.showTool = true,
    this.minimized = false,
    this.callStatus = const CallStatus(),
    this.callDuration = '00:00',
    this.localX = 0.0,
    this.localY = 0.0,
    this.floatX = 0.0,
    this.floatY = 0.0,
    this.reconnecting = false,
    this.remoteVideoOff = false,
    this.errorMessage = '',
    this.permissionTarget,
    this.localPreviewReady = false,
  });

  P2pCallScreenState copyWith({
    bool? cameraOff,
    bool? isFrontCamera,
    bool? micOff,
    bool? speakerOn,
    bool? connected,
    bool? showTool,
    bool? minimized,
    CallStatus? callStatus,
    String? callDuration,
    double? localX,
    double? localY,
    double? floatX,
    double? floatY,
    bool? reconnecting,
    bool? remoteVideoOff,
    String? errorMessage,
    MediaPermissionTarget? permissionTarget,
    bool? localPreviewReady,
    bool clearPermissionTarget = false,
  }) {
    return P2pCallScreenState(
      cameraOff: cameraOff ?? this.cameraOff,
      isFrontCamera: isFrontCamera ?? this.isFrontCamera,
      micOff: micOff ?? this.micOff,
      speakerOn: speakerOn ?? this.speakerOn,
      connected: connected ?? this.connected,
      showTool: showTool ?? this.showTool,
      minimized: minimized ?? this.minimized,
      callStatus: callStatus ?? this.callStatus,
      callDuration: callDuration ?? this.callDuration,
      localX: localX ?? this.localX,
      localY: localY ?? this.localY,
      floatX: floatX ?? this.floatX,
      floatY: floatY ?? this.floatY,
      reconnecting: reconnecting ?? this.reconnecting,
      remoteVideoOff: remoteVideoOff ?? this.remoteVideoOff,
      errorMessage: errorMessage ?? this.errorMessage,
      permissionTarget: clearPermissionTarget
          ? null
          : permissionTarget ?? this.permissionTarget,
      localPreviewReady: localPreviewReady ?? this.localPreviewReady,
    );
  }
}

/// P2P Call Screen Provider
///
/// LK-APP-01：媒体面迁移 LiveKit SFU（与群通话 rtc_room_provider 同一模式）。
/// 信令（邀请/响铃/接听/拒接/挂断）、状态机、悬浮窗 UX 全部保留原有实现；
/// offer/answer 信令退化为“邀请/接听”通知（payload 仅 media，无 SDP），
/// ICE candidate 彻底消失——媒体协商由 SFU 完成。
@riverpod
class P2pCallScreenNotifier extends _$P2pCallScreenNotifier {
  WebRTCSession? session;
  String media = 'video';
  bool caller = true;
  String msgId = '';

  // 页面 dispose 期间置位：阻止仍在飞行中的信令回调继续操作正在被
  // cleanUpP2P() 释放的 LiveKit Room（并发访问有崩溃风险）。
  bool _closing = false;

  // answer 信令幂等闩：只向页面广播一次 callStateAnswered（重复 answer /
  // 主叫 connect 尚未起身的竞态窗口内到达的第二条 answer 不再触发）。
  bool _answeredNotified = false;

  Timer? _answerTimer;
  Timer? _callTimer;
  int _callSeconds = 0;

  // ===== LiveKit 媒体面（参照 rtc_room_provider） =====
  Room? _room;
  EventsListener<RoomEvent>? _listener;
  CameraPosition _cameraPosition = CameraPosition.front;
  bool _connecting = false;

  // ===== 接通前本地预览（响铃等待期的房外自视图） =====
  // 主叫 accept 前不 joinRoom（见 invitePeer 注释），但视频通话仍需让
  // 用户确认自己的摄像头已工作：用独立 LocalVideoTrack 房外采集、仅
  // 渲染不发布。connect()/挂断前必须先停掉——两路相机采集并发抢占
  // 设备，iOS 上会静默黑屏。
  LocalPreviewTrack? _previewTrack;

  /// 预览创建任务的串行链：startLocalPreview 幂等入队，stopLocalPreview
  /// 先 await 整条链再停轨，保证 Room 采集不会被在途的 getUserMedia 抢占。
  Future<void> _previewJob = Future.value();

  /// 测试注入：预览轨创建替身（单测不触碰平台相机通道）。
  @visibleForTesting
  Future<LocalPreviewTrack> Function(CameraCaptureOptions options)?
  previewTrackFactory;

  /// 接通前的本地预览轨；未创建 / 已停时为 null（页面据此回退头像背景）。
  LocalPreviewTrack? get previewTrack => _previewTrack;

  /// 测试注入：RtcRoomApi 替身（断言 joinRoom 调用时机/参数）。
  @visibleForTesting
  RtcRoomApi? rtcApiOverride;

  /// 测试注入：Room 连接替身（单测不触碰真实网络/平台通道）。
  @visibleForTesting
  Future<bool> Function(String wsUrl, String token)? roomConnectOverride;

  RtcRoomApi get _rtcApi => rtcApiOverride ?? RtcRoomApi();

  /// LiveKit Room（ChangeNotifier），页面用 ListenableBuilder 监听
  /// 参与者/轨道变化来重取渲染轨道。
  Room? get room => _room;

  /// 回调函数
  void Function(WebRTCSession? session, WebRTCCallState state)?
  onCallStateChange;

  @override
  P2pCallScreenState build() {
    // provider 释放时统一取消所有定时器，避免定时器在 dispose 后写 state
    // 抛 "Cannot use Ref after disposed"（cleanup 原仅在手动挂断路径调用）
    ref.onDispose(cleanup);
    return const P2pCallScreenState();
  }

  void initSession({
    required WebRTCSession newSession,
    required String newMedia,
    required bool isCaller,
    required String newMsgId,
  }) {
    session = newSession;
    media = newMedia;
    caller = isCaller;
    msgId = newMsgId;
    _closing = false;
    _answeredNotified = false;
    _callSeconds = 0;
  }

  /// 处理对端信令（ringing/busy/bye/answer/track_state）。
  ///
  /// LiveKit 模式下媒体协商类信令（offer/answer/candidate）不再携带
  /// SDP/ICE：offer 由来电页处理；answer 只作为“被叫已接听”通知，
  /// 由主叫侧据此触发 joinRoom 接入媒体房。
  Future<void> onMessageP2P(WebRTCSession s, WebRTCSignalingModel msg) async {
    if (_closing) {
      iPrint('> rtc onMessageP2P: 正在关闭中，忽略信令 ${msg.webRtcType}');
      return;
    }
    iPrint("> rtc onMessageP2P ${msg.webRtcType}");

    // 安全校验：验证信令消息发送方是否为当前会话的合法对等端
    if (msg.from != s.peerId &&
        msg.webRtcType != 'peers' &&
        msg.webRtcType != 'heartbeat') {
      iPrint(
        '> rtc WARNING: message from unexpected peer ${msg.from}, expected ${s.peerId}',
      );
      return;
    }

    switch (msg.webRtcType) {
      case 'ringing':
        onCallStateChange?.call(s, WebRTCCallState.callStateRinging);
        break;
      case 'busy':
        onCallStateChange?.call(s, WebRTCCallState.callStateBusy);
        break;
      case 'answer':
        // 主叫侧：被叫已接听。msgId 匹配（被叫沿用主叫 invite 的 msgId）
        // 防止串话；幂等闩防重复 answer 重复触发 joinRoom。
        if (msg.msgId == msgId && !_answeredNotified) {
          _answeredNotified = true;
          onCallStateChange?.call(s, WebRTCCallState.callStateAnswered);
        } else {
          iPrint('> rtc answer: stale/duplicate answer, dropping');
        }
        break;
      case 'bye':
        // 幽灵 bye 防御：双方共用同一 msgId（主叫生成、随邀请传递），
        // 用它区分迟到 bye 属于哪一通通话。
        if (msg.msgId == msgId) {
          onCallStateChange?.call(s, WebRTCCallState.callStateBye);
        } else {
          iPrint(
            '> rtc bye: stale bye for sid ${s.sid} (msgId mismatch), ignored',
          );
        }
        break;
      case 'track_state':
        // 对端摄像头开关的信令同步：驱动本端 remoteVideoOff 占位 UI。
        if (ref.mounted && !_closing) {
          final videoOn = msg.payload['video'] as bool? ?? true;
          state = state.copyWith(remoteVideoOff: !videoOn);
        }
        break;
      default:
        // offer/peers/heartbeat/leave/candidate：LiveKit 模式无 P2P 媒体
        // 协商，统一忽略（candidate 已随 1:1 RTCPeerConnection 链路移除）。
        break;
    }
  }

  /// 主叫发起邀请：只发信令，不碰媒体。
  ///
  /// accept 前不调用 joinRoom、不连 Room、不获取媒体权限——
  /// 发起方保持纯信令等待，拒绝/取消/超时不会在服务端留下房间。
  Future<void> invitePeer({
    required String msgId,
    required String peer,
    required String media,
  }) async {
    final currentSession = session;
    if (currentSession == null) {
      iPrint('> rtc invitePeer: session is null, cannot invite');
      return;
    }
    iPrint("> rtc invitePeer $peer $media");
    // 邀请沿用 webrtc_offer 消息类型（后端按 webrtc_ 前缀透传），
    // payload 仅保留 media，SDP 字段随 P2P 媒体链路一并移除。
    sendWebRTCMsg(
      'offer',
      {'media': media},
      msgId: msgId,
      to: currentSession.peerId,
      debug: 'from_invitePeer',
    );
    onCallStateChange?.call(currentSession, WebRTCCallState.callStateNew);
  }

  /// 被叫接听：回 answer 信令通知主叫。
  /// 媒体接入由页面随后调用 [connect]（joinRoom → LiveKit Room）。
  Future<void> answerInvite() async {
    final currentSession = session;
    if (currentSession == null) {
      iPrint('> rtc answerInvite: session is null, skipping');
      return;
    }
    sendWebRTCMsg(
      'answer',
      {'media': media},
      msgId: msgId,
      to: currentSession.peerId,
      debug: 'from_answerInvite',
    );
  }

  /// 开启接通前本地预览（仅视频通话、未接房时；重复调用幂等入队）。
  void startLocalPreview() {
    if (media != 'video' ||
        _room != null ||
        _connecting ||
        _previewTrack != null ||
        _closing) {
      return;
    }
    _previewJob = _previewJob.then((_) => _doStartLocalPreview());
  }

  Future<void> _doStartLocalPreview() async {
    if (_closing || _previewTrack != null) return;
    try {
      final Future<LocalPreviewTrack> Function(CameraCaptureOptions) create =
          previewTrackFactory ?? _createDefaultPreviewTrack;
      final track = await create(
        CameraCaptureOptions(cameraPosition: _cameraPosition),
      );
      // 创建等待期间用户可能已挂断/接房：立即停掉，绝不带病上岗。
      if (_closing || _previewTrack != null) {
        await track.stop();
        return;
      }
      _previewTrack = track;
      if (ref.mounted) state = state.copyWith(localPreviewReady: true);
    } on Object catch (e) {
      // on Object 而非 on Exception：这里跑在 _previewJob 任务链上，
      // 未捕获的 Error 会毒化后续入队的任务。
      iPrint('> rtc local preview failed: $e');
      updateStateError(
        t.common.permissionAcquisitionFailed,
        permissionTarget: MediaPermissionTarget.camera,
      );
    }
  }

  /// 默认预览轨：房外直接开相机（不 joinRoom、不发布）。
  Future<LocalPreviewTrack> _createDefaultPreviewTrack(
    CameraCaptureOptions options,
  ) async {
    final track = await LocalVideoTrack.createCameraTrack(options);
    return _LiveKitPreviewTrack(track);
  }

  /// 停掉接通前预览轨（connect / 挂断释放前调用）。先等在途创建完成
  /// 再停轨清状态；未开启过时为安全 no-op。
  Future<void> stopLocalPreview() async {
    await _previewJob;
    final track = _previewTrack;
    _previewTrack = null;
    if (ref.mounted && state.localPreviewReady) {
      state = state.copyWith(localPreviewReady: false);
    }
    try {
      await track?.stop();
    } on Object catch (e) {
      iPrint('> rtc stop local preview error: $e');
    }
  }

  /// accept 之后接入媒体：joinRoom(kind=c2c) 拿 LiveKit 入场券并连接。
  ///
  /// 两端因后端对称房间名（双 uid 排序）落到同一 room。
  /// 失败返回 false（不抛出），由页面走 failed 收尾。
  Future<bool> connect({required String peerId}) async {
    if (_room != null || _connecting) return true;
    _connecting = true;
    try {
      // 先停掉房外预览轨：Room 建立后由 setCameraEnabled 重新采集，
      // 两路并发抢相机设备会黑屏/失败。
      await stopLocalPreview();
      if (_closing) return false;
      final res = await _rtcApi.joinRoom(
        kind: 'c2c',
        targetId: peerId,
        did: deviceId,
      );
      // joinRoom 失败原因已由 RtcRoomApi 透出（后端中文 msg）
      if (res == null) return false;
      if (_closing) return false;
      final connectRoom = roomConnectOverride ?? _connectRoom;
      return await connectRoom(res['wsUrl'] ?? '', res['token'] ?? '');
    } finally {
      _connecting = false;
    }
  }

  Future<bool> _connectRoom(String wsUrl, String token) async {
    final room = Room();
    // await 前先登记：connecting 中页面 pop 触发释放时才能拿到这个 room
    // 去取消连接，否则竞态窗口内释放流程摸到 null、connect 完成后反而
    // 把已释放的 Room 复活（同 rtc_room_provider 的教训）。
    _room = room;
    try {
      await room.connect(wsUrl, token);
      if (_closing) {
        await _disposeRoom(room);
        return false;
      }
      final listener = room.createListener()
        ..on<RoomReconnectingEvent>((_) => setReconnecting(true))
        ..on<RoomResumingEvent>((_) => setReconnecting(true))
        ..on<RoomReconnectedEvent>((_) => setReconnecting(false))
        ..on<RoomDisconnectedEvent>((e) {
          if (_closing || !ref.mounted) return;
          // 非本端挂断的彻底断开 = 链路故障（对应原 ICE 重启耗尽语义），
          // 与对端挂断（bye 信令 → callStateBye）区分。
          iPrint('> rtc Room disconnected: reason=${e.reason}');
          setReconnecting(false);
          onCallStateChange?.call(session, WebRTCCallState.callStateFailed);
        });
      _listener = listener;

      // 发布媒体：麦克风总是尝试；视频仅视频通话。权限/设备失败降级为
      // 错误横幅提示（复用 errorMessage/permissionTarget 机制），不判死
      // 整场通话——与群通话的降级策略一致。
      try {
        await room.localParticipant?.setMicrophoneEnabled(true);
      } on Exception catch (e) {
        iPrint('> rtc mic enable failed: $e');
        updateStateError(
          t.common.permissionAcquisitionFailed,
          permissionTarget: MediaPermissionTarget.microphone,
        );
      }
      if (media == 'video' && !state.cameraOff) {
        // 接通前已关摄像头的（响铃期预览可关）尊重该选择，不强制开启。
        try {
          await room.localParticipant?.setCameraEnabled(true);
        } on Exception catch (e) {
          iPrint('> rtc camera enable failed: $e');
          updateStateError(
            t.common.permissionAcquisitionFailed,
            permissionTarget: MediaPermissionTarget.camera,
          );
        }
      }
      if (_closing) {
        await _disposeRoom(room);
        return false;
      }
      return true;
    } on Exception catch (e) {
      iPrint('> rtc connect failed: $e');
      await _disposeRoom(room);
      if (_room == room) _room = null;
      return false;
    }
  }

  void sendBusy(String msgId, String to) {
    sendWebRTCMsg('busy', {}, msgId: msgId, to: to);
  }

  /// 本机挂断/关页：发 bye 信令并释放 LiveKit Room。
  void sendBye(String msgId) {
    final currentSession = session;
    if (currentSession == null) {
      iPrint('> rtc sendBye: session is null, skipping');
      return;
    }
    sendWebRTCMsg(
      'bye',
      {'sid': currentSession.sid},
      msgId: msgId,
      to: currentSession.peerId,
    );
    unawaited(releaseMedia());
  }

  /// 释放 LiveKit 连接与轨道（挂断 = 离开 Room + 释放 track/连接）。
  Future<void> releaseMedia() async {
    await stopLocalPreview();
    final listener = _listener;
    final room = _room;
    _listener = null;
    _room = null;
    try {
      await listener?.dispose();
      await room?.disconnect();
      await room?.dispose();
    } on Exception catch (e) {
      iPrint('> rtc releaseMedia error: $e');
    }
  }

  Future<void> _disposeRoom(Room room) async {
    await _listener?.dispose();
    _listener = null;
    if (_room == room) _room = null;
    await room.disconnect();
    await room.dispose();
  }

  Future<void> cleanUpP2P() async {
    // 先置位再做任何异步清理：阻止仍在飞行中的 onMessageP2P 继续读写
    // 即将被释放的 LiveKit Room。
    _closing = true;
    await releaseMedia();
    // ⚠️ 不在此处复位 _closing：关闭流程是异步的，飞行中的原生回调可能
    // 随后到达；复位由下一通通话的 initSession 完成。
    p2pCallScreenOn = false;
  }

  /// 前后镜头切换（本地 camera track 的采集方位）。
  Future<void> switchCamera() async {
    final pubs = _room?.localParticipant?.videoTrackPublications ?? const [];
    LocalVideoTrack? track;
    for (final p in pubs) {
      if (p.source == TrackSource.camera && p.track is LocalVideoTrack) {
        track = p.track as LocalVideoTrack;
        break;
      }
    }
    // 接通前（响铃等待）只有房外预览轨：同样支持切换前后镜头。
    // 无任何可用轨时保持原语义：不翻转方位。
    if (track != null) {
      _cameraPosition = _cameraPosition.switched();
      await track.setCameraPosition(_cameraPosition);
    } else if (_previewTrack != null) {
      _cameraPosition = _cameraPosition.switched();
      await _previewTrack!.setCameraPosition(_cameraPosition);
    } else {
      return;
    }
    if (ref.mounted) {
      state = state.copyWith(
        isFrontCamera: _cameraPosition == CameraPosition.front,
      );
    }
  }

  /// 通话建立时应用初始音频路由：视频通话默认扬声器、音频通话默认听筒。
  /// 必须在 Room 接入后调用一次，否则 iOS 上 UI 显示"扩音开"而实际
  /// 音频仍从听筒出（首态与真实路由不符）。
  void setInitialSpeaker(bool speakerOn) {
    state = state.copyWith(speakerOn: speakerOn);
    applyInitialAudioRoute();
  }

  Future<void> applyInitialAudioRoute() async {
    try {
      await AudioManager.instance.setSpeakerOutputPreferred(state.speakerOn);
    } on Exception catch (_) {
      // 桌面平台无扬声器/听筒概念，忽略。
    }
  }

  Future<void> switchSpeaker(bool speakerOn) async {
    try {
      await AudioManager.instance.setSpeakerOutputPreferred(speakerOn);
    } on Exception catch (_) {
      // 桌面平台无扬声器/听筒概念，忽略。
    }
    if (ref.mounted) {
      state = state.copyWith(speakerOn: speakerOn);
    }
  }

  Future<void> turnMicrophone() async {
    iPrint("> rtc turnMicrophone");
    final lp = _room?.localParticipant;
    if (lp == null) return;
    final nextEnabled = state.micOff;
    try {
      await lp.setMicrophoneEnabled(nextEnabled);
      if (ref.mounted) state = state.copyWith(micOff: !nextEnabled);
    } on Exception catch (e) {
      iPrint('> rtc turnMicrophone failed: $e');
    }
  }

  Future<void> turnCamera() async {
    final lp = _room?.localParticipant;
    if (lp == null) {
      // 接通前只有房外预览轨：直接开/关预览。不发 track_state——对端
      // 尚未接入房间，接房后以本端真实发布状态为准（_connectRoom 会
      // 尊重 cameraOff）。
      final nextOff = !state.cameraOff;
      if (ref.mounted) state = state.copyWith(cameraOff: nextOff);
      if (nextOff) {
        await stopLocalPreview();
      } else {
        startLocalPreview();
      }
      return;
    }
    final muted = !state.cameraOff;
    try {
      await lp.setCameraEnabled(!muted);
    } on Exception catch (e) {
      iPrint('> rtc turnCamera failed: $e');
      return;
    }
    if (ref.mounted) state = state.copyWith(cameraOff: muted);
    // 摄像头开关通过信令同步给对端（后端对 webrtc_* 整包透传，无需改动），
    // 对端据此显示"对方已关闭摄像头"占位，而不是无差别黑屏。
    final currentSession = session;
    if (currentSession != null) {
      sendWebRTCMsg(
        'track_state',
        {'video': !muted},
        msgId: msgId,
        to: currentSession.peerId,
      );
    }
  }

  /// 用信令/本地事件驱动状态机，返回迁移后的状态（页面据此决定收尾动作）。
  CallStatus applySignal(CallSignal signal) {
    final next = state.callStatus.apply(signal);
    if (next != state.callStatus) {
      state = state.copyWith(callStatus: next);
    }
    return next;
  }

  void updateStateError(
    String message, {
    MediaPermissionTarget? permissionTarget,
  }) {
    if (!ref.mounted) return;
    state = state.copyWith(
      errorMessage: message,
      permissionTarget: permissionTarget,
      clearPermissionTarget: permissionTarget == null,
    );
  }

  void updateConnected(bool isConnected, {double? width}) {
    state = state.copyWith(
      connected: isConnected,
      localX: width != null
          // localX 与页面的 Positioned(right: localX) 保持同一坐标语义。
          // 旧实现把屏幕宽度减进来，导致窄屏时小窗直接跑到屏幕外。
          ? CallUILayoutConfig.localVideoOffsetX
          : state.localX,
      localY: CallUILayoutConfig.localVideoInitialY,
    );
  }

  void setReconnecting(bool v) {
    // Room 事件来自原生层：provider 已释放（页面关闭）后写 state 会抛
    // "Cannot use Ref after disposed"。
    if (!ref.mounted) return;
    state = state.copyWith(reconnecting: v);
  }

  void startCallTimer(void Function() onUpdate) {
    _callTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      // 同帧竞态兜底：provider 已释放则自行取消，不再写 state
      if (!ref.mounted) {
        timer.cancel();
        return;
      }
      _callSeconds++;
      state = state.copyWith(callDuration: formatCallDuration(_callSeconds));
      onUpdate();
    });
  }

  void stopCallTimer() {
    _callTimer?.cancel();
    _callTimer = null;
  }

  void stopAnswerTimer() {
    _answerTimer?.cancel();
    _answerTimer = null;
  }

  void startAnswerTimer(VoidCallback onTimeout) {
    // 重复起臂时先撤旧的，否则旧 Timer 无人持有也不会被取消。
    _answerTimer?.cancel();
    _answerTimer = Timer(
      const Duration(seconds: CallTimeoutConfig.answerTimeout),
      () {
        onTimeout();
      },
    );
  }

  void toggleShowTool() {
    state = state.copyWith(showTool: !state.showTool);
  }

  void toggleMinimized() {
    state = state.copyWith(minimized: !state.minimized);
  }

  void updateLocalPosition(double x, double y) {
    state = state.copyWith(localX: x, localY: y);
  }

  /// 进入悬浮窗：设定初始小窗位置（由页面用 MediaQuery 算出右上角）并最小化。
  void enterFloating(double x, double y) {
    state = state.copyWith(floatX: x, floatY: y, minimized: true);
  }

  void updateFloatPosition(double x, double y) {
    state = state.copyWith(floatX: x, floatY: y);
  }

  void cleanup() {
    _callTimer?.cancel();
    _answerTimer?.cancel();
  }
}
