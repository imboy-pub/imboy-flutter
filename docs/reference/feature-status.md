# imboyapp 功能状态清单 / Feature Status Checklist

> 最后更新 / Last updated：2026-06-05
> 范围 / Scope：Flutter 客户端（iOS / Android / macOS）功能开关与实现状态
> 相关文件 / See also：`lib/app_core/feature_flags/app_feature_registry.dart`、`lib/app_core/feature_flags/feature_keys.dart`

---

## 功能开关机制说明 / Feature Flag Mechanism

功能可见性由两层控制：

| 层级 | 机制 | 优先级 |
|------|------|--------|
| 本地硬关闭 | `AppFeatureRegistry._localDisabledKeys`（编译期常量集合） | 最高，覆盖后端 |
| 远程开关 | 后端 `/v1/app/features` 返回的 snapshot，无数据时默认 **true** | 次之 |

**解除本地硬关闭**：从 `_localDisabledKeys` 集合中删除对应 `FeatureKeys.*` 常量即可；功能代码保留，无需恢复。

Feature visibility is controlled by two layers. Local hard-disable overrides the remote snapshot. To re-enable a locally-disabled feature, remove its key from `_localDisabledKeys`; the implementation code is always present.

---

## 功能清单 / Feature Checklist

图例 / Legend：✅ 完整 · ⚠️ 部分实现 · ❌ 未实现 · 🔒 本地硬关闭 · 🟢 默认开 · 🔴 默认关

### 核心通讯 / Core Messaging

| 功能 | 前端 | 后端 API | Feature Flag | UI 入口 | 备注 |
|------|------|---------|-------------|--------|------|
| C2C 单聊（文字/图片/语音/视频/文件/位置） | ✅ | ✅ | 无开关，常驻 | 会话列表 → 进入聊天 | — |
| C2G 群聊（@提醒 / 禁言 / 已读统计） | ✅ | ✅ | 无开关，常驻 | 联系人 → 群组 | — |
| 消息撤回 / 编辑 / 引用回复 | ✅ | ✅ | 无开关，常驻 | 聊天页长按菜单 | — |
| 阅后即焚 | ✅ | ✅ | 无开关，常驻 | 聊天设置 | — |
| E2EE 端对端加密 | ✅ | ✅ | `E2EESettings`（独立于 AppFeatureRegistry） | 聊天设置 → 加密 | RSA-OAEP-256 + AES-256-GCM |
| 音视频通话（WebRTC） | ✅ | ✅ | 无开关，常驻 | 聊天页右上角 | 信令由后端转发 |
| 消息 ACK / 重试 / 离线拉取 | ✅ | ✅ | 无开关，常驻 | 不可见（后台） | 4 步重试 + 跨节点 syn |

### 社交关系 / Social Graph

| 功能 | 前端 | 后端 API | Feature Flag | UI 入口 | 备注 |
|------|------|---------|-------------|--------|------|
| 好友管理（添加/删除/备注） | ✅ | ✅ | 无开关，常驻 | 联系人列表 | — |
| 好友分类标签 `friendTag` | ✅ | ✅ | 🟢 默认开（已移出硬关） | 联系人 → 标签 | — |
| 附近人 `location` | ✅ | ✅ | 🟢 默认开 | 联系人列表顶部（条件显示） | 集成高德地图 |
| 黑名单 | ✅ | ✅ | 无开关，常驻 | 我的 → 黑名单 | — |

### 朋友圈 / Moments

| 功能 | 前端 | 后端 API | Feature Flag | UI 入口 | 备注 |
|------|------|---------|-------------|--------|------|
| 朋友圈动态流 `moment` | ✅ | ✅ | 🟢 默认开 | 联系人列表首位 | 路由守卫保护 |
| 发布动态（文字/图片） | ✅ | ✅ | 依赖 `moment` | 朋友圈页右上角 | — |
| 可见范围（好友选择器） | ✅ | ✅ | 依赖 `moment` | 发布页 | — |
| 点赞 / 评论 | ✅ | ✅ | 依赖 `moment` | 动态卡片 | — |
| 朋友圈通知中心 | ✅ | ✅ | 依赖 `moment` | 底部导航红点 | — |

### 频道 / Channel

