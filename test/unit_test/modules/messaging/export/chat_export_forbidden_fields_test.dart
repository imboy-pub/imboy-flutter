/// W1-C 禁止字段扫描验收测试：对全部导出输出（txt/html/文件名）做字符串
/// 包含断言，证明 PLAN_SNAPSHOT §4.4/§4.5 禁止字段清单零泄漏。
///
/// 禁止出现：peer_id、conversation_uk3、sender_did、sender_dtype、
/// E2EE content key/descriptor、burn_read_at、服务端内部主键、
/// 原会话成员列表。
library;

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/modules/messaging/application/export/chat_export_artifact.dart';
import 'package:imboy/modules/messaging/application/export/chat_export_document.dart';
import 'package:imboy/modules/messaging/application/export/chat_export_entry.dart';
import 'package:imboy/modules/messaging/application/export/chat_export_formatter.dart';
import 'package:imboy/modules/messaging/domain/message_status.dart';
import 'package:imboy/service/message_type_constants.dart';

void main() {
  // 覆盖所有输出通道的富文档：文本/媒体/quote/卡片全类型混合
  final doc = ChatExportDocument(
    conversationTitle: '张三',
    exportedAt: DateTime(2026, 11, 11, 10, 5, 0),
    entries: [
      ChatExportEntry(
        msgType: MessageType.text,
        senderName: '张三',
        createdAt: DateTime(2026, 11, 11, 9, 0, 0),
        status: MessageStatus.sent,
        text: '正常正文内容',
      ),
      ChatExportEntry(
        msgType: MessageType.file,
        senderName: '李四',
        createdAt: DateTime(2026, 11, 11, 9, 1, 0),
        status: MessageStatus.sent,
        description: '报表.xlsx',
      ),
      ChatExportEntry(
        msgType: MessageType.quote,
        senderName: '王五',
        createdAt: DateTime(2026, 11, 11, 9, 2, 0),
        status: MessageStatus.sent,
        text: '回复内容',
        quotedText: '被引用内容',
      ),
      ChatExportEntry(
        msgType: MessageType.location,
        senderName: '张三',
        createdAt: DateTime(2026, 11, 11, 9, 3, 0),
        status: MessageStatus.sent,
        description: '公司地址',
      ),
    ],
  );

  final txt = ChatExportFormatter.formatAsTxt(doc);
  final html = ChatExportFormatter.formatAsHtml(doc);
  final txtArtifact = ChatExportArtifact.fromContent(
    content: txt,
    extension: 'txt',
    conversationUk3: 'conv_uk3_should_not_leak',
    now: DateTime(2026, 11, 11),
    random: Random(3),
  );
  final htmlArtifact = ChatExportArtifact.fromContent(
    content: html,
    extension: 'html',
    conversationUk3: 'conv_uk3_should_not_leak',
    now: DateTime(2026, 11, 11),
    random: Random(4),
  );

  const forbiddenTokens = <String>[
    'peer_id',
    'conversation_uk3',
    'conv_uk3_should_not_leak',
    'sender_did',
    'sender_dtype',
    'content_key',
    'descriptor',
    'burn_read_at',
    'uk3',
    'did',
  ];

  test('txt 输出零禁止字段，且正向内容确实在（非空转扫描）', () {
    expect(txt, contains('正常正文内容')); // 正向对照
    expect(txt, contains('张三'));
    for (final token in forbiddenTokens) {
      expect(txt.contains(token), isFalse, reason: 'txt 输出泄漏禁止字段: $token');
    }
  });

  test('html 输出零禁止字段', () {
    expect(html, contains('正常正文内容')); // 正向对照
    for (final token in forbiddenTokens) {
      expect(html.contains(token), isFalse, reason: 'html 输出泄漏禁止字段: $token');
    }
  });

  test('导出文件名零禁止字段（artifact.conversationUk3 不得进入文件名）', () {
    final names = <String>[txtArtifact.fileName, htmlArtifact.fileName];
    for (final name in names) {
      expect(
        name,
        matches(RegExp(r'^imboy-chat-export-\d{8}-[0-9a-f]{6}\.(txt|html)$')),
      );
      for (final token in forbiddenTokens) {
        expect(name.contains(token), isFalse, reason: '文件名泄漏禁止字段: $token');
      }
    }
  });

  test('输出不含消息服务端 id / 成员列表形态的 JSON 结构', () {
    // DTO 无 id/payload 字段，输出为纯行文本——以结构化痕迹断言兜底
    for (final output in [txt, html]) {
      expect(output, isNot(contains('"id"')));
      expect(output, isNot(contains('payload')));
      expect(output, isNot(contains('members')));
      expect(output, isNot(contains('member_list')));
    }
  });
}
