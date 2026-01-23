/// WebSocket API v2.0 消息类型常量定义
///
/// 统一定义所有消息类型 (msg_type) 和系统动作 (action) 的常量
/// 避免硬编码字符串，提高代码可维护性
///
/// 使用示例：
/// ```dart
/// // 使用常量（推荐）
/// String type = MessageType.text;
/// if (msgType == MessageType.image) { ... }
///
/// // 使用枚举（类型安全）
/// if (msgTypeEnum == MsgTypeEnum.image) { ... }
///
/// // S2C 系统动作
/// String action = S2CAction.pullOfflineMsg;
/// if (action == S2CAction.c2cRevoke) { ... }
/// ```
library;

// ============================================
// 消息类型枚举 (类型安全)
// ============================================

/// 用户消息类型枚举
///
/// 提供 类型安全的消息类型定义
/// 迁移自 lib/component/chat/enum.dart 的 CustomMessageType
///
/// 使用示例：
/// ```dart
/// MsgTypeEnum type = MsgTypeEnum.image;
/// String typeStr = type.value;  // 'image'
/// ```
enum MsgTypeEnum {
  /// 文本消息
  text,

  /// 文本流消息（AI对话等流式输出）
  textStream,

  /// 图片消息
  image,

  /// 多图消息（一次发送多张图片）
  imageMulti,

  /// 文件消息
  file,

  /// 位置消息
  location,

  /// 语音消息
  audio,

  /// 视频消息
  video,

  /// 不支持的消息类型
  unsupported,

  /// 系统消息
  system,

  /// 自定义消息
  custom,

  /// WebRTC 音频通话
  webrtcAudio,

  /// WebRTC 视频通话
  webrtcVideo,

  /// 引用消息
  quote,
}

/// MsgTypeEnum 扩展方法
extension MsgTypeEnumExtension on MsgTypeEnum {
  /// 获取枚举对应的字符串值
  String get value {
    switch (this) {
      case MsgTypeEnum.text:
        return MessageType.text;
      case MsgTypeEnum.textStream:
        return MessageType.textStream;
      case MsgTypeEnum.image:
        return MessageType.image;
      case MsgTypeEnum.imageMulti:
        return MessageType.imageMulti;
      case MsgTypeEnum.file:
        return MessageType.file;
      case MsgTypeEnum.location:
        return MessageType.location;
      case MsgTypeEnum.audio:
        return MessageType.audio;
      case MsgTypeEnum.video:
        return MessageType.video;
      case MsgTypeEnum.unsupported:
        return MessageType.unsupported;
      case MsgTypeEnum.system:
        return MessageType.system;
      case MsgTypeEnum.custom:
        return MessageType.custom;
      case MsgTypeEnum.webrtcAudio:
        return CustomMessageType.webrtcAudio;
      case MsgTypeEnum.webrtcVideo:
        return CustomMessageType.webrtcVideo;
      case MsgTypeEnum.quote:
        return MessageType.quote;
    }
  }

  /// 从字符串值获取枚举
  static MsgTypeEnum? fromValue(String value) {
    switch (value) {
      case MessageType.text:
        return MsgTypeEnum.text;
      case MessageType.textStream:
        return MsgTypeEnum.textStream;
      case MessageType.image:
        return MsgTypeEnum.image;
      case MessageType.imageMulti:
        return MsgTypeEnum.imageMulti;
      case MessageType.file:
        return MsgTypeEnum.file;
      case MessageType.location:
        return MsgTypeEnum.location;
      case MessageType.audio:
        return MsgTypeEnum.audio;
      case MessageType.video:
        return MsgTypeEnum.video;
      case MessageType.unsupported:
        return MsgTypeEnum.unsupported;
      case MessageType.system:
        return MsgTypeEnum.system;
      case MessageType.custom:
        return MsgTypeEnum.custom;
      case CustomMessageType.webrtcAudio:
        return MsgTypeEnum.webrtcAudio;
      case CustomMessageType.webrtcVideo:
        return MsgTypeEnum.webrtcVideo;
      case MessageType.quote:
        return MsgTypeEnum.quote;
      default:
        return null;
    }
  }
}

// ============================================
// 用户消息类型 (C2C/C2G/C2S)
// ============================================

/// 用户消息类型常量
///
/// 用于 C2C、C2G、C2S 消息的 `msg_type` 字段
/// 定义消息的内容类型
abstract class MessageType {
  // ==================== 基础消息类型 ====================

