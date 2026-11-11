/// QR SSE 帧解析 + 降级决策单测（PR-4α RED→GREEN→REFACTOR）。
library;

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/page/passport/qr_login_sse_rules.dart';
import 'package:imboy/page/passport/qr_login_response_rules.dart';

void main() {
  // -------------------------------------------------------------------------
  // parseSseFrame: SSE 帧解析（10 测）
  // -------------------------------------------------------------------------
  group('parseSseFrame', () {
    test('data: {"status":"waiting"} → QrStatusWaiting', () {
      final event = parseSseFrame('data: {"status":"waiting"}');
      expect(event, isA<QrStatusWaiting>());
    });

    test('data: {"status":"scanned"} → QrStatusScanned', () {
      final event = parseSseFrame('data: {"status":"scanned"}');
      expect(event, isA<QrStatusScanned>());
    });

    test('data: {"status":"confirmed","token":"jwt_xyz"} → QrStatusConfirmed("jwt_xyz")', () {
      final event = parseSseFrame(
        'data: {"status":"confirmed","token":"jwt_xyz"}',
      );
      expect(event, isA<QrStatusConfirmed>());
      expect((event as QrStatusConfirmed).token, 'jwt_xyz');
    });

    test('data: {"status":"expired"} → QrStatusExpired', () {
      final event = parseSseFrame('data: {"status":"expired"}');
      expect(event, isA<QrStatusExpired>());
    });

    test('data: {"status":"cancelled"} → QrStatusCancelled', () {
      final event = parseSseFrame('data: {"status":"cancelled"}');
      expect(event, isA<QrStatusCancelled>());
    });

    test('data: {"status":"future_unknown"} → QrStatusUnknown(透传)', () {
      final event = parseSseFrame('data: {"status":"future_unknown"}');
      expect(event, isA<QrStatusUnknown>());
      expect((event as QrStatusUnknown).rawStatus, 'future_unknown');
    });

    test('data: {"status":"confirmed"} 缺 token → QrStatusUnknown("confirmed") (协议违反防御)', () {
      // 与 parseQrStatusResponse:155 行为对齐：confirmed 必须附 token
      final event = parseSseFrame('data: {"status":"confirmed"}');
      expect(event, isA<QrStatusUnknown>());
      expect((event as QrStatusUnknown).rawStatus, 'confirmed');
    });

    test('非 data: 前缀（如 SSE comment ":heartbeat"）→ QrStatusStopPolling', () {
      // SSE 规范允许 `:heartbeat` 注释行；客户端不应解析为 event
      final event = parseSseFrame(':heartbeat');
      expect(event, isA<QrStatusStopPolling>());
    });

    test('JSON 解析失败 → QrStatusStopPolling（防御网络截断）', () {
      final event = parseSseFrame('data: {invalid json');
      expect(event, isA<QrStatusStopPolling>());
    });

    test('空字符串 → QrStatusStopPolling', () {
      expect(parseSseFrame(''), isA<QrStatusStopPolling>());
    });

    test('data:{"status":"waiting"} 无空格也接受（SSE 规范允许）', () {
      final event = parseSseFrame('data:{"status":"waiting"}');
      expect(event, isA<QrStatusWaiting>());
    });

    test('SSE and polling preserve the same exact authoritative UID', () {
      // Same synthetic wire pair asserted by backend qr_login_uid_contract_tests.
      const wire =
          '{"status":"confirmed","token":"synthetic-qr-contract-token",'
          '"uid":111174215241304065,"uid_str":"111174215241304065",'
          '"future_field":"ignored by existing clients"}';
      final payload = jsonDecode(wire) as Map<String, dynamic>;
      final sse = parseSseFrame('data: $wire') as QrStatusConfirmed;
      final polling = parseQrStatusResponse(
        ok: true,
        code: 0,
        payload: payload,
      ) as QrStatusConfirmed;
      expect(sse.token, polling.token);
      expect(sse.uid, payload['uid_str']);
      expect(sse.uid, polling.uid);
    });

    test('non-finite numeric compatibility fields cannot assert identity', () {
      for (final uid in [
        double.nan,
        double.infinity,
        double.negativeInfinity,
      ]) {
        final event = parseQrStatusResponse(
          ok: true,
          code: 0,
          payload: {
            'status': 'confirmed',
            'token': 'synthetic-token',
            'uid': uid,
            'uid_str': '42',
          },
        ) as QrStatusConfirmed;
        expect(event.uid, isNull);
      }
    });

    test('exact legacy string UID is preserved without the new field', () {
      final event = parseSseFrame(
        'data: {"status":"confirmed","token":"synthetic-token",'
        '"uid":"9223372036854775807"}',
      ) as QrStatusConfirmed;
      expect(event.uid, '9223372036854775807');
    });

    for (final uidFields in <Map<String, dynamic>>[
      {'uid_str': '42', 'uid': 42},
      {'uid_str': '42', 'uid': '42'},
      {'uid_str': '42'},
      {'uid_str': '9223372036854775807'},
    ]) {
      test(
        'exact UID accepts consistent or absent legacy field: $uidFields',
        () {
          final payload = {
            'status': 'confirmed',
            'token': 'synthetic-token',
            ...uidFields,
          };
          final sse = parseSseFrame(
            'data: ${jsonEncode(payload)}',
          ) as QrStatusConfirmed;
          final polling = parseQrStatusResponse(
            ok: true,
            code: 0,
            payload: payload,
          ) as QrStatusConfirmed;
          expect(sse.uid, uidFields['uid_str']);
          expect(polling.uid, uidFields['uid_str']);
        },
      );
    }

    test(
      'safe legacy numeric UID uses the same parsing on both transports',
      () {
        const payload = {
          'status': 'confirmed',
          'token': 'synthetic-claimed-token',
          'uid': 9007199254740991,
        };
        final sse =
            parseSseFrame('data: ${jsonEncode(payload)}') as QrStatusConfirmed;
        final polling = parseQrStatusResponse(
          ok: true,
          code: 0,
          payload: payload,
        ) as QrStatusConfirmed;
        expect(sse.uid, '9007199254740991');
        expect(sse.uid, polling.uid);
      },
    );

    for (final invalidUid in <Object?>[
      null,
      '',
      '   ',
      0,
      -1,
      9007199254740992,
      1.5,
      true,
      <String, Object>{'uid': 'not-authoritative'},
      <String>['not-authoritative'],
    ]) {
      test(
        'invalid UID ($invalidUid) is never synthesized by either parser',
        () {
          final payload = {
            'status': 'confirmed',
            'token': 'synthetic-claimed-token',
            'uid': invalidUid,
            'scanned_by': 'not-a-wire-uid',
            'user': {'uid': 'not-authoritative'},
          };
          final sse = parseSseFrame(
            'data: ${jsonEncode(payload)}',
          ) as QrStatusConfirmed;
          final polling = parseQrStatusResponse(
            ok: true,
            code: 0,
            payload: payload,
          ) as QrStatusConfirmed;
          expect(sse.uid, isNull);
          expect(polling.uid, isNull);
        },
      );
    }

    for (final uidFields in <Map<String, dynamic>>[
      {'uid_str': null, 'uid': 42},
      {'uid_str': '', 'uid': 42},
      {'uid_str': ' 42 ', 'uid': 42},
      {'uid_str': '42\n'},
      {'uid_str': '9223372036854775808'},
      {'uid_str': '999999999999999999999999999999999999999999999'},
      {'uid_str': '042', 'uid': 42},
      {'uid_str': '0', 'uid': 42},
      {'uid_str': '-1', 'uid': 42},
      {'uid_str': 42, 'uid': 42},
      {'uid_str': '43', 'uid': 42},
      {'uid_str': '43', 'uid': '42'},
      {'uid_str': '42', 'uid': 1.5},
      {'uid_str': '42', 'uid': -9007199254740992},
      {'uid_str': '42', 'uid': null},
      {'uid_str': '42', 'uid': true},
      {'uid_str': '42', 'uid': <String, dynamic>{}},
    ]) {
      test(
        'malformed or conflicting exact UID cannot downgrade: $uidFields',
        () {
          final payload = {
            'status': 'confirmed',
            'token': 'synthetic-claimed-token',
            ...uidFields,
          };
          final sse = parseSseFrame(
            'data: ${jsonEncode(payload)}',
          ) as QrStatusConfirmed;
          final polling = parseQrStatusResponse(
            ok: true,
            code: 0,
            payload: payload,
          ) as QrStatusConfirmed;
          expect(sse.uid, isNull);
          expect(polling.uid, isNull);
        },
      );
    }

    test('already-claimed responses carry no reusable login credentials', () {
      final sse = parseSseFrame(': claimed_elsewhere');
      final polling = parseQrStatusResponse(
        ok: true,
        code: 5203,
        payload: const <String, dynamic>{},
      );
      expect(sse, isA<QrStatusStopPolling>());
      expect(polling, isA<QrStatusStopPolling>());
    });
  });

  // -------------------------------------------------------------------------
  // shouldFallbackToPolling: 降级决策（6 测）
  // -------------------------------------------------------------------------
  group('shouldFallbackToPolling', () {
    test('sseAttemptFailed=true → 立即降级（连接异常路径）', () {
      expect(
        shouldFallbackToPolling(
          sseConnected: false,
          sseAttemptFailed: true,
          silentSeconds: 0,
        ),
        isTrue,
      );
    });

    test('未连且超出宽限期（silentSeconds=3）→ 降级', () {
      expect(
        shouldFallbackToPolling(
          sseConnected: false,
          sseAttemptFailed: false,
          silentSeconds: 3,
        ),
        isTrue,
      );
    });

    test('未连但还在宽限期（silentSeconds=2）→ 不降级', () {
      // 企业代理 SSE 握手可能慢，避免误判
      expect(
        shouldFallbackToPolling(
          sseConnected: false,
          sseAttemptFailed: false,
          silentSeconds: 2,
        ),
        isFalse,
      );
    });

    test('已连接即使长时间无 event 也不降级（waiting 阶段正常）', () {
      expect(
        shouldFallbackToPolling(
          sseConnected: true,
          sseAttemptFailed: false,
          silentSeconds: 999,
        ),
        isFalse,
      );
    });

    test('已连接 + attemptFailed=true（不太可能但防御）→ 仍降级', () {
      // attemptFailed 应优先于 sseConnected（语义：连接出过问题，不可信）
      expect(
        shouldFallbackToPolling(
          sseConnected: true,
          sseAttemptFailed: true,
          silentSeconds: 0,
        ),
        isTrue,
      );
    });

    test('自定义 gracePeriodSeconds=10 → silentSeconds=5 时不降级', () {
      // 弱网环境可调高宽限期
      expect(
        shouldFallbackToPolling(
          sseConnected: false,
          sseAttemptFailed: false,
          silentSeconds: 5,
          gracePeriodSeconds: 10,
        ),
        isFalse,
      );
    });
  });
}
