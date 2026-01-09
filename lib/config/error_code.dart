// ignore_for_file: constant_identifier_names
// ⚠️ 此文件由脚本自动生成，请勿手动修改
//
// 生成命令: dart script/generate_error_code.dart
// 源文件: ../imboy/include/error_code.hrl
// 生成时间: 2026-01-08T08:24:53.634664
//
// 错误码设计原则:
// - 0: 成功（API 响应成功标记）
// - 4xx: 客户端错误（参数、认证、资源等）
// - 5xx: 服务端错误（服务器问题）
// - 9xx: 业务特定错误（IM 业务专用）

class ErrorCode {
  // =====================================================================
  // 成功 (0)
  // =====================================================================

  /// 成功
  static const int OK = 0;

  /// 通用错误
  static const int ERROR = 1;

  // =====================================================================
  // 4xx 客户端错误（参考 HTTP 4xx）
  // =====================================================================

  /// 请求参数错误
  static const int BAD_REQUEST = 400;
  static const int INVALID_PARAM = 400;
  static const int INVALID_FORMAT = 400;
  static const int PARAM_TOO_LONG = 400;

  /// 未认证
  static const int UNAUTHORIZED = 401;
  static const int TOKEN_MISSING = 401;
  static const int TOKEN_INVALID = 401;
  static const int TOKEN_EXPIRED = 401;

  /// 需要付费
  static const int PAYMENT_REQUIRED = 402;

  /// 已认证但无权限
  static const int FORBIDDEN = 403;
  static const int ACCESS_DENIED = 403;

  /// 资源不存在
  static const int NOT_FOUND = 404;
  static const int USER_NOT_FOUND = 404;
  static const int FRIEND_NOT_FOUND = 404;
  static const int GROUP_NOT_FOUND = 404;
  static const int MESSAGE_NOT_FOUND = 404;

  /// 错误码 405
  static const int METHOD_NOT_ALLOWED = 405;

  /// 错误码 406
  static const int NOT_ACCEPTABLE = 406;

  /// 错误码 408
  static const int REQUEST_TIMEOUT = 408;

  /// 错误码 409
  static const int CONFLICT = 409;
  static const int RESOURCE_EXISTS = 409;
  static const int ALREADY_FRIENDS = 409;
  static const int ALREADY_IN_GROUP = 409;

  /// 错误码 410
  static const int GONE = 410;

  /// 错误码 412
  static const int PRECONDITION_FAILED = 412;

  /// 错误码 413
  static const int PAYLOAD_TOO_LARGE = 413;
  static const int FILE_SIZE_EXCEEDED = 413;

  /// 错误码 415
  static const int UNSUPPORTED_MEDIA_TYPE = 415;
  static const int FILE_TYPE_INVALID = 415;

  /// 错误码 422
  static const int UNPROCESSABLE_ENTITY = 422;
  static const int MISSING_PARAM = 422;
  static const int PARAM_INVALID = 422;

  /// 错误码 423
  static const int LOCKED = 423;
  static const int ACCOUNT_LOCKED = 423;

  /// 请求过于频繁
  static const int TOO_MANY_REQUESTS = 429;
  static const int OPERATION_TOO_FREQUENT = 429;

  // =====================================================================
  // 5xx 服务端错误（参考 HTTP 5xx）
  // =====================================================================

  /// 服务器内部错误
  static const int INTERNAL_SERVER_ERROR = 500;
  static const int SERVER_ERROR = 500;
  static const int BUSINESS_FAILED = 500;
  static const int OPERATION_FAILED = 500;

  /// 错误码 501
  static const int NOT_IMPLEMENTED = 501;

  /// 错误码 502
  static const int BAD_GATEWAY = 502;

  /// 服务不可用
  static const int SERVICE_UNAVAILABLE = 503;
  static const int NODE_OFFLINE = 503;
  static const int CLUSTER_ERROR = 503;

  /// 错误码 504
  static const int GATEWAY_TIMEOUT = 504;
  static const int TIMEOUT = 504;

  /// 错误码 507
  static const int INSUFFICIENT_STORAGE = 507;

  // =====================================================================
  // 9xx 业务特定错误（IM 业务专用）
  // =====================================================================

  /// 错误码 901
  static const int TOKEN_REFRESH_NOT_ALLOWED = 901;

  /// 错误码 902
  static const int SIGNATURE_INVALID = 902;

  /// 错误码 903
  static const int CSRF_TOKEN_ERROR = 903;

