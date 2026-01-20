import 'base_event.dart';
import 'package:imboy/store/model/conversation_model.dart';

/// UI 更新相关事件
///
/// 定义了会话更新、未读数变化、联系人变化等 UI 层需要响应的事件类型

/// 会话更新事件
///
/// 当会话信息发生变化时触发（如最后消息更新、未读数变化等）
final class ConversationUpdatedEvent extends AppEvent {
  @override
  List<Object> get props => [conversation, updateType, isNewConversation];

  /// 更新后的会话模型
  final ConversationModel conversation;

  /// 会话 UK3
  String get conversationUk3 => conversation.uk3;

  /// 会话 ID
  int get conversationId => conversation.id;

  /// 更新类型
  final ConversationUpdateType updateType;

  /// 更新的字段列表
  final List<String>? updatedFields;

  /// 是否为新会话（之前不存在）
  final bool isNewConversation;

  const ConversationUpdatedEvent({
    required this.conversation,
    required this.updateType,
    this.updatedFields,
    this.isNewConversation = false,
  });

  @override
  String toString() {
    return 'ConversationUpdatedEvent(conversationId: $conversationId, conversationUk3: $conversationUk3, updateType: $updateType, updatedFields: $updatedFields, isNew: $isNewConversation)';
  }
}

/// 会话更新类型枚举
enum ConversationUpdateType {
  /// 新增会话
  inserted,

  /// 更新会话
  updated,

  /// 删除会话
  deleted,

  /// 会话置顶
  pinned,

  /// 会话取消置顶
  unpinned,

  /// 会话免打扰
  muted,

  /// 会话取消免打扰
  unmuted,

  /// 标记全部已读
  markAllRead,

  /// 清空聊天记录
  clearHistory,
}

/// 未读数变化事件
///
/// 当会话未读数或全局未读数发生变化时触发
final class UnreadCountChangedEvent extends AppEvent {
  @override
  List<Object> get props => [oldCount, newCount];

  /// 会话 UK3（如果为空则表示全局未读数变化）
  final String? conversationUk3;

  /// 会话 ID（如果为空则表示全局未读数变化）
  final int? conversationId;

  /// 旧的未读数
  final int oldCount;

  /// 新的未读数
  final int newCount;

  /// 未读数变化量
  int get delta => newCount - oldCount;

  /// 是否为增加
  bool get isIncreased => delta > 0;

  /// 是否为减少
  bool get isDecreased => delta < 0;

  /// 会话类型（C2C, C2G 等）
  final String? conversationType;

  const UnreadCountChangedEvent({
    this.conversationUk3,
    this.conversationId,
    required this.oldCount,
    required this.newCount,
    this.conversationType,
  });

  @override
  String toString() {
    return 'UnreadCountChangedEvent(conversationUk3: $conversationUk3, conversationId: $conversationId, oldCount: $oldCount, newCount: $newCount, delta: $delta, conversationType: $conversationType)';
  }
}

/// 全局未读数变化事件
///
/// 当应用的全局未读数（所有会话的未读数总和）发生变化时触发
final class GlobalUnreadCountChangedEvent extends AppEvent {
  @override
  List<Object> get props => [oldCount, newCount, breakdown];

  /// 旧的全局未读数
  final int oldCount;

  /// 新的全局未读数
  final int newCount;

  /// 未读数变化量
  int get delta => newCount - oldCount;

  /// 是否为零（所有消息已读）
  bool get isZero => newCount == 0;

  /// 各类型会话的未读数明细
  final Map<String, int> breakdown;

  const GlobalUnreadCountChangedEvent({
    required this.oldCount,
    required this.newCount,
    required this.breakdown,
  });

  @override
  String toString() {
    return 'GlobalUnreadCountChangedEvent(oldCount: $oldCount, newCount: $newCount, delta: $delta, breakdown: $breakdown)';
  }
}

/// 会话列表刷新事件
///
/// 当需要刷新会话列表时触发
final class ConversationListRefreshEvent extends AppEvent {
  @override
  List<Object> get props => [reason, forceRefresh];

  /// 刷新原因
  final ConversationListRefreshReason reason;

  /// 是否需要强制刷新（忽略缓存）
  final bool forceRefresh;

  /// 需要高亮显示的会话 UK3（可选）
  final String? highlightConversationUk3;

  /// 刷新源（标识是谁发起的刷新请求）
  final String? source;

  const ConversationListRefreshEvent({
    required this.reason,
    this.forceRefresh = false,
    this.highlightConversationUk3,
    this.source,
  });

  @override
  String toString() {
    return 'ConversationListRefreshEvent(reason: $reason, forceRefresh: $forceRefresh, highlight: $highlightConversationUk3, source: $source)';
  }
}

/// 会话列表刷新原因枚举
enum ConversationListRefreshReason {
  /// 收到新消息
  newMessage,

  /// 会话已读
  messageRead,

