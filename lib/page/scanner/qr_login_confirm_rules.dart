/// 手机端 QR 登录确认状态机纯函数（零外部依赖）。
///
/// 职责：将后端 `imboy/src/api/qr_login_handler.erl` 的 `scan/2` 与 `confirm/2`
/// 响应解析为 sealed 状态变体，供 `QrLoginConfirmNotifier` 与 UI 层消费。
///
/// 状态机流转图：
/// ```
///                  +--→ Expired ←--+
///                  |               |
///   Idle ─→ Scanning ─→ AwaitingConfirm ─→ Confirming ─→ Success
///                  |               |               |
///                  +→ AlreadyUsed  |               +→ Failed
///                  +→ Failed       +→ CancelledByMe
///                                  +→ CancelledByOther
/// ```
///
/// 错误码值取自 `imboy/include/error_code.hrl:243-248` + 标准 HTTP 码：
///   - 5200 `INVALID_QR_TOKEN` → Failed (msg 透传)
///   - 5201 `QR_LOGIN_EXPIRED` → Expired
///   - 5202 `QR_LOGIN_CANCELLED` → CancelledByOther
///   - 5203 `QR_LOGIN_ALREADY_USED` → AlreadyUsed
///   - 5204 `QR_LOGIN_NOT_SCANNED` → Failed (confirm 路径)
///   - 5205 `QR_LOGIN_DEVICE_LIMIT` → Failed (msg 透传)
///   - 400 / 403 / 其他 → Failed (msg 透传)
///
/// 设备信息（device_name / platform）解析层预备就绪，但当前后端 scan 响应
/// 未携带这些字段（仅 `{status: scanned}`），属已知契约缺口；客户端先做
/// 兼容支持，将来后端补字段后无需重写。
library;

// ---------------------------------------------------------------------------
// 状态变体（sealed）
// ---------------------------------------------------------------------------

sealed class QrLoginConfirmState {
  const QrLoginConfirmState();
}

/// 初始态：用户刚扫到 QR，尚未调用 scan API。
final class QrLoginConfirmIdle extends QrLoginConfirmState {
  const QrLoginConfirmIdle();
}

/// scan API 调用中（loading）。
final class QrLoginConfirmScanning extends QrLoginConfirmState {
  const QrLoginConfirmScanning();
}

/// scan 成功，等待用户在手机端点"确认登录"。可携带设备信息卡片。
final class QrLoginConfirmAwaitingConfirm extends QrLoginConfirmState {
  const QrLoginConfirmAwaitingConfirm({this.deviceInfo});
  final QrLoginDeviceInfo? deviceInfo;
}

/// confirm API 调用中（loading）。
final class QrLoginConfirmConfirming extends QrLoginConfirmState {
  const QrLoginConfirmConfirming();
}

/// 登录成功（web 端会从 confirming → success）。手机端通常退栈即可。
final class QrLoginConfirmSuccess extends QrLoginConfirmState {
  const QrLoginConfirmSuccess();
}

/// 二维码已过期（>60s 或后端主动清理）。
final class QrLoginConfirmExpired extends QrLoginConfirmState {
  const QrLoginConfirmExpired();
}

/// 二维码已被使用（同一 QR 不能重复登录）。
final class QrLoginConfirmAlreadyUsed extends QrLoginConfirmState {
  const QrLoginConfirmAlreadyUsed();
}

/// 当前用户主动点击"取消"（本端动作，不调后端）。
final class QrLoginConfirmCancelledByMe extends QrLoginConfirmState {
  const QrLoginConfirmCancelledByMe();
}

/// 二维码被其他渠道取消（如 web 端用户关闭页面、其他设备 cancel）。
final class QrLoginConfirmCancelledByOther extends QrLoginConfirmState {
  const QrLoginConfirmCancelledByOther();
}

/// 通用失败（网络错误 / 协议错误 / 未识别错误码）。
final class QrLoginConfirmFailed extends QrLoginConfirmState {
  const QrLoginConfirmFailed(this.errorMessage);
  final String errorMessage;
}

// ---------------------------------------------------------------------------
// 设备信息（scan API 响应可选携带，UI 卡片渲染用）
// ---------------------------------------------------------------------------

