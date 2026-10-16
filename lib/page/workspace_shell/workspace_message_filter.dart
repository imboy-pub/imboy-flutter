/// 企业壳「消息」页的内容态与筛选态（2026-10 飞书风格改版）。
///
/// 内容态（消息页顶部 tab）：消息 / 日程 / 待办。
/// 日程·待办聚合当前工作区内企业群的群日程与群作业
/// （见 workspace_group_agenda_views）；会议/邮件/文档 imboy 没有，不做。
enum WorkspaceMessageTab { message, schedule, todo }

/// 消息内容态下的筛选（第一个 tab 的下拉菜单）。
///
/// 数据面对照（当前 workspace 会话快照只有群维度行）：
/// - all / unread / group / channel：本地可算，真实生效；
/// - mentions / dm / internal / external / flagged：快照无对应字段，
///   选中后按「无匹配会话」空态展示，待服务端补字段后逐项点亮。
enum WorkspaceMessageFilter {
  all,
  unread,
  mentions,
  dm,
  group,
  channel,
  internal,
  external,
  flagged;

  bool get appliesToConversations => this != channel;
}

/// 筛选下拉当前真实可用的档位：全部/未读/群聊/频道。
///
/// mentions / dm / internal / external / flagged 选中只会落空态（快照无
/// 字段支撑），属「功能开发中」——广州第一期交付前不展示入口。
// TODO 广州第一期交付后实现：服务端补齐 mention/单聊/内外部/标记字段后，
// 把对应枚举值追加回本列表，并点亮
// workspace_conversations_page 的 `_visibleRows` 对应分支。
const List<WorkspaceMessageFilter> kVisibleWorkspaceMessageFilters = [
  WorkspaceMessageFilter.all,
  WorkspaceMessageFilter.unread,
  WorkspaceMessageFilter.group,
  WorkspaceMessageFilter.channel,
];
