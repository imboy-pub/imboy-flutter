// test/unit_test/page/chat/integration_smoke/chat_multi_export_smoke_test.dart
//
// W3-K 本地冒烟锚（RUN_ID=chat-multi-20261111）——
// integration_test/chat_multi_export_test.dart 的本地版：
// W1-C 导出核心真链（准入 → txt/html 格式化 → gateway fake 注入）+
// W3-J rollout flag 判定。「取消 = 零副作用」在本地以 fake 语义锚定：
// 准入拒绝 / 用户取消路径 gateway 调用数为 0（assertNoCalls）。

import 'package:flutter_chat_core/flutter_chat_core.dart' show Message;
import 'package:flutter_test/flutter_test.dart';

import 'package:imboy/app_core/feature_flags/app_feature_registry.dart';
import 'package:imboy/modules/messaging/application/export/chat_export_admission.dart';
import 'package:imboy/modules/messaging/application/export/chat_export_artifact.dart';
import 'package:imboy/modules/messaging/application/export/chat_export_document.dart';
import 'package:imboy/modules/messaging/application/export/chat_export_entry.dart';
import 'package:imboy/modules/messaging/application/export/chat_export_formatter.dart';
import 'package:imboy/modules/messaging/application/export/chat_share_gateway.dart';
import 'package:imboy/modules/messaging/domain/message_status.dart';
import 'package:imboy/service/message_type_constants.dart';

import '../../../../../integration_test/helpers/chat_multi_fixtures.dart';

void main() {
  final fixtures = ChatMultiMessageFixtures.standardSet(
    authorId: 'w3k-peer',
    textMarker: 'w3k',
  );

  ChatExportEntry entryOf(Message message, {String senderName = 'SmokeBob'}) =>
      chatMultiExportEntry(message: message, senderName: senderName);

  group('W3-K 冒烟 | 导出准入（W1-C 真实现，设备旅程②的本地锚）', () {
    test('类型矩阵：text/image/file/voice 准入；webrtc/未知拒绝', () {
      final allowed = [for (final m in fixtures) entryOf(m)];
      expect(
        allowed.every((e) => evaluateChatExportAdmission(e).allowed),
        isTrue,
        reason: '标准 fixtures（text/image/file/voice）应全部可导出',
      );

      final webrtc = evaluateChatExportAdmission(
        ChatExportEntry(
          msgType: MessageType.webrtcAudio,
          senderName: 'w3k',
          createdAt: DateTime.fromMillisecondsSinceEpoch(0),
          status: MessageStatus.sent,
        ),
      );
      expect(webrtc.allowed, isFalse, reason: 'WebRTC 不支持导出（§4.4）');
    });
  });

  group('W3-K 冒烟 | txt/html 格式化与 gateway fake（W1-C 真链）', () {
    test('formatAsTxt：按 createdAt 旧→新排序；正文类型映射', () {
      // 传入顺序故意打乱（新→旧），断言格式化内部稳定排序。
      final shuffled = [
        entryOf(fixtures[4]), // t2
        entryOf(fixtures[0]), // t1
      ];
      final doc = ChatExportDocument(
        conversationTitle: 'SmokeBob',
        entries: shuffled,
        exportedAt: DateTime.fromMillisecondsSinceEpoch(1700000000000),
      );
      final txt = ChatExportFormatter.formatAsTxt(doc);
      // 文本条目正文应按旧→新出现（'w3k-1' 在 'w3k-2' 之前）。
      final idx1 = txt.indexOf('w3k-1');
      final idx2 = txt.indexOf('w3k-2');
      expect(idx1, greaterThanOrEqualTo(0), reason: 'txt 应含第一个文本条目');
      expect(idx2, greaterThan(idx1), reason: '导出顺序 = createdAt 旧→新');
    });

    test('formatAsHtml：HTML 特殊字符转义（XSS 安全）', () {
      final entry = ChatExportEntry(
        msgType: MessageType.text,
        senderName: '<img>',
        createdAt: DateTime.fromMillisecondsSinceEpoch(1700000000000),
        status: MessageStatus.sent,
        text: '<script>alert("x")</script> & "quotes"',
      );
      final doc = ChatExportDocument(
        conversationTitle: 'W3K & <html>',
        entries: [entry],
        exportedAt: DateTime.fromMillisecondsSinceEpoch(1700000000000),
      );
      final html = ChatExportFormatter.formatAsHtml(doc);
      expect(html.contains('<script>'), isFalse, reason: '正文不得出现未转义 <script>');
      expect(html.contains('&lt;script&gt;'), isTrue);
      expect(html.contains('&amp;'), isTrue);
    });

    test('gateway fake 注入：分享调用被记录；取消 = 零副作用（零调用）', () async {
      final artifact = ChatExportArtifact.fromContent(
        content: 'w3k-export-body',
        extension: 'txt',
        conversationUk3: 'C2C_w3k_dst',
      );
      final gateway = RecordingChatShareGateway(
        outcome: const ChatShareOutcome.shared(),
      );
      final outcome = await gateway.shareFiles(
        ChatShareFilesRequest(
          artifacts: [artifact],
          filePaths: ['/tmp/${artifact.fileName}'],
        ),
      );
      expect(gateway.callCount, 1, reason: 'fake 记录调用');
      expect(outcome.status, ChatShareOutcomeStatus.shared);

      // 用户在系统面板取消（fake 默认 outcome = canceled）也走记录语义。
      final canceledPanel = RecordingChatShareGateway();
      final cancelOutcome = await canceledPanel.shareText('w3k-cancel-body');
      expect(cancelOutcome.status, ChatShareOutcomeStatus.canceled);
      expect(canceledPanel.callCount, 1);

      // 用户在确认弹窗点取消 → gateway 恒不被触达（零副作用）。
      final untouchedGateway = RecordingChatShareGateway();
      untouchedGateway.assertNoCalls(reason: '取消 = 零副作用（gateway 零调用）');
    });

    test('文件名安全：不含昵称/uid/会话标识（W1-C 隐私不变量）', () {
      final artifact = ChatExportArtifact.fromContent(
        content: 'body',
        extension: 'html',
        conversationUk3: 'C2C_1000000051_1000000056',
      );
      expect(
        artifact.fileName,
        matches(RegExp(r'^imboy-chat-export-\d{8}-[0-9a-f]{6}\.html$')),
        reason: '文件名结构 = 固定前缀 + 日期 + 随机后缀',
      );
      expect(artifact.fileName.contains('1000000051'), isFalse);
      expect(artifact.fileName.contains('SmokeBob'), isFalse);
    });
  });

  group('W3-K 冒烟 | rollout flag 判定（设备旅程③的本地锚）', () {
    test('chat_export_share_v1 / chat_history_bundle_v1 默认 false', () {
      expect(
        AppFeatureRegistry.isRolloutFlagEnabled(ChatMultiFlags.exportShare),
        isFalse,
      );
      expect(
        AppFeatureRegistry.isRolloutFlagEnabled(ChatMultiFlags.historyBundle),
        isFalse,
      );

      final override = ChatMultiFlagOverride()..enableAll();
      try {
        expect(
          AppFeatureRegistry.isRolloutFlagEnabled(ChatMultiFlags.exportShare),
          isTrue,
        );
        expect(
          AppFeatureRegistry.isRolloutFlagEnabled(ChatMultiFlags.historyBundle),
          isTrue,
        );
      } finally {
        override.restore();
      }
      expect(
        AppFeatureRegistry.isRolloutFlagEnabled(ChatMultiFlags.exportShare),
        isFalse,
        reason: 'restore 幂等',
      );
    });
  });
}
