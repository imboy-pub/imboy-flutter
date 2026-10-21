/// 面聊记录（talk_record）错误码预留段与异常分型（T08）。
///
/// 契约源：BACKEND-API.md §4 错误 HTTP 语义（401/403/404/409/412/413/415/
/// 422/428/429/503）+ CONTRACT-FREEZE-T02 §2.7（业务码从 5xxx 分域分配器
/// 登记，建议 55xx=talk_record，实施时以 include/error_code.hrl 实际空闲
/// 段为准，并同步 imboyapp/scripts/generate_error_code.dart 再生成）。
///
/// 设计约束：`lib/config/error_code.dart` 是生成物（禁手改），通用 4xx/5xx
/// 语义复用 [ErrorCode]；本文件只集中定义 talk_record 域 55xx 预留段结构
/// 与分型映射，码值登记后仅需替换常量区，分型/异常不变。
library;

import 'package:imboy/config/error_code.dart';

/// talk_record 域业务错误码预留段（结构占位，非最终码值）。
///
/// 实际码值以后端 `include/error_code.hrl` 登记为准；登记后：
/// 1. 将下方各常量替换为真实值（或删除本类改引 ErrorCode 生成物）；
/// 2. 同步 `scripts/generate_error_code.dart` 再生成；
/// 3. 本文件 `classifyTalkRecordError` 无需改动（按语义分型）。
class TalkRecordErrorCode {
  /// 55xx 段边界（CONTRACT-FREEZE-T02 §2.7 建议新域 55xx=talk_record）。
  static const int domainBase = 5500;
  static const int domainEnd = 5599;

  // Current backend export envelope codes (talk_record_handler).
  static const int exportExpired = 5554;
  static const int exportDisabledByPolicy = 5555;

  // —— 428 语义码：现 ErrorCode 生成物无 428（If-Match 为 talk_record
  //    首次引入的业务面模式，T02 §2.6），在此登记避免魔数散落。 ——
  static const int preconditionRequired = 428;

  /// 是否落在 talk_record 域业务码段。
  static bool inDomain(int code) => code >= domainBase && code <= domainEnd;
}

/// talk_record 失败分型（供 UI 选失败态，替代逐码 switch）。
enum TalkRecordErrorKind {
  /// 401：未登录 / token 失效（HttpClient 已统一触发重登流程）。
  unauthorized,

  /// 404：无权限或不存在统一 404（§4/§11.3，不区分两者防探测）。
  noAccess,

  /// 403：有读权限但无操作能力。
  forbidden,

  /// 409：缺段/状态冲突/幂等键冲突（含 ErrorCode.IDEMPOTENCY_CONFLICT）/
  /// context_changed / capture_fenced。
  conflict,

  /// 428：写操作缺 If-Match 头（ETag 未随请求携带）。
  preconditionRequired,

  /// 412：If-Match 版本过期（revision 冲突，走刷新后重试 UI）。
  revisionStale,

  /// 413：超体积（duration/bytes 超配额）。
  payloadTooLarge,

  /// 415：格式不支持。
  unsupportedMedia,

  /// 422：输入不合法/超时长/缺告知确认（unsupported_source_type 等）。
  invalidInput,

  /// 429：配额/限流（含 Retry-After）。
  rateLimited,

  /// 503：处理能力不可用/未配置（AI 阶段「待选型」）。
  processingUnavailable,

  /// 55xx 域内业务码（细分码值待后端登记）。
  domain,

  /// 其余 5xx / 未知。
  server,

  /// 无法归类的其他码。
  unknown,
}

/// envelope code → 分型（§4 错误语义映射的唯一入口）。
TalkRecordErrorKind classifyTalkRecordError(int code) {
  if (TalkRecordErrorCode.inDomain(code)) {
    return TalkRecordErrorKind.domain;
  }
  switch (code) {
    case ErrorCode.UNAUTHORIZED: // 401（TOKEN_INVALID/EXPIRED/MISSING 同值）
      return TalkRecordErrorKind.unauthorized;
    case ErrorCode.NOT_FOUND:
      return TalkRecordErrorKind.noAccess;
    case ErrorCode.FORBIDDEN: // 403（ACCESS_DENIED 同值）
      return TalkRecordErrorKind.forbidden;
    case ErrorCode.CONFLICT:
    case ErrorCode.IDEMPOTENCY_CONFLICT:
      return TalkRecordErrorKind.conflict;
    case ErrorCode.PRECONDITION_FAILED:
      return TalkRecordErrorKind.revisionStale;
    case TalkRecordErrorCode.preconditionRequired:
      return TalkRecordErrorKind.preconditionRequired;
    case ErrorCode.PAYLOAD_TOO_LARGE:
      return TalkRecordErrorKind.payloadTooLarge;
    case ErrorCode.UNSUPPORTED_MEDIA_TYPE:
      return TalkRecordErrorKind.unsupportedMedia;
    case ErrorCode.UNPROCESSABLE_ENTITY:
      return TalkRecordErrorKind.invalidInput;
    case ErrorCode.TOO_MANY_REQUESTS:
      return TalkRecordErrorKind.rateLimited;
    case ErrorCode.SERVICE_UNAVAILABLE:
      return TalkRecordErrorKind.processingUnavailable;
    default:
      if (code >= 500 && code < 600) return TalkRecordErrorKind.server;
      return TalkRecordErrorKind.unknown;
  }
}

/// talk_record API 失败异常（对齐 WorkspaceApiException 先例：透传
/// envelope code/msg/payload，失败统一抛出，不静默压成空数据）。
class TalkRecordApiException implements Exception {
  final int code;
  final String message;

  /// 服务端 envelope payload（如 409 missing_sequences 的缺失序号清单）。
  final dynamic payload;

  const TalkRecordApiException(this.code, this.message, [this.payload]);

  factory TalkRecordApiException.fromEnvelope(
    int code,
    String message, [
    dynamic payload,
  ]) => TalkRecordApiException(code, message, payload);

  TalkRecordErrorKind get kind => classifyTalkRecordError(code);

  // —— 高频判定（对齐 WorkspaceApiException.isArchived 风格） ——

  /// 428：客户端漏带 If-Match（编程错误：可变写操作必须携带）。
  bool get isPreconditionRequired =>
      kind == TalkRecordErrorKind.preconditionRequired;

  /// 412：版本过期（刷新 record/ETag 后重试或提示冲突 UI）。
  bool get isRevisionStale => kind == TalkRecordErrorKind.revisionStale;

  /// 409：操作状态冲突（缺段/活跃采集/幂等键冲突/context_changed）。
  bool get isConflict => kind == TalkRecordErrorKind.conflict;

  /// 429：配额限制（payload 可能带 retry_after）。
  bool get isRateLimited => kind == TalkRecordErrorKind.rateLimited;

  /// 404 统一无权限/不存在（§11.3：不披露具体原因）。
  bool get isNoAccess => kind == TalkRecordErrorKind.noAccess;

  @override
  String toString() => 'TalkRecordApiException($code/$kind): $message';
}
