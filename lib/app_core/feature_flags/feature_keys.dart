class FeatureKeys {
  static const channel = 'channel';
  static const channelDiscover = 'channel_discover';
  static const channelInvitation = 'channel_invitation';
  static const channelOrder = 'channel_order';
  static const moment = 'moment';
  static const location = 'location';
  static const groupVote = 'group_vote';
  static const groupSchedule = 'group_schedule';
  static const groupTask = 'group_task';

  // W1.5 稳定化 Sprint 隐藏入口（2026-04-17）：
  // 本地硬关闭，避免不完善功能暴露给 App Store 审核 + 早期用户。
  // 代码保留，待 v2 决策（见 .claude/plans/stabilization-sprint-2026Q2.md 第六节）。
  static const wallet = 'wallet';
  static const liveRoom = 'live_room';
  // friendTag removed — zero references confirmed (Task B3)
}