| 功能 | 前端 | 后端 API | Feature Flag | UI 入口 | 备注 |
|------|------|---------|-------------|--------|------|
| 频道列表 `channel` | ✅ | ✅ | 🟢 默认开 | 底部导航 Tab | 父开关，控制所有子功能 |
| 频道发现 `channelDiscover` | ✅ | ✅ | 🟢 默认开（依赖 channel） | 频道列表页搜索按钮 | — |
| 频道邀请 `channelInvitation` | ✅ | ✅ | 🟢 默认开（依赖 channel） | 频道列表页邀请按钮 | — |
| 频道订阅管理 `channelOrder` | ✅ | ✅ | 🟢 默认开（依赖 channel） | 频道详情页 | — |
| 创建/编辑/管理频道 | ✅ | ✅ | 依赖 `channel` | 频道列表页 + 按钮 | — |
| 已订阅频道条（会话列表顶部） | ✅ | ✅ | 依赖 `channel` | 会话列表顶部 | — |

### 群组协作 / Group Collaboration

| 功能 | 前端 | 后端 API | Feature Flag | UI 入口 | 备注 |
|------|------|---------|-------------|--------|------|
| 群投票 `groupVote` | ✅ | ✅ | 🟢 默认开 | 群详情页 → 投票 | 路由守卫保护 |
| 群日程 `groupSchedule` | ✅ | ✅ | 🟢 默认开 | 群详情页 → 日程 | 日历视图 |
| 群任务 `groupTask` | ✅ | ✅ | 🟢 默认开 | 群详情页 → 任务 | 含任务分配和审核 |
| 群相册 | ✅ | ✅ | 无开关，常驻 | 群详情页 → 相册 | — |
| 群文件 | ✅ | ✅ | 无开关，常驻 | 群详情页 → 文件 | — |
| 群公告 | ✅ | ✅ | 无开关，常驻 | 群详情页 → 公告 | — |

### 安全与隐私 / Security & Privacy

| 功能 | 前端 | 后端 API | Feature Flag | UI 入口 | 备注 |
|------|------|---------|-------------|--------|------|
| E2EE 密钥管理 | ✅ | ✅ | `E2EESettings`（独立系统） | 设置 → 加密 | — |
| E2EE 备份导出/导入 | ✅ | ✅ | 同上 | 设置 → 加密备份 | — |
| 设备管理 | ✅ | ✅ | 无开关，常驻 | 我的 → 设备 | — |

### 待后端支持（前端隐藏） / Pending Backend — Hidden

以下功能前端代码已完成，但**后端 API 尚未实现**，通过本地硬关闭隐藏。

> **解除条件**：后端对应接口上线并验收通过后，删除 `app_feature_registry.dart` 中 `_localDisabledKeys` 里的对应 key。

The following features have complete frontend implementations but **backend APIs are not yet available**. They are hidden via local hard-disable.

> **To re-enable**: once the backend API is live and verified, remove the corresponding key from `_localDisabledKeys` in `app_feature_registry.dart`.

| 功能 | 前端 | 后端 API | Feature Flag | 前端入口（隐藏中） | 解除所需后端接口 |
|------|------|---------|-------------|---------|--------------|
| **钱包 `wallet`** | ✅ 完整（472 行，含充值/流水/分页） | ❌ 未实现 | 🔒 `_localDisabledKeys` | 我的页面宫格「钱包」按钮 | `GET /v1/wallet/balance`<br>`GET /v1/wallet/transactions`<br>`POST /v1/wallet/topup` |
| **直播间 `liveRoom`** | ✅ 完整（推流/订阅/列表，WHIP 协议） | ⚠️ 元数据 API ✅ 已实现（handler/logic/ds/repo/router/迁移齐全）；缺 WHIP/WHEP 媒体服务器 | 🔒 `_localDisabledKeys` | 无主入口（需新增） | WHIP/WHEP 媒体服务器（部署件，非应用代码）+ 前端入口 + 移出 `_localDisabledKeys` |

---

## 变更记录 / Change Log

| 日期 | 变更 | 原因 |
|------|------|------|
| 2026-04-17 | `wallet`、`liveRoom` 加入 `_localDisabledKeys` | W1.5 稳定化 Sprint — 避免不完善功能暴露给 App Store 审核 |
| 2026-04-17 | `friendTag`、`moment interactions` 移出 `_localDisabledKeys` | 用户决定继续完善，不隐藏 |
| 2026-06-05 | 创建本文档，整理功能矩阵 | — |