  /// 文本消息
  ///
  /// payload 结构：
  /// ```json
  /// {
  ///   "text": "消息内容",
  ///   "client_send_ts": 1642579200000
  /// }
  /// ```
  static const String text = 'text';

  /// 文本流消息
  ///
  /// 用于 AI 对话等流式文本输出场景，文本分段传输
  /// payload 结构：
  /// ```json
  /// {
  ///   "text": "当前分片文本",
  ///   "index": 0,
  ///   "is_end": false,
  ///   "stream_id": "stream_abc123"
  /// }
  /// ```
  static const String textStream = 'textStream';

  /// 图片消息
  ///
  /// payload 结构：
  /// ```json
  /// {
  ///   "uri": "https://cdn.example.com/image.jpg",
  ///   "size": 102400,
  ///   "width": 1920,
  ///   "height": 1080
  /// }
  /// ```
  static const String image = 'image';

  /// 多图消息
  ///
  /// 一次发送多张图片（最多9张）
  /// payload 结构：
  /// ```json
  /// {
  ///   "images": [
  ///     {"uri": "https://...", "size": 102400, "width": 1920, "height": 1080}
  ///   ],
  ///   "total": 3
  /// }
  /// ```
  static const String imageMulti = 'imageMulti';

  /// 语音消息
  ///
  /// payload 结构：
  /// ```json
  /// {
  ///   "uri": "https://cdn.example.com/voice.mp3",
  ///   "duration_ms": 15000
  /// }
  /// ```
  static const String voice = 'voice';

  /// 视频消息
  ///
  /// payload 结构：
  /// ```json
  /// {
  ///   "uri": "https://cdn.example.com/video.mp4",
  ///   "thumb": {
  ///     "uri": "https://cdn.example.com/thumb.jpg"
  ///   },
  ///   "duration_ms": 60000,
  ///   "size": 5120000
  /// }
  /// ```
  static const String video = 'video';

  /// 文件消息
  ///
  /// payload 结构：
  /// ```json
  /// {
  ///   "uri": "https://cdn.example.com/document.pdf",
  ///   "name": "report.pdf",
  ///   "size": 1024000,
  ///   "mime_type": "application/pdf"
  /// }
  /// ```
  static const String file = 'file';

  /// 位置消息
  ///
  /// payload 结构：
  /// ```json
  /// {
  ///   "latitude": 39.9042,
  ///   "longitude": 116.4074,
  ///   "title": "北京市朝阳区",
  ///   "address": "朝阳区建国路88号"
  /// }
  /// ```
  static const String location = 'location';

  /// 引用消息
  ///
  /// payload 结构：
  /// ```json
  /// {
  ///   "quote_msg_id": "msg100",
  ///   "quote_text": "原始消息内容",
  ///   "text": "回复内容"
  /// }
  /// ```
  static const String quote = 'quote';

  /// 自定义消息
  ///
  /// 通过 `custom_type` 字段子类型区分具体类型
  /// payload 结构示例：
  /// ```json
  /// {
  ///   "custom_type": "webrtc_audio",
  ///   "call_type": "offer",
  ///   "sdp": "..."
  /// }
  /// ```
  static const String custom = 'custom';

  // ==================== E2EE 加密消息 ====================

  /// 端到端加密消息（已废弃，仅用于向后兼容）
  ///
  /// **WebSocket API v2.0 变更**：
  /// - ❌ **不再**使用 `msg_type = 'e2ee'` 来标识加密消息
  /// - ✅ **保留**原始消息的 `msg_type`（text, image, video 等）
  /// - ✅ **通过** `e2ee` 字段（Map 类型）是否存在判断是否为加密消息
  ///
  /// v2.0 消息结构：
  /// ```json
  /// {
  ///   "msg_type": "text",  // 保留原始消息类型
  ///   "e2ee": {
  ///     "e2ee": true,
  ///     "e2ee_ver": 1,
  ///     "e2ee_suite": "RSA-OAEP-256+AES-256-GCM",
  ///     "iv": "base64_encoded_iv",
  ///     "ct": "base64_encoded_ciphertext",
  ///     "recipients": [...],
  ///     "sig": "base64_signature"
  ///   },
  ///   "payload": "base64(iv).base64(ciphertext)"
  /// }
  /// ```
  ///
  /// v1.0 旧格式（已废弃）：
  /// ```json
  /// {
  ///   "msg_type": "e2ee",
  ///   "payload": "base64(nonce).base64(ciphertext)"
  /// }
  /// ```
  @Deprecated('WebSocket API v2.0: 使用原始 msg_type + e2ee 字段代替')
  static const String e2ee = 'e2ee';

