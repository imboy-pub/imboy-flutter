// test/unit_test/page/chat/integration_smoke/chat_multi_bundle_roundtrip_smoke_test.dart
//
// W3-K 本地冒烟锚（RUN_ID=chat-multi-20261111）——
// integration_test/chat_multi_bundle_roundtrip_test.dart 的本地版：
// W2-G HistoryBundleBuilder 真构建（快照/排序/禁止字段清理/上限）+ DTO
// JSON roundtrip；fixtures 与真机版共享。详情页渲染锚由 W3-I 自有
// history_bundle_detail_page_test.dart 承担（该代码在并行 lane，集成后
// 由设备用例点气泡驱动）。

import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:imboy/modules/messaging/application/history_bundle/history_bundle_builder.dart';
import 'package:imboy/modules/messaging/application/history_bundle/history_bundle_sanitizer.dart';
import 'package:imboy/modules/messaging/application/history_bundle/history_bundle_source.dart';
import 'package:imboy/modules/messaging/application/history_bundle/history_bundle_types.dart';
import 'package:imboy/modules/messaging/domain/message_status.dart';
import 'package:imboy/service/message_type_constants.dart';

import '../../../../../integration_test/helpers/chat_multi_fixtures.dart';
import '../../../../../integration_test/helpers/chat_multi_bundle_history.dart';

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
  bundleHistoryEvidenceTests();
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

