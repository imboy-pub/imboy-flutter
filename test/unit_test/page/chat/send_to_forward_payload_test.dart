import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/page/chat/send_to/send_to_provider.dart';

/// 转发消息构造契约测试。
///
/// 钉住两个真机实测到的缺陷（2026-08-03，从群聊转发到单聊）：
///   1. 源消息 metadata 覆盖了目标会话的 peer_id / conversation_uk3，
///      发出的 payload 仍指向源群，消息归属错乱。
///   2. 顶层 msg_type 为空 → 服务端回 action=invalid_message，
///      消息显示「[无效消息类型]」并每 5~10s 无限重试。
void main() {
  group('SendToNotifier.buildForwardPayload', () {
    test('目标会话的 peer_id / conversation_uk3 覆盖源消息 metadata', () {
      final payload = SendToNotifier.buildForwardPayload(
        // 源自群会话的 metadata
        sourceMetadata: {
          'peer_id': '104603643803863040',
          'conversation_uk3': 'C2G_50_104603643803863040',
          'msg_type': 'text',
        },
        text: 'group-msg-001',
        peerId: 1,
        conversationUk3: 'C2C_1_50',
      );

      expect(payload['peer_id'], 1, reason: '必须是目标会话的 peer，不是源群 gid');
      expect(payload['conversation_uk3'], 'C2C_1_50');
      expect(payload['text'], 'group-msg-001');
      // 与会话无关的元信息应保留
      expect(payload['msg_type'], 'text');
    });

    test('metadata 为 null 时也能构造出完整 payload', () {
      final payload = SendToNotifier.buildForwardPayload(
        sourceMetadata: null,
        text: 'hi',
        peerId: 7,
        conversationUk3: 'C2C_7_50',
      );

      expect(payload['text'], 'hi');
      expect(payload['peer_id'], 7);
      expect(payload['conversation_uk3'], 'C2C_7_50');
    });
  });

  group('SendToNotifier.resolveForwardMsgType', () {
    test('取源消息的 msg_type', () {
      expect(
        SendToNotifier.resolveForwardMsgType({'msg_type': 'image'}),
        'image',
      );
    });

    test('metadata 为 null → 兜底 text（顶层 msg_type 绝不能为空）', () {
      expect(SendToNotifier.resolveForwardMsgType(null), 'text');
    });

    test('msg_type 为空串 → 兜底 text', () {
      expect(SendToNotifier.resolveForwardMsgType({'msg_type': ''}), 'text');
    });

    test('msg_type 缺失 → 兜底 text', () {
      expect(SendToNotifier.resolveForwardMsgType({'text': 'hi'}), 'text');
    });
  });
}
