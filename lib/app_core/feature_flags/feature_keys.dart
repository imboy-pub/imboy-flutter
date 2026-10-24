class FeatureKeys {
  static const rtc = 'rtc';
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

  // E2EE 收藏 v1 能力键（服务端 manifest features 键空间，PLAN 2026-10-24 §9/A7）：
  // e2ee_collect 只存在于服务端 feature_names/manifest 下发，**不会出现在客户端
  // 编译清单**（compiledProductFeatures 只含组合域键）——客户端能力门必须查
  // e2ee 域键（[FeatureKeys.e2ee]，与服务端 enabled(e2ee_collect) -> enabled(e2ee)
  // 同构）：旧后端/未选 e2ee 域的组合编译清单无 e2ee → isEnabled fail-closed
  // 为 false，新端拒绝创建 sealed 收藏（升级提示，无明文静默回退）。
  static const e2eeCollect = 'e2ee_collect';

  // W1.5 稳定化 Sprint 隐藏入口（2026-04-17）：
  // 本地硬关闭，避免不完善功能暴露给 App Store 审核 + 早期用户。
  // 代码保留，待 v2 决策（见 .claude/plans/stabilization-sprint-2026Q2.md 第六节）。
  static const wallet = 'wallet';
  static const liveRoom = 'live_room';
  // friendTag removed — zero references confirmed (Task B3)
}
