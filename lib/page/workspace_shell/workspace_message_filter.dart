/// 企业壳「消息」页的内容态与筛选态（2026-10 飞书风格改版）。
///
/// 内容态（消息页顶部 tab）：消息 / 日程 / 待办。
/// 日程·待办聚合当前工作区内企业群的群日程与群作业
/// （见 workspace_group_agenda_views）；会议/邮件/文档 imboy 没有，不做。
enum WorkspaceMessageTab { message, schedule, todo }

/// 消息内容态下的筛选（第一个 tab 的下拉菜单，参考稿 9 项）。
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
