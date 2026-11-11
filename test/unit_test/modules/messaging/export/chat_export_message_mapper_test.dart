/// W3-J Message→ChatExportEntry 映射测试：显示字段白名单、状态/类型口径、
/// 发送者名解析顺序、无 msg_type 丢弃（fail-closed）。
library;

import 'package:flutter_chat_core/flutter_chat_core.dart' as core;
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/modules/messaging/domain/message_status.dart' as domain;
import 'package:imboy/modules/messaging/infrastructure/export/chat_export_message_mapper.dart';
import 'package:imboy/service/message_type_constants.dart';

void main() {
  final at = DateTime(2026, 11, 11, 9, 0, 0);

  test('TextMessage：msg_type/status/text/发送者名（resolver 注入口径）', () async {
    final entries = await chatExportEntriesFromMessages([
      core.TextMessage(authorId: '42', createdAt: at, id: 'm1', text: '你好'),
    ], senderNameResolver: (authorId) async => '张三($authorId)');
    expect(entries, hasLength(1));
    final e = entries.single;
    expect(e.msgType, MessageType.text);
    expect(e.senderName, '张三(42)');
    expect(e.text, '你好');
    expect(e.status, domain.MessageStatus.sent); // null → sent
    expect(e.createdAt, at);
    expect(e.e2eeFailedPlaceholder, isFalse);
    expect(e.burnAfterRead, isFalse);
  });

  test('状态映射：error/sending → 域枚举（会被准入拒绝）', () async {
    final entries = await chatExportEntriesFromMessages([
      core.TextMessage(
        authorId: '42',
        createdAt: at,
        id: 'm1',
        text: '失败',
        status: core.MessageStatus.error,
      ),
      core.TextMessage(
        authorId: '42',
        createdAt: at,
        id: 'm2',
        text: '发送中',
        status: core.MessageStatus.sending,
      ),
    ]);
    expect(entries[0].status, domain.MessageStatus.error);
    expect(entries[1].status, domain.MessageStatus.sending);
  });

  test('FileMessage：文件名进 description；metadata msg_type 优先于类兜底', () async {
    final entries = await chatExportEntriesFromMessages([
      core.FileMessage(
        authorId: '42',
        createdAt: at,
        id: 'm1',
        source: 'https://example.invalid/a.pdf',
        name: '合同.pdf',
        metadata: const {'msg_type': 'file'},
      ),
      core.FileMessage(
        authorId: '42',
        createdAt: at,
        id: 'm2',
        source: 'https://example.invalid/b.pdf',
        name: '报告.pdf',
        // 无 metadata：类兜底 file。
      ),
    ]);
    expect(entries[0].msgType, 'file');
    expect(entries[0].description, '合同.pdf');
    expect(entries[1].msgType, MessageType.file);
  });

  test('quote：text/quote_text 从 metadata 提取；e2ee/burn 标志位', () async {
    final entries = await chatExportEntriesFromMessages([
      core.CustomMessage(
        authorId: '42',
        createdAt: at,
        id: 'm1',
        metadata: const {
          'msg_type': 'quote',
          'text': '回复正文',
          'quote_text': '被引用文本',
          '_e2ee_failed': true,
        },
      ),
      core.CustomMessage(
        authorId: '42',
        createdAt: at,
        id: 'm2',
        metadata: const {'msg_type': 'text', 'burn_read_at': 1731300000},
      ),
    ]);
    expect(entries[0].text, '回复正文');
    expect(entries[0].quotedText, '被引用文本');
    expect(entries[0].e2eeFailedPlaceholder, isTrue);
    expect(entries[1].burnAfterRead, isTrue);
  });

  test('description 白名单优先级：filename → name → title（metadata）', () async {
    Future<String?> desc(Map<String, dynamic>? metadata) async {
      final entries = await chatExportEntriesFromMessages([
        core.CustomMessage(
          authorId: '42',
          createdAt: at,
          id: 'm1',
          metadata: {'msg_type': 'location', ...?metadata},
        ),
      ]);
      return entries.single.description;
    }

    expect(
      await desc(const {'filename': 'f.txt', 'name': 'n', 'title': 't'}),
      'f.txt',
    );
    expect(await desc(const {'name': 'n', 'title': 't'}), 'n');
    expect(await desc(const {'title': 't'}), 't');
    expect(await desc(const {}), isNull);
  });

  test(
    '发送者名回落：resolver 空 → metadata peer_name → quote_msg_author_name → 空',
    () async {
      Future<String> name(Map<String, dynamic>? metadata) async {
        final entries = await chatExportEntriesFromMessages([
          core.CustomMessage(
            authorId: '42',
            createdAt: at,
            id: 'm1',
            metadata: {'msg_type': 'text', ...?metadata},
          ),
        ], senderNameResolver: (_) async => '');
        return entries.single.senderName;
      }

      expect(await name(const {'peer_name': '对端名'}), '对端名');
      expect(await name(const {'quote_msg_author_name': '被引用者'}), '被引用者');
      // 内部标识（authorId）绝不落入导出正文：宁空勿泄。
      expect(await name(null), '');
    },
  );

  test('无 msg_type 的 CustomMessage 被丢弃（与多选 fail-closed 同口径）', () async {
    final entries = await chatExportEntriesFromMessages([
      core.CustomMessage(authorId: '42', createdAt: at, id: 'm1'),
      core.CustomMessage(
        authorId: '42',
        createdAt: at,
        id: 'm2',
        metadata: const {'msg_type': ''},
      ),
      core.TextMessage(authorId: '42', createdAt: at, id: 'm3', text: 'ok'),
    ]);
    expect(entries, hasLength(1));
    expect(entries.single.text, 'ok');
  });

  test('createdAt 缺失：epoch 兜底（不崩、确定性排序位）', () async {
    final entries = await chatExportEntriesFromMessages([
      core.TextMessage(authorId: '42', id: 'm1', text: '无时间'),
    ]);
    expect(entries.single.createdAt, DateTime.fromMillisecondsSinceEpoch(0));
  });
}
