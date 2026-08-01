// ignore_for_file: constant_identifier_names
// ⚠️ 此文件由脚本自动生成，请勿手动修改
//
// 生成命令: dart scripts/generate_error_code.dart
// 校验命令: dart scripts/generate_error_code.dart --check
// 源文件: imboy/include/error_code.hrl
//
// 错误码设计原则:
// - 0: 成功（API 响应成功标记）
// - 4xx: 客户端错误（参数、认证、资源等）
// - 5xx: 服务端错误（服务器问题）
// - 9xx: 业务特定错误（IM 业务专用）
// - 其余: 各子系统扩展码（E2EE / 支付 / 插件 …）

class ErrorCode {
  // =====================================================================
  // 成功 (0) 与通用错误 (1)
  // =====================================================================

  /// 错误码 0
  static const int OK = 0;

  /// 错误码 1
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

  /// 群组不存在
  static const int GROUP_NOT_FOUND = 404;
  static const int USER_NOT_FOUND = 404;
  static const int FRIEND_NOT_FOUND = 404;
  static const int NOT_FOUND = 404;
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
  static const int REVOKE_TIMEOUT = 409;

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
  static const int PARAM_INVALID = 422;
  static const int MISSING_PARAM = 422;

  /// 错误码 423
  static const int ACCOUNT_LOCKED = 423;
  static const int LOCKED = 423;

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
  static const int TIMEOUT = 504;
  static const int GATEWAY_TIMEOUT = 504;

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

  /// 错误码 911
  static const int SETUP_ALREADY_COMPLETED = 911;

  /// 错误码 912
  static const int SETUP_INVALID_PARAMS = 912;

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

  /// 错误码 952
  static const int FILE_NOT_FOUND = 952;

  /// 错误码 953
  static const int FILE_TYPE_NOT_ALLOWED = 953;

  /// 错误码 955
  static const int FILE_DELETE_FAILED = 955;

  /// 错误码 956
  static const int FILE_STORAGE_FULL = 956;

  /// 错误码 960
  static const int ALBUM_NOT_FOUND = 960;

  /// 错误码 961
  static const int ALBUM_NAME_INVALID = 961;

  /// 错误码 962
  static const int ALBUM_ALREADY_EXISTS = 962;

  /// 错误码 963
  static const int PHOTO_NOT_FOUND = 963;

  /// 错误码 964
  static const int PHOTO_UPLOAD_FAILED = 964;

  /// 错误码 965
  static const int PHOTO_TYPE_INVALID = 965;

  /// 错误码 966
  static const int PHOTO_SIZE_EXCEEDED = 966;

  /// 错误码 967
  static const int ALBUM_PERMISSION_DENIED = 967;

  /// 错误码 968
  static const int PHOTO_ALREADY_LIKED = 968;

  // =====================================================================
  // 其余：各子系统扩展错误码
  // =====================================================================

  /// 错误码 5000
  static const int E2EE_TRANSFER_INVALID_SESSION = 5000;

  /// 错误码 5001
  static const int E2EE_TRANSFER_SESSION_EXPIRED = 5001;

  /// 错误码 5002
  static const int E2EE_TRANSFER_SESSION_NOT_FOUND = 5002;

  /// 错误码 5003
  static const int E2EE_TRANSFER_INVALID_DEVICE = 5003;

  /// 错误码 5004
  static const int E2EE_TRANSFER_ALREADY_ACCEPTED = 5004;

  /// 错误码 5005
  static const int E2EE_TRANSFER_CANNOT_CONFIRM = 5005;

  /// 错误码 5006
  static const int E2EE_TRANSFER_FROM_UID_NOT_MATCH = 5006;

  /// 错误码 5007
  static const int E2EE_TRANSFER_TO_UID_NOT_MATCH = 5007;

  /// 错误码 5008
  static const int E2EE_TRANSFER_CONCURRENT = 5008;

  /// 错误码 5009
  static const int E2EE_TRANSFER_ALREADY_CANCELLED = 5009;

  /// 错误码 5010
  static const int E2EE_TRANSFER_STATUS_INVALID = 5010;

  /// 错误码 5020
  static const int E2EE_SOCIAL_CONTACT_NOT_FOUND = 5020;

  /// 错误码 5021
  static const int E2EE_SOCIAL_CONTACT_ALREADY_EXISTS = 5021;

  /// 错误码 5022
  static const int E2EE_SOCIAL_CONTACT_IS_SELF = 5022;

  /// 错误码 5023
  static const int E2EE_SOCIAL_CONTACT_NOT_TRUSTED = 5023;

  /// 错误码 5024
  static const int E2EE_SOCIAL_NOT_ENOUGH_SHARES = 5024;

  /// 错误码 5025
  static const int E2EE_SOCIAL_SHARE_ALREADY_CREATED = 5025;

  /// 错误码 5026
  static const int E2EE_SOCIAL_SHARE_NOT_FOUND = 5026;

  /// 错误码 5027
  static const int E2EE_SOCIAL_INVALID_THRESHOLD = 5027;

  /// 错误码 5028
  static const int E2EE_SOCIAL_RECOVER_FAILED = 5028;

  /// 错误码 5029
  static const int E2EE_SOCIAL_TRUSTEE_LIMIT_EXCEEDED = 5029;

  /// 错误码 5040
  static const int E2EE_BACKUP_INVALID_PASSWORD = 5040;

  /// 错误码 5041
  static const int E2EE_BACKUP_FILE_CORRUPTED = 5041;

  /// 错误码 5042
  static const int E2EE_BACKUP_VERSION_MISMATCH = 5042;

  /// 错误码 5043
  static const int E2EE_BACKUP_CHECKSUM_MISMATCH = 5043;

