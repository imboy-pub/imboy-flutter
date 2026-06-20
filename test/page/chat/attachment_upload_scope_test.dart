/// 单元测试：聊天附件上传 scope/scope_ref 派生
///
/// 覆盖 resource-access-control.md §5/§7 契约：
/// - C2G 群聊 → scope=group, scope_ref=group_id
/// - C2C 单聊 → scope=c2c, scope_ref=`c2c:<minUid>:<maxUid>`（整数归一化顺序）
/// - 系统会话/未知 → private（避免误标可见范围）
///
/// 回归点：历史 BUG 是 _uploadScope 误判 conversationUk3 为冒号权威格式
/// （c2c:/c2g:），而生成器实际产出大写下划线格式（C2C_/C2G_），导致永远
/// 回退 private。本测试锁定按【类型前缀 + peerId/currentUid】派生，与
/// conversationUk3 的具体分隔符形态解耦。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/page/chat/chat/attachment_handler.dart';

void main() {
  group('ChatAttachmentHandler.deriveUploadScope', () {
    test('C2G 群聊：scope=group，scope_ref=group_id（peerId）', () {
      final s = ChatAttachmentHandler.deriveUploadScope(
        conversationUk3: 'C2G_52278_900001',
        currentUid: '52278',
        peerId: '900001',
      );
      expect(s.scope, 'group');
      expect(s.scopeRef, '900001');
    });

    test('C2C 单聊：scope=c2c，scope_ref 为 c2c:min:max（整数归一化）', () {
      final s = ChatAttachmentHandler.deriveUploadScope(
        conversationUk3: 'C2C_52278_53314',
        currentUid: '53314',
        peerId: '52278',
      );
      expect(s.scope, 'c2c');
      expect(s.scopeRef, 'c2c:52278:53314');
    });

    test('C2C：currentUid/peerId 顺序颠倒仍归一化为同一 conv_key', () {
      final a = ChatAttachmentHandler.deriveUploadScope(
        conversationUk3: 'C2C_x',
        currentUid: '52278',
        peerId: '53314',
      );
      final b = ChatAttachmentHandler.deriveUploadScope(
        conversationUk3: 'C2C_x',
        currentUid: '53314',
        peerId: '52278',
      );
      expect(a.scopeRef, b.scopeRef);
      expect(a.scopeRef, 'c2c:52278:53314');
    });

    test('C2C：整数顺序而非字符串顺序（9 < 52278）', () {
      final s = ChatAttachmentHandler.deriveUploadScope(
        conversationUk3: 'C2C_9_52278',
        currentUid: '52278',
        peerId: '9',
      );
      // 字符串排序会把 "52278" 排在 "9" 前面，整数排序则 9 在前
      expect(s.scopeRef, 'c2c:9:52278');
    });

    test('legacy 冒号形态 c2c:1:2 也按类型前缀识别为 c2c（防御性）', () {
      final s = ChatAttachmentHandler.deriveUploadScope(
        conversationUk3: 'c2c:1:2',
        currentUid: '1',
        peerId: '2',
      );
      expect(s.scope, 'c2c');
      expect(s.scopeRef, 'c2c:1:2');
    });

    test('type 为权威源：type=C2C 即便 uk3 缺前缀也归 c2c', () {
      final s = ChatAttachmentHandler.deriveUploadScope(
        conversationUk3: 'legacy-hash-no-prefix',
        currentUid: '52278',
        peerId: '53314',
        type: 'C2C',
      );
      expect(s.scope, 'c2c');
      expect(s.scopeRef, 'c2c:52278:53314');
    });

    test('type 为权威源：type=C2G 即便 uk3 缺前缀也归 group', () {
      final s = ChatAttachmentHandler.deriveUploadScope(
        conversationUk3: '',
        currentUid: '52278',
        peerId: '900001',
        type: 'C2G',
      );
      expect(s.scope, 'group');
      expect(s.scopeRef, '900001');
    });

    test('C2S 系统会话（type 优先）→ private', () {
      final s = ChatAttachmentHandler.deriveUploadScope(
        conversationUk3: 'C2S_SYSTEM_52278',
        currentUid: '52278',
        peerId: '0',
        type: 'C2S',
      );
      expect(s.scope, 'private');
      expect(s.scopeRef, isNull);
    });

    test('Web 大 TSID（>2^53）按 BigInt 整数序，不退化为字符串序', () {
      // 两个 64 位 TSID，仅末位不同；字符串序与整数序在此一致，
      // 但若用 53 位 int 解析会丢精度致比较错乱。BigInt 保证精确。
      const small = '7300000000000000001';
      const large = '7300000000000000002';
      final s = ChatAttachmentHandler.deriveUploadScope(
        conversationUk3: 'C2C_x',
        currentUid: large,
        peerId: small,
        type: 'C2C',
      );
      expect(s.scopeRef, 'c2c:$small:$large');
    });

    test('S2C 系统会话 → private，scope_ref 为 null', () {
      final s = ChatAttachmentHandler.deriveUploadScope(
        conversationUk3: 'S2C_SYSTEM_52278',
        currentUid: '52278',
        peerId: '0',
      );
      expect(s.scope, 'private');
      expect(s.scopeRef, isNull);
    });

    test('未知/空 conversationUk3 → private', () {
      final s = ChatAttachmentHandler.deriveUploadScope(
        conversationUk3: '',
        currentUid: '52278',
        peerId: '53314',
      );
      expect(s.scope, 'private');
      expect(s.scopeRef, isNull);
    });
  });
}
