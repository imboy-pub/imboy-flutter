/// Characterization tests for [resolveQuoteAuthorName].
///
/// slice-C-4: `_sendQuoteMessage` 与 `QuoteTipsWidget.title` 两处都在解析
/// "引用消息的发送方显示名"，但枢轴不同：
///   - `_sendQuoteMessage`     比较 authorId == peerId（"来自对方"）
///   - `QuoteTipsWidget.title` 比较 authorId == currentUid（"来自自己"）
///
/// 语义完全等价，提取后注入 currentUid / myNickname / peerTitle，可独立单测钉死矩阵契约。
///
/// 契约（钉死）：
///   - quoteAuthorId == currentUid → myNickname
///   - quoteAuthorId != currentUid → peerTitle
///   - quoteAuthorId == null      → peerTitle（安全回退：身份不明按"对方"处理）
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/page/chat/chat/utils/quote_author_rules.dart';

void main() {
  const me = 'uid_me_001';
  const peer = 'uid_peer_999';
  const myNick = '我的昵称';
  const peerName = '对方名称';

  // ─────────────────────────────────────────────────────────
  // 核心矩阵
  // ─────────────────────────────────────────────────────────
  group('resolveQuoteAuthorName 核心矩阵', () {
    test('authorId == currentUid → myNickname', () {
      expect(
        resolveQuoteAuthorName(
          quoteAuthorId: me,
          currentUid: me,
          myNickname: myNick,
          peerTitle: peerName,
        ),
        myNick,
      );
    });

    test('authorId == peerId (非 currentUid) → peerTitle', () {
      expect(
        resolveQuoteAuthorName(
          quoteAuthorId: peer,
          currentUid: me,
          myNickname: myNick,
          peerTitle: peerName,
        ),
        peerName,
      );
    });

    test('authorId 为完全陌生的 uid → peerTitle（安全回退）', () {
      expect(
        resolveQuoteAuthorName(
          quoteAuthorId: 'uid_stranger_xyz',
          currentUid: me,
          myNickname: myNick,
          peerTitle: peerName,
        ),
        peerName,
      );
    });
  });

  // ─────────────────────────────────────────────────────────
  // 边界：null quoteAuthorId（对应 QuoteTipsWidget null-safety check）
  // ─────────────────────────────────────────────────────────
  group('null quoteAuthorId', () {
    test('null → peerTitle（身份不明按对方处理）', () {
      expect(
        resolveQuoteAuthorName(
          quoteAuthorId: null,
          currentUid: me,
          myNickname: myNick,
          peerTitle: peerName,
        ),
        peerName,
      );
    });
  });

  // ─────────────────────────────────────────────────────────
  // 边界：空串
  // ─────────────────────────────────────────────────────────
  group('空串边界', () {
    test('两者都为空串 → myNickname（空 == 空）', () {
      expect(
        resolveQuoteAuthorName(
          quoteAuthorId: '',
          currentUid: '',
          myNickname: myNick,
          peerTitle: peerName,
        ),
        myNick,
      );
    });

    test('quoteAuthorId 空串 + currentUid 非空 → peerTitle', () {
      expect(
        resolveQuoteAuthorName(
          quoteAuthorId: '',
          currentUid: me,
          myNickname: myNick,
          peerTitle: peerName,
        ),
        peerName,
      );
    });
  });
}
