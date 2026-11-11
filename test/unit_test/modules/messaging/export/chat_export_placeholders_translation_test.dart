/// W3-J 翻译缝验收：默认 zh-CN 契约不变（W1-C 冻结）、覆盖/空值/清除语义、
/// formatter 输出随覆盖变化。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/modules/messaging/application/export/chat_export_document.dart';
import 'package:imboy/modules/messaging/application/export/chat_export_entry.dart';
import 'package:imboy/modules/messaging/application/export/chat_export_formatter.dart';
import 'package:imboy/modules/messaging/application/export/chat_export_placeholders.dart';
import 'package:imboy/modules/messaging/domain/message_status.dart';
import 'package:imboy/service/message_type_constants.dart';

void main() {
  tearDown(() {
    ChatExportPlaceholders.applyTranslations(null);
  });

  test('默认（未注入翻译）= W1-C 冻结的 zh-CN 契约', () {
    expect(ChatExportPlaceholders.image, '[图片]');
    expect(ChatExportPlaceholders.voice, '[语音]');
    expect(ChatExportPlaceholders.video, '[视频]');
    expect(ChatExportPlaceholders.file, '[文件]');
    expect(ChatExportPlaceholders.location, '[位置]');
    expect(ChatExportPlaceholders.expression, '[表情]');
    expect(ChatExportPlaceholders.messageFallback, '[消息]');
    expect(ChatExportPlaceholders.conversationLabel, '会话');
    expect(ChatExportPlaceholders.exportedAtLabel, '导出时间');
    expect(ChatExportPlaceholders.countLabel, '条数');
    expect(ChatExportPlaceholders.htmlTitle, 'IMBoy 聊天记录');
    expect(ChatExportPlaceholders.htmlLang, 'zh-CN');
    expect(ChatExportPlaceholders.translations, isEmpty);
  });

  test('注入映射：全部 getter 切换；映射被快照（后续改原 map 无效）', () {
    final source = <String, String>{'image': '[Image]'};
    ChatExportPlaceholders.applyTranslations(source);
    source['image'] = '[HACK]';

    expect(ChatExportPlaceholders.image, '[Image]');
    expect(ChatExportPlaceholders.voice, '[语音]'); // 未覆盖回落
    expect(ChatExportPlaceholders.translations['image'], '[Image]');
  });

  test('空串覆盖视为未翻译：回落 zh-CN（防 i18n 空值穿透）', () {
    ChatExportPlaceholders.applyTranslations(const {'image': ''});
    expect(ChatExportPlaceholders.image, '[图片]');
  });

  test('applyTranslations(null) 清除覆盖', () {
    ChatExportPlaceholders.applyTranslations(const {'image': '[Image]'});
    expect(ChatExportPlaceholders.image, '[Image]');
    ChatExportPlaceholders.applyTranslations(null);
    expect(ChatExportPlaceholders.image, '[图片]');
  });

  test('formatter 输出随覆盖变化（纯函数签名未动）', () {
    ChatExportPlaceholders.applyTranslations(const {
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
    final txt = ChatExportFormatter.formatAsTxt(doc);
    expect(txt, contains('Conversation: Alice'));
    expect(txt, contains('Alice: [Photo]'));
    expect(
      ChatExportFormatter.formatAsHtml(doc),
      contains('<html lang="en-US">'),
    );
  });
}
