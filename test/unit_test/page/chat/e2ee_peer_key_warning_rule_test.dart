// TOFU 对端密钥变更告警判定测试。
//
// 钉死契约：仅 C2C 单聊 + uid 非空 + uid 匹配当前对端 → 提示。
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/page/chat/chat/e2ee_peer_key_warning_rule.dart';

void main() {
  group('shouldWarnPeerKeyChanged', () {
    test('C2C + uid 匹配当前对端 → 提示', () {
      expect(
        shouldWarnPeerKeyChanged(
          isGroupChat: false,
          eventUid: '1838294017982465',
          currentPeerId: '1838294017982465',
        ),
        isTrue,
      );
    });

    test('群聊一律不提示（即使 uid 匹配）', () {
      expect(
        shouldWarnPeerKeyChanged(
          isGroupChat: true,
          eventUid: '123',
          currentPeerId: '123',
        ),
        isFalse,
      );
    });

    test('uid 不匹配当前对端 → 不提示（变更的是别的会话）', () {
      expect(
        shouldWarnPeerKeyChanged(
          isGroupChat: false,
          eventUid: '999',
          currentPeerId: '123',
        ),
        isFalse,
      );
    });

    test('事件 uid 为空 → 不提示', () {
      expect(
        shouldWarnPeerKeyChanged(
          isGroupChat: false,
          eventUid: '',
          currentPeerId: '123',
        ),
        isFalse,
      );
    });
  });
}
