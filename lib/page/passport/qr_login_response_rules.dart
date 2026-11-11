/// QR 登录响应解析纯函数（零外部依赖）。
///
/// 锚定后端 `imboy/src/api/qr_login_handler.erl` 的契约字段，作为
/// `lib/page/passport/web_login_page.dart` 的 `QRLogin` Notifier 解析层，
/// 将 dynamic JSON 负载转换为类型安全的 sealed 结果。
///
/// 后端契约（行号对齐 `qr_login_handler.erl`）：
///   - `create/2`（76-113）：成功响应 payload 为
///     `#{<<"qr_token">> => Bin, <<"session_token">> => Bin, <<"expires_in">> => 60}`
///   - `status/2`（117-147）：成功响应 payload 为
///     仅 `confirmed` 时附 `token`、旧格式 `uid` 和同次领取结果的精确
///     十进制字符串 `uid_str`；SSE 与轮询共享此合同。
///
/// 本文件故意零 Flutter / HTTP 依赖，便于纯 Dart 单元测试，覆盖：
///   - 字段缺失 / 空值 / 错误类型的防御行为
///   - status 字符串大小写敏感
///   - 未知 status 透传到 `QrStatusUnknown.rawStatus` 便于调用层日志
library;

// ---------------------------------------------------------------------------
// QrCreateResult: parseQrCreateResponse 结果
// ---------------------------------------------------------------------------

/// 创建 QR 码的响应解析结果（sealed）。
///
/// 调用方典型接线（对齐 `web_login_page.dart:107-130`）：
/// ```dart
/// switch (parseQrCreateResponse(ok: resp.ok, payload: resp.payload)) {
///   case QrCreateSuccess(:final qrToken, :final sessionToken, :final expiresInSeconds):
///     state = QRLoginState(
///       status: QRLoginStatus.waiting,
///       qrData: qrToken,
///       sessionToken: sessionToken,
///       remainingSeconds: expiresInSeconds,
///     );
///   case QrCreateFailure():
///     state = QRLoginState(status: QRLoginStatus.failed, ...);
/// }
/// ```
sealed class QrCreateResult {
  const QrCreateResult();
}

final class QrCreateSuccess extends QrCreateResult {
  const QrCreateSuccess({
    required this.qrToken,
    required this.sessionToken,
    required this.expiresInSeconds,
  });

  /// 后端 `qr_token` 字段（手机端扫码上报使用）。
  final String qrToken;

  /// 后端 `session_token` 字段（Web 端轮询 status 使用）。
  final String sessionToken;

  /// 后端 `expires_in` 秒数；缺失时默认 60（对齐后端 cache_session 60s TTL）。
  final int expiresInSeconds;
}

final class QrCreateFailure extends QrCreateResult {
  const QrCreateFailure();
}

/// 后端默认 QR 过期秒数（对齐 `qr_login_handler.erl:101` 的 60s TTL）。
const int _kDefaultExpiresInSeconds = 60;

/// 解析 `POST /api/v1/passport/qr_login/create` 的响应。
///
/// - HTTP 错误（`ok=false`）→ [QrCreateFailure]
/// - payload 非 `Map<String, dynamic>` 或缺关键字段 / 空字段 → [QrCreateFailure]
/// - `expires_in` 容错解析（int / 字符串数字 / 缺失 → 默认 60）
QrCreateResult parseQrCreateResponse({
  required bool ok,
  required dynamic payload,
}) {
  if (!ok) return const QrCreateFailure();
  if (payload is! Map<String, dynamic>) return const QrCreateFailure();

  final qrToken = _readNonEmptyString(payload, 'qr_token');
  if (qrToken == null) return const QrCreateFailure();

  final sessionToken = _readNonEmptyString(payload, 'session_token');
  if (sessionToken == null) return const QrCreateFailure();

  final expiresIn =
      _readPositiveInt(payload, 'expires_in') ?? _kDefaultExpiresInSeconds;

  return QrCreateSuccess(
    qrToken: qrToken,
    sessionToken: sessionToken,
    expiresInSeconds: expiresIn,
  );
}

// ---------------------------------------------------------------------------
// QrStatusEvent: parseQrStatusResponse 结果
// ---------------------------------------------------------------------------

/// 轮询 QR 状态的响应解析结果（sealed）。
///
/// 状态语义（对齐后端 `qr_login_handler.erl:117-147` + `web_login_page.dart:156-180`）：
///   - [QrStatusWaiting]：用户尚未扫码，继续轮询
///   - [QrStatusScanned]：手机端已扫码（调 `/scan`），等待用户在手机点确认
///   - [QrStatusConfirmed]：手机端已确认（调 `/confirm`），附 JWT token
///   - [QrStatusExpired]：会话已过期（>60s 未确认或后端主动清理）
///   - [QrStatusCancelled]：用户在手机端取消登录
///   - [QrStatusStopPolling]：HTTP 错误 / 业务错误 / payload 非法，应停止轮询
///   - [QrStatusUnknown]：status 字段未识别，调用方应继续轮询并日志告警
sealed class QrStatusEvent {
  const QrStatusEvent();
}