class QrLoginDeviceInfo {
  const QrLoginDeviceInfo({this.deviceName, this.platform});

  /// 设备名称（如 "Chrome 120" / "Safari on macOS"）。
  final String? deviceName;

  /// 平台标识（如 "web" / "macos" / "windows"）。
  final String? platform;
}

// ---------------------------------------------------------------------------
// 解析函数
// ---------------------------------------------------------------------------

/// 错误码到状态的统一映射（scan / confirm 共用）。
///
/// 设计：保持 errorMessage 透传给 UI（后端文案多为 utf8 中文，UI 直接展示）；
/// 未知 code 时 fallback 文案包含 code 数字，便于排错。
QrLoginConfirmState mapQrLoginErrorCode(int code, String? errorMessage) {
  switch (code) {
    case 5201:
      return const QrLoginConfirmExpired();
    case 5202:
      return const QrLoginConfirmCancelledByOther();
    case 5203:
      return const QrLoginConfirmAlreadyUsed();
    case 5200:
    case 5204:
    case 5205:
    case 400:
    case 403:
      return QrLoginConfirmFailed(errorMessage ?? _fallbackForCode(code));
    default:
      return QrLoginConfirmFailed(errorMessage ?? '未知错误（code=$code）');
  }
}

String _fallbackForCode(int code) {
  switch (code) {
    case 5200:
      return '无效的二维码';
    case 5204:
      return '二维码尚未扫码';
    case 5205:
      return '设备数量达到上限';
    case 400:
      return '请求参数错误';
    case 403:
      return '无权限操作';
    default:
      return '操作失败';
  }
}

/// 解析 `POST /api/v1/passport/qr_login/scan` 响应。
///
/// 成功路径：`ok && code==0 && payload.status == "scanned"` → AwaitingConfirm，
/// 同时尽力解析 device_name / platform 填充 deviceInfo。
QrLoginConfirmState parseScanResponse({
  required bool ok,
  required int code,
  required String? errorMessage,
  required dynamic payload,
}) {
  if (ok && code == 0) {
    if (payload is! Map<String, dynamic>) {
      return const QrLoginConfirmFailed('协议错误：scan 响应非 Map<String, dynamic>');
    }
    if (payload['status'] != 'scanned') {
      return const QrLoginConfirmFailed('协议错误：scan 响应缺 status');
    }
    return QrLoginConfirmAwaitingConfirm(deviceInfo: _readDeviceInfo(payload));
  }
  return mapQrLoginErrorCode(code, errorMessage);
}

/// 解析 `POST /api/v1/passport/qr_login/confirm` 响应。
///
/// 成功路径：`ok && code==0 && payload.status == "confirmed"` → Success。
QrLoginConfirmState parseConfirmResponse({
  required bool ok,
  required int code,
  required String? errorMessage,
  required dynamic payload,
}) {
  if (ok && code == 0) {
    if (payload is! Map<String, dynamic>) {
      return const QrLoginConfirmFailed(
        '协议错误：confirm 响应非 Map<String, dynamic>',
      );
    }
    if (payload['status'] != 'confirmed') {
      return const QrLoginConfirmFailed('协议错误：confirm 响应缺 status');
    }
    return const QrLoginConfirmSuccess();
  }
  return mapQrLoginErrorCode(code, errorMessage);
}

// ---------------------------------------------------------------------------
// 内部辅助
// ---------------------------------------------------------------------------

/// 读取 device_name / platform，全空 / 全空白时返回 null（防 UI 渲染空白行）。
QrLoginDeviceInfo? _readDeviceInfo(Map<String, dynamic> payload) {
  final deviceName = _readNonEmptyString(payload, 'device_name');
  final platform = _readNonEmptyString(payload, 'platform');
  if (deviceName == null && platform == null) return null;
  return QrLoginDeviceInfo(deviceName: deviceName, platform: platform);
}

String? _readNonEmptyString(Map<String, dynamic> map, String key) {
  final v = map[key];
  if (v is! String) return null;
  final trimmed = v.trim();
  return trimmed.isEmpty ? null : trimmed;
}
