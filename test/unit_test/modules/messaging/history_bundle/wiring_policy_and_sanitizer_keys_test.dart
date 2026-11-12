/// Central Wiring 配套回归（W3-L F-3 / §12.5 类型策略）：
/// 1. sanitizer 禁止键补齐 `header_hash`/`ciphertext`（裸信封片段任意层清理）；
/// 2. `HistoryBundleBuilder.isTypeBundleAdmissible` 与 `_admit` 类型桶同源
///    （别称归一 + 快照/附件集合）。
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:imboy/modules/messaging/application/history_bundle/history_bundle_builder.dart';
import 'package:imboy/modules/messaging/application/history_bundle/history_bundle_sanitizer.dart';

void main() {
  group('BundleSanitizer F-3 补键', () {
    test('header_hash / ciphertext 任意嵌套层被清理并计数', () {
      final input = <String, dynamic>{
        'text': 'hi',
        'header_hash': 'h1',
        'nested': {
          'ciphertext': 'c1',
          'deeper': [
            <String, dynamic>{'header_hash': 'h2', 'ok': 1},
          ],
        },
      };
      final r = BundleSanitizer.sanitize(input);
      expect(r.cleaned['header_hash'], isNull);
      expect((r.cleaned['nested'] as Map)['ciphertext'], isNull);
      final deeper =
          ((r.cleaned['nested'] as Map)['deeper'] as List).first as Map;
      expect(deeper['header_hash'], isNull);
      expect(deeper['ok'], 1);
      expect(r.removedFieldCount, 3);
      // 输入不被原地修改（不可变性）
      expect(input['header_hash'], 'h1');
      expect(input['text'], 'hi');
    });

    test('既有键仍被清理（回归锚：peer_id / e2ee 前缀，含驼峰变体）', () {
      final r = BundleSanitizer.sanitize(<String, dynamic>{
        'peer_id': 'p',
        'e2ee_envelope': <String, dynamic>{},
        'e2ee': <String, dynamic>{},
        'e2eeRoomKey': <String, dynamic>{}, // 驼峰变体（G2-8）
        'keep': 1,
      });
      expect(r.cleaned.containsKey('peer_id'), isFalse);
      expect(r.cleaned.containsKey('e2ee_envelope'), isFalse);
      expect(r.cleaned.containsKey('e2ee'), isFalse);
      expect(r.cleaned.containsKey('e2eeRoomKey'), isFalse);
      expect(r.cleaned['keep'], 1);
    });
  });

  group('HistoryBundleBuilder.isTypeBundleAdmissible（§12.5 类型策略）', () {
    test('快照/附件类型 → true（含别称归一 audio→voice）', () {
      expect(HistoryBundleBuilder.isTypeBundleAdmissible('text'), isTrue);
      expect(HistoryBundleBuilder.isTypeBundleAdmissible('image'), isTrue);
      expect(HistoryBundleBuilder.isTypeBundleAdmissible('imageMulti'), isTrue);
      expect(HistoryBundleBuilder.isTypeBundleAdmissible('voice'), isTrue);
      expect(
        HistoryBundleBuilder.isTypeBundleAdmissible('audio'),
        isTrue,
        reason: '协议别称归一 audio→voice 后进附件桶',
      );
      expect(HistoryBundleBuilder.isTypeBundleAdmissible('quote'), isTrue);
      expect(HistoryBundleBuilder.isTypeBundleAdmissible('location'), isTrue);
      expect(HistoryBundleBuilder.isTypeBundleAdmissible('expression'), isTrue);
    });

    test('不可合并类型 → false（webrtc 别称/红包/系统/未知/null）', () {
      expect(
        HistoryBundleBuilder.isTypeBundleAdmissible('webrtc_audio'),
        isFalse,
      );
      expect(
        HistoryBundleBuilder.isTypeBundleAdmissible('webrtcAudio'),
        isFalse,
      );
      expect(HistoryBundleBuilder.isTypeBundleAdmissible('redPacket'), isFalse);
      expect(
        HistoryBundleBuilder.isTypeBundleAdmissible('groupNotice'),
        isFalse,
      );
      expect(HistoryBundleBuilder.isTypeBundleAdmissible('nope'), isFalse);
      expect(HistoryBundleBuilder.isTypeBundleAdmissible(null), isFalse);
    });
  });
}