final class QrStatusWaiting extends QrStatusEvent {
  const QrStatusWaiting();
}

final class QrStatusScanned extends QrStatusEvent {
  const QrStatusScanned();
}

final class QrStatusConfirmed extends QrStatusEvent {
  const QrStatusConfirmed(this.token, {this.uid});

  /// 后端 `token` 字段（JWT），调用方应保存到 SecureTokenStorageService。
  final String token;

  /// 后端 `uid_str` 优先；缺省时兼容旧 `uid` 字符串或安全整数。
  /// 缺失、无效或字段矛盾时为 null，loginAfterQr 必须在会话写入前拒绝。
  final String? uid;
}

final class QrStatusExpired extends QrStatusEvent {
  const QrStatusExpired();
}

final class QrStatusCancelled extends QrStatusEvent {
  const QrStatusCancelled();
}

/// HTTP 层 / 业务层错误，调用方必须 `timer.cancel()` 停止轮询。
final class QrStatusStopPolling extends QrStatusEvent {
  const QrStatusStopPolling();
}

/// 未知 status，调用方应继续轮询但记日志（后端可能新增状态字符串）。
final class QrStatusUnknown extends QrStatusEvent {
  const QrStatusUnknown(this.rawStatus);

  /// 原始 status 字符串（含 null / 非 string 类型情形）。
  final String? rawStatus;
}

/// 解析 `GET /api/v1/passport/qr_login/status` 的响应。
///
/// - `ok=false` 或 `code≠0` → [QrStatusStopPolling]（停止轮询，避免攻击会话）
/// - payload 非 `Map<String, dynamic>` → [QrStatusStopPolling]
/// - 已知 status 字符串 → 对应变体
/// - `confirmed` 必须附非空非全空白 token，否则降级为 [QrStatusUnknown]
/// - 未知 status → [QrStatusUnknown]，调用方继续轮询
QrStatusEvent parseQrStatusResponse({
  required bool ok,
  required int code,
  required dynamic payload,
}) {
  if (!ok || code != 0) return const QrStatusStopPolling();
  if (payload is! Map<String, dynamic>) return const QrStatusStopPolling();

  final rawStatus = payload['status'];
  if (rawStatus is! String) {
    return QrStatusUnknown(rawStatus is String ? rawStatus : null);
  }

  switch (rawStatus) {
    case 'waiting':
      return const QrStatusWaiting();
    case 'scanned':
      return const QrStatusScanned();
    case 'confirmed':
      final token = _readNonEmptyString(payload, 'token');
      if (token == null) return QrStatusUnknown(rawStatus);
      return QrStatusConfirmed(token, uid: _readQrUid(payload));
    case 'expired':
      return const QrStatusExpired();
    case 'cancelled':
      return const QrStatusCancelled();
    default:
      return QrStatusUnknown(rawStatus);
  }
}

// ---------------------------------------------------------------------------
// 内部解析辅助
// ---------------------------------------------------------------------------

/// Prefer the exact additive field without changing the legacy wire field.
/// Never reconstruct an identity from a number rounded by JavaScript.
String? _readQrUid(Map<String, dynamic> payload) {
  const maxSafeInteger = 9007199254740991;
  final raw = payload['uid'];
  final legacy = raw is int && raw > 0 && raw <= maxSafeInteger
      ? raw.toString()
      : _readNonEmptyString(payload, 'uid');
  if (!payload.containsKey('uid_str')) return legacy;

  final exact = payload['uid_str'];
  const maxUid = '9223372036854775807';
  if (exact is! String ||
      exact.length > maxUid.length ||
      RegExp(r'^[1-9][0-9]*$').stringMatch(exact) != exact ||
      (exact.length == maxUid.length && exact.compareTo(maxUid) > 0)) {
    return null; // A malformed new field must not silently downgrade.
  }
  if (raw is String && legacy != exact) return null;
  if (payload.containsKey('uid') && raw is! String) {
    if (raw is! int || raw <= 0) return null;
    if (raw <= maxSafeInteger && legacy != exact) return null;
  }
  // The old large numeric field may already be rounded in a browser. It must
  // neither override nor invalidate the exact value from the same response.
  return exact;
}

/// 从 `Map<String, dynamic>` 读取字段，要求非空非全空白字符串；否则返回 null。
String? _readNonEmptyString(Map<String, dynamic> map, String key) {
  final value = map[key];
  if (value is! String) return null;
  final trimmed = value.trim();
  if (trimmed.isEmpty) return null;
  return trimmed;
}

/// 从 `Map<String, dynamic>` 读取正整数（容错 int / 字符串数字）；否则返回 null。
int? _readPositiveInt(Map<String, dynamic> map, String key) {
  final value = map[key];
  if (value is int && value > 0) return value;
  if (value is String) {
    final parsed = int.tryParse(value);
    if (parsed != null && parsed > 0) return parsed;
  }
  return null;
}
