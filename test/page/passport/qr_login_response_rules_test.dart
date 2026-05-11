/// QR 登录响应解析纯函数回归保护测试（RED）。
///
/// 目的：钉死 `lib/page/passport/web_login_page.dart` 的 `QRLogin` Notifier
/// 当前依赖的后端响应字段契约，**保护现有 80% 已落地实现免于回归**。
///
/// 对齐后端 `imboy/src/api/qr_login_handler.erl`：
///   - `create/2`（行 76-113）：返回 `qr_token` / `session_token` / `expires_in: 60`
///   - `status/2`（行 117-147）：返回 `status: waiting|scanned|confirmed|cancelled`，
///     仅 `confirmed` 时附 `token`（即登录后的 JWT）
///
/// 对齐前端 `lib/page/passport/web_login_page.dart`：
///   - 行 107-114：解析 `qr_token` / `session_token`
///   - 行 156-180：switch 6 分支处理 status 字符串
///   - 行 167：confirmed 分支取 `data['token']`
///
/// 本文件故意零 Flutter / HTTP 依赖，纯 Dart 函数测试。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/page/passport/qr_login_response_rules.dart';

void main() {
  group('parseQrCreateResponse', () {
    test('ok + 完整 payload → QrCreateSuccess', () {
      final result = parseQrCreateResponse(
        ok: true,
        payload: {
          'qr_token': 'token_abc',
          'session_token': 'sess_xyz',
          'expires_in': 60,
        },
      );
      expect(result, isA<QrCreateSuccess>());
      final success = result as QrCreateSuccess;
      expect(success.qrToken, 'token_abc');
      expect(success.sessionToken, 'sess_xyz');
      expect(success.expiresInSeconds, 60);
    });

    test('ok + 缺失 expires_in → 默认 60 秒（对齐后端 cache_session 60s TTL）', () {
      final result = parseQrCreateResponse(
        ok: true,
        payload: {
          'qr_token': 'token_abc',
          'session_token': 'sess_xyz',
        },
      );
      expect(result, isA<QrCreateSuccess>());
      expect((result as QrCreateSuccess).expiresInSeconds, 60);
    });

    test('ok + payload null → QrCreateFailure', () {
      final result = parseQrCreateResponse(ok: true, payload: null);
      expect(result, isA<QrCreateFailure>());
    });

    test('ok + 空 Map → QrCreateFailure（缺 qr_token）', () {
      final result = parseQrCreateResponse(ok: true, payload: <String, dynamic>{});
      expect(result, isA<QrCreateFailure>());
    });

    test('ok + qr_token 空字符串 → QrCreateFailure', () {
      final result = parseQrCreateResponse(
        ok: true,
        payload: {'qr_token': '', 'session_token': 'sess_xyz'},
      );
      expect(result, isA<QrCreateFailure>());
    });

    test('ok + session_token 空字符串 → QrCreateFailure', () {
      final result = parseQrCreateResponse(
        ok: true,
        payload: {'qr_token': 'token_abc', 'session_token': ''},
      );
      expect(result, isA<QrCreateFailure>());
    });

    test('ok=false → QrCreateFailure（HTTP 层错误）', () {
      final result = parseQrCreateResponse(
        ok: false,
        payload: {'qr_token': 'irrelevant'},
      );
      expect(result, isA<QrCreateFailure>());
    });

    test('payload 非 Map 类型（如 List）→ QrCreateFailure（防御）', () {
      final result = parseQrCreateResponse(
        ok: true,
        payload: ['qr_token', 'sess_xyz'],
      );
      expect(result, isA<QrCreateFailure>());
    });

    test('expires_in 字符串数字 → 容错解析（防后端 JSON 序列化抖动）', () {
      final result = parseQrCreateResponse(
        ok: true,
        payload: {
          'qr_token': 'token_abc',
          'session_token': 'sess_xyz',
          'expires_in': '90',
        },
      );
      expect(result, isA<QrCreateSuccess>());
      expect((result as QrCreateSuccess).expiresInSeconds, 90);
    });
  });

  group('parseQrStatusResponse', () {
    test('ok=false → QrStatusStopPolling（HTTP 错误，停止轮询）', () {
      final result = parseQrStatusResponse(ok: false, code: 0, payload: null);
      expect(result, isA<QrStatusStopPolling>());
    });

    test('ok=true + code≠0 → QrStatusStopPolling（业务错误如会话过期，停止轮询）', () {
      final result = parseQrStatusResponse(
        ok: true,
        code: 4040,
        payload: {'status': 'waiting'},
      );
      expect(result, isA<QrStatusStopPolling>());
    });

    test('ok=true + code=0 + payload=null → QrStatusStopPolling（防御）', () {
      final result = parseQrStatusResponse(ok: true, code: 0, payload: null);
      expect(result, isA<QrStatusStopPolling>());
    });

    test('status="waiting" → QrStatusWaiting', () {
      final result = parseQrStatusResponse(
        ok: true,
        code: 0,
        payload: {'status': 'waiting'},
      );
      expect(result, isA<QrStatusWaiting>());
    });

    test('status="scanned" → QrStatusScanned', () {
      final result = parseQrStatusResponse(
        ok: true,
        code: 0,
        payload: {'status': 'scanned'},
      );
      expect(result, isA<QrStatusScanned>());
    });

    test('status="confirmed" + 有效 token → QrStatusConfirmed(token)', () {
      final result = parseQrStatusResponse(
        ok: true,
        code: 0,
        payload: {'status': 'confirmed', 'token': 'jwt.aaa.bbb'},
      );
      expect(result, isA<QrStatusConfirmed>());
      expect((result as QrStatusConfirmed).token, 'jwt.aaa.bbb');
    });

    test('status="confirmed" + token=null → QrStatusUnknown（协议违反，防御）', () {
      final result = parseQrStatusResponse(
        ok: true,
        code: 0,
        payload: {'status': 'confirmed'},
      );
      expect(result, isA<QrStatusUnknown>());
    });

    test('status="confirmed" + token="" → QrStatusUnknown（空 token 视为无效）', () {
      final result = parseQrStatusResponse(
        ok: true,
        code: 0,
        payload: {'status': 'confirmed', 'token': ''},
      );
      expect(result, isA<QrStatusUnknown>());
    });

    test('status="confirmed" + token 全空白 → QrStatusUnknown', () {
      final result = parseQrStatusResponse(
        ok: true,
        code: 0,
        payload: {'status': 'confirmed', 'token': '   '},
      );
      expect(result, isA<QrStatusUnknown>());
    });

    test('status="expired" → QrStatusExpired', () {
      final result = parseQrStatusResponse(
        ok: true,
        code: 0,
        payload: {'status': 'expired'},
      );
      expect(result, isA<QrStatusExpired>());
    });

    test('status="cancelled" → QrStatusCancelled', () {
      final result = parseQrStatusResponse(
        ok: true,
        code: 0,
        payload: {'status': 'cancelled'},
      );
      expect(result, isA<QrStatusCancelled>());
    });

    test('status 字段缺失 → QrStatusUnknown(rawStatus=null)', () {
      final result = parseQrStatusResponse(
        ok: true,
        code: 0,
        payload: <String, dynamic>{},
      );
      expect(result, isA<QrStatusUnknown>());
      expect((result as QrStatusUnknown).rawStatus, isNull);
    });

    test('status 未知字符串 → QrStatusUnknown(rawStatus 透传)', () {
      final result = parseQrStatusResponse(
        ok: true,
        code: 0,
        payload: {'status': 'pending_review'},
      );
      expect(result, isA<QrStatusUnknown>());
      expect((result as QrStatusUnknown).rawStatus, 'pending_review');
    });

    test('status 大小写敏感（"WAITING" 不匹配 "waiting"）', () {
      final result = parseQrStatusResponse(
        ok: true,
        code: 0,
        payload: {'status': 'WAITING'},
      );
      expect(result, isA<QrStatusUnknown>());
    });

    test('status 非字符串类型（如 int）→ QrStatusUnknown（防御）', () {
      final result = parseQrStatusResponse(
        ok: true,
        code: 0,
        payload: {'status': 1},
      );
      expect(result, isA<QrStatusUnknown>());
    });

    test('payload 非 Map（如 List）→ QrStatusStopPolling', () {
      final result = parseQrStatusResponse(
        ok: true,
        code: 0,
        payload: const ['waiting'],
      );
      expect(result, isA<QrStatusStopPolling>());
    });
  });

  group('sealed exhaustiveness（编译期保护）', () {
    test('QrCreateResult switch 穷尽所有变体', () {
      final result = parseQrCreateResponse(
        ok: true,
        payload: {'qr_token': 'a', 'session_token': 'b'},
      );
      // 编译期检查：未来新增变体时此处必须更新，否则编译失败
      final label = switch (result) {
        QrCreateSuccess() => 'success',
        QrCreateFailure() => 'failure',
      };
      expect(label, isNotEmpty);
    });

    test('QrStatusEvent switch 穷尽所有变体', () {
      final result = parseQrStatusResponse(
        ok: true,
        code: 0,
        payload: {'status': 'waiting'},
      );
      final label = switch (result) {
        QrStatusWaiting() => 'waiting',
        QrStatusScanned() => 'scanned',
        QrStatusConfirmed() => 'confirmed',
        QrStatusExpired() => 'expired',
        QrStatusCancelled() => 'cancelled',
        QrStatusStopPolling() => 'stop',
        QrStatusUnknown() => 'unknown',
      };
      expect(label, isNotEmpty);
    });
  });
}
