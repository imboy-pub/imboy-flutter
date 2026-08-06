/// Characterization tests for [decideSendMode].
///
/// slice-C-3a (TDD): `_handleSendPressed` 当前混杂 muted 检查 / 防抖判定 /
/// 编辑态分支 / quote 分支 / IO 调用,零测试覆盖。本套件钉死决策优先级:
///   1. isMuted → DenyMuted(压过所有其他分支)
///   2. 防抖窗口内 → DenyDebounced
///   3. editingMessageId 非空 → AsEdit
///   4. quoteMessage 非空 → AsQuote
///   5. 否则 → AsNewText
///
/// **不依赖**:Widget / i18n / WebSocket。纯 Dart 决策。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/modules/messaging/domain/policy/send_mode_rules.dart';

void main() {
  final base = DateTime(2026, 1, 1, 12, 0, 0);
  const debounce = Duration(milliseconds: 300);

  group('DenyMuted 优先级最高', () {
    test('isMuted=true + 其他任意输入 → DenyMuted', () {
      final d = decideSendMode(
        isMuted: true,
        now: base,
        lastSendTime: null,
        debounce: debounce,
        editingMessageId: 'm1',
        hasQuoteMessage: true,
      );
      expect(d, isA<SendDenyMuted>());
    });

    test('isMuted 压过防抖(即便在防抖窗口内也走 muted 分支)', () {
      final d = decideSendMode(
        isMuted: true,
        now: base,
        lastSendTime: base.subtract(const Duration(milliseconds: 50)),
        debounce: debounce,
        editingMessageId: null,
        hasQuoteMessage: false,
      );
      expect(d, isA<SendDenyMuted>());
    });
  });

  group('DenyDebounced', () {
    test('lastSendTime 在防抖窗口内(严格小于) → DenyDebounced', () {
      final d = decideSendMode(
        isMuted: false,
        now: base,
        lastSendTime: base.subtract(const Duration(milliseconds: 299)),
        debounce: debounce,
        editingMessageId: null,
        hasQuoteMessage: false,
      );
      expect(d, isA<SendDenyDebounced>());
    });

    test('lastSendTime=null → 不触发防抖', () {
      final d = decideSendMode(
        isMuted: false,
        now: base,
        lastSendTime: null,
        debounce: debounce,
        editingMessageId: null,
        hasQuoteMessage: false,
      );
      expect(d, isNot(isA<SendDenyDebounced>()));
    });

    test('距离恰好=debounce(300ms) → 不触发防抖(严格小于才拦)', () {
      // 钉死当前实现 `now.difference(last) < debounce`,相等时放行
      final d = decideSendMode(
        isMuted: false,
        now: base,
        lastSendTime: base.subtract(const Duration(milliseconds: 300)),
        debounce: debounce,
        editingMessageId: null,
        hasQuoteMessage: false,
      );
      expect(d, isA<SendAsNewText>());
    });

    test('距离=debounce+1ms → 不触发防抖', () {
      final d = decideSendMode(
        isMuted: false,
        now: base,
        lastSendTime: base.subtract(const Duration(milliseconds: 301)),
        debounce: debounce,
        editingMessageId: null,
        hasQuoteMessage: false,
      );
      expect(d, isA<SendAsNewText>());
    });
  });

  group('AsEdit(editingMessageId 优先于 quote/new)', () {
    test('editingMessageId 非空 → AsEdit,携带 id', () {
      final d = decideSendMode(
        isMuted: false,
        now: base,
        lastSendTime: null,
        debounce: debounce,
        editingMessageId: 'msg_abc',
        hasQuoteMessage: false,
      );
      expect(d, isA<SendAsEdit>());
      expect((d as SendAsEdit).messageId, 'msg_abc');
    });

    test('editingMessageId 非空 + hasQuote=true → 仍走 AsEdit(edit 优先)', () {
      final d = decideSendMode(
        isMuted: false,
        now: base,
        lastSendTime: null,
        debounce: debounce,
        editingMessageId: 'm1',
        hasQuoteMessage: true,
      );
      expect(d, isA<SendAsEdit>());
    });

    test('editingMessageId 空串 → 不走 AsEdit', () {
      // 钉死 `_editingMessageId != null && _editingMessageId!.isNotEmpty`
      final d = decideSendMode(
        isMuted: false,
        now: base,
        lastSendTime: null,
        debounce: debounce,
        editingMessageId: '',
        hasQuoteMessage: false,
      );
      expect(d, isA<SendAsNewText>());
    });
  });

  group('AsQuote vs AsNewText', () {
    test('hasQuote=true + editing=null → AsQuote', () {
      final d = decideSendMode(
        isMuted: false,
        now: base,
        lastSendTime: null,
        debounce: debounce,
        editingMessageId: null,
        hasQuoteMessage: true,
      );
      expect(d, isA<SendAsQuote>());
    });

    test('hasQuote=false + editing=null → AsNewText', () {
      final d = decideSendMode(
        isMuted: false,
        now: base,
        lastSendTime: null,
        debounce: debounce,
        editingMessageId: null,
        hasQuoteMessage: false,
      );
      expect(d, isA<SendAsNewText>());
    });
  });

  group('优先级总览(组合场景)', () {
    test('muted + debounce + edit + quote → muted 胜', () {
      final d = decideSendMode(
        isMuted: true,
        now: base,
        lastSendTime: base.subtract(const Duration(milliseconds: 50)),
        debounce: debounce,
        editingMessageId: 'm1',
        hasQuoteMessage: true,
      );
      expect(d, isA<SendDenyMuted>());
    });

    test('不 muted + debounce + edit + quote → debounce 胜', () {
      final d = decideSendMode(
        isMuted: false,
        now: base,
        lastSendTime: base.subtract(const Duration(milliseconds: 50)),
        debounce: debounce,
        editingMessageId: 'm1',
        hasQuoteMessage: true,
      );
      expect(d, isA<SendDenyDebounced>());
    });

    test('不 muted + 出防抖 + edit + quote → edit 胜', () {
      final d = decideSendMode(
        isMuted: false,
        now: base,
        lastSendTime: base.subtract(const Duration(seconds: 1)),
        debounce: debounce,
        editingMessageId: 'm1',
        hasQuoteMessage: true,
      );
      expect(d, isA<SendAsEdit>());
    });
  });
}
