import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/component/webrtc/active_call_match.dart';
import 'package:imboy/component/webrtc/session.dart';

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
}
