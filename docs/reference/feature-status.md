# imboyapp 功能状态清单 / Feature Status Checklist

> 最后更新 / Last updated：2026-10-07
> 范围 / Scope：Flutter 客户端（iOS / Android / macOS）功能开关与实现状态
> 真源 / Source of truth：
> - 编译期产品面：`lib/app_core/feature_flags/generated_product_features.dart`（**生成物勿手改**，生成器 `imboy/scripts/generate_product_features.py`）
> - 产品清单 manifest：`imboy/config/product-feature-manifest.json`
> - 一期交付面契约：`imboy/docs/product/packaging-contract.md` §9 phase1_delivery
> - 功能注册表：`lib/app_core/feature_flags/app_feature_registry.dart`、`feature_keys.dart`

---

## 功能开关机制说明 / Feature Flag Mechanism

功能可见性由**三层**控制（自上而下短路判定）：

| 层级 | 机制 | 优先级 |
|------|------|--------|
| ① 编译期产品面 | `compiledProductFeatures`（生成文件，不含即恒 false） | 最高 |
| ② 本地硬关闭 | `AppFeatureRegistry._localDisabledKeys`（编译期常量集合） | 次之，覆盖后端 |
| ③ 远程开关 | 后端 `/v1/app/features` snapshot，无数据默认 **true**，子功能随父级联动 | 最低 |

**开发态 vs 交付态（重要）**：仓内 checked-in 的生成文件按 manifest `full-selected` profile 产出（开发态，编译面 15 键：core 基座 + 14 selected）；**一期交付**时以 `phase1_delivery` profile manifest 重新生成——编译面收敛为 `core / channel / customer_service / enterprise_business` 四键，moment、channel_discover/invitation/order、group_vote/schedule/task、location、bot_webhook、e2ee、project 的路由不生成、入口为 0（AC05 dry-render 实测记录，见 RUN_ROOT control/acceptance.tsv）。

**解除本地硬关闭**：从 `_localDisabledKeys` 删除对应 `FeatureKeys.*` 常量即可，功能代码保留。

Feature visibility is controlled by three layers: compiled product face (generated) → local hard-disable → remote snapshot. The checked-in artifact reflects the **full-selected development profile**; phase1 delivery regenerates it with the `phase1_delivery` profile, shrinking the compiled face to four keys with all secondary-domain routes not generated.

---

## 功能清单 / Feature Checklist

图例 / Legend：✅ 完整 · ⚠️ 部分实现 · 🔒 关闭 · 🟢 开发态默认开 · 📦 一期交付面内

### 一期常驻核心 / Core IM（phase1_delivery，无开关）

| 功能 | 前端 | 后端 API | 开关 | UI 入口 | 备注 |
|------|------|---------|------|--------|------|
| C2C 单聊（文字/图片/语音/视频/文件/位置） | ✅ | ✅ | 无，常驻 | 会话列表 → 聊天 | 附件经 Garage S3 直传 |
| C2G 群聊（@提醒 / 禁言 / 已读游标） | ✅ | ✅ | 无，常驻 | 联系人 → 群组 | 已读游标 GREATEST 单调 |
| 消息撤回 / 编辑 / 引用回复 / 阅后即焚 | ✅ | ✅ | 无，常驻 | 聊天页长按菜单 | — |
| 消息 ACK / 重试 / 离线拉取 | ✅ | ✅ | 无，常驻 | 不可见（后台） | 4 步重试 + 跨节点 syn |
| 好友管理 / 分类标签 / 黑名单 | ✅ | ✅ | 无，常驻 | 联系人 / 我的 | — |
| 企业组织 / RBAC / 工作空间 | ✅ | ✅ | 📦 `enterprise_business` | 工作空间切换 | 一期交付面内 |
| 人工客服（坐席工作台） | ✅ | ✅ | 📦 `customer_service` | 客服入口 | 一期交付面内 |
| OA 对接 / 推送通知 | ✅ | ✅ | 无，常驻 | 不可见（后台） | JPush 出口受 DND 规则 |
| 设备管理 | ✅ | ✅ | 无，常驻 | 我的 → 设备 | — |

### 一期受控面 / Delivery-profile Controlled（📦 四键）

