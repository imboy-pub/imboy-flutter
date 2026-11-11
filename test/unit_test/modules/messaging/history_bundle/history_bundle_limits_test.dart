/// 条数上限（1..50）与序列化尺寸上限（256 KiB UTF-8 字节）边界验收测试。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/modules/messaging/application/history_bundle/bundle_attachment_forwarder.dart';
import 'package:imboy/modules/messaging/application/history_bundle/history_bundle_builder.dart';
import 'package:imboy/modules/messaging/application/history_bundle/history_bundle_source.dart';
import 'package:imboy/modules/messaging/application/history_bundle/history_bundle_types.dart';
import 'package:imboy/modules/messaging/application/history_bundle/history_bundle_v1.dart';
import 'package:imboy/modules/messaging/domain/message_status.dart';
import 'package:imboy/service/message_type_constants.dart';

HistoryBundleSourceMessage _text(String body, {int sentAtMs = 1760000000000}) {
  return HistoryBundleSourceMessage(
    msgType: MessageType.text,
    sourceMessageId: 'src_$sentAtMs',
    sourceChatType: 'C2C',
    sourceFromUid: '1001',
    sourceToUid: '2002',
    sentAtMs: sentAtMs,
    payload: <String, dynamic>{'text': body},
    status: MessageStatus.sent,
  );
}

HistoryBundleBuildSuccess _buildOk(List<HistoryBundleSourceMessage> msgs) {
  final r = HistoryBundleBuilder.buildForTarget('C2C_9001_9002', msgs);
  expect(r, isA<HistoryBundleBuildSuccessResult>(), reason: '期望构建成功');
  return (r as HistoryBundleBuildSuccessResult).success;
}

void main() {
  group('条数上限 1..50（§4.2 合并转发条目）', () {
    test('1 条：合法', () {
      final success = _buildOk([_text('only one')]);
      expect(success.bundle.entries, hasLength(1));
    });

    test('50 条：合法（边界值）', () {
      final msgs = [
        for (var i = 0; i < 50; i++) _text('m$i', sentAtMs: 1760000000000 + i),
      ];
      final success = _buildOk(msgs);
      expect(success.bundle.entries, hasLength(50));
    });

    test('0 条：拒绝 bundle_entries_out_of_range', () {
      final r = HistoryBundleBuilder.buildForTarget('C2C_9001_9002', const []);
      expect(r, isA<HistoryBundleBuildFailureResult>());
      expect(
        (r as HistoryBundleBuildFailureResult).failure.errorCode,
        HistoryBundleBuildErrorCode.entriesOutOfRange,
      );
    });

    test('51 条：构建前拒绝 bundle_entries_out_of_range', () {
      final msgs = [
        for (var i = 0; i < 51; i++) _text('m$i', sentAtMs: 1760000000000 + i),
      ];
      final r = HistoryBundleBuilder.buildForTarget('C2C_9001_9002', msgs);
      expect(r, isA<HistoryBundleBuildFailureResult>());
      expect(
        (r as HistoryBundleBuildFailureResult).failure.errorCode,
        HistoryBundleBuildErrorCode.entriesOutOfRange,
      );
      expect((r).failure.messageIndex, isNull);
    });
  });

  group('序列化尺寸 ≤ 256 KiB（UTF-8 字节，与后端同一常量）', () {
    const limit = HistoryBundleContract.maxPayloadBytes;
    test('常量冻结：256×1024', () {
      expect(limit, 256 * 1024);
    });

    // 线性逼近：entry payload 的 ASCII 'a' 每 +1 字符 → JSON +1 字节，
    // 一次校准即可命中任意目标字节数。
    HistoryBundleV1 bundleWithFiller(int fillerLen) =>
        _buildOk([_text('a' * fillerLen)]).bundle;

    test('恰好 256 KiB：边界值合法', () {
      final probe = bundleWithFiller(1000);
      final base = probe.serializedByteLength;
      final fillerLen = 1000 + (limit - base);
      final bundle = bundleWithFiller(fillerLen);
      expect(bundle.serializedByteLength, limit);
    });

    test('256 KiB + 1 字节：拒绝 bundle_payload_too_large', () {
      final probe = bundleWithFiller(1000);
      final base = probe.serializedByteLength;
      final fillerLen = 1000 + (limit - base) + 1;
      final r = HistoryBundleBuilder.buildForTarget('C2C_9001_9002', [
        _text('a' * fillerLen),
      ]);
      expect(r, isA<HistoryBundleBuildFailureResult>());
      expect(
        (r as HistoryBundleBuildFailureResult).failure.errorCode,
        HistoryBundleBuildErrorCode.payloadTooLarge,
      );
    });

    test('字节数按 UTF-8 计：CJK 每字符 3 字节', () {
      final ascii = _buildOk([_text('a')]).bundle.serializedByteLength;
      final cjk = _buildOk([_text('中')]).bundle.serializedByteLength;
      expect(cjk - ascii, 2); // 'a'=1 字节，'中'=3 字节
    });

    test('附件写回后尺寸复检 helper（validateBundlePayloadSize）', () {
      expect(validateBundlePayloadSize(limit), isNull);
      expect(
        validateBundlePayloadSize(limit + 1),
        HistoryBundleBuildErrorCode.payloadTooLarge,
      );
    });
  });

  group('稳定排序：createdAt 从旧到新，同时间戳保持输入顺序（§4.3）', () {
    test('乱序输入按时间升序', () {
      final success = _buildOk([
        _text('newest', sentAtMs: 3000),
        _text('oldest', sentAtMs: 1000),
        _text('middle', sentAtMs: 2000),
      ]);
      expect(
        success.bundle.entries.map((e) => e.payload['text']).toList(),
        <String>['oldest', 'middle', 'newest'],
      );
    });

    test('同 createdAt 稳定：保持输入相对顺序', () {
      final success = _buildOk([
        _text('same-1-first', sentAtMs: 2000),
        _text('older', sentAtMs: 1000),
        _text('same-2-second', sentAtMs: 2000),
        _text('same-3-third', sentAtMs: 2000),
      ]);
      expect(
        success.bundle.entries.map((e) => e.payload['text']).toList(),
        <String>['older', 'same-1-first', 'same-2-second', 'same-3-third'],
      );
    });

    test('附件任务 entryIndex 跟随排序后的条目位置', () {
      final r = HistoryBundleBuilder.buildForTarget('C2C_9001_9002', [
        HistoryBundleSourceMessage(
          msgType: MessageType.image,
          sourceMessageId: 'IMG-NEW',
          sourceChatType: 'C2C',
          sourceFromUid: '1001',
          sourceToUid: '2002',
          sentAtMs: 9000,
          payload: <String, dynamic>{'name': 'new.png'},
          status: MessageStatus.sent,
        ),
        _text('old text', sentAtMs: 1000),
      ]);
      final success = (r as HistoryBundleBuildSuccessResult).success;
      expect(success.bundle.entries.first.payload['text'], 'old text');
      expect(success.bundle.entries.last.msgType, 'image');
      final task = success.attachmentTasks.single;
      expect(task.entryIndex, 1);
      expect(task.sourceMessageId, 'IMG-NEW');
    });
  });
}
