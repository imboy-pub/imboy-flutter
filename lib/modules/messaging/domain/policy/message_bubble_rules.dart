/// 消息气泡显示决策 —— 纯函数（零外部依赖）
///
/// slice-C-7: `chat_page.dart` L1956-1963 内联的两个布尔决策
/// 依赖 isSystemMessage / isLastInGroup / isFirstInGroup / isRemoved，
/// 提取后可独立单测钉死所有分支与边界契约。
library;

/// 判断当前消息是否应显示头像。
///
/// 头像出现条件：
/// 1. 非系统消息（`authorId != 'system'`）
/// 2. 是组内最后一条消息（`isLastInGroup`）
/// 3. 消息未被删除（`isRemoved != true`）
///
/// 任一条件不满足 → 不显示头像。
/// [isRemoved] 为 null 时视为未删除。
bool shouldShowMessageAvatar({
  required bool isSystemMessage,
  required bool isLastInGroup,
  required bool? isRemoved,
}) => !isSystemMessage && isLastInGroup && isRemoved != true;

/// 判断当前消息是否应显示发送者昵称。
///
/// 用户名出现条件：
/// 1. 非系统消息（`authorId != 'system'`）
/// 2. 是组内第一条消息（`isFirstInGroup`）
/// 3. 消息未被删除（`isRemoved != true`）
///
/// 任一条件不满足 → 不显示用户名。
/// [isRemoved] 为 null 时视为未删除。
bool shouldShowMessageUsername({
  required bool isSystemMessage,
  required bool isFirstInGroup,
  required bool? isRemoved,
}) => !isSystemMessage && isFirstInGroup && isRemoved != true;
