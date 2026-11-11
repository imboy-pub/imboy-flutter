// test/unit_test/page/chat/integration_smoke/chat_multi_bundle_roundtrip_smoke_test.dart
//
// W3-K 本地冒烟锚（RUN_ID=chat-multi-20261111）——
// integration_test/chat_multi_bundle_roundtrip_test.dart 的本地版：
// W2-G HistoryBundleBuilder 真构建（快照/排序/禁止字段清理/上限）+ DTO
// JSON roundtrip；fixtures 与真机版共享。详情页渲染锚由 W3-I 自有
// history_bundle_detail_page_test.dart 承担（该代码在并行 lane，集成后
// 由设备用例点气泡驱动）。

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:imboy/modules/messaging/application/history_bundle/history_bundle_builder.dart';
import 'package:imboy/modules/messaging/application/history_bundle/history_bundle_sanitizer.dart';
import 'package:imboy/modules/messaging/application/history_bundle/history_bundle_source.dart';
import 'package:imboy/modules/messaging/application/history_bundle/history_bundle_types.dart';
import 'package:imboy/modules/messaging/domain/message_status.dart';
import 'package:imboy/service/message_type_constants.dart';

import '../../../../../integration_test/helpers/chat_multi_fixtures.dart';

/// fixtures standardSet（text/image/file/voice/text，createdAt 升序）
/// → HistoryBundleSourceMessage（W2-G 输入契约）。
List<HistoryBundleSourceMessage> _sources({
  Map<int, Map<String, dynamic>> payloadOverrides = const {},
}) {
  final msgs = ChatMultiMessageFixtures.standardSet(
    authorId: '1000000056',
    textMarker: 'w3k',
    baseTime: DateTime.fromMillisecondsSinceEpoch(1700000000000),
  );
  return [
    for (var i = 0; i < msgs.length; i++)
      () {
        final base = chatMultiBundleSource(
          msgs[i],
          chatType: 'C2C',
          fromUid: '1000000056',
          toUid: '1000000051',
          senderName: 'SmokeBob',
        );
        if (!payloadOverrides.containsKey(i)) return base;
        return HistoryBundleSourceMessage(
          msgType: base.msgType,
          sourceMessageId: base.sourceMessageId,
          sourceChatType: base.sourceChatType,
          sourceFromUid: base.sourceFromUid,
          sourceToUid: base.sourceToUid,
          sentAtMs: base.sentAtMs,
          status: base.status,
          senderName: base.senderName,
          payload: payloadOverrides[i]!,
        );
      }(),
  ];
}

HistoryBundleBuildSuccess? _successOf(HistoryBundleBuildResult result) =>
    switch (result) {
      HistoryBundleBuildSuccessResult(:final success) => success,
      _ => null,
    };

