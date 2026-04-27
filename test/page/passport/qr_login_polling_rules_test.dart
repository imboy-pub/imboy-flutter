/// QR 登录 Notifier 状态转换决策器单测（RED → GREEN → REFACTOR）。
///
/// 锚定 `lib/page/passport/web_login_page.dart` 的 `QRLogin` Notifier 三个决策面：
///   - `_startPolling` 内 switch（轮询 tick）→ derivePollingDecision
///   - `_startExpireTimer` 内（倒计时 tick）→ deriveExpireTickDecision
///   - `_completeLogin` 内 token 校验 → deriveCompleteLoginDecision
///
/// 测试不依赖 fake_async / Riverpod / HTTP，纯 Dart。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/page/passport/qr_login_polling_rules.dart';
import 'package:imboy/page/passport/qr_login_response_rules.dart';

void main() {
  // -------------------------------------------------------------------------
  // derivePollingDecision: 11 个分支 × sessionToken 守卫
  // -------------------------------------------------------------------------
  group('derivePollingDecision', () {
    test('sessionToken=null → StopSilently（守卫 web_login_page:143）', () {
      final decision = derivePollingDecision(
        sessionToken: null,
        event: const QrStatusWaiting(),
      );
      expect(decision, isA<StopSilently>());
    });

    test('sessionToken="" → StopSilently（防御空字符串）', () {
      final decision = derivePollingDecision(
        sessionToken: '',
        event: const QrStatusWaiting(),
      );
      expect(decision, isA<StopSilently>());
    });

    test('event=QrStatusStopPolling → StopSilently', () {
      final decision = derivePollingDecision(
        sessionToken: 'sess_abc',
        event: const QrStatusStopPolling(),
      );
      expect(decision, isA<StopSilently>());
    });

    test('event=QrStatusWaiting → KeepPolling', () {
      final decision = derivePollingDecision(
        sessionToken: 'sess_abc',
        event: const QrStatusWaiting(),
      );
      expect(decision, isA<KeepPolling>());
    });

    test('event=QrStatusScanned → TransitionToScanned', () {
      final decision = derivePollingDecision(
        sessionToken: 'sess_abc',
        event: const QrStatusScanned(),
      );
      expect(decision, isA<TransitionToScanned>());
    });

    test('event=QrStatusConfirmed(token="jwt") → RequestCompleteLogin(token="jwt")', () {
      final decision = derivePollingDecision(
        sessionToken: 'sess_abc',
        event: const QrStatusConfirmed('jwt_xyz'),
      );
      expect(decision, isA<RequestCompleteLogin>());
      expect((decision as RequestCompleteLogin).token, 'jwt_xyz');
    });

    test('event=QrStatusExpired → TransitionToExpired', () {
      final decision = derivePollingDecision(
        sessionToken: 'sess_abc',
        event: const QrStatusExpired(),
      );
      expect(decision, isA<TransitionToExpired>());
    });

    test('event=QrStatusCancelled → TransitionToCancelledThenRefresh', () {
      final decision = derivePollingDecision(
        sessionToken: 'sess_abc',
        event: const QrStatusCancelled(),
      );
      expect(decision, isA<TransitionToCancelledThenRefresh>());
    });

    test('event=QrStatusUnknown(rawStatus="confirmed") → ProtocolViolation（防御）', () {
      // 协议违反：parseQrStatusResponse 在 confirmed 但 token 为空时返回
      // QrStatusUnknown(rawStatus="confirmed")，本决策器必须升级为 ProtocolViolation
      final decision = derivePollingDecision(
        sessionToken: 'sess_abc',
        event: const QrStatusUnknown('confirmed'),
      );
      expect(decision, isA<ProtocolViolation>());
    });

    test('event=QrStatusUnknown(rawStatus="weird") → KeepPolling（未知 status 容忍）', () {
      final decision = derivePollingDecision(
        sessionToken: 'sess_abc',
        event: const QrStatusUnknown('weird'),
      );
      expect(decision, isA<KeepPolling>());
    });

    test('event=QrStatusUnknown(rawStatus=null) → KeepPolling（status 字段缺失）', () {
      final decision = derivePollingDecision(
        sessionToken: 'sess_abc',
        event: const QrStatusUnknown(null),
      );
      expect(decision, isA<KeepPolling>());
    });

    test('sessionToken 守卫优先于 event 决策（即使 event=Confirmed 也 StopSilently）', () {
      final decision = derivePollingDecision(
        sessionToken: null,
        event: const QrStatusConfirmed('jwt_xyz'),
      );
      expect(decision, isA<StopSilently>());
    });
  });

  // -------------------------------------------------------------------------
  // deriveExpireTickDecision: 边界值穷尽
  // -------------------------------------------------------------------------
  group('deriveExpireTickDecision', () {
    test('remainingSeconds=60 → DecrementRemaining(59)', () {
      final decision = deriveExpireTickDecision(remainingSeconds: 60);
      expect(decision, isA<DecrementRemaining>());
      expect((decision as DecrementRemaining).newRemainingSeconds, 59);
    });

    test('remainingSeconds=2 → DecrementRemaining(1)', () {
      final decision = deriveExpireTickDecision(remainingSeconds: 2);
      expect((decision as DecrementRemaining).newRemainingSeconds, 1);
    });

    test('remainingSeconds=1 → DecrementRemaining(0)（最后 1 秒，下次 tick 才 expire）', () {
      // 注意：保留原 web_login_page.dart:202-209 行为 —— remaining=1 时减到 0，
      // 下次 tick 进入 `<= 0` 分支才 MarkExpired。避免单 tick 同时减计 + 标记
      // expired 造成双状态。
      final decision = deriveExpireTickDecision(remainingSeconds: 1);
      expect((decision as DecrementRemaining).newRemainingSeconds, 0);
    });

    test('remainingSeconds=0 → MarkExpired', () {
      final decision = deriveExpireTickDecision(remainingSeconds: 0);
      expect(decision, isA<MarkExpired>());
    });

    test('remainingSeconds=-1 → MarkExpired（防御外部 state 异常）', () {
      final decision = deriveExpireTickDecision(remainingSeconds: -1);
      expect(decision, isA<MarkExpired>());
    });

    test('remainingSeconds=-9999 → MarkExpired（极端负数仍 expire）', () {
      final decision = deriveExpireTickDecision(remainingSeconds: -9999);
      expect(decision, isA<MarkExpired>());
    });
  });

  // -------------------------------------------------------------------------
  // deriveCompleteLoginDecision: token 守卫语义
  // -------------------------------------------------------------------------
  group('deriveCompleteLoginDecision', () {
    test('token=null → RejectInvalidToken', () {
      final decision = deriveCompleteLoginDecision(token: null);
      expect(decision, isA<RejectInvalidToken>());
    });

    test('token="" → RejectInvalidToken', () {
      final decision = deriveCompleteLoginDecision(token: '');
      expect(decision, isA<RejectInvalidToken>());
    });

    test('token="jwt_abc" → ProceedWithToken("jwt_abc")', () {
      final decision = deriveCompleteLoginDecision(token: 'jwt_abc');
      expect(decision, isA<ProceedWithToken>());
      expect((decision as ProceedWithToken).token, 'jwt_abc');
    });

    test('token="   " → ProceedWithToken (不 trim 空白，对齐 web_login_page:214 isEmpty 语义)', () {
      // 关键：保留原 Notifier 行为，**不**在纯函数引入 trim() 副作用 —— 否则
      // 后续若后端契约里出现合法的 base64 全空白头部 token 会被误拒。
      final decision = deriveCompleteLoginDecision(token: '   ');
      expect(decision, isA<ProceedWithToken>());
      expect((decision as ProceedWithToken).token, '   ');
    });

    test('token=单字符 "x" → ProceedWithToken("x")', () {
      final decision = deriveCompleteLoginDecision(token: 'x');
      expect(decision, isA<ProceedWithToken>());
      expect((decision as ProceedWithToken).token, 'x');
    });
  });

  // -------------------------------------------------------------------------
  // sealed 穷尽性回归（编译期保证 — 此处只断言可被 switch 覆盖）
  // -------------------------------------------------------------------------
  group('sealed exhaustive coverage', () {
    test('PollingDecision switch 必须穷尽所有 7 个变体', () {
      const decisions = <PollingDecision>[
        KeepPolling(),
        TransitionToScanned(),
        RequestCompleteLogin('t'),
        TransitionToExpired(),
        TransitionToCancelledThenRefresh(),
        ProtocolViolation(),
        StopSilently(),
      ];
      for (final d in decisions) {
        final label = switch (d) {
          KeepPolling() => 'keep',
          TransitionToScanned() => 'scanned',
          RequestCompleteLogin() => 'confirmed',
          TransitionToExpired() => 'expired',
          TransitionToCancelledThenRefresh() => 'cancelled',
          ProtocolViolation() => 'protocol',
          StopSilently() => 'stop',
        };
        expect(label, isNotEmpty);
      }
    });
  });
}
