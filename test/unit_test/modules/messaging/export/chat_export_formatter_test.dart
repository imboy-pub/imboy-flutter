/// W1-C 导出格式化器验收测试（txt/html）：稳定格式、排序、Unicode、
/// 换行、HTML 转义注入、空选择、拒绝类型过滤、媒体占位。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/modules/messaging/application/export/chat_export_document.dart';
import 'package:imboy/modules/messaging/application/export/chat_export_entry.dart';
import 'package:imboy/modules/messaging/application/export/chat_export_formatter.dart';
import 'package:imboy/modules/messaging/application/export/chat_export_placeholders.dart';
import 'package:imboy/modules/messaging/domain/message_status.dart';
import 'package:imboy/service/message_type_constants.dart';

ChatExportEntry _text(
  String sender,
  DateTime at,
  String body, {
  String type = MessageType.text,
}) {
  return ChatExportEntry(
    msgType: type,
    senderName: sender,
    createdAt: at,
    status: MessageStatus.sent,
    text: body,
  );
}

void main() {
  final t1 = DateTime(2026, 11, 11, 9, 59, 0);
  final t2 = DateTime(2026, 11, 11, 10, 0, 30);
  final exportedAt = DateTime(2026, 11, 11, 10, 5, 0);

  group('formatAsTxt', () {
    test('稳定格式：文档头 + `[时间] 发送者: 内容` 行', () {
      final doc = ChatExportDocument(
        conversationTitle: '张三',
        exportedAt: exportedAt,
        entries: [_text('张三', t1, '你好'), _text('李四', t2, '在吗')],
      );
      final out = ChatExportFormatter.formatAsTxt(doc);
      expect(out, contains('会话: 张三\n导出时间: 2026-11-11 10:05:00\n条数: 2\n'));
      expect(out, contains('[2026-11-11 09:59:00] 张三: 你好\n'));
      expect(out, contains('[2026-11-11 10:00:30] 李四: 在吗\n'));
    });

    test('按 createdAt 从旧到新排序；相同时间保持原始顺序（稳定）', () {
      final tie1 = DateTime(2026, 11, 11, 9, 0, 0);
      final tie2 = DateTime(2026, 11, 11, 9, 0, 0);
      final late = DateTime(2026, 11, 11, 9, 30, 0);
      // 故意乱序传入：late 在最前，tie 两个随后（原始相对顺序 B → C）
      final doc = ChatExportDocument(
        conversationTitle: 'g',
        exportedAt: exportedAt,
        entries: [
          _text('Late', late, 'last'),
          _text('B', tie1, 'first-tie'),
          _text('C', tie2, 'second-tie'),
        ],
      );
      final lines = ChatExportFormatter.formatAsTxt(doc)
          .split('\n')
          .where((l) => l.startsWith('['))
          .toList();
      expect(lines.map((l) => l.split('] ')[1].split(': ')[0]), [
        'B',
        'C',
        'Late',
      ]);
    });

    test('Unicode 原样保留：中文 / emoji / RTL（阿拉伯语、希伯来语）', () {
      const body = '你好 👋 مرحبا שלום ＡＢＣ';
      final doc = ChatExportDocument(
        conversationTitle: '会话-ر',
        exportedAt: exportedAt,
        entries: [_text('علي', t1, body)],
      );
      final out = ChatExportFormatter.formatAsTxt(doc);
      expect(out, contains(body));
      expect(out, contains('会话-ر'));
    });

    test('正文换行原样保留（txt 不转义不折叠）', () {
      final doc = ChatExportDocument(
        conversationTitle: 'a',
        exportedAt: exportedAt,
        entries: [_text('u', t1, '第一行\n第二行\r\n第三行')],
      );
      expect(ChatExportFormatter.formatAsTxt(doc), contains('第一行\n第二行\r\n第三行'));
    });

    test('空选择：空文档仍可格式化且无异常，条数为 0', () {
      final doc = ChatExportDocument(
        conversationTitle: '空会话',
        exportedAt: exportedAt,
        entries: const <ChatExportEntry>[],
      );
      final out = ChatExportFormatter.formatAsTxt(doc);
      expect(out, contains('条数: 0'));
      expect(out, isNot(contains('['))); // 无消息行（无 [时间] 行）
    });

    test('拒绝类型不出现在输出，且不计入条数', () {
      final doc = ChatExportDocument(
        conversationTitle: 'a',
        exportedAt: exportedAt,
        entries: [
          _text('u', t1, '保留我'),
          ChatExportEntry(
            msgType: MessageType.redPacket,
            senderName: 'u',
            createdAt: t2,
            status: MessageStatus.sent,
            text: '恭喜发财',
          ),
          ChatExportEntry(
            msgType: MessageType.text,
            senderName: 'u',
            createdAt: t2,
            status: MessageStatus.sending,
            text: '发送中不该出现',
          ),
        ],
      );
      final out = ChatExportFormatter.formatAsTxt(doc);
      expect(out, contains('条数: 1'));
      expect(out, contains('保留我'));
      expect(out, isNot(contains('恭喜发财')));
      expect(out, isNot(contains('发送中不该出现')));
    });

    test('媒体类型只输出安全占位描述', () {
      final entries = <ChatExportEntry>[
        ChatExportEntry(
          msgType: MessageType.image,
          senderName: 'a',
          createdAt: DateTime(2026, 11, 11, 9, 0, 1),
          status: MessageStatus.sent,
        ),
        ChatExportEntry(
          msgType: MessageType.imageMulti,
          senderName: 'a',
          createdAt: DateTime(2026, 11, 11, 9, 0, 2),
          status: MessageStatus.sent,
        ),
        ChatExportEntry(
          msgType: MessageType.voice,
          senderName: 'a',
          createdAt: DateTime(2026, 11, 11, 9, 0, 3),
          status: MessageStatus.sent,
        ),
        ChatExportEntry(
          msgType: MessageType.video,
          senderName: 'a',
          createdAt: DateTime(2026, 11, 11, 9, 0, 4),
          status: MessageStatus.sent,
        ),
        ChatExportEntry(
          msgType: MessageType.file,
          senderName: 'a',
          createdAt: DateTime(2026, 11, 11, 9, 0, 5),
          status: MessageStatus.sent,
          description: '合同.pdf',
        ),
        ChatExportEntry(
          msgType: MessageType.location,
          senderName: 'a',
          createdAt: DateTime(2026, 11, 11, 9, 0, 6),
          status: MessageStatus.sent,
          description: '北京市朝阳区',
        ),
        ChatExportEntry(
          msgType: MessageType.expression,
          senderName: 'a',
          createdAt: DateTime(2026, 11, 11, 9, 0, 7),
          status: MessageStatus.sent,
          text: '[微笑]',
        ),
      ];
      final doc = ChatExportDocument(
        conversationTitle: 'a',
        exportedAt: exportedAt,
        entries: entries,
      );
      final out = ChatExportFormatter.formatAsTxt(doc);
      expect(out, contains(ChatExportPlaceholders.zhCn.image)); // [图片]
      expect(out, contains(ChatExportPlaceholders.zhCn.voice)); // [语音]
      expect(out, contains(ChatExportPlaceholders.zhCn.video)); // [视频]
      expect(
        out,
        contains('${ChatExportPlaceholders.zhCn.file} 合同.pdf'), // [文件] 合同.pdf
      );
      expect(out, contains('${ChatExportPlaceholders.zhCn.location} 北京市朝阳区'));
      expect(out, contains(': ${ChatExportPlaceholders.zhCn.expression}'));
      // expression 显式映射为占位，忽略 label 文本
      expect(out, isNot(contains('[微笑]')));
    });

    test('quote 可见文本扁平化：回复正文 + 被引用文本空格连接', () {
      final doc = ChatExportDocument(
        conversationTitle: 'a',
        exportedAt: exportedAt,
        entries: [
          ChatExportEntry(
            msgType: MessageType.quote,
            senderName: 'a',
            createdAt: t1,
            status: MessageStatus.sent,
            text: '回复正文',
            quotedText: '被引用内容',
          ),
        ],
      );
      expect(ChatExportFormatter.formatAsTxt(doc), contains('] a: 回复正文 被引用内容'));
    });

    test('其余允许类型按安全描述导出（channelCard / 未知类型）', () {
      final doc = ChatExportDocument(
        conversationTitle: 'a',
        exportedAt: exportedAt,
        entries: [
          ChatExportEntry(
            msgType: MessageType.channelCard,
            senderName: 'a',
            createdAt: t1,
            status: MessageStatus.sent,
            description: '频道文章标题',
          ),
          ChatExportEntry(
            msgType: 'future_new_type',
            senderName: 'a',
            createdAt: t2,
            status: MessageStatus.sent,
            description: '新类型描述',
          ),
        ],
      );
      final out = ChatExportFormatter.formatAsTxt(doc);
      expect(out, contains('频道文章标题'));
      expect(out, contains('新类型描述'));
      expect(out, contains('条数: 2'));
    });
  });

  group('formatAsHtml', () {
    test('最小骨架：DOCTYPE / charset / lang / style / h1 / meta / entry', () {
      final doc = ChatExportDocument(
        conversationTitle: '张三',
        exportedAt: exportedAt,
        entries: [_text('张三', t1, '你好')],
      );
      final out = ChatExportFormatter.formatAsHtml(doc);
      expect(out, startsWith('<!DOCTYPE html>'));
      expect(out, contains('<html lang="zh-CN">'));
      expect(out, contains('<meta charset="utf-8">'));
      expect(out, contains('<style>'));
      expect(out, contains('<h1>张三</h1>'));
      expect(out, contains('<p class="meta">导出时间: 2026-11-11 10:05:00'));
      expect(out, contains('<span class="sender">张三</span>'));
      expect(out, endsWith('</html>\n'));
    });

    test('注入转义：`<script>` 与 <>&"\' 全转义，无原始标签', () {
      const payload = '''<script>alert('x & y')</script>
"quoted" <b>bold</b>''';
      final doc = ChatExportDocument(
        conversationTitle: '<b>会话名</b>',
        exportedAt: exportedAt,
        entries: [
          _text('张<script>', t1, payload),
          ChatExportEntry(
            msgType: MessageType.text,
            senderName: 'u',
            createdAt: t2,
            status: MessageStatus.sent,
            text: "a=\"1\" b='2'",
          ),
        ],
      );
      final out = ChatExportFormatter.formatAsHtml(doc);
      // 五字符全转义
      expect(out, contains('&lt;script&gt;'));
      expect(out, contains('alert(&#39;x &amp; y&#39;)'));
      expect(out, contains('&quot;quoted&quot;'));
      expect(out, contains('a=&quot;1&quot; b=&#39;2&#39;'));
      expect(out, contains('&lt;b&gt;会话名&lt;/b&gt;')); // 标题转义
      expect(out, contains('&lt;b&gt;bold&lt;/b&gt;'));
      // 负向断言：任何未转义的用户标签不可出现
      expect(out, isNot(contains('<script')));
      expect(out, isNot(contains('<b>')));
      expect(out, isNot(contains('"quoted"')));
    });

    test('正文换行转 <br>，\r\n 与 \r 归一', () {
      final doc = ChatExportDocument(
        conversationTitle: 'a',
        exportedAt: exportedAt,
        entries: [_text('u', t1, '第一行\n第二行\r\n第三行\r第四行')],
      );
      final out = ChatExportFormatter.formatAsHtml(doc);
      expect(out, contains('第一行<br>第二行<br>第三行<br>第四行'));
      expect(out, isNot(contains('第一行\n')));
    });

    test('空选择 html：仍完整可渲染，条数 0', () {
      final doc = ChatExportDocument(
        conversationTitle: '空',
        exportedAt: exportedAt,
        entries: const <ChatExportEntry>[],
      );
      final out = ChatExportFormatter.formatAsHtml(doc);
      expect(out, contains('条数: 0'));
      expect(out, contains('<h1>空</h1>'));
      expect(out, isNot(contains('class="entry"')));
    });

    test('会话名为空时使用兜底标题；拒绝类型同样被过滤', () {
      final doc = ChatExportDocument(
        conversationTitle: '',
        exportedAt: exportedAt,
        entries: [
          ChatExportEntry(
            msgType: MessageType.webrtcVideo,
            senderName: 'a',
            createdAt: t1,
            status: MessageStatus.sent,
          ),
        ],
      );
      final out = ChatExportFormatter.formatAsHtml(doc);
      expect(out, contains(ChatExportPlaceholders.zhCn.htmlTitle));
      expect(out, contains('条数: 0'));
    });
  });
}
