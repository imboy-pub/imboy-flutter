import 'package:livekit_client/livekit_client.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:imboy/component/helper/func.dart';

part 'rtc_room_provider.g.dart';

/// 群通话房间连接状态
enum RtcRoomStatus { idle, connecting, connected, failed, disconnected }

/// 群通话页状态（媒体面由 LiveKit Room 自管，这里只留 UI 需要的开关）
class RtcRoomState {
  final RtcRoomStatus status;
  final bool micOn;
  final bool cameraOn;

  const RtcRoomState({
    this.status = RtcRoomStatus.idle,
    this.micOn = true,
    this.cameraOn = true,
  });

  RtcRoomState copyWith({RtcRoomStatus? status, bool? micOn, bool? cameraOn}) {
    return RtcRoomState(
      status: status ?? this.status,
      micOn: micOn ?? this.micOn,
      cameraOn: cameraOn ?? this.cameraOn,
    );
  }
}

@riverpod
class RtcRoomNotifier extends _$RtcRoomNotifier {
  Room? _room;
  EventsListener<RoomEvent>? _listener;
  CameraPosition _cameraPosition = CameraPosition.front;

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
    final room = Room();
    try {
      await room.connect(wsUrl, token);
      _room = room;
      _listener = room.createListener()
        ..on<RoomDisconnectedEvent>((_) {
          state = state.copyWith(status: RtcRoomStatus.disconnected);
        });
      await room.localParticipant?.setMicrophoneEnabled(true);
      await room.localParticipant?.setCameraEnabled(true);
      state = state.copyWith(
        status: RtcRoomStatus.connected,
        micOn: true,
        cameraOn: true,
      );
      return true;
    } on Exception catch (e) {
      iPrint('RtcRoom connect failed: $e');
      await room.dispose();
      _room = null;
      state = state.copyWith(status: RtcRoomStatus.failed);
      return false;
    }
  }

  Future<void> toggleMic() async {
    final lp = _room?.localParticipant;
    if (lp == null) return;
    final next = !state.micOn;
    await lp.setMicrophoneEnabled(next);
    state = state.copyWith(micOn: next);
  }

  Future<void> toggleCamera() async {
    final lp = _room?.localParticipant;
    if (lp == null) return;
    final next = !state.cameraOn;
    await lp.setCameraEnabled(next);
    state = state.copyWith(cameraOn: next);
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
    await _teardown();
    state = state.copyWith(status: RtcRoomStatus.disconnected);
  }

  Future<void> _teardown() async {
    final listener = _listener;
    final room = _room;
    _listener = null;
    _room = null;
    await listener?.dispose();
    await room?.disconnect();
    await room?.dispose();
  }
}
