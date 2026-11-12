/// W3-J 翻译缝验收（W5-G3-5 参数化后）：默认 zh-CN 契约不变（W1-C 冻结）、
/// 覆盖/空值/null 语义、映射快照、formatter 输出随传入快照变化。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/modules/messaging/application/export/chat_export_document.dart';
import 'package:imboy/modules/messaging/application/export/chat_export_entry.dart';
import 'package:imboy/modules/messaging/application/export/chat_export_formatter.dart';
import 'package:imboy/modules/messaging/application/export/chat_export_placeholders.dart';
import 'package:imboy/modules/messaging/domain/message_status.dart';
import 'package:imboy/service/message_type_constants.dart';

void main() {
  test('默认（zhCn 快照）= W1-C 冻结的 zh-CN 契约', () {
    final p = ChatExportPlaceholders.zhCn;
    expect(p.image, '[图片]');
    expect(p.voice, '[语音]');
    expect(p.video, '[视频]');
    expect(p.file, '[文件]');
    expect(p.location, '[位置]');
    expect(p.expression, '[表情]');
    expect(p.messageFallback, '[消息]');
    expect(p.conversationLabel, '会话');
    expect(p.exportedAtLabel, '导出时间');
    expect(p.countLabel, '条数');
    expect(p.htmlTitle, 'IMBoy 聊天记录');
    expect(p.htmlLang, 'zh-CN');
    expect(p.translations, isEmpty);
  });

  test('注入映射：getter 切换；映射被快照（后续改原 map 无效）', () {
    final source = <String, String>{'image': '[Image]'};
    final p = ChatExportPlaceholders.of(source);
    source['image'] = '[HACK]';

    expect(p.image, '[Image]');
    expect(p.voice, '[语音]'); // 未覆盖回落
    expect(p.translations['image'], '[Image]');
  });

  test('空串覆盖视为未翻译：回落 zh-CN（防 i18n 空值穿透）', () {
    final p = ChatExportPlaceholders.of(const {'image': ''});
    expect(p.image, '[图片]');
  });

  test('of(null) = 纯 zh-CN 兜底（无 provider 路径，无跨导出残留）', () {
    final p = ChatExportPlaceholders.of(null);
    expect(p.image, '[图片]');
    expect(p.translations, isEmpty);
    // 与 zhCn 缺省实例同口径：格式化器缺省参数即此快照。
    expect(p.htmlLang, ChatExportPlaceholders.zhCn.htmlLang);
  });

  test('formatter 输出随传入快照变化（纯函数，无全局态）', () {
    final placeholders = ChatExportPlaceholders.of(const {
      ChatExportTranslationKey.conversationLabel: 'Conversation',
      ChatExportTranslationKey.image: '[Photo]',
      ChatExportTranslationKey.htmlLang: 'en-US',
    });
    final doc = ChatExportDocument(
      conversationTitle: 'Alice',
      entries: [
        ChatExportEntry(
          msgType: MessageType.image,
          senderName: 'Alice',
          createdAt: DateTime(2026, 11, 11, 9, 0, 0),
          status: MessageStatus.sent,
        ),
      ],
      exportedAt: DateTime(2026, 11, 11, 10, 0, 0),
    );
    final txt = ChatExportFormatter.formatAsTxt(
      doc,
      placeholders: placeholders,
    );
    expect(txt, contains('Conversation: Alice'));
    expect(txt, contains('Alice: [Photo]'));
    expect(
      ChatExportFormatter.formatAsHtml(doc, placeholders: placeholders),
      contains('<html lang="en-US">'),
    );
    // 不传快照的调用不受上面注入影响（无全局态，W5-G3-5）。
    expect(ChatExportFormatter.formatAsTxt(doc), contains('会话: Alice'));
  });
}
