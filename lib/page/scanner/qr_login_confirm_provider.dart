/// 手机端 QR 登录确认 Notifier（薄壳：HTTP ↔ 纯函数胶水层）。
///
/// 职责：
///   1. 暴露 `state` 给 UI（[QrLoginConfirmState] sealed 变体）
///   2. 暴露 `scan(qrToken)` / `confirm(qrToken)` / `cancelByMe()` 三个动作
///   3. 调用后端 `/v1/passport/qr_login/{scan,confirm}` 后委托
///      [parseScanResponse] / [parseConfirmResponse] 转换为状态
///
/// 不做（避免与 Web 端 [QRLogin] Notifier 行为重叠）：
///   - 轮询：手机端是用户主动 confirm，无需轮询
///   - QR 生成：仅 Web 端调 `/create`，手机端只消费 qr_token
///   - cancel API：后端 cancel 接口签名是 session_token 而非 qr_token，
///     手机端无 session_token；用户主动取消仅本端关闭页面，让 web 端等过期
///
/// 测试策略：本 Notifier 不单测（按项目惯例：薄壳 widget/HTTP 集成代码）；
/// 决策正确性已被 `qr_login_confirm_rules_test.dart` 覆盖（31 测）。
library;

import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:imboy/component/http/http_client.dart';
import 'package:imboy/component/http/http_response.dart';
import 'package:imboy/page/scanner/qr_login_confirm_rules.dart';

part 'qr_login_confirm_provider.g.dart';

/// 后端 QR 登录路由（与 `imboy/src/imboy_router.erl:184-188` 对齐）。
const String _kQrLoginScanPath = '/v1/passport/qr_login/scan';
const String _kQrLoginConfirmPath = '/v1/passport/qr_login/confirm';

/// QR 登录确认状态 Notifier。
///
/// 典型生命周期：
/// ```
/// container.read(qrLoginConfirmProvider)            // → Idle
///   → notifier.scan('token')                        // → Scanning → AwaitingConfirm
///   → notifier.confirm('token')                     // → Confirming → Success
///   或 → notifier.cancelByMe()                      // → CancelledByMe
/// ```
@riverpod
class QrLoginConfirm extends _$QrLoginConfirm {
  @override
  QrLoginConfirmState build() {
    return const QrLoginConfirmIdle();
  }

  /// 通知后端"已扫码"，等待用户在本端点确认。
  ///
  /// - 网络异常 → [QrLoginConfirmFailed]（msg 含 toString）
  /// - 后端错误码 → [mapQrLoginErrorCode] 决定具体状态
  Future<void> scan(String qrToken) async {
    final trimmed = qrToken.trim();
    if (trimmed.isEmpty) {
      state = const QrLoginConfirmFailed('参数错误：qr_token 为空');
      return;
    }
    state = const QrLoginConfirmScanning();
    try {
      final IMBoyHttpResponse resp = await HttpClient.client.post(
        _kQrLoginScanPath,
        data: {'qr_token': trimmed},
      );
      state = parseScanResponse(
        ok: resp.ok,
        code: resp.code,
        errorMessage: resp.msg,
        payload: resp.payload,
      );
    } on Exception catch (e) {
      if (kDebugMode) debugPrint('qr_login scan failed: ${e.runtimeType}');
      state = QrLoginConfirmFailed('网络错误: ${e.runtimeType}');
    }
  }

  /// 用户在手机端点击"确认登录"，完成跨端登录。
  ///
  /// - 网络异常 → [QrLoginConfirmFailed]
  /// - 后端错误码 → [mapQrLoginErrorCode]
  Future<void> confirm(String qrToken) async {
    final trimmed = qrToken.trim();
    if (trimmed.isEmpty) {
      state = const QrLoginConfirmFailed('参数错误：qr_token 为空');
      return;
    }
    state = const QrLoginConfirmConfirming();
    try {
      final IMBoyHttpResponse resp = await HttpClient.client.post(
        _kQrLoginConfirmPath,
        data: {'qr_token': trimmed},
      );
      state = parseConfirmResponse(
        ok: resp.ok,
        code: resp.code,
        errorMessage: resp.msg,
        payload: resp.payload,
      );
    } on Exception catch (e) {
      if (kDebugMode) debugPrint('qr_login confirm failed: ${e.runtimeType}');
      state = QrLoginConfirmFailed('网络错误: ${e.runtimeType}');
    }
  }

  /// 用户主动点击"取消"，仅本端关闭，不调后端。
  ///
  /// 设计：后端 cancel API 签名是 session_token 而非 qr_token，手机端无
  /// session_token；让 web 端的 60s 过期机制自然清理。如未来产品要求
  /// "立即让 web 端感知取消"，可后端补 `cancel_by_qr_token/2` 路由。
  void cancelByMe() {
    state = const QrLoginConfirmCancelledByMe();
  }
}
