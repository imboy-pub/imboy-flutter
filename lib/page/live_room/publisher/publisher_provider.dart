import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:http/http.dart' as http;
import 'package:imboy/store/api/live_room_api.dart';
import 'package:imboy/store/model/live_room_model.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'publisher_provider.g.dart';

/// Publisher 页面状态
class PublisherState {
  final String stateStr;
  final String serverUrl;
  final bool isConnecting;
  final String roomId; // 当前关联的直播间 ID
  final SharedPreferences? preferences;

  const PublisherState({
    this.stateStr = 'idle',
    this.serverUrl = '',
    this.isConnecting = false,
    this.roomId = '',
    this.preferences,
  });

  PublisherState copyWith({
    String? stateStr,
    String? serverUrl,
    bool? isConnecting,
    String? roomId,
    SharedPreferences? preferences,
  }) {
    return PublisherState(
      stateStr: stateStr ?? this.stateStr,
      serverUrl: serverUrl ?? this.serverUrl,
      isConnecting: isConnecting ?? this.isConnecting,
      roomId: roomId ?? this.roomId,
      preferences: preferences ?? this.preferences,
    );
  }
}

/// Publisher Provider - 管理 WHIP 推流状态和 PeerConnection
@riverpod
class PublisherNotifier extends _$PublisherNotifier {
  RTCPeerConnection? _pc;
  MediaStream? _localStream;
  String? _resourceUrl; // WHIP DELETE 端点
  final _api = LiveRoomApi();

  @override
  PublisherState build() {
    _loadSettings();
    return const PublisherState();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final url = prefs.getString('pushServer') ?? '';
    state = state.copyWith(serverUrl: url, preferences: prefs);
  }

  Future<void> saveServerUrl(String url) async {
    final prefs = state.preferences ?? await SharedPreferences.getInstance();
    await prefs.setString('pushServer', url);
    state = state.copyWith(serverUrl: url, preferences: prefs);
  }

  /// 设置关联的直播间（携带 roomId，后续 start/stop 通知后端）
  void setRoom(LiveRoomModel room) {
    state = state.copyWith(roomId: room.id);
  }

  /// 通知后端更新直播状态为"直播中"
  Future<void> _notifyServerStart() async {
    if (state.roomId.isNotEmpty) {
      await _api.start(state.roomId);
    }
  }

  /// 通知后端更新直播状态为"已结束"
  Future<void> _notifyServerStop() async {
    if (state.roomId.isNotEmpty) {
      await _api.stop(state.roomId);
    }
  }

  void updateState(String newState) {
    state = state.copyWith(stateStr: newState);
  }

  void setConnecting(bool connecting) {
    state = state.copyWith(isConnecting: connecting);
  }

  /// 开始推流（WHIP 协议）
  Future<void> startPublish(RTCVideoRenderer localRenderer) async {
    if (state.isConnecting || state.stateStr == 'publishing') return;

    state = state.copyWith(isConnecting: true, stateStr: 'connecting');

    try {
      // 1. 获取本地媒体流
      _localStream = await navigator.mediaDevices.getUserMedia({
        'audio': true,
        'video': {
          'facingMode': 'user',
          'width': {'ideal': 1280},
          'height': {'ideal': 720},
          'frameRate': {'ideal': 30},
        },
      });

      // 绑定本地预览
      localRenderer.srcObject = _localStream;

      // 2. 创建 PeerConnection
      _pc = await createPeerConnection({
        'iceServers': [
          {'urls': 'stun:stun.l.google.com:19302'},
        ],
        'sdpSemantics': 'unified-plan',
      });

      // 3. 添加本地媒体轨道
      _localStream!.getTracks().forEach((track) {
        _pc!.addTrack(track, _localStream!);
      });

      // 4. 创建 SDP Offer
      final offer = await _pc!.createOffer({
        'offerToReceiveAudio': false,
        'offerToReceiveVideo': false,
      });
      await _pc!.setLocalDescription(offer);

      // 等待 ICE 收集完成（超时 5s）
      await _waitForIceGathering();

      final localDesc = await _pc!.getLocalDescription();
      if (localDesc == null) throw Exception('无法获取本地 SDP');

      // 5. POST SDP offer 到 WHIP 端点
      final response = await http
          .post(
            Uri.parse(state.serverUrl),
            headers: {
              'Content-Type': 'application/sdp',
              'Accept': 'application/sdp',
            },
            body: localDesc.sdp,
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 201 && response.statusCode != 200) {
        throw Exception('WHIP 服务器拒绝连接: HTTP ${response.statusCode}');
      }

      // 6. 记录 resource URL（用于 DELETE 停止推流）
      _resourceUrl = response.headers['location'];

      // 7. 设置远端 SDP answer
      final answerSdp = response.body;
      await _pc!.setRemoteDescription(
        RTCSessionDescription(answerSdp, 'answer'),
      );

      state = state.copyWith(isConnecting: false, stateStr: 'publishing');
      if (kDebugMode) debugPrint('[WHIP Publisher] 推流成功');
      // 通知后端更新直播状态
      await _notifyServerStart();
    } on Exception catch (e) {
      if (kDebugMode) debugPrint('[WHIP Publisher] 推流失败: ${e.runtimeType}');
      state = state.copyWith(isConnecting: false, stateStr: 'error');
      await _cleanup(localRenderer);
    }
  }

  /// 停止推流
  Future<void> stopPublish(RTCVideoRenderer localRenderer) async {
    // 发送 DELETE 请求通知服务器关闭推流会话
    if (_resourceUrl != null) {
      try {
        await http.delete(Uri.parse(_resourceUrl!));
      } on Exception catch (e) {
        if (kDebugMode) {}
      }
      _resourceUrl = null;
    }
    await _cleanup(localRenderer);
    // 通知后端更新直播状态
    await _notifyServerStop();
    state = state.copyWith(stateStr: 'idle', isConnecting: false);
  }

  Future<void> _cleanup(RTCVideoRenderer localRenderer) async {
    localRenderer.srcObject = null;
    _localStream?.getTracks().forEach((t) => t.stop());
    _localStream = null;
    await _pc?.close();
    _pc = null;
  }

  /// 等待 ICE 候选收集完成（最长 5 秒）
  Future<void> _waitForIceGathering() async {
    final completer = Completer<void>();
    Timer? timeout;

    void checkGatheringState() {
      if (_pc == null) {
        if (!completer.isCompleted) completer.complete();
        return;
      }
      _pc!.getLocalDescription().then((desc) {
        if (desc?.sdp != null &&
            desc!.sdp!.contains('a=candidate') &&
            !completer.isCompleted) {
          completer.complete();
        }
      });
    }

    _pc!.onIceGatheringState = (state) {
      if (state == RTCIceGatheringState.RTCIceGatheringStateComplete &&
          !completer.isCompleted) {
        completer.complete();
      }
    };

    timeout = Timer(const Duration(seconds: 5), () {
      if (!completer.isCompleted) completer.complete();
    });

    // 轮询确保不遗漏
    Timer.periodic(const Duration(milliseconds: 200), (t) {
      checkGatheringState();
      if (completer.isCompleted) t.cancel();
    });

    await completer.future;
    timeout.cancel();
  }
}
