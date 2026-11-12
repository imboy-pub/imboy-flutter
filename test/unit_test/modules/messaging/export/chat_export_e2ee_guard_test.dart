/// W5-G3 复审 S1-L4 验收：导出 E2EE 确认门判定 =
/// 「outgoing 需加密 OR 本次导出消息存在 E2EE 历史行」任一命中。
///
/// 缺口背景：部署级策略从加密翻为不加密后，单靠 outgoing 判定会让历史
/// E2EE 消息的导出**静默跳过**「内容将离开加密环境」确认——历史密文
/// 落盘/分享的敏感性不因当前策略放松而消失。
library;

import 'package:flutter_chat_core/flutter_chat_core.dart' as core;
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/modules/messaging/infrastructure/export/chat_export_e2ee_guard.dart';
import 'package:imboy/service/encryption_mode.dart';

core.TextMessage _msg(Map<String, dynamic>? metadata) => core.TextMessage(
  authorId: '42',
  createdAt: DateTime(2026, 11, 11, 9, 0, 0),
  id: 'm1',
  text: '正文',
  metadata: metadata,
);

void main() {
  tearDown(() {
    EncryptionModeService.debugSet(
      mode: EncryptionMode.plaintext,
      initialized: false,
    );
  });

  test('outgoing 需加密（strictE2ee）：无历史标记也需确认', () async {
    EncryptionModeService.debugSet(
      mode: EncryptionMode.strictE2ee,
      initialized: true,
    );
    expect(
      // toId 缺省跳过 AiPlaintextGate 分支（测试环境未接线，判定确定性）。
      await isEncryptedConversationForExport(
        chatType: 'C2C',
        messages: [
          _msg(const {'text': '明文历史'}),
        ],
      ),
      isTrue,
    );
  });

  test('outgoing=plaintext + 无 E2EE 历史标记：不需要确认（明文部署正路）', () async {
    EncryptionModeService.debugSet(
      mode: EncryptionMode.plaintext,
      initialized: true,
    );
    expect(
      await isEncryptedConversationForExport(
        chatType: 'C2C',
        toId: 'peer',
        messages: [
          _msg(const {'text': '明文历史'}),
          _msg(null),
        ],
      ),
      isFalse,
    );
  });

  test('S1-L4 缺口修复：outgoing=plaintext 但存在 e2ee 元数据非空的历史行 → 需确认', () async {
    EncryptionModeService.debugSet(
      mode: EncryptionMode.plaintext,
      initialized: true,
    );
    expect(
      await isEncryptedConversationForExport(
        chatType: 'C2C',
        toId: 'peer',
        messages: [
          _msg(const {'text': '明文行'}),
          // 历史 E2EE 行：e2ee 元数据被透传进 metadata（Map 形状非空）
          _msg(const {
            'text': '密文行',
            'e2ee': <String, dynamic>{'meta_version': 3},
          }),
        ],
      ),
      isTrue,
    );
  });

  test('S1-L4：outgoing=plaintext + 解密失败占位行（_e2ee_failed）→ 需确认', () async {
    EncryptionModeService.debugSet(
      mode: EncryptionMode.plaintext,
      initialized: true,
    );
    expect(
      await isEncryptedConversationForExport(
        chatType: 'C2C',
        toId: 'peer',
        messages: [
          _msg(const {'_e2ee_failed': true, '_e2ee_reason': 'decrypt_failed'}),
        ],
      ),
      isTrue,
    );
  });

  test('空 e2ee 元数据（Map 空 / 空串）不算历史行：不需要确认', () async {
    EncryptionModeService.debugSet(
      mode: EncryptionMode.plaintext,
      initialized: true,
    );
    // 落库里 e2ee='' 是明文行的常规形状（chat_provider 反应消息同款）。
    expect(
      hasE2eeHistoryMarker(_msg(const {'e2ee': <String, dynamic>{}})),
      isFalse,
    );
    expect(hasE2eeHistoryMarker(_msg(const {'e2ee': ''})), isFalse);
  });

  test('policy 未初始化（requireReadyForSend 抛异常）：fail-closed 需确认（不回归）', () async {
    // 未 debugSet → isInitialized=false → 抛 E2eeSecurityException → 守卫兜住。
    expect(
      await isEncryptedConversationForExport(
        chatType: 'C2C',
        toId: 'peer',
        messages: const <core.Message>[],
      ),
      isTrue,
    );
  });

  test('hasE2eeHistoryMarker：无 metadata / 非法形状安全返回 false', () {
    expect(hasE2eeHistoryMarker(_msg(null)), isFalse);
    expect(
      hasE2eeHistoryMarker(_msg(const {'e2ee': 42})), // 非 Map/String 形状
      isFalse,
    );
  });
}