/// Pure history regressions shared with the device journey; no API or uploads.
void bundleHistoryEvidenceTests() {
  group('W3-K P2 history evidence', () {
    const markers = ['[run]-t1', '[run]-t2', '[run]-t3'];
    Map<String, dynamic> row(String id, int seq) => {
      'msg_id': id,
      'chat_type': 'C2C',
      'conv_seq': seq,
      'from': '51',
      'to': '56',
      'msg_type': HistoryBundleContract.msgType,
      'created_at':
          1, // Client clocks are deliberately not acceptance evidence.
      'accepted_at': null,
      'payload': '',
      'e2ee': {
        'meta_version': 3,
        'protocol': 'olm',
        'fan_out': 'per_device',
        'devices': {
          'synthetic-device': {'ciphertext': 'opaque-not-decoded'},
        },
      },
    };
    Map<String, dynamic> page(
      List<Map<String, dynamic>> rows, {
      int next = 100,
      int head = 100,
      bool more = false,
      bool blocked = false,
      String key = 'c2c:51:56',
    }) => {
      'code': 0,
      'payload': {
        'messages': rows,
        'next_seq': next,
        'safe_head': head,
        'has_more': more,
        'blocked': blocked,
        'conv_key': key,
      },
    };
    Map<String, dynamic> baseline() => page([row('old', 100)]);
    ChatMultiBundleHistory probe(
      List<Map<String, dynamic>> pages, {
      List<Map<String, dynamic>>? queries,
    }) {
      var index = 0;
      return ChatMultiBundleHistory(
        senderUid: '51',
        recipientUid: '56',
        fetchPage: (query) async {
          queries?.add(query);
          return pages[index < pages.length ? index++ : pages.length - 1];
        },
      );
    }

    Future<Map<String, dynamic>> wait(
      ChatMultiBundleHistory history, {
      String id = 'current',
    }) => history.waitForBundle(
      messageId: id,
      timeout: const Duration(milliseconds: 100),
      pollInterval: const Duration(milliseconds: 1),
    );

    test(
      'baseline uses safe_head, not the oldest page tail or timestamps',
      () async {
        final queries = <Map<String, dynamic>>[];
        final history = probe([
          page([row('very-old', 1)], next: 1, head: 100, more: true),
          page([row('current', 101)], next: 101, head: 101),
        ], queries: queries);
        await history.captureBaseline();
        expect(history.baselineSeq, 100);
        expect(queries.length, 1);
        expect((await wait(history))['msg_id'], 'current');
        expect(queries.last['after_seq'], '100');
        expect(queries.first['limit'], '1');
        expect(queries.last['peer_id'], '51');
      },
    );

    test(
      'more than 50 new rows: follows next_seq to exact ID on page two',
      () async {
        final queries = <Map<String, dynamic>>[];
        final history = probe([
          baseline(),
          page(
            [for (var n = 101; n <= 150; n++) row('other-$n', n)],
            next: 150,
            head: 151,
            more: true,
          ),
          page([row('current', 151)], next: 151, head: 151),
        ], queries: queries);
        await history.captureBaseline();
        expect((await wait(history))['conv_seq'], 151);
        expect(queries.map((q) => q['after_seq']), ['0', '100', '150']);
      },
    );

    test('blocked old gap: never skips to max(row.conv_seq)', () async {
      final queries = <Map<String, dynamic>>[];
      final history = probe([
        baseline(),
        page([row('old-late-archive', 105)], more: true, blocked: true),
        page([row('current', 102)], next: 102, head: 105),
      ], queries: queries);
      await history.captureBaseline();
      expect((await wait(history))['msg_id'], 'current');
      expect(queries.map((q) => q['after_seq']), ['0', '100', '100']);
    });

    test(
      'exact visible target may be above safe_head while cursor is blocked',
      () async {
        final history = probe([
          baseline(),
          page([row('current', 105)], blocked: true),
        ]);
        await history.captureBaseline();
        expect((await wait(history))['conv_seq'], 105);
      },
    );

    test('empty filtered page still follows has_more/next_seq', () async {
      final history = probe([
        baseline(),
        page([], next: 150, head: 151, more: true),
        page([row('current', 151)], next: 151, head: 151),
      ]);
      await history.captureBaseline();
      expect((await wait(history))['msg_id'], 'current');
    });

    for (final scenario in [
      'empty',
      'old-ciphertext',
      'other-new-ciphertext',
    ]) {
      test('$scenario cannot satisfy a missing current message', () async {
        final history = probe([
          baseline(),
          page(
            scenario == 'empty'
                ? []
                : [row('not-current', scenario == 'old-ciphertext' ? 99 : 105)],
            blocked: scenario == 'other-new-ciphertext',
          ),
        ]);
        await history.captureBaseline();
        await expectLater(wait(history), throwsA(isA<TimeoutException>()));
      });
    }

    test(
      'repeated runs cannot reuse the previous successful encrypted bundle',
      () async {
        final first = probe([
          baseline(),
          page([row('run-one', 101)], next: 101, head: 101),
        ]);
        await first.captureBaseline();
        expect((await wait(first, id: 'run-one'))['msg_id'], 'run-one');
        final second = probe([
          page([row('run-one', 101)], next: 101, head: 101),
          page([row('run-one', 101)], next: 101, head: 101),
        ]);
        await second.captureBaseline();
        await expectLater(
          wait(second, id: 'run-two'),
          throwsA(isA<TimeoutException>()),
        );
        final retry = probe([
          page([row('run-one', 101)], next: 101, head: 101),
          page([row('run-two', 102)], next: 102, head: 102),
        ]);
        await retry.captureBaseline();
        expect((await wait(retry, id: 'run-two'))['msg_id'], 'run-two');
      },
    );

    for (final mismatch in <String, Object>{
      'conv_seq': 100,
      'from': 'other',
      'to': 'other',
      'chat_type': 'C2G',
      'msg_type': 'text',
    }.entries) {
      test('exact ID still rejects mismatched ${mismatch.key}', () async {
        final history = probe([
          baseline(),
          page(
            [
              {...row('current', 101), mismatch.key: mismatch.value},
            ],
            next: 101,
            head: 101,
          ),
        ]);
        await history.captureBaseline();
        await expectLater(wait(history), throwsStateError);
      });
    }

    test(
      'missing/invalid baseline and API errors fail without fallback to zero',
      () async {
        for (final bad in [
          {'code': 401},
          {'code': 0, 'payload': {}},
          {
            'code': 0,
            'payload': {...baseline()['payload'] as Map, 'safe_head': 'bad'},
          },
        ]) {
          await expectLater(probe([bad]).captureBaseline(), throwsStateError);
        }
        await expectLater(wait(probe([baseline()])), throwsStateError);
      },
    );

    test(
      'conversation changes and unblocked non-progressing pages fail',
      () async {
        for (final invalidPage in [
          page([], key: 'c2c:51:someone-else'),
          page([], more: true),
          page([], next: 99),
          page([], next: 101, head: 100),
        ]) {
          final history = probe([baseline(), invalidPage]);
          await history.captureBaseline();
          await expectLater(wait(history), throwsStateError);
        }
      },
    );

    test(
      'int64 sequences keep precision and message IDs remain opaque strings',
      () async {
        const large = 9007199254741001;
        final history = probe([
          page([row('old', large)], next: large, head: large),
          page(
            [
              {...row('opaque-xid', large + 1), 'conv_seq': '${large + 1}'},
            ],
            next: large + 1,
            head: large + 1,
          ),
        ]);
        await history.captureBaseline();
        expect((await wait(history, id: 'opaque-xid'))['msg_id'], 'opaque-xid');
      },
    );

    for (final asJson in [false, true]) {
      test(
        'PFv3 empty payload with ${asJson ? 'JSON' : 'Map'} envelope is opaque',
        () {
          final encrypted = row('current', 101);
          if (asJson) encrypted['e2ee'] = jsonEncode(encrypted['e2ee']);
          expect(
            bundleHistoryPlaintext(
              encrypted,
              markers: markers,
              expectEncrypted: true,
            ),
            isNull,
          );
        },
      );
    }

    test('legacy payload ciphertext remains opaque', () {
      expect(
        bundleHistoryPlaintext(
          {
            ...row('current', 101),
            'e2ee': {'e2ee': true, 'e2ee_ver': 1},
            'payload': 'opaque-nonce.opaque-ciphertext',
          },
          markers: markers,
          expectEncrypted: true,
        ),
        isNull,
      );
    });

    test(
      'all three markers are forbidden in either ciphertext storage location',
      () {
        for (final marker in markers) {
          for (final leaking in [
            {
              ...row('current', 101),
              'e2ee': {'e2ee': true},
              'payload': marker,
            },
            {
              ...row('current', 101),
              'e2ee': {
                'meta_version': 3,
                'devices': {
                  'synthetic-device': {'ciphertext': marker},
                },
              },
            },
          ]) {
            expect(
              () => bundleHistoryPlaintext(leaking, markers: markers),
              throwsA(
                isA<StateError>().having(
                  (e) => e.toString(),
                  'diagnostic omits plaintext',
                  isNot(contains(marker)),
                ),
              ),
            );
          }
        }
      },
    );

    test(
      'malformed/missing envelopes cannot masquerade as encrypted success',
      () {
        for (final bad in [
          {...row('current', 101), 'e2ee': null, 'payload': 'not-json'},
          {...row('current', 101), 'e2ee': 'not-json'},
          {
            ...row('current', 101),
            'e2ee': {'meta_version': 3, 'devices': {}},
          },
          {
            ...row('current', 101),
            'e2ee': {'unrelated': true},
          },
        ]) {
          expect(
            () => bundleHistoryPlaintext(bad, markers: markers),
            throwsStateError,
          );
        }
      },
    );

    test('plaintext Map/JSON keeps all four entries for the existing reconciliation', () {
      final snapshot = {
        'bundle_version': 1,
        'title': 'Synthetic',
        'entries': [
          for (final marker in markers)
            {
              'msg_type': 'text',
              'payload': {'text': marker},
            },
          {
            'msg_type': 'image',
            'payload': {'uri': 'synthetic-object', 'width': 8, 'height': 8},
          },
        ],
      };
      for (final payload in [snapshot, jsonEncode(snapshot)]) {
        final plain = {
          ...row('current', 101),
          'e2ee': null,
          'payload': payload,
        };
        expect(
          bundleHistoryPlaintext(
            plain,
            markers: markers,
            expectEncrypted: false,
          ),
          snapshot,
        );
        expect(
          () => bundleHistoryPlaintext(
            plain,
            markers: markers,
            expectEncrypted: true,
          ),
          throwsStateError,
        );
      }
    });
  });
}
