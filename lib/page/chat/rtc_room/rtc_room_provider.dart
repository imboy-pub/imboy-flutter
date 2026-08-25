import 'package:livekit_client/livekit_client.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:imboy/component/helper/func.dart';

part 'rtc_room_provider.g.dart';

/// 群通话房间连接状态
enum RtcRoomStatus { idle, connecting, connected, failed, disconnected }

/// 群通话页状态（媒体面由 LiveKit Room 自管，这里只留 UI 需要的开关）
class RtcRoomState {
  final RtcRoomStatus status;
  final bool reconnecting;
  final bool micOn;
  final bool cameraOn;
  final bool speakerOn;

  const RtcRoomState({
    this.status = RtcRoomStatus.idle,
    this.reconnecting = false,
    this.micOn = true,
    this.cameraOn = true,
    this.speakerOn = true,
  });

  RtcRoomState copyWith({
    RtcRoomStatus? status,
    bool? reconnecting,
    bool? micOn,
    bool? cameraOn,
    bool? speakerOn,
  }) {
    return RtcRoomState(
      status: status ?? this.status,
      reconnecting: reconnecting ?? this.reconnecting,
      micOn: micOn ?? this.micOn,
      cameraOn: cameraOn ?? this.cameraOn,
      speakerOn: speakerOn ?? this.speakerOn,
    );
  }
}

/// 群通话副画面上下滑动交换主次位置的阈值。
bool shouldSwapRtcVideoLayout(
  double? verticalVelocity, {
  double threshold = 280,
}) {
  return (verticalVelocity ?? 0).abs() > threshold;
}

/// 群通话副画面松手后吸附到舞台左右边缘。
double snapRtcThumbnailLeft({
  required double currentLeft,
  required double thumbnailWidth,
  required double stageWidth,
  double margin = 12,
}) {
  final center = currentLeft + thumbnailWidth / 2;
  return center < stageWidth / 2
      ? margin
      : stageWidth - thumbnailWidth - margin;
}

@riverpod
class RtcRoomNotifier extends _$RtcRoomNotifier {
  Room? _room;
  EventsListener<RoomEvent>? _listener;
  CameraPosition _cameraPosition = CameraPosition.front;

  /// provider 已释放（页面 pop 触发 autoDispose）。
  /// connect() 的 await 返回后必须检查：弱网下 room.connect 挂起数秒、
  /// 用户已退出页面，若继续赋值 _room/开麦开摄像头会"复活"已释放的 Room，
  /// 并在已 dispose 的 notifier 上写 state 抛 StateError（Error 不会被
  /// on Exception 捕获）。
  bool _disposed = false;

  /// 用户主动挂断：页面据此区分「自己挂断」（直接退页）与
  /// 「异常断开」（toast 提示后退页），避免主动挂断也弹"通话已断开"。
  bool _userHangup = false;

  bool get userHangup => _userHangup;

  /// LiveKit Room（ChangeNotifier），页面用 ListenableBuilder 监听参与者变化
  Room? get room => _room;

  @override
  RtcRoomState build() {
    ref.onDispose(_teardown);
    return const RtcRoomState();
  }