  // ==================== 已废弃/兼容性类型 ====================

  /// @Deprecated 使用 'voice' 代替
  static const String audio = 'audio';

  /// @Deprecated 使用 'custom' 代替
  static const String system = 'system';

  /// 不支持的消息类型
  ///
  /// 客户端无法识别或处理的消息类型
  static const String unsupported = 'unsupported';
}

// ============================================
// 自定义消息子类型 (custom_type)
// ============================================

/// 自定义消息子类型常量
///
/// 当 `msg_type` 为 `custom` 时，通过 `custom_type` 区分子类型
abstract class CustomMessageType {
  /// 消息撤回 (自己撤回)
  ///
  /// 用户主动撤回消息时使用
  static const String messageRevoke = 'message_revoke';

  /// 正在输入提示
  ///
  /// 显示对方正在输入状态
  static const String typingIndicator = 'typing_indicator';

  /// WebRTC 音频通话
  ///
  /// WebRTC 音频通话邀请/信令
  static const String webrtcAudio = 'webrtcAudio';

  /// WebRTC 视频通话
  ///
  /// WebRTC 视频通话邀请/信令
  static const String webrtcVideo = 'webrtcVideo';

  /// 个人名片
  ///
  /// 分享联系人名片
  static const String visitCard = 'visitCard';

  /// 实时通话邀请
  ///
  /// WebRTC 实时通话邀请信令
  static const String rtcCall = 'rtc_call';
}

// ============================================
// S2C 系统动作类型 (action)
// ============================================

/// S2C 系统消息动作常量
///
/// 用于 S2C 消息的 `action` 字段
/// 定义服务端到客户端的各种系统指令
abstract class S2CAction {
  // ==================== 消息操作 ====================

  /// 拉取离线消息
  ///
  /// 触发时机：服务端通知客户端有离线消息需要拉取
  /// 处理方式：发布离线消息拉取事件
  static const String pullOfflineMsg = 'pull_offline_msg';

  /// C2C 消息撤回
  ///
  /// 触发时机：对端撤回了一条消息
  /// 处理方式：将消息转换为撤回提示，更新数据库
  static const String c2cRevoke = 'c2c_revoke';

  /// C2C 双方删除
  ///
  /// 触发时机：对端删除了一条消息（双方都删除）
  /// 处理方式：从会话中移除消息
  static const String c2cDelEveryone = 'c2c_del_everyone';

  /// C2G 全员删除
  ///
  /// 触发时机：群组消息被删除（所有人可见）
  /// 处理方式：从群组会话中移除消息
  static const String c2gDelEveryone = 'c2g_del_everyone';

  /// C2G 单方删除
  ///
  /// 触发时机：自己删除群消息
  /// 处理方式：仅自己移除，不影响其他成员
  static const String c2gDelForMe = 'c2g_del_for_me';

  // ==================== 群组操作 ====================

  /// 群成员加入
  ///
  /// 触发时机：有新成员加入群组
  /// 处理方式：更新群组成员列表，触发UI更新
  static const String groupMemberJoin = 'group_member_join';

  /// 群组解散
  ///
  /// 触发时机：群组被解散
  /// 处理方式：清理群组相关数据，更新UI
  static const String groupDissolve = 'group_dissolve';

  /// 群成员离开
  ///
  /// 触发时机：有成员离开群组
  /// 处理方式：更新群组成员列表，触发UI更新
  static const String groupMemberLeave = 'group_member_leave';

  /// 群成员别名更新
  ///
  /// 触发时机：群成员昵称/备注修改
  /// 处理方式：更新成员显示名称
  static const String groupMemberAlias = 'group_member_alias';

  // ==================== 好友关系 ====================

  /// 好友申请
  ///
  /// 触发时机：收到好友申请
  /// 处理方式：显示申请通知，添加到新好友列表
  static const String applyFriend = 'apply_friend';

