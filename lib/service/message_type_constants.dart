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

part 'message_type_enum.dart';

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

  /// 语音消息协议别称
  ///
  /// protobuf 通道（ContentType.AUDIO）与收藏恢复链路（kind=3）产出的
  /// 是 'audio' 而非 'voice'。渲染真值统一为 [voice]（见
  /// MessageTypeNormalizer 的 audio→voice 别名归一），此处仅保证
  /// `isValidType('audio')` 通过、不被判成 unsupported。
  static const String audio = 'audio';

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

  /// 表情消息
  ///
  /// payload 结构：
  /// ```json
  /// {
  ///   "url": "https://cdn.example.com/emoji.png",
  ///   "width": 120,
  ///   "height": 120,
  ///   "text": "[微笑]"
  /// }
  /// ```
  static const String expression = 'expression';

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

  /// WebRTC 音频通话信令
  static const String webrtcAudio = 'webrtcAudio';

  /// WebRTC 视频通话信令
  static const String webrtcVideo = 'webrtcVideo';

  /// 个人名片消息
  static const String visitCard = 'visitCard';

  /// 频道卡片消息
  static const String channelCard = 'channel_card';
  static const String talkRecordCard = 'talk_record_card';

  /// 红包消息
  static const String redPacket = 'redPacket';

  /// 转账消息
  static const String transfer = 'transfer';

  /// 群日程卡片消息
  static const String groupSchedule = 'groupSchedule';
  static const String groupVote = 'groupVote';
  static const String groupTask = 'groupTask';

  /// 群公告卡片消息（服务端在公告发布时创建，客户端只渲染不发送）
  static const String groupNotice = 'groupNotice';

  /// 自定义消息
  ///
  /// 作为通用兜底类型使用。
  /// 推荐直接使用具体 `msg_type`（如 `webrtcAudio`、`visitCard`）。
  /// payload 结构示例（兜底场景）：
  /// ```json
  /// {
  ///   "event": "unknown_custom_event",
  ///   "call_type": "offer",
  ///   "sdp": "..."
  /// }
  /// ```
  static const String custom = 'custom';

  // ==================== 特殊类型 ====================

  /// 不支持的消息类型
  ///
  /// 客户端无法识别或处理的消息类型
  static const String unsupported = 'unsupported';

  // ==================== 辅助属性 ====================

  /// 所有有效的消息类型列表
  ///
  /// 用于类型验证和归一化
  static const List<String> allTypes = [
    text,
    textStream,
    image,
    imageMulti,
    voice,
    audio,
    video,
    file,
    location,
    expression,
    quote,
    // 业务消息类型（直接作为 msg_type 使用）
    webrtcAudio,
    webrtcVideo,
    visitCard,
    channelCard,
    talkRecordCard,
    redPacket,
    transfer,
    groupSchedule,
    groupVote,
    groupTask,
    groupNotice,
  ];

  /// 判断是否为有效的消息类型
  ///
  /// ## 参数
  /// - [type]: 待验证的类型
  ///
  /// ## 返回
  /// true 如果类型有效，false 否则
  static bool isValidType(String type) {
    return allTypes.contains(type) || type == custom || type == unsupported;
  }
}

// ============================================
// C2S 上行动作类型 (action)
// ============================================

/// 客户端→服务端 上行 WS 帧的 action 常量
///
/// 与后端真源 `imboy_ws_action_registry` 的 ?BUILTIN_ACTIONS 对齐；
/// 后端契约门（imboy 仓 `make contract-check`）以本类为 App 侧清单
/// 做单向比对：App 不得声明 registry 之外的 action。
abstract class C2SAction {
  /// 消息已读
  static const String messageRead = 'message_read';

  /// 已读确认
  static const String messageReadAck = 'message_read_ack';

  /// 消息撤回
  static const String messageRevoke = 'message_revoke';

  /// 撤回确认
  static const String messageRevokeAck = 'message_revoke_ack';

  /// 消息编辑
  static const String messageEdit = 'message_edit';

  /// 编辑确认
  static const String messageEditAck = 'message_edit_ack';

  /// 输入中状态
  static const String messageInput = 'message_input';

  /// Megolm 群会话密钥分发帧（服务端不透明中转）
  static const String e2eeRoomKey = 'e2ee_room_key';

