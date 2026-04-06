import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:http/http.dart' as http;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'subscriber_provider.g.dart';

/// Subscriber 页面状态
class SubscriberState {
  final String stateStr;
  final String serverUrl;
  final bool isConnecting;
  final SharedPreferences? preferences;

  const SubscriberState({
    this.stateStr = 'idle',
    this.serverUrl = 'https://192.168.0.144:9800/whep/subscribe/a1234/1',
    this.isConnecting = false,
    this.preferences,
  });

  SubscriberState copyWith({
    String? stateStr,
    String? serverUrl,
    bool? isConnecting,
    SharedPreferences? preferences,
  }) {
    return SubscriberState(
      stateStr: stateStr ?? this.stateStr,
      serverUrl: serverUrl ?? this.serverUrl,
      isConnecting: isConnecting ?? this.isConnecting,
      preferences: preferences ?? this.preferences,
    );
  }
}

/// Subscriber Provider - 管理 WHEP 拉流状态和 PeerConnection
@riverpod
class SubscriberNotifier extends _$SubscriberNotifier {
  RTCPeerConnection? _pc;
  String? _resourceUrl; // WHEP DELETE 端点

  @override
  SubscriberState build() {
    _loadSettings();
    return const SubscriberState();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final url =
        prefs.getString('pullServer') ??
        'https://192.168.0.144:9800/whep/subscribe/a1234/1';
    state = state.copyWith(serverUrl: url, preferences: prefs);
  }

  Future<void> saveServerUrl(String url) async {
    final prefs = state.preferences ?? await SharedPreferences.getInstance();
    await prefs.setString('pullServer', url);
    state = state.copyWith(serverUrl: url, preferences: prefs);
  }

  void updateState(String newState) {
    state = state.copyWith(stateStr: newState);
  }

  void setConnecting(bool connecting) {
    state = state.copyWith(isConnecting: connecting);
  }

  /// 开始拉流（WHEP 协议）
  Future<void> startSubscribe(RTCVideoRenderer remoteRenderer) async {
    if (state.isConnecting || state.stateStr == 'playing') return;

    state = state.copyWith(isConnecting: true, stateStr: 'connecting');

    try {
      // 1. 创建 PeerConnection（只接收，不发送）
      _pc = await createPeerConnection({
        'iceServers': [
          {'urls': 'stun:stun.l.google.com:19302'},
        ],
        'sdpSemantics': 'unified-plan',
      });

      // 2. 添加 transceiver 接收音视频（recvonly）
      await _pc!.addTransceiver(
        kind: RTCRtpMediaType.RTCRtpMediaTypeVideo,
        init: RTCRtpTransceiverInit(direction: TransceiverDirection.RecvOnly),
      );
      await _pc!.addTransceiver(
        kind: RTCRtpMediaType.RTCRtpMediaTypeAudio,
        init: RTCRtpTransceiverInit(direction: TransceiverDirection.RecvOnly),
      );

      // 3. 监听远端轨道并绑定到 renderer
      _pc!.onTrack = (RTCTrackEvent event) {
        if (event.streams.isNotEmpty) {
          remoteRenderer.srcObject = event.streams[0];
          state = state.copyWith(stateStr: 'playing', isConnecting: false);
          debugPrint('[WHEP Subscriber] 收到远端流');
        }
      };

      // 4. 创建 SDP Offer（WHEP 客户端也发 offer）
      final offer = await _pc!.createOffer({
        'offerToReceiveAudio': true,
        'offerToReceiveVideo': true,
      });
      await _pc!.setLocalDescription(offer);

      // 等待 ICE 收集完成（超时 5s）
      await _waitForIceGathering();

      final localDesc = await _pc!.getLocalDescription();
      if (localDesc == null) throw Exception('无法获取本地 SDP');

      // 5. POST SDP offer 到 WHEP 端点
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
        throw Exception('WHEP 服务器拒绝连接: HTTP ${response.statusCode}');
      }

      // 6. 记录 resource URL（用于 DELETE 停止拉流）
      _resourceUrl = response.headers['location'];

      // 7. 设置远端 SDP answer
      final answerSdp = response.body;
      await _pc!.setRemoteDescription(
        RTCSessionDescription(answerSdp, 'answer'),
      );

      debugPrint('[WHEP Subscriber] 拉流成功，resource=$_resourceUrl');
      // stateStr 会在 onTrack 回调中更新为 'playing'
    } catch (e) {
      debugPrint('[WHEP Subscriber] 拉流失败: $e');
      state = state.copyWith(
        isConnecting: false,
        stateStr: 'error: ${e.toString()}',
      );
      await _cleanup(remoteRenderer);
    }
  }

  /// 停止拉流
  Future<void> stopSubscribe(RTCVideoRenderer remoteRenderer) async {
    if (_resourceUrl != null) {
      try {
        await http.delete(Uri.parse(_resourceUrl!));
      } catch (e) {
        debugPrint('[SubscriberProvider] WebRTC operation failed: $e');
      }
      _resourceUrl = null;
    }
    await _cleanup(remoteRenderer);
    state = state.copyWith(stateStr: 'idle', isConnecting: false);
  }

  Future<void> _cleanup(RTCVideoRenderer remoteRenderer) async {
    remoteRenderer.srcObject = null;
    await _pc?.close();
    _pc = null;
  }

  /// 等待 ICE 候选收集完成（最长 5 秒）
  Future<void> _waitForIceGathering() async {
    final completer = Completer<void>();
    Timer? timeout;

    _pc!.onIceGatheringState = (gatheringState) {
      if (gatheringState ==
              RTCIceGatheringState.RTCIceGatheringStateComplete &&
          !completer.isCompleted) {
        completer.complete();
      }
    };

    timeout = Timer(const Duration(seconds: 5), () {
      if (!completer.isCompleted) completer.complete();
    });

    await completer.future;
    timeout.cancel();
  }
}
