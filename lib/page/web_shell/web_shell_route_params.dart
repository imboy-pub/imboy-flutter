/// Phase 1.1.m — Web Shell 深链参数编解码（纯函数）
///
/// 把 URL query 参数与 [WebShellState] 互转，为 1.1.i 路由整合提供基础设施：
/// - **解码**：浏览器从 `/web_shell?tab=chat&id=xxx&type=C2C` 恢复完整 state
/// - **编码**：state 变化时同步到浏览器 URL（支持后退/收藏/分享链接）
///
/// 设计原则：
/// - **纯函数**：零外部依赖，可独立 TDD
/// - **保守降级**：任何非法/缺失参数 → 安全 fallback（默认 state）
/// - **round-trip 不变性**：`parse(toParams(state)) == state` 对所有合法 state 成立
/// - **TSID 字符串透传**：id 参数原样保存，不做格式校验（业务层负责）
library;

import 'web_shell_state.dart';

/// URL query 参数 key 常量（避免散落字符串字面量）
const String kRouteParamTab = 'tab';
const String kRouteParamId = 'id';
const String kRouteParamType = 'type';

/// Tab 字符串名称 → currentTab 索引的映射
///
/// 顺序对齐 [WebShellState.currentTab] 0..3：
/// 'chat' = 0 / 'contact' = 1 / 'channel' = 2 / 'mine' = 3
const Map<String, int> kRouteTabNameToIndex = {
  'chat': 0,
  'contact': 1,
  'channel': 2,
  'mine': 3,
};

/// 反向映射（编码时用）
const List<String> kRouteTabIndexToName = [
  'chat',
  'contact',
  'channel',
  'mine',
];

/// 从 URL query 参数恢复 [WebShellState]
///
/// 容错策略：
/// - 缺失 tab / 非法 tab name → 返回默认 state（currentTab=0, selectedItem=null）
/// - 有 tab 但缺失 id → 返回 state（仅 currentTab，selectedItem=null）
/// - id 为空字符串 → 视为缺失（不构造 selection）
/// - tab=chat 时 type 缺失 → 默认 'C2C'
WebShellState parseShellRouteParams(Map<String, String> params) {
  final tabName = params[kRouteParamTab];
  final tabIndex = kRouteTabNameToIndex[tabName];
  if (tabIndex == null) {
    // 缺失或非法 tab → 完全降级到默认 state
    return const WebShellState();
  }

  final id = params[kRouteParamId];
  if (id == null || id.isEmpty) {
    // 有 tab 但无 id → 只恢复 tab
    return WebShellState(currentTab: tabIndex);
  }

  // 根据 tab 类型构造对应 selection
  final WebSelection selection = switch (tabIndex) {
    0 => ChatSelection(
      peerId: id,
      chatType: params[kRouteParamType] ?? 'C2C',
    ),
    1 => ContactSelection(uid: id),
    2 => ChannelSelection(channelId: id),
    3 => MineSelection(section: id),
    _ => throw StateError('unreachable: tabIndex $tabIndex'),
  };

  return WebShellState(
    currentTab: tabIndex,
    selectedItem: selection,
  );
}

/// 把 [WebShellState] 编码为 URL query 参数
///
/// 编码策略：
/// - tab 始终输出（即使 currentTab=0）
/// - selectedItem=null → 仅输出 tab
/// - ChatSelection → 输出 id (peerId) + type (chatType)
/// - ContactSelection / ChannelSelection → 输出 id
/// - MineSelection(section=null) → 仅输出 tab
/// - MineSelection(section!=null) → 输出 id (section)
Map<String, String> shellStateToRouteParams(WebShellState state) {
  // 安全守卫：currentTab 越界（理论不可达，状态机已守卫）
  if (state.currentTab < 0 || state.currentTab >= kRouteTabIndexToName.length) {
    return const {};
  }

  final params = <String, String>{
    kRouteParamTab: kRouteTabIndexToName[state.currentTab],
  };

  switch (state.selectedItem) {
    case null:
      // 无选中项，只输出 tab
      break;
    case ChatSelection(:final peerId, :final chatType):
      params[kRouteParamId] = peerId;
      params[kRouteParamType] = chatType;
    case ContactSelection(:final uid):
      params[kRouteParamId] = uid;
    case ChannelSelection(:final channelId):
      params[kRouteParamId] = channelId;
    case MineSelection(:final section):
      if (section != null && section.isNotEmpty) {
        params[kRouteParamId] = section;
      }
  }

  return params;
}
