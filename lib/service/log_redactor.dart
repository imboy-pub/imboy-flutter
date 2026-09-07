import 'dart:convert';

/// 日志与上报脱敏共享层（Overseas Compliance Plan Task V-02）
///
/// 与后端 imboy/src/lib/log_redact.erl 保持同一判定口径：
/// - 键脱敏：精确键名匹配（不做子串，避免 design/assignment 误伤）
/// - 值脱敏：JWT / Bearer / 手机号 / 邮箱 / URL 敏感参数（参数名保留）
///
/// 接入点：
/// - SentryFlutter.init 的 beforeSend（事件级清洗）与 beforeBreadcrumb
///   （默认面包屑整体禁用——面包屑会自动记录路由与请求，无法逐一审计）
/// - 任何自行拼装上报载荷的调用点应先过 [scrubDynamic]
class LogRedactor {
  static const String _redacted = '[REDACTED]';

  /// 精确键名（lowercase 后全等匹配）
  static const Set<String> forbiddenKeys = {
    'password',
    'passwd',
    'pwd',
    'secret',
    'secret_key',
    'client_secret',
    'token',
    'access_token',
    'refresh_token',
    'id_token',
    'private_key',
    'privatekey',
    'salt',
    'password_salt',
    'credential',
    'credentials',
    'api_key',
    'apikey',
    'access_key',
    'authorization',
    'auth',
    'cookie',
    'set-cookie',
    'sign',
    'signature',
    'openid',
    'session_key',
    'verify_code',
    'sms_code',
    'verification_code',
    'email_code',
    'plaintext',
    'plain_text',
    'plain',
    'msg_content',
    'message_content',
    'password_hash',
    'passhash',
  };

  static final RegExp _jwt = RegExp(
    r'eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+',
  );
  static final RegExp _bearer = RegExp(
    r'bearer[ ]+[A-Za-z0-9._~-]+',
    caseSensitive: false,
  );

  /// 捕获组保持前后分隔符，避免吞掉相邻字符
  static final RegExp _mobile = RegExp(r'(^|[^0-9])1[3-9][0-9]{9}([^0-9]|$)');
  static final RegExp _email = RegExp(
    r'[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}',
  );
  static final RegExp _urlSecret = RegExp(
    r'([?&](?:token|access_token|refresh_token|sign|signature|ticket|auth)=)[^&\s]+',
    caseSensitive: false,
  );

  /// 字符串值模式兜底
  static String scrubText(String input) {
    var s = input.replaceAll(_jwt, _redacted);
    s = s.replaceAll(_bearer, _redacted);
    s = s.replaceAllMapped(
      _mobile,
      (m) => '${m.group(1)}$_redacted${m.group(2)}',
    );
    s = s.replaceAll(_email, _redacted);
    s = s.replaceAllMapped(_urlSecret, (m) => '${m.group(1)}$_redacted');
    return s;
  }

  /// 任意结构脱敏：map 按键判定（命中即整值替换，不再深入），list 逐元素，
  /// 字符串跑值模式，其他标量原样。
  static dynamic scrubDynamic(dynamic value) {
    if (value is Map) {
      final out = <dynamic, dynamic>{};
      value.forEach((k, v) {
        if (k != null && forbiddenKeys.contains(k.toString().toLowerCase())) {
          out[k] = _redacted;
        } else {
          out[k] = scrubDynamic(v);
        }
      });
      return out;
    }
    if (value is List) {
      return value.map(scrubDynamic).toList();
    }
    if (value is String) {
      return scrubText(value);
    }
    return value;
  }

  /// 字符串可能内嵌 JSON（如 extra 里的请求体转储）时，先尝试 JSON 展开
  /// 做键级清洗再序列化回字符串；解析失败退回纯文本值模式。
  static String scrubMaybeJson(String input) {
    try {
      final decoded = jsonDecode(input);
      return jsonEncode(scrubDynamic(decoded));
    } on FormatException {
      return scrubText(input);
    }
  }
}