  /// 连接房间并发布音视频；失败返回 false（不抛出，由页面提示用户）
  Future<bool> connect({required String wsUrl, required String token}) async {
    if (state.status == RtcRoomStatus.connecting ||
        state.status == RtcRoomStatus.connected) {
      return true;
    }
    state = state.copyWith(status: RtcRoomStatus.connecting);
    _userHangup = false;
    final room = Room();
    // await 前先登记：connecting 中页面 pop 触发 _teardown 时才能拿到
    // 这个 room 去取消连接/释放，否则竞态窗口内 teardown 摸到 null、
    // connect 完成后反而把已释放的 Room 复活。
    _room = room;
    try {
      await room.connect(wsUrl, token);
      if (_disposed) {
        // 页面已退出：彻底释放本地资源，不写 state。
        await room.disconnect();
        await room.dispose();
        return false;
      }
      final listener = room.createListener()
        ..on<RoomReconnectingEvent>((_) {
          if (!ref.mounted || _disposed) return;
          state = state.copyWith(
            status: RtcRoomStatus.connected,
            reconnecting: true,
          );
        })
        ..on<RoomResumingEvent>((_) {
          if (!ref.mounted || _disposed) return;
          state = state.copyWith(
            status: RtcRoomStatus.connected,
            reconnecting: true,
          );
        })
        ..on<RoomReconnectedEvent>((_) {
          if (!ref.mounted || _disposed) return;
          state = state.copyWith(
            status: RtcRoomStatus.connected,
            reconnecting: false,
          );
        })
        ..on<RoomDisconnectedEvent>((e) {
          if (!ref.mounted || _disposed) return;
          // 区分被踢/房间关闭/重连失败，便于诊断（UI 文案统一）。
          iPrint('RtcRoom disconnected: reason=${e.reason}');
          state = state.copyWith(
            status: RtcRoomStatus.disconnected,
            reconnecting: false,
          );
        });
      if (_disposed) {
        await listener.dispose();
        await room.disconnect();
        await room.dispose();
        return false;
      }
      _listener = listener;

      // 麦克风/摄像头分别降级：权限被拒或设备被占用只关闭对应能力，
      // 不能把整场通话判死（旧实现两者任一失败即 failed，无摄像头的
      // 用户永远进不了群通话）。
      var micOn = true;
      try {
        await room.localParticipant?.setMicrophoneEnabled(true);
      } on Exception catch (e) {
        micOn = false;
        iPrint('RtcRoom mic enable failed: $e');
      }
      var cameraOn = true;
      try {
        await room.localParticipant?.setCameraEnabled(true);
      } on Exception catch (e) {
        cameraOn = false;
        iPrint('RtcRoom camera enable failed: $e');
      }
      // 初始音频路由与 UI 状态对齐：iOS playAndRecord 默认走听筒，
      // 不显式应用会出现"图标显示扩音开、实际听筒出声"的首态错位。
      try {
        await AudioManager.instance.setSpeakerOutputPreferred(state.speakerOn);
      } on Exception catch (_) {
        // 桌面平台无扬声器/听筒概念，忽略。
      }
      if (!ref.mounted || _disposed) return false;
      state = state.copyWith(
        status: RtcRoomStatus.connected,
        reconnecting: false,
        micOn: micOn,
        cameraOn: cameraOn,
      );
      return true;
    } on Exception catch (e) {
      iPrint('RtcRoom connect failed: $e');
      if (_disposed) {
        await room.dispose();
        return false;
      }
      await room.dispose();
      if (_room == room) _room = null;
      if (!ref.mounted) return false;
      state = state.copyWith(status: RtcRoomStatus.failed, reconnecting: false);
      return false;
    }
  }

  Future<void> toggleMic() async {
    final lp = _room?.localParticipant;
    if (lp == null) return;
    final next = !state.micOn;
    try {
      await lp.setMicrophoneEnabled(next);
      if (ref.mounted) state = state.copyWith(micOn: next);
    } on Exception catch (e) {
      // 失败时保持图标与实际状态一致（旧实现 state 只在成功后更新，
      // 异常路径下 UI 与真实能力失同步）。
      iPrint('RtcRoom toggleMic failed: $e');
    }
  }

  Future<void> toggleCamera() async {
    final lp = _room?.localParticipant;
    if (lp == null) return;
    final next = !state.cameraOn;
    try {
      await lp.setCameraEnabled(next);
      if (ref.mounted) state = state.copyWith(cameraOn: next);
    } on Exception catch (e) {
      iPrint('RtcRoom toggleCamera failed: $e');
    }
  }

  Future<void> toggleSpeaker() async {
    final next = !state.speakerOn;
    await AudioManager.instance.setSpeakerOutputPreferred(next);
    state = state.copyWith(speakerOn: next);
  }

  Future<void> switchCamera() async {
    final pubs = _room?.localParticipant?.videoTrackPublications ?? const [];
    Track? track;
    for (final p in pubs) {
      if (p.source == TrackSource.camera) {
        track = p.track;
        break;
      }
    }
    if (track is! LocalVideoTrack) return;
    _cameraPosition = _cameraPosition.switched();
    await track.setCameraPosition(_cameraPosition);
  }

  /// 挂断：断开并释放 Room，页面据 status==disconnected 退出
  Future<void> hangup() async {
    _userHangup = true;
    await _teardown();
    if (ref.mounted) {
      state = state.copyWith(status: RtcRoomStatus.disconnected);
    }
  }

  Future<void> _teardown() async {
    _disposed = true;
    final listener = _listener;
    final room = _room;
    _listener = null;
    _room = null;
    await listener?.dispose();
    await room?.disconnect();
    await room?.dispose();
  }
}
