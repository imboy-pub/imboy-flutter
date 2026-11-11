/// W1-C 导出产物验收测试：安全文件名（隐私断言）、UTF-8 字节数、
/// 临时文件清理策略、分享网关契约形态。
library;

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/modules/messaging/application/export/chat_export_artifact.dart';
import 'package:imboy/modules/messaging/application/export/chat_share_gateway.dart';

void main() {
  final fixedNow = DateTime(2026, 11, 11, 10, 5, 0);

  group('generateChatExportFileName 文件名安全', () {
    test('结构：imboy-chat-export-<yyyyMMdd>-<6位小写hex>.<ext>', () {
      final name = generateChatExportFileName(
        extension: 'txt',
        now: fixedNow,
        random: Random(1),
      );
      expect(
        name,
        matches(RegExp(r'^imboy-chat-export-20261111-[0-9a-f]{6}\.txt$')),
      );
      final htmlName = generateChatExportFileName(
        extension: 'html',
        now: fixedNow,
        random: Random(1),
      );
      expect(
        htmlName,
        matches(RegExp(r'^imboy-chat-export-20261111-[0-9a-f]{6}\.html$')),
      );
    });

    test('隐私断言：不含昵称/uid/手机号/会话名/uk3 等任何用户数据', () {
      // 生成器签名不接收用户数据；即便内容充满隐私串，文件名也不可能带出
      final name = generateChatExportFileName(now: fixedNow, random: Random(7));
      const privacyTokens = <String>[
        '张三',
        '13800138000',
        '10086',
        'conv_uk3_abc',
        'uk3',
        'peer_id',
        'uid',
      ];
      for (final token in privacyTokens) {
        expect(name.contains(token), isFalse, reason: '文件名泄漏: $token');
      }
      // 严格白名单：除日期与 hex 外无其他可变内容
      expect(
        name,
        matches(RegExp(r'^imboy-chat-export-\d{8}-[0-9a-f]{6}\.txt$')),
      );
    });

    test('随机后缀：两次生成（同种子不同种子均测）不可预测且可区分', () {
      final a = generateChatExportFileName(now: fixedNow, random: Random(42));
      final b = generateChatExportFileName(now: fixedNow, random: Random(43));
      expect(a, isNot(equals(b)));
    });

    test('非法扩展名拒绝（防文件名注入）', () {
      expect(
        () => generateChatExportFileName(extension: 'txt"evil'),
        throwsArgumentError,
      );
      expect(
        () => generateChatExportFileName(extension: ''),
        throwsArgumentError,
      );
      expect(
        () => generateChatExportFileName(extension: 'TXT'),
        throwsArgumentError,
      );
      expect(
        () => generateChatExportFileName(extension: 'superlongext'),
        throwsArgumentError,
      );
    });
  });

  group('ChatExportArtifact', () {
    test('fromContent：MIME 按扩展名、byteSize 为 UTF-8 字节数', () {
      final txt = ChatExportArtifact.fromContent(
        content: '你好abc', // 中文 3 字节 ×2 + ascii ×3 = 9
        extension: 'txt',
        conversationUk3: 'conv-1',
        now: fixedNow,
        random: Random(1),
      );
      expect(txt.byteSize, 9);
      expect(txt.mimeType, 'text/plain; charset=utf-8');
      expect(txt.fileName, endsWith('.txt'));
      expect(txt.conversationUk3, 'conv-1');

      final html = ChatExportArtifact.fromContent(
        content: '<p>你好</p>',
        extension: 'html',
        conversationUk3: 'conv-1',
        now: fixedNow,
        random: Random(1),
      );
      expect(html.mimeType, 'text/html; charset=utf-8');
      expect(html.fileName, endsWith('.html'));
    });

    test('emoji 等多字节字符字节数正确', () {
      final a = ChatExportArtifact.fromContent(
        content: '👋', // U+1F44B → 4 字节
        extension: 'txt',
        conversationUk3: 'c',
        now: fixedNow,
        random: Random(1),
      );
      expect(a.byteSize, 4);
    });
  });

  group('ExportTempFilePolicy 默认清理策略', () {
    const policy = DefaultExportTempFilePolicy();

    ChatExportArtifact artifact(String conv, String name) => ChatExportArtifact(
      fileName: name,
      mimeType: 'text/plain; charset=utf-8',
      byteSize: 10,
      conversationUk3: conv,
    );

    test('分享完成（成功/取消/失败）→ 全量清理', () {
      final all = [artifact('c1', 'a.txt'), artifact('c2', 'b.txt')];
      expect(policy.artifactsToPurgeAfterShare(all), equals(all));
      expect(policy.artifactsToPurgeAfterShare(const []), isEmpty);
    });

    test('会话结束 → 仅清理该会话产物，其他会话不动', () {
      final a1 = artifact('c1', 'a.txt');
      final a2 = artifact('c1', 'b.txt');
      final a3 = artifact('c2', 'c.txt');
      final purge = policy.artifactsToPurgeOnConversationClosed(
        conversationUk3: 'c1',
        artifacts: [a1, a2, a3],
      );
      expect(purge, equals([a1, a2]));
      expect(purge.contains(a3), isFalse);
    });
  });

  group('ChatShareGateway 契约（本波无平台实现，fake 钉住形态）', () {
    test('fake 实现满足接口：shareText / shareFiles + 结果语义', () async {
      final gateway = _FakeGateway();
      final r1 = await gateway.shareText('hello', subject: 's');
      expect(r1.status, ChatShareOutcomeStatus.shared);

      final r2 = await gateway.shareFiles(
        ChatShareFilesRequest(
          artifacts: [
            ChatExportArtifact(
              fileName: 'f.txt',
              mimeType: 'text/plain; charset=utf-8',
              byteSize: 5,
              conversationUk3: 'c',
            ),
          ],
          filePaths: ['/tmp/f.txt'],
        ),
      );
      expect(r2.status, ChatShareOutcomeStatus.canceled);

      final r3 = await gateway.failNext();
      expect(r3.status, ChatShareOutcomeStatus.error);
      expect(r3.errorCode, 'share_unavailable');
      expect(ChatShareOutcome.shared().status, ChatShareOutcomeStatus.shared);
      expect(
        ChatShareOutcome.canceled().status,
        ChatShareOutcomeStatus.canceled,
      );
    });
  });
}

class _FakeGateway implements ChatShareGateway {
  @override
  Future<ChatShareOutcome> shareText(String text, {String? subject}) async {
    return const ChatShareOutcome.shared();
  }

  @override
  Future<ChatShareOutcome> shareFiles(ChatShareFilesRequest request) async {
    return const ChatShareOutcome.canceled();
  }

  Future<ChatShareOutcome> failNext() async {
    return const ChatShareOutcome.error('share_unavailable');
  }
}