  /// ⚠️ 服务端 registry 未注册（上行恒回 unknown_action）：表情回应的生效
  /// 通道是 HTTP messaging API（后端 messaging_logic → msg_reaction_logic）。
  /// 本 WS 通道去留待拍板（契约漂移登记簿 #9），先按现状收编进清单。
  static const String messageReaction = 'message_reaction';
}

// ============================================
// S2C 系统动作类型 (action)
// ============================================

/// S2C 系统消息动作常量
///
/// 用于 S2C 消息的 `action` 字段
/// 定义服务端到客户端的各种 system 指令
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

  // ==================== 朋友圈通知 ====================

  /// 朋友圈新动态
  static const String momentNew = 'moment_new';

  /// 朋友圈点赞
  static const String momentLike = 'moment_like';

  /// 朋友圈评论
  static const String momentComment = 'moment_comment';

  /// 朋友圈删除
  static const String momentDeleted = 'moment_deleted';

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
    momentNew,
    momentLike,
    momentComment,
    momentDeleted,
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
    momentNew: '朋友圈新动态',
    momentLike: '朋友圈点赞',
    momentComment: '朋友圈评论',
    momentDeleted: '朋友圈删除',
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

  /// 频道消息 (Channel)
  static const String channel = 'CHANNEL';

  /// 客户端发起的聊天流向类型（不包含 S2C/CHANNEL）
  static const List<String> _chatFlows = [c2c, c2g, c2s];

  /// 判断是否为客户端聊天流向类型（C2C/C2G/C2S）
  static bool isChatFlow(String? type) {
    if (type == null) return false;
    return _chatFlows.contains(type.trim().toUpperCase());
  }

  /// 归一化聊天流向类型，非法值回落到 [fallback]
  ///
  /// 设计目标：
  /// - 统一处理历史脏值（如 `'null'`、空字符串）
  /// - 保证发送/读取链路仅流通 C2C/C2G/C2S
  static String normalize(String? type, {String fallback = c2c}) {
    final normalized = (type ?? '').trim().toUpperCase();
    return isChatFlow(normalized) ? normalized : fallback;
  }
}

// ============================================
// 频道消息类型 (Channel Message Types)
// ============================================

/// 频道消息类型常量
///
/// 用于频道消息的 `msg_type` 字段
/// 频道消息使用 `channel_` 前缀以区分普通消息
abstract class ChannelMessageType {
  /// 频道文本消息
  static const String text = 'channel_text';

  /// 频道图片消息
  static const String image = 'channel_image';

  /// 频道视频消息
  static const String video = 'channel_video';

  /// 频道语音消息
  static const String audio = 'channel_audio';

  /// 频道文件消息
  static const String file = 'channel_file';

  /// 频道图文消息（公众号式：正文 + 图片九宫格，一次发布一条）
  static const String imageText = 'channel_imageText';

  /// 频道链接消息
  static const String link = 'channel_link';

  /// 频道位置消息
  static const String location = 'channel_location';

  /// 纯媒体消息的 content 占位：后端 send_message 拒收空 content
  /// （channel_handler_message.erl「消息内容不能为空」），发布端以占位符过闸；
  /// 渲染/预览层须将其视为空正文（见 ChannelMessageModel.displayContent）。
  static const String mediaPlaceholder = '[media]';

  /// 所有有效的频道消息类型
  static const List<String> allTypes = [
    text,
    image,
    video,
    audio,
    file,
    imageText,
    link,
    location,
  ];

  /// 判断是否为有效的频道消息类型
  static bool isValid(String type) {
    return allTypes.contains(type);
  }

  /// 从普通消息类型转换为频道消息类型
  ///
  /// 例如：'text' -> 'channel_text'
  static String fromMessageType(String msgType) {
    if (msgType.startsWith('channel_')) {
      return msgType;
    }
    return 'channel_$msgType';
  }

  /// 转换为普通消息类型（去除前缀）
  ///
  /// 例如：'channel_text' -> 'text'
  static String toMessageType(String channelMsgType) {
    if (channelMsgType.startsWith('channel_')) {
      return channelMsgType.substring(8);
    }
    return channelMsgType;
  }
}