  /// 会话删除
  conversationDeleted,

  /// 会话置顶状态变化
  pinChanged,

  /// 用户登录
  userLogin,

  /// 网络重连
  networkReconnect,

  /// 用户手动下拉刷新
  manualRefresh,

  /// 其他原因
  other,
}

/// 联系人更新事件
///
/// 当联系人信息发生变化时触发
final class ContactUpdatedEvent extends AppEvent {
  @override
  List<Object> get props => [userId, updateType];

  /// 联系人用户 ID
  final String userId;

  /// 更新类型
  final ContactUpdateType updateType;

  /// 更新的字段列表
  final List<String>? updatedFields;

  /// 备注（如果有更新）
  final String? remark;

  /// 分组（如果有更新）
  final String? group;

  const ContactUpdatedEvent({
    required this.userId,
    required this.updateType,
    this.updatedFields,
    this.remark,
    this.group,
  });

  @override
  String toString() {
    return 'ContactUpdatedEvent(userId: $userId, updateType: $updateType, updatedFields: $updatedFields, remark: $remark, group: $group)';
  }
}

/// 联系人更新类型枚举
enum ContactUpdateType {
  /// 新增联系人
  added,

  /// 更新联系人信息
  updated,

  /// 删除联系人
  deleted,

  /// 备注更新
  remarkUpdated,

  /// 分组更新
  groupUpdated,

  /// 拉黑
  blocked,

  /// 取消拉黑
  unblocked,
}

/// 群组更新事件
///
/// 当群组信息发生变化时触发
final class GroupUpdatedEvent extends AppEvent {
  @override
  List<Object> get props => [groupId, updateType];

  /// 群组 ID
  final String groupId;

  /// 更新类型
  final GroupUpdateType updateType;

  /// 更新的字段列表
  final List<String>? updatedFields;

  /// 操作者用户 ID（如果适用）
  final String? operatorId;

  const GroupUpdatedEvent({
    required this.groupId,
    required this.updateType,
    this.updatedFields,
    this.operatorId,
  });

  @override
  String toString() {
    return 'GroupUpdatedEvent(groupId: $groupId, updateType: $updateType, updatedFields: $updatedFields, operatorId: $operatorId)';
  }
}

/// 群组更新类型枚举
enum GroupUpdateType {
  /// 群组信息更新（名称、头像等）
  infoUpdated,

  /// 成员加入
  memberJoined,

  /// 成员离开
  memberLeft,

  /// 群主转让
  ownerTransferred,

  /// 群组解散
  disbanded,

  /// 群组公告更新
  announcementUpdated,

  /// 群组名称更新
  nameUpdated,

  /// 群组头像更新
  avatarUpdated,

  /// 被移出群组
  removed,
}

/// 用户信息更新事件
///
/// 当当前用户信息发生变化时触发
final class UserInfoUpdatedEvent extends AppEvent {
  @override
  List<Object> get props => [updatedFields];

  /// 更新的字段列表
  final List<String> updatedFields;

  /// 旧的用户信息（部分字段）
  final Map<String, dynamic>? oldData;

  /// 新的用户信息（部分字段）
  final Map<String, dynamic>? newData;

  const UserInfoUpdatedEvent({
    required this.updatedFields,
    this.oldData,
    this.newData,
  });

  @override
  String toString() {
    return 'UserInfoUpdatedEvent(updatedFields: $updatedFields)';
  }
}

/// 消息列表滚动事件
///
/// 当用户滚动消息列表时触发（用于加载更多历史消息）
final class MessageListScrollEvent extends AppEvent {
  @override
  List<Object> get props => [conversationUk3, direction, needsLoadMore];

  /// 会话 UK3
  final String conversationUk3;

  /// 滚动方向
  final ScrollDirection direction;

  /// 当前第一条可见消息的 autoId
  final int? firstVisibleMessageAutoId;

  /// 当前最后一条可见消息的 autoId
  final int? lastVisibleMessageAutoId;

  /// 是否需要加载更多消息
  final bool needsLoadMore;

  const MessageListScrollEvent({
    required this.conversationUk3,
    required this.direction,
    this.firstVisibleMessageAutoId,
    this.lastVisibleMessageAutoId,
    this.needsLoadMore = false,
  });

  @override
  String toString() {
    return 'MessageListScrollEvent(conversationUk3: $conversationUk3, direction: $direction, firstVisible: $firstVisibleMessageAutoId, lastVisible: $lastVisibleMessageAutoId, needsLoadMore: $needsLoadMore)';
  }
}

/// 滚动方向枚举
enum ScrollDirection {
  /// 向上滚动（加载更早的消息）
  up,

  /// 向下滚动（加载更晚的消息）
  down,
}

/// 聊天界面状态变化事件
///
/// 当聊天界面状态发生变化时触发
final class ChatViewStateChangeEvent extends AppEvent {
  @override
  List<Object> get props => [conversationUk3, newState];

