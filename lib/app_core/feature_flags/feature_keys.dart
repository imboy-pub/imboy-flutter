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
  // 项目协作面（计划 §5.3）：导航入口与直达 route 受同一 feature 配置保护。
  // 广州演示构建从 Git 外把该键置为未选中，客户端即整体不可发现。
  static const project = 'project';

  // E2EE 总开关（服务端在 storage_mode=disabled 硬闸下强制下发 false）：
  // 关闭时隐藏 E2EE 相关入口（刷新设备密钥/密钥管理/合规审计密钥）。
  // 注意判定顺序——加密行为由 EncryptionModeService 决定，本键只管 UI 可见性。
  static const e2ee = 'e2ee';

  // W1.5 稳定化 Sprint 隐藏入口（2026-04-17）：
  // 本地硬关闭，避免不完善功能暴露给 App Store 审核 + 早期用户。
  // 代码保留，待 v2 决策（见 .claude/plans/stabilization-sprint-2026Q2.md 第六节）。
  static const wallet = 'wallet';
  static const liveRoom = 'live_room';
  // friendTag removed — zero references confirmed (Task B3)
}
