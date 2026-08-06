/// WebRTC 信令协议对齐测试 / WebRTC signaling protocol alignment
///
/// 钉死 Flutter 客户端 ↔ Erlang 后端的 WS 信令 wire 契约，防止任一侧漂移。
///
/// 后端契约来源（imboy 仓）：
///   - src/logic/message_router_logic.erl:82  `<<"webrtc_", _Event/binary>>`
///       → 按 `type` 的 `webrtc_` 前缀（小写）路由到 webrtc_ws_logic
///   - 同文件 :84  `To = maps:get(<<"to">>, Data)`
///       → 取 **`to`** 键解析 ToUid；发 `to_id` 会 `{badkey,<<"to">>}` 崩溃
///   - src/logic/webrtc_ws_logic.erl  `message_ds:send_next(ToUid, MsgId, Msg, _)`
///       → 整包逐字透传，对端解析须与发送格式对齐
///
/// 对齐两端：
///   A. 发送格式 buildWebRtcRequest —— 满足后端前缀匹配与 `to` 键约束
///   B. 透传后接收解析 WebRTCSignalingModel —— 还原 webRtcType 与 payload
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/component/webrtc/func.dart' show buildWebRtcRequest;
import 'package:imboy/store/model/webrtc_signaling_model.dart';

/// 客户端发起 / 接收的全部信令事件（与 onMessageP2P 的 switch 分支对齐）。
const _events = <String>[
  'offer',
  'answer',
  'candidate',
  'ringing',
  'busy',
  'bye',
  'leave',
];

void main() {
  group('A. 发送格式对齐后端路由契约', () {
    for (final event in _events) {
      test('webrtc_$event：type 带 webrtc_ 前缀 + 用 to 键（非 to_id）', () {
        final req = buildWebRtcRequest(
          event: event,
          payload: const {'k': 'v'},
          msgId: 'mid-1',
          to: '52278',
          from: '53314',
          ts: 1718800000000,
        );

        // 后端按 webrtc_ 前缀（小写）路由
        final type = req['type'] as String;
        expect(type, 'webrtc_$event');
        expect(type.toLowerCase().startsWith('webrtc_'), isTrue);

        // 后端取 `to` 键；严禁回退为 to_id（会崩溃）
        expect(req.containsKey('to'), isTrue);
        expect(req['to'], '52278');
        expect(req.containsKey('to_id'), isFalse);

        // 透传所需的其余必备字段
        expect(req['id'], 'mid-1');
        expect(req['from'], '53314');
        expect(req['payload'], const {'k': 'v'});
        expect(req['ts'], isA<int>());
      });
    }
  });

  group('B. 透传后接收解析对齐（后端逐字透传，sent == received）', () {
    for (final event in _events) {
      test('webrtc_$event：webRtcType 还原为 $event', () {
        final sent = buildWebRtcRequest(
          event: event,
          payload: const {'k': 'v'},
          msgId: 'mid-2',
          to: '52278',
          from: '53314',
          ts: 1718800000000,
        );

        // 后端 message_ds:send_next 整包透传 → 对端收到的就是 sent
        final model = WebRTCSignalingModel.fromJson(sent);

        // onMessageP2P 的 switch 基于 webRtcType（已剥离 webrtc_ 前缀）
        expect(model.webRtcType, event);
        expect(model.from, '53314');
        expect(model.to, '52278');
        expect(model.msgId, 'mid-2');
        expect(model.payload, const {'k': 'v'});
      });
    }
  });

  group('C. offer/answer/candidate 的 payload 子结构对齐', () {
    test('offer/answer 透传 sd{sdp,type}，接收方能取回', () {
      final sent = buildWebRtcRequest(
        event: 'offer',
        payload: const {
          'media': 'video',
          'sd': {'sdp': 'v=0...', 'type': 'offer'},
        },
        msgId: 'mid-3',
        to: '52278',
        from: '53314',
        ts: 1718800000000,
      );
      final model = WebRTCSignalingModel.fromJson(sent);
      final sd = model.payload['sd'] as Map<String, dynamic>;
      expect(sd['type'], 'offer');
      expect(sd['sdp'], 'v=0...');
      expect(model.payload['media'], 'video');
    });

    test('candidate 透传 candidate{sdpMLineIndex,sdpMid,candidate}', () {
      final sent = buildWebRtcRequest(
        event: 'candidate',
        payload: const {
          'candidate': {
            'sdpMLineIndex': 0,
            'sdpMid': '0',
            'candidate': 'candidate:1 1 udp ...',
          },
        },
        msgId: 'mid-4',
        to: '52278',
        from: '53314',
        ts: 1718800000000,
      );
      final model = WebRTCSignalingModel.fromJson(sent);
      final c = model.payload['candidate'] as Map<String, dynamic>;
      expect(c['sdpMLineIndex'], 0);
      expect(c['sdpMid'], '0');
      expect(c['candidate'], isA<String>());
    });
  });

  group('D. 后端大小写不敏感前缀匹配（cowboy_bstr:to_lower）', () {
    test('TYPE 大写也应被识别并剥离前缀', () {
      final model = WebRTCSignalingModel.fromJson(const {
        'id': 'mid-5',
        'type': 'WEBRTC_OFFER',
        'from': '53314',
        'to': '52278',
        'payload': <String, dynamic>{},
      });
      expect(model.webRtcType, 'offer');
    });
  });
}
