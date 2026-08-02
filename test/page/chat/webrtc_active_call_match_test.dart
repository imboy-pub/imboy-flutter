import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/component/webrtc/active_call_match.dart';
import 'package:imboy/component/webrtc/func.dart'
    show p2pSignalingReady, setP2pSignalingReady;
import 'package:imboy/component/webrtc/session.dart';
import 'package:imboy/service/message_webrtc.dart';

void main() {
  test('ICE restart 的独立 envelope 仍匹配原始活动通话', () {
    final session = WebRTCSession(
      peerId: '118',
      sid: '117-118',
      callId: 'call-original',
    );

    expect(
      isActiveWebRtcCallOffer(
        hasCallOverlay: true,
        peerId: '118',
        callId: 'call-original',
        sessions: [session],
      ),
      isTrue,
    );
  });

  test('不同通话 ID 不得注入当前通话', () {
    final session = WebRTCSession(
      peerId: '118',
      sid: '117-118',
      callId: 'call-original',
    );

    expect(
      isActiveWebRtcCallOffer(
        hasCallOverlay: true,
        peerId: '118',
        callId: 'call-other',
        sessions: [session],
      ),
      isFalse,
    );
  });

  test('没有活动通话页面时不吞掉新来电', () {
    final session = WebRTCSession(
      peerId: '118',
      sid: '117-118',
      callId: 'call-original',
    );

    expect(
      isActiveWebRtcCallOffer(
        hasCallOverlay: false,
        peerId: '118',
        callId: 'call-original',
        sessions: [session],
      ),
      isFalse,
    );
  });

  test('通话页订阅建立前 candidate 进入短期缓存', () async {
    setP2pSignalingReady(false);
    expect(p2pSignalingReady, isFalse);
    const data = <String, dynamic>{
      'id': 'wire-candidate-1',
      'from': '118',
      'to': '117',
      'type': 'WEBRTC_CANDIDATE',
      'payload': <String, dynamic>{
        'call_id': 'call-race-1',
        'candidate': <String, dynamic>{
          'sdpMLineIndex': 0,
          'sdpMid': '0',
          'candidate': 'candidate:1 1 udp ... typ relay',
        },
      },
    };

    await MessageWebrtc.instance.handleWebRTC('WEBRTC_CANDIDATE', data);
    expect(MessageWebrtc.instance.takePendingCandidates('call-race-1'), [data]);
    setP2pSignalingReady(true);
    expect(p2pSignalingReady, isTrue);
  });
}
