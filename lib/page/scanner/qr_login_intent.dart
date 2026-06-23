/// QR 扫码意图识别纯函数（零外部依赖）。
///
/// 上下文：`lib/page/scanner/scanner_page.dart:80-148` 的 `onDetect` 路径
/// 当前仅识别两类 QR：
///   1. HTTP(S) URL with `s=app_qrcode` 后缀 → user / group / channel 名片，
///      由后端 GET 路由分派
///   2. 其他文本 → `ScannerResultPage` 显示
///
/// 本模块新增第 3 类：**Web 端登录 QR**，对齐 `imboy/src/api/qr_login_handler.erl:88-90`
/// 的 `qr_token` 协议。约定 QR 编码使用 `imboy://qr_login/<qr_token>` 私有 scheme，
/// 优势：
///   - 与已有 HTTP URL QR 命名空间隔离，零冲突
///   - scheme 大小写不敏感（RFC 3986 § 6.2.2.1），用户/扫码器随意大小写
///   - token 透传到后端 `/api/v1/passport/qr_login/scan`，本端不做 base64 校验
///
/// 兼容形式 2（备用）：HTTP(S) URL with `/qr_login_qr` path + `?token=` query，
/// 供未来后端短链网关使用。
///
/// 本文件零 Flutter / HTTP 依赖，便于 Model-only 单测。
library;

// ---------------------------------------------------------------------------
// QrLoginIntent: detectQrLoginIntent 结果
// ---------------------------------------------------------------------------

/// 扫码意图（sealed）。
///
/// 调用方典型接线（slice-4 中 `scanner_page.dart:onDetect` 接入）：
/// ```dart
/// switch (detectQrLoginIntent(barcodeStr)) {
///   case QrLoginIntentWebLogin(:final qrToken):
///     Navigator.push(context, MaterialPageRoute<dynamic>(
///       builder: (_) => QrLoginConfirmPage(qrToken: qrToken),
///     ));
///   case QrLoginIntentOther(:final raw):
///     // 走原有 user/group/channel/外部文本分支
/// }
/// ```
sealed class QrLoginIntent {
  const QrLoginIntent();
}

/// Web 端登录 QR，token 字段透传给后端 `/api/v1/passport/qr_login/{scan,confirm}`。
final class QrLoginIntentWebLogin extends QrLoginIntent {
  const QrLoginIntentWebLogin(this.qrToken);

  /// 后端 `qr_token` 字段（base64 编码字符串），原样转发，不本端解码。
  final String qrToken;
}

/// 其他类型 QR（user 名片 / group 邀请 / channel 邀请 / 外部 URL / 纯文本），
/// 由 `scanner_page.dart` 的现有分支处理。
final class QrLoginIntentOther extends QrLoginIntent {
  const QrLoginIntentOther(this.raw);

  /// 原始扫码字符串（保留前后空白，便于上层 fallback 不丢失语义）。
  final String raw;
}

/// 解析扫码原始字符串，识别是否为 web 登录 QR。
///
/// 支持形式：
///   1. `imboy://qr_login/<qr_token>` — 私有 scheme，scheme 大小写不敏感
///   2. `<scheme>://<host>[/...]/qr_login_qr?token=<qr_token>` — HTTP(S) URL 形式
///
/// 不应误判：
///   - 用户/群组/频道名片 QR（`<api>/{user,group,channel}/qrcode?...&s=app_qrcode`）
///   - 外部 HTTP URL（如 google.com）
///   - 纯文本
QrLoginIntent detectQrLoginIntent(String rawQr) {
  final trimmed = rawQr.trim();
  if (trimmed.isEmpty) return QrLoginIntentOther(rawQr);

  // 形式 1：imboy://qr_login/<token> 字面量前缀（大小写不敏感）。
  // 用字面量前缀匹配而非 Uri.parse，避免 host="qr_login"（含 underscore）
  // 在某些 Uri 解析器下被拒绝。
  const prefixLower = 'imboy://qr_login/';
  if (trimmed.length > prefixLower.length) {
    final head = trimmed.substring(0, prefixLower.length).toLowerCase();
    if (head == prefixLower) {
      final token = trimmed.substring(prefixLower.length).trim();
      if (token.isEmpty) return QrLoginIntentOther(rawQr);
      return QrLoginIntentWebLogin(token);
    }
  }

  // 形式 2：HTTP(S) URL with /qr_login_qr path + ?token query。
  final uri = Uri.tryParse(trimmed);
  if (uri != null) {
    final scheme = uri.scheme.toLowerCase();
    if ((scheme == 'http' || scheme == 'https') &&
        uri.path.endsWith('/qr_login_qr')) {
      final token = (uri.queryParameters['token'] ?? '').trim();
      if (token.isNotEmpty) {
        return QrLoginIntentWebLogin(token);
      }
    }
  }

  return QrLoginIntentOther(rawQr);
}