| 功能 | 前端 | 后端 API | 开关 | 备注 |
|------|------|---------|------|------|
| 频道基础 `channel` | ✅ | ✅ | 📦 🟢 | 父开关，一期交付面内含 |
| 企业业务域 `enterprise_business` | ✅ | ✅ | 📦 🟢 | 组织/RBAC/工作空间 |
| 客服域 `customer_service` | ✅ | ✅ | 📦 🟢 | 坐席/排队/转接 |

### 开发态可用 / Development-only（一期交付不生成入口）

以下功能开发态（full-selected）默认开、代码完整；**phase1_delivery 交付时路由不生成、入口为 0**，服务端一期 profile 同步关闭（AC02 实测 5190 拒绝）：

| 功能 | 前端 | 后端 API | 开关（开发态） | 备注 |
|------|------|---------|--------------|------|
| 朋友圈全套 `moment` | ✅ | ✅ | 🟢 默认开 | 动态流/发布/点赞/评论/通知中心 |
| 频道发现/邀请/订阅 `channelDiscover/Invitation/Order` | ✅ | ✅ | 🟢 依赖 `channel` | 一期交付仅保留 channel 基础 |
| 群投票/日程/任务 `groupVote/Schedule/Task` | ✅ | ✅ | 🟢 默认开 | 群协作三件套 |
| 附近人 `location` | ✅ | ✅ | 🟢 默认开 | 高德地图 |
| 项目协作 `project` | ✅ | ✅ | 🟢 默认开 | — |
| Bot Webhook `bot_webhook` | ✅ | ✅ | 🟢 默认开 | 二期 Bot 域保留源码 |
| E2EE 端对端加密 `e2ee` | ✅ | ✅ | 🟢 开发态开；**phase1_delivery 关闭** | RSA-OAEP-256 + AES-256-GCM；UI 入口挂 `FeatureKeys.e2ee`（chat_setting_page / contact_setting_page / group_member_detail_page）；一期 OFF 不影响 TLS/企业托管加密/归档/历史/权限 |

### 关闭区 / Disabled

| 功能 | 前端 | 后端 | 关闭机制 | 现状与解除条件 |
|------|------|------|---------|--------------|
| 直播间 `liveRoom` | ✅ 完整（WHIP 推流） | 元数据 API 已实现；缺 WHIP/WHEP 媒体服务器 | 🔒 `_localDisabledKeys` + 编译面不含（双重） | 2026-09-10 产品决策：暂不做。需产品重新批准 + 移出硬关 + 入 manifest |
| 钱包 `wallet` | ✅ 完整（充值/流水/分页） | ✅ 已实现并通过测试（沙箱充值闭环；真实支付 SDK 待接入） | 编译面不含（manifest full-selected 未选 `wallet`） | 已移出 `_localDisabledKeys`，但加入 manifest 前 isEnabled 恒 false；真实支付 SDK（fluwx/tobias/stripe）接入后方可面向用户 |
| 音视频通话（WebRTC/LiveRoom 群通话） | ✅ | ⚠️ 一期 5190 拒绝 | **不经过 Feature Flag 体系**（无 `FeatureKeys.rtc` 键） | 开发态构建入口存在（聊天页群通话 extra_item）；一期服务端 `rtc/room/join` 返回 5190（AC02 实测），点击透出后端错误提示。一期交付面的入口收敛依赖 phase1 重渲染路由裁剪覆盖核验（Q12 门复核项） |

---

## 变更记录 / Change Log

| 日期 | 变更 | 原因 |
|------|------|------|
| 2026-04-17 | `wallet`、`liveRoom` 加入 `_localDisabledKeys` | W1.5 稳定化 Sprint — App Store 审核 |
| 2026-04-17 | `friendTag`、`moment interactions` 移出 `_localDisabledKeys` | 用户决定继续完善 |
| 2026-06-05 | 创建本文档，整理功能矩阵 | — |
| 2026-10-07 | 全量重写：两层开关机制更正为三层（补编译期产品面）；建立开发态/交付态双口径（full-selected vs phase1_delivery 四键）；钱包条目更正（后端已实现，改为编译面控制）；live_room 更正为产品决策关闭；RTC 条目新增（不走 flag 体系的边界现状） | DOC-Q11 跳过项 #9 清偿——原文件 4 个月未更新且与一期 phase1_delivery 边界冲突（AC02/AC05 验收后口径对齐） |