  /// 好友申请确认
  ///
  /// 触发时机：好友申请被通过
  /// 处理方式：保存好友信息，更新UI
  static const String applyFriendConfirm = 'apply_friend_confirm';

  /// 用户注销
  ///
  /// 触发时机：好友注销账号
  /// 处理方式：标记用户已注销
  static const String userCancel = 'user_cancel';

  /// 加入黑名单
  ///
  /// 触发时机：消息被对方拒收
  /// 处理方式：显示拒收提示
  static const String inDenylist = 'in_denylist';

  /// 非好友关系
  ///
  /// 触发时机：好友关系解除
  /// 处理方式：显示关系解除提示
  static const String notAFriend = 'not_a_friend';

  // ==================== 在线状态 ====================

  /// 好友上线
  ///
  /// 触发时机：好友上线
  /// 处理方式：显示在线提示
  static const String online = 'online';

  /// 好友下线
  ///
  /// 触发时机：好友下线
  /// 处理方式：显示离线提示
  static const String offline = 'offline';

  /// 隐身状态
  ///
  /// 触发时机：好友隐身
  /// 处理方式：更新好友状态显示
  static const String hide = 'hide';

  // ==================== 账号安全 ====================

  /// 异地登录
  ///
  /// 触发时机：账号在其他设备登录
  /// 处理方式：强制退出当前设备，跳转登录页
  static const String loggedAnotherDevice = 'logged_another_device';

  /// 设备强制下线
  ///
  /// 触发时机：账号被服务端强制下线（封号、违规等）
  /// 处理方式：显示提示，退出登录
  static const String deviceForceOffline = 'device_force_offline';

  /// 刷新令牌
  ///
  /// 触发时机：访问令牌即将过期
  /// 处理方式：使用刷新令牌获取新令牌
  static const String pleaseRefreshToken = 'please_refresh_token';

  // ==================== 应用管理 ====================

  /// 应用升级
  ///
  /// 触发时机：有新版本可用
  /// 处理方式：检查版本，显示升级提示
  static const String appUpgrade = 'app_upgrade';

  // ==================== 辅助方法 ====================

  /// 判断是否为有效的 S2C action
  static bool isValid(String action) {
    return _allActions.contains(action);
  }

  /// 获取 action 的显示名称
  static String getDisplayName(String action) {
    return _actionNames[action] ?? action;
  }

  /// 所有有效的 S2C action
  static const List<String> _allActions = [
    pullOfflineMsg,
    c2cRevoke,
    c2cDelEveryone,
    c2gDelEveryone,
    c2gDelForMe,
    groupMemberJoin,
    groupDissolve,
    groupMemberLeave,
    groupMemberAlias,
    applyFriend,
    applyFriendConfirm,
    userCancel,
    inDenylist,
    notAFriend,
    online,
    offline,
    hide,
    loggedAnotherDevice,
    deviceForceOffline,
    pleaseRefreshToken,
    appUpgrade,
  ];

  /// Action 显示名称映射
  static const Map<String, String> _actionNames = {
    pullOfflineMsg: '拉取离线消息',
    c2cRevoke: '消息撤回',
    c2cDelEveryone: '双方删除',
    c2gDelEveryone: '全员删除',
    c2gDelForMe: '单方删除',
    groupMemberJoin: '成员加入',
    groupDissolve: '群组解散',
    groupMemberLeave: '成员离开',
    groupMemberAlias: '成员别名',
    applyFriend: '好友申请',
    applyFriendConfirm: '申请通过',
    userCancel: '用户注销',
    inDenylist: '加入黑名单',
    notAFriend: '非好友',
    online: '上线提醒',
    offline: '下线提醒',
    hide: '隐身状态',
    loggedAnotherDevice: '异地登录',
    deviceForceOffline: '强制下线',
    pleaseRefreshToken: '刷新令牌',
    appUpgrade: '应用升级',
  };
}

// ============================================
// 消息流向类型 (type)
// ============================================

/// 消息流向类型常量
///
/// 用于消息的 `type` 字段，定义消息的流向方向
abstract class MessageFlowType {
  /// 客户端到客户端 (单聊)
  static const String c2c = 'C2C';

  /// 客户端到群组 (群聊)
  static const String c2g = 'C2G';

  /// 客户端到服务端 (请求)
  static const String c2s = 'C2S';

  /// 服务端到客户端 (通知/指令)
  static const String s2c = 'S2C';
}