  /// 错误码 904
  static const int VERIFICATION_CODE_ERROR = 904;

  /// 错误码 905
  static const int VERIFICATION_CODE_EXPIRED = 905;

  /// 密码错误
  static const int PASSWORD_WRONG = 906;

  /// 账号已禁用
  static const int ACCOUNT_DISABLED = 907;

  /// 账号不存在
  static const int ACCOUNT_NOT_EXIST = 908;

  /// 账号已存在
  static const int ACCOUNT_ALREADY_EXISTS = 909;

  /// 在其他设备登录
  static const int LOGIN_ELSEWHERE = 910;

  /// 不是好友
  static const int NOT_FRIENDS = 920;

  /// 错误码 921
  static const int FRIEND_REQUEST_PENDING = 921;

  /// 错误码 922
  static const int FRIEND_REQUEST_REJECTED = 922;

  /// 错误码 923
  static const int FRIEND_EXISTS = 923;

  /// 非群组成员
  static const int NOT_GROUP_MEMBER = 930;

  /// 错误码 931
  static const int NOT_GROUP_ADMIN = 931;

  /// 错误码 932
  static const int NOT_GROUP_OWNER = 932;

  /// 错误码 933
  static const int GROUP_PERMISSION_DENIED = 933;

  /// 错误码 934
  static const int GROUP_MEMBER_FULL = 934;

  /// 错误码 935
  static const int GROUP_CREATE_FAILED = 935;

  /// 错误码 940
  static const int USER_OFFLINE = 940;

  /// 消息发送失败
  static const int MSG_SEND_FAILED = 941;

  /// 错误码 942
  static const int MSG_NOT_FOUND = 942;

  /// 错误码 950
  static const int FILE_UPLOAD_FAILED = 950;

  /// 错误码 951
  static const int FILE_DOWNLOAD_FAILED = 951;

  // =====================================================================
  // 错误消息映射
  // =====================================================================

  static const Map<int, String> _messageMap = {
    0: '成功',
    1: '操作失败',
    400: '请求参数错误',
    401: '未认证，请先登录',
    402: '需要付费',
    403: '无权限访问',
    404: '资源不存在',
    405: '方法不允许',
    406: '内容格式不支持',
    408: '请求超时',
    409: '资源冲突',
    410: '资源已删除',
    412: '前置条件失败',
    413: '请求体过大',
    415: '不支持的媒体类型',
    422: '请求语义错误',
    423: '资源被锁定',
    429: '请求过于频繁，请稍后重试',
    500: '服务器内部错误',
    501: '功能未实现',
    502: '网关错误',
    503: '服务不可用',
    504: '网关超时',
    507: '存储空间不足',
    901: '不支持刷新 Token',
    902: '签名验证失败',
    903: 'CSRF Token 错误',
    904: '验证码错误',
    905: '验证码已过期',
    906: '密码错误',
    907: '账号已禁用',
    908: '账号不存在',
    909: '账号已存在',
    910: '您的账号已在其他设备登录',
    920: '还不是好友',
    921: '好友请求待确认',
    922: '好友请求被拒绝',
    923: '好友关系已存在',
    930: '非群组成员',
    931: '非群管理员',
    932: '非群主',
    933: '群组权限不足',
    934: '群成员已满',
    935: '创建群组失败',
    940: '用户离线，消息已存储',
    941: '消息发送失败',
    942: '消息不存在',
    950: '文件上传失败',
    951: '文件下载失败',
  };

  /// 获取错误码对应的默认消息
  static String getMessage(int code) {
    return _messageMap[code] ?? '未知错误';
  }

  /// 判断是否为成功响应
  static bool isSuccess(int code) {
    return code == OK;
  }

  /// 判断是否为客户端错误 (4xx)
  static bool isClientError(int code) {
    return code >= 400 && code < 500;
  }

  /// 判断是否为服务端错误 (5xx)
  static bool isServerError(int code) {
    return code >= 500 && code < 600;
  }

  /// 判断是否为业务错误 (9xx)
  static bool isBusinessError(int code) {
    return code >= 900 && code < 1000;
  }

  /// 判断是否需要重新登录
  static bool shouldReLogin(int code) {
    return code == UNAUTHORIZED ||
        code == TOKEN_INVALID ||
        code == TOKEN_EXPIRED ||
        code == TOKEN_MISSING ||
        code == LOGIN_ELSEWHERE;
  }
}