  /// 错误码 5044
  static const int E2EE_BACKUP_FILE_TOO_LARGE = 5044;

  /// 错误码 5045
  static const int E2EE_BACKUP_INVALID_FORMAT = 5045;

  /// 错误码 5050
  static const int E2EE_INVALID_KEY_FORMAT = 5050;

  /// 错误码 5051
  static const int E2EE_KEY_DERIVATION_FAILED = 5051;

  /// 错误码 5052
  static const int E2EE_ENCRYPTION_FAILED = 5052;

  /// 错误码 5053
  static const int E2EE_DECRYPTION_FAILED = 5053;

  /// 错误码 5054
  static const int E2EE_KEY_NOT_FOUND = 5054;

  /// 错误码 5055
  static const int E2EE_OPERATION_NOT_SUPPORTED = 5055;

  /// 错误码 5056
  static const int E2EE_BACKUP_PASSWORD_TOO_WEAK = 5056;

  /// 错误码 5060
  static const int E2EE_RECOVERY_NO_OPTIONS = 5060;

  /// 错误码 5061
  static const int E2EE_RECOVERY_IN_PROGRESS = 5061;

  /// 错误码 5062
  static const int E2EE_RECOVERY_FAILED = 5062;

  /// 错误码 5063
  static const int E2EE_RECOVERY_TIMEOUT = 5063;

  /// 错误码 5064
  static const int E2EE_RECOVERY_KEY_MISMATCH = 5064;

  /// 错误码 5100
  static const int DEVICE_SESSION_INVALID = 5100;

  /// 错误码 5101
  static const int DEVICE_SESSION_KICKED = 5101;

  /// 错误码 5102
  static const int DEVICE_TYPE_CONFLICT = 5102;

  /// 错误码 5103
  static const int DEVICE_NOT_FOUND = 5103;

  /// 错误码 5104
  static const int DEVICE_SESSION_EXPIRED = 5104;

  /// 错误码 5190
  static const int FEATURE_DISABLED = 5190;

  /// 错误码 5200
  static const int INVALID_QR_TOKEN = 5200;

  /// 错误码 5201
  static const int QR_LOGIN_EXPIRED = 5201;

  /// 错误码 5202
  static const int QR_LOGIN_CANCELLED = 5202;

  /// 错误码 5203
  static const int QR_LOGIN_ALREADY_USED = 5203;

  /// 错误码 5204
  static const int QR_LOGIN_NOT_SCANNED = 5204;

  /// 错误码 5205
  static const int QR_LOGIN_DEVICE_LIMIT = 5205;

  /// 错误码 5300
  static const int TASK_NOT_FOUND = 5300;

  /// 错误码 5301
  static const int TASK_TITLE_REQUIRED = 5301;

  /// 错误码 5302
  static const int TASK_ALREADY_SUBMITTED = 5302;

  /// 错误码 5303
  static const int TASK_ASSIGNMENT_NOT_FOUND = 5303;

  /// 错误码 5304
  static const int TASK_ALREADY_REVIEWED = 5304;

  /// 错误码 5305
  static const int TASK_DEADLINE_PASSED = 5305;

  /// 错误码 5306
  static const int TASK_PERMISSION_DENIED = 5306;

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
    911: '系统已完成首启初始化',
    912: '首启参数无效',
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
    952: '文件不存在',
    953: '不允许的文件类型',
    954: '文件大小超出限制',
    955: '文件删除失败',
    956: '群文件存储空间已满',
    960: '相册不存在',
    961: '相册名称无效',
    962: '相册已存在',
    963: '图片不存在',
    964: '图片上传失败',
    965: '图片类型无效',
    966: '图片大小超出限制',
    967: '相册权限不足',
    968: '已点赞该图片',
    5000: '无效的传输会话',
    5001: '传输会话已过期',
    5002: '传输会话不存在',
    5003: '无效的设备',
    5004: '传输会话已被接受',
    5005: '无法确认传输会话',
    5006: '发送方用户 ID 不匹配',
    5007: '接收方用户 ID 不匹配',
    5008: '存在进行中的传输会话',
    5009: '传输会话已取消',
    5010: '无效的会话状态转换',
    5020: '可信联系人不存在',
    5021: '可信联系人已存在',
    5022: '不能添加自己为可信联系人',
    5023: '该联系人不在可信列表中',
    5024: '密钥分片数量不足',
    5025: '密钥分片已创建',
    5026: '密钥分片不存在',
    5027: '无效的恢复阈值',
    5028: '密钥恢复失败',
    5029: '受托人数量超过限制',
    5040: '备份密码错误',
    5041: '备份文件已损坏',
    5042: '备份版本不匹配',
    5043: '备份校验和不匹配',
    5044: '备份文件过大',
    5045: '备份文件格式无效',
    5050: '无效的密钥格式',
    5051: '密钥派生失败',
    5052: '加密失败',
    5053: '解密失败',
    5054: '密钥不存在',
    5055: '不支持的操作',
    5056: '备份密码强度不足',
    5060: '无可用恢复方式',
    5061: '恢复进行中，请稍后',
    5062: '密钥恢复失败',
    5063: '恢复操作超时',
    5064: '密钥不匹配，请重新获取',
    5100: '设备会话无效',
    5101: '设备会话已被踢出，请重新登录',
    5102: '同类型设备已登录，请确认是否踢出旧设备',
    5103: '设备不存在',
    5104: '设备会话已过期',
    5190: '功能未启用',
    5300: '作业不存在',
    5301: '作业标题必填',
    5302: '作业已提交，无法修改',
    5303: '作业分配不存在',
    5304: '作业已批改，无法修改',
    5305: '作业已过期，无法提交',
    5306: '无权限操作此作业',
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