void main() {
  group('W3-K 冒烟 | HistoryBundleBuilder（设备旅程②③的本地锚）', () {
    test('标准集构建成功：5 entries 旧→新，附件任务 3 个，audio 归一 voice', () {
      final success = _successOf(
        HistoryBundleBuilder.buildForTarget('C2C_w3k_dst', _sources()),
      );
      expect(success, isNotNull, reason: '标准 fixtures 全部可合并');
      expect(success!.bundle.entries.length, 5);
      expect(success.attachmentTasks.length, 3, reason: 'image/file/voice 各 1');
      expect(success.bundle.entries.map((e) => e.msgType).toList(), [
        MessageType.text,
        MessageType.image,
        MessageType.file,
        MessageType.voice,
        MessageType.text,
      ], reason: 'entries 顺序应等于源顺序；audio 归一 voice（W2-G）');
    });

    test('禁止字段递归清理：源 payload 脏字段不进 bundle JSON', () {
      final success = _successOf(
        HistoryBundleBuilder.buildForTarget(
          'C2C_w3k_dst',
          _sources(
            payloadOverrides: {
              0: {
                'msg_type': 'text',
                'text': 'clean-me',
                'peer_id': '1000000056',
                'conversation_uk3': 'C2C_w3k_src',
                'burn_read_at': 123,
                'content_key': 'dirty',
                'attachment_descriptor': {'k': 'v'},
              },
            },
          ),
        ),
      );
      expect(success, isNotNull);
      expect(success!.sanitizedFieldCount, greaterThan(0));

      final json = jsonEncode(success.bundle.toJson());
      for (final forbidden in [
        '"peer_id"',
        '"conversation_uk3"',
        '"burn_read_at"',
        '"content_key"',
        '"attachment_descriptor"',
      ]) {
        expect(
          json.contains(forbidden),
          isFalse,
          reason: 'bundle JSON 不得含禁止字段 $forbidden（冻结合同 §4.5）',
        );
      }
      expect(json.contains('clean-me'), isTrue, reason: '可见正文保留');
    });

    test('BundleSanitizer.isForbiddenKey 契约：e2ee 前缀族全拒', () {
      expect(BundleSanitizer.isForbiddenKey('peer_id'), isTrue);
      expect(BundleSanitizer.isForbiddenKey('e2ee_envelope'), isTrue);
      expect(BundleSanitizer.isForbiddenKey('e2ee_devices'), isTrue);
      expect(BundleSanitizer.isForbiddenKey('sender_did'), isTrue);
      expect(BundleSanitizer.isForbiddenKey('members'), isTrue);
      expect(BundleSanitizer.isForbiddenKey('text'), isFalse);
      expect(BundleSanitizer.isForbiddenKey('msg_type'), isFalse);
    });

    test('上限：1 条合法；51 条 entries_out_of_range 整体拒绝', () {
      final one = _successOf(
        HistoryBundleBuilder.buildForTarget(
          'C2C_w3k_dst',
          _sources().take(1).toList(),
        ),
      );
      expect(one, isNotNull, reason: '1 条下界合法（冻结合同 §4.2）');

      final many = <HistoryBundleSourceMessage>[
        for (var i = 0; i < 51; i++)
          HistoryBundleSourceMessage(
            msgType: MessageType.text,
            sourceMessageId: 'w3k-many-$i',
            sourceChatType: 'C2C',
            sourceFromUid: '1000000056',
            sourceToUid: '1000000051',
            sentAtMs: 1700000000000 + i,
            status: MessageStatus.sent,
            payload: {'msg_type': 'text', 'text': 'n-$i'},
          ),
      ];
      final failure = switch (HistoryBundleBuilder.buildForTarget(
        'C2C_w3k_dst',
        many,
      )) {
        HistoryBundleBuildFailureResult(:final failure) => failure,
        _ => null,
      };
      expect(failure, isNotNull);
      expect(
        failure!.errorCode,
        HistoryBundleBuildErrorCode.entriesOutOfRange,
        reason: '51 条应整体拒绝（稳定错误码）',
      );
    });

    test('空目标 uk3 拒绝；msg_type 冻结常量；JSON roundtrip 保 entries 序', () {
      expect(
        HistoryBundleBuilder.buildForTarget('', _sources()),
        isA<HistoryBundleBuildFailureResult>(),
        reason: '空目标拒绝（W2-G）',
      );
      expect(
        HistoryBundleContract.msgType,
        'chat_history_bundle',
        reason: '冻结 msg_type 常量（后端合同同值）',
      );

      final success = _successOf(
        HistoryBundleBuilder.buildForTarget('C2C_w3k_dst', _sources()),
      )!;
      final roundtripped = jsonDecode(
        jsonEncode(success.bundle.toJson()),
      ) as Map<String, dynamic>;
      final entries = roundtripped['entries'] as List;
      expect(entries.length, 5, reason: 'roundtrip 不丢 entry');
      expect(
        [for (final e in entries) (e as Map<String, dynamic>)['msg_type']],
        [
          MessageType.text,
          MessageType.image,
          MessageType.file,
          MessageType.voice,
          MessageType.text,
        ],
        reason: 'roundtrip 保顺序',
      );
      expect(
        roundtripped['bundle_version'],
        HistoryBundleContract.bundleVersion,
      );
    });
  });
}