  /// 会话 UK3
  final String conversationUk3;

  /// 新状态
  final ChatViewState newState;

  /// 旧状态
  final ChatViewState? oldState;

  const ChatViewStateChangeEvent({
    required this.conversationUk3,
    required this.newState,
    this.oldState,
  });

  @override
  String toString() {
    return 'ChatViewStateChangeEvent(conversationUk3: $conversationUk3, oldState: $oldState, newState: $newState)';
  }
}

/// 聊天界面状态枚举
enum ChatViewState {
  /// 界面创建
  created,

  /// 界面显示
  visible,

  /// 界面隐藏
  hidden,

  /// 界面销毁
  destroyed,

  /// 开始输入
  inputStarted,

  /// 停止输入
  inputStopped,

  /// 开始录音
  recordingStarted,

  /// 停止录音
  recordingStopped,
}

/// 通知事件
///
/// 当需要显示系统通知时触发
final class NotificationEvent extends AppEvent {
  @override
  List<Object> get props => [type, title, content];

  /// 通知类型
  final NotificationType type;

  /// 通知标题
  final String title;

  /// 通知内容
  final String content;

  /// 会话 UK3（如果与会话相关）
  final String? conversationUk3;

  /// 发送者用户 ID（如果是消息通知）
  final String? senderId;

  /// 发送者昵称
  final String? senderNickname;

  /// 发送者头像
  final String? senderAvatar;

  /// 附加数据（点击通知时携带的数据）
  final Map<String, dynamic>? payload;

  const NotificationEvent({
    required this.type,
    required this.title,
    required this.content,
    this.conversationUk3,
    this.senderId,
    this.senderNickname,
    this.senderAvatar,
    this.payload,
  });

  @override
  String toString() {
    return 'NotificationEvent(type: $type, title: $title, content: $content, conversationUk3: $conversationUk3, senderId: $senderId)';
  }
}

/// 通知类型枚举
enum NotificationType {
  /// 新消息通知
  newMessage,

  /// 系统通知
  system,

  /// 好友请求
  friendRequest,

  /// 群组邀请
  groupInvite,

  /// 音视频通话
  call,

  /// 其他通知
  other,
}

/// 主题变更事件
///
/// 当应用主题发生变化时触发
final class ThemeChangedEvent extends AppEvent {
  @override
  List<Object> get props => [themeMode];
  final ThemeMode themeMode;

  /// 是否为暗色主题
  bool get isDarkMode => themeMode == ThemeMode.dark;

  /// 是否跟随系统
  bool get isSystemMode => themeMode == ThemeMode.system;

  const ThemeChangedEvent({required this.themeMode});

  @override
  String toString() {
    return 'ThemeChangedEvent(themeMode: $themeMode, isDarkMode: $isDarkMode, isSystemMode: $isSystemMode)';
  }
}

/// 主题模式枚举
enum ThemeMode {
  /// 亮色主题
  light,

  /// 暗色主题
  dark,

  /// 跟随系统
  system,
}

/// 语言变更事件
///
/// 当应用语言发生变化时触发
final class LanguageChangedEvent extends AppEvent {
  @override
  List<Object> get props => [languageCode, languageName];

  /// 新的语言代码
  final String languageCode;

  /// 语言名称（用于显示）
  final String languageName;

  const LanguageChangedEvent({
    required this.languageCode,
    required this.languageName,
  });

  @override
  String toString() {
    return 'LanguageChangedEvent(languageCode: $languageCode, languageName: $languageName)';
  }
}

/// 数据加载事件
///
/// 当加载数据（如历史消息、联系人列表等）时触发
final class DataLoadingEvent extends AppEvent {
  @override
  List<Object> get props => [loadingType, isLoading];

  /// 加载类型
  final DataLoadingType loadingType;

  /// 是否正在加载
  final bool isLoading;

  /// 加载进度（0.0 - 1.0）
  final double? progress;

  /// 已加载数量
  final int? loadedCount;

  /// 总数量
  final int? totalCount;

  /// 错误消息（如果加载失败）
  final String? errorMessage;

  const DataLoadingEvent({
    required this.loadingType,
    required this.isLoading,
    this.progress,
    this.loadedCount,
    this.totalCount,
    this.errorMessage,
  });

  @override
  String toString() {
    return 'DataLoadingEvent(loadingType: $loadingType, isLoading: $isLoading, progress: $progress, loaded: $loadedCount, total: $totalCount, error: $errorMessage)';
  }
}

/// 数据加载类型枚举
enum DataLoadingType {
  /// 加载历史消息
  historyMessages,

  /// 加载会话列表
  conversationList,

  /// 加载联系人列表
  contactList,

  /// 加载群组成员列表
  groupMembers,

  /// 加载群组列表
  groupList,

  /// 加载用户信息
  userInfo,

  /// 加载媒体文件
  mediaFiles,

  /// 其他加载
  other,
}
