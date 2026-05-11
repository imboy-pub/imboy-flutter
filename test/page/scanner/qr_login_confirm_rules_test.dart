/// 手机端 QR 登录确认状态机纯函数测试（RED）。
///
/// 锚定后端 `imboy/src/api/qr_login_handler.erl`：
///   - `scan/2`（行 150-218）：成功 → `{status: scanned}`；失败错误码：
///     5200 INVALID_QR_TOKEN / 5201 EXPIRED / 5202 CANCELLED / 5203 ALREADY_USED /
///     403 FORBIDDEN
///   - `confirm/2`（行 220-307）：成功 → `{status: confirmed}`；失败错误码：
///     5200 / 5201 / 5202 / 5203 / 5204 NOT_SCANNED / 403
///
/// 错误码值取自 `imboy/include/error_code.hrl:243-248`。
///
/// 设备信息（device_name/platform）的解析逻辑预备就绪，但后端当前 scan
/// 响应未携带这些字段（仅返回 `{status: scanned}`），属已知契约缺口；
/// 客户端先做兼容支持，将来后端补字段后无需重写。
///
/// 本文件零外部依赖（无 Flutter / HTTP / Riverpod），纯 Dart 单测。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/page/scanner/qr_login_confirm_rules.dart';

void main() {
  group('parseScanResponse — 成功路径', () {
    test('ok + status="scanned" + 无设备信息 → AwaitingConfirm(deviceInfo=null)', () {
      final result = parseScanResponse(
        ok: true,
        code: 0,
        errorMessage: null,
        payload: {'status': 'scanned'},
      );
      expect(result, isA<QrLoginConfirmAwaitingConfirm>());
      expect(
        (result as QrLoginConfirmAwaitingConfirm).deviceInfo,
        isNull,
      );
    });

    test('ok + status="scanned" + device_name → AwaitingConfirm(deviceInfo with name)', () {
      final result = parseScanResponse(
        ok: true,
        code: 0,
        errorMessage: null,
        payload: {'status': 'scanned', 'device_name': 'Chrome 120'},
      );
      expect(result, isA<QrLoginConfirmAwaitingConfirm>());
      final s = result as QrLoginConfirmAwaitingConfirm;
      expect(s.deviceInfo?.deviceName, 'Chrome 120');
      expect(s.deviceInfo?.platform, isNull);
    });

    test('ok + status="scanned" + 完整 device 字段 → 完整 DeviceInfo', () {
      final result = parseScanResponse(
        ok: true,
        code: 0,
        errorMessage: null,
        payload: {
          'status': 'scanned',
          'device_name': 'Chrome 120',
          'platform': 'web',
        },
      );
      expect(result, isA<QrLoginConfirmAwaitingConfirm>());
      final info = (result as QrLoginConfirmAwaitingConfirm).deviceInfo!;
      expect(info.deviceName, 'Chrome 120');
      expect(info.platform, 'web');
    });

    test('设备字段全空白 → deviceInfo=null（防 UI 显示空白行）', () {
      final result = parseScanResponse(
        ok: true,
        code: 0,
        errorMessage: null,
        payload: {'status': 'scanned', 'device_name': '   ', 'platform': ''},
      );
      expect(result, isA<QrLoginConfirmAwaitingConfirm>());
      expect((result as QrLoginConfirmAwaitingConfirm).deviceInfo, isNull);
    });
  });

  group('parseScanResponse — 协议异常', () {
    test('ok + payload null → Failed', () {
      final result = parseScanResponse(
        ok: true,
        code: 0,
        errorMessage: null,
        payload: null,
      );
      expect(result, isA<QrLoginConfirmFailed>());
    });

    test('ok + payload 非 Map → Failed', () {
      final result = parseScanResponse(
        ok: true,
        code: 0,
        errorMessage: null,
        payload: const ['scanned'],
      );
      expect(result, isA<QrLoginConfirmFailed>());
    });

    test('ok + status 字段缺失 → Failed', () {
      final result = parseScanResponse(
        ok: true,
        code: 0,
        errorMessage: null,
        payload: const <String, dynamic>{},
      );
      expect(result, isA<QrLoginConfirmFailed>());
    });

    test('ok + status 非 "scanned" → Failed（防后端契约抖动）', () {
      final result = parseScanResponse(
        ok: true,
        code: 0,
        errorMessage: null,
        payload: const {'status': 'pending'},
      );
      expect(result, isA<QrLoginConfirmFailed>());
    });
  });

  group('parseScanResponse — 错误码映射', () {
    test('code=5201 (EXPIRED) → Expired', () {
      final result = parseScanResponse(
        ok: false,
        code: 5201,
        errorMessage: '二维码已过期',
        payload: null,
      );
      expect(result, isA<QrLoginConfirmExpired>());
    });

    test('code=5200 (INVALID_QR_TOKEN) → Failed (透传后端 msg)', () {
      final result = parseScanResponse(
        ok: false,
        code: 5200,
        errorMessage: '无效的二维码',
        payload: null,
      );
      expect(result, isA<QrLoginConfirmFailed>());
      expect((result as QrLoginConfirmFailed).errorMessage, '无效的二维码');
    });

    test('code=5203 (ALREADY_USED) → AlreadyUsed', () {
      final result = parseScanResponse(
        ok: false,
        code: 5203,
        errorMessage: '二维码已使用',
        payload: null,
      );
      expect(result, isA<QrLoginConfirmAlreadyUsed>());
    });

    test('code=5202 (CANCELLED 由 web 端) → CancelledByOther', () {
      final result = parseScanResponse(
        ok: false,
        code: 5202,
        errorMessage: '登录已取消',
        payload: null,
      );
      expect(result, isA<QrLoginConfirmCancelledByOther>());
    });
  });

  group('parseConfirmResponse — 成功路径', () {
    test('ok + status="confirmed" → Success', () {
      final result = parseConfirmResponse(
        ok: true,
        code: 0,
        errorMessage: null,
        payload: {'status': 'confirmed'},
      );
      expect(result, isA<QrLoginConfirmSuccess>());
    });

    test('ok + status 字段缺失 → Failed', () {
      final result = parseConfirmResponse(
        ok: true,
        code: 0,
        errorMessage: null,
        payload: const <String, dynamic>{},
      );
      expect(result, isA<QrLoginConfirmFailed>());
    });

    test('ok + payload null → Failed', () {
      final result = parseConfirmResponse(
        ok: true,
        code: 0,
        errorMessage: null,
        payload: null,
      );
      expect(result, isA<QrLoginConfirmFailed>());
    });

    test('ok + status="scanned"（错误状态）→ Failed', () {
      // confirm 接口正确响应应是 "confirmed"，"scanned" 视为协议错误
      final result = parseConfirmResponse(
        ok: true,
        code: 0,
        errorMessage: null,
        payload: const {'status': 'scanned'},
      );
      expect(result, isA<QrLoginConfirmFailed>());
    });
  });

  group('parseConfirmResponse — 错误码映射', () {
    test('code=5204 (NOT_SCANNED) → Failed（提示先扫码）', () {
      final result = parseConfirmResponse(
        ok: false,
        code: 5204,
        errorMessage: '二维码尚未扫码',
        payload: null,
      );
      expect(result, isA<QrLoginConfirmFailed>());
      expect(
        (result as QrLoginConfirmFailed).errorMessage,
        '二维码尚未扫码',
      );
    });

    test('code=5201 (EXPIRED) → Expired', () {
      final result = parseConfirmResponse(
        ok: false,
        code: 5201,
        errorMessage: '二维码已过期',
        payload: null,
      );
      expect(result, isA<QrLoginConfirmExpired>());
    });

    test('code=5203 (ALREADY_USED) → AlreadyUsed', () {
      final result = parseConfirmResponse(
        ok: false,
        code: 5203,
        errorMessage: '二维码已使用',
        payload: null,
      );
      expect(result, isA<QrLoginConfirmAlreadyUsed>());
    });

    test('code=403 (FORBIDDEN，扫码用户与确认用户不一致) → Failed', () {
      final result = parseConfirmResponse(
        ok: false,
        code: 403,
        errorMessage: '无权限操作',
        payload: null,
      );
      expect(result, isA<QrLoginConfirmFailed>());
    });
  });

  group('mapQrLoginErrorCode — 显式契约', () {
    test('5200 INVALID_QR_TOKEN → Failed (msg 透传)', () {
      final result = mapQrLoginErrorCode(5200, '无效的二维码');
      expect(result, isA<QrLoginConfirmFailed>());
      expect((result as QrLoginConfirmFailed).errorMessage, '无效的二维码');
    });

    test('5201 EXPIRED → Expired（无 msg 字段，UI 用本地化文案）', () {
      expect(mapQrLoginErrorCode(5201, null), isA<QrLoginConfirmExpired>());
      expect(
        mapQrLoginErrorCode(5201, '二维码已过期'),
        isA<QrLoginConfirmExpired>(),
      );
    });

    test('5202 CANCELLED → CancelledByOther', () {
      expect(
        mapQrLoginErrorCode(5202, null),
        isA<QrLoginConfirmCancelledByOther>(),
      );
    });

    test('5203 ALREADY_USED → AlreadyUsed', () {
      expect(
        mapQrLoginErrorCode(5203, null),
        isA<QrLoginConfirmAlreadyUsed>(),
      );
    });

    test('5204 NOT_SCANNED → Failed', () {
      final result = mapQrLoginErrorCode(5204, '二维码尚未扫码');
      expect(result, isA<QrLoginConfirmFailed>());
      expect(
        (result as QrLoginConfirmFailed).errorMessage,
        '二维码尚未扫码',
      );
    });

    test('5205 DEVICE_LIMIT → Failed (msg 透传)', () {
      final result = mapQrLoginErrorCode(5205, '设备数量达到上限');
      expect(result, isA<QrLoginConfirmFailed>());
      expect(
        (result as QrLoginConfirmFailed).errorMessage,
        '设备数量达到上限',
      );
    });

    test('400 BAD_REQUEST → Failed', () {
      expect(mapQrLoginErrorCode(400, '参数错误'), isA<QrLoginConfirmFailed>());
    });

    test('403 FORBIDDEN → Failed', () {
      expect(mapQrLoginErrorCode(403, '无权操作'), isA<QrLoginConfirmFailed>());
    });

    test('未知 code → Failed (msg 透传，code 透传到 fallback 文案)', () {
      final result = mapQrLoginErrorCode(9999, null);
      expect(result, isA<QrLoginConfirmFailed>());
      expect(
        (result as QrLoginConfirmFailed).errorMessage,
        contains('9999'),
      );
    });

    test('未知 code + 有 msg → Failed (msg 优先于 fallback)', () {
      final result = mapQrLoginErrorCode(9999, '服务器内部错误');
      expect(result, isA<QrLoginConfirmFailed>());
      expect(
        (result as QrLoginConfirmFailed).errorMessage,
        '服务器内部错误',
      );
    });
  });

  group('sealed exhaustiveness', () {
    test('QrLoginConfirmState switch 穷尽所有变体（编译期保护）', () {
      final result = parseScanResponse(
        ok: true,
        code: 0,
        errorMessage: null,
        payload: {'status': 'scanned'},
      );
      final label = switch (result) {
        QrLoginConfirmIdle() => 'idle',
        QrLoginConfirmScanning() => 'scanning',
        QrLoginConfirmAwaitingConfirm() => 'awaiting',
        QrLoginConfirmConfirming() => 'confirming',
        QrLoginConfirmSuccess() => 'success',
        QrLoginConfirmExpired() => 'expired',
        QrLoginConfirmAlreadyUsed() => 'already',
        QrLoginConfirmCancelledByMe() => 'cancelled_me',
        QrLoginConfirmCancelledByOther() => 'cancelled_other',
        QrLoginConfirmFailed() => 'failed',
      };
      expect(label, isNotEmpty);
    });
  });
}
