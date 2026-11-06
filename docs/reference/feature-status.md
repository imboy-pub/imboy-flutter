# imboyapp 功能状态清单 / Feature Status Checklist

> 最后更新 / Last updated：2026-11-06
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
| ③ 远程开关 | 后端 `/v1/app/features` snapshot，无数据默认 **false**（`core` 例外），子功能随父级联动 | 最低 |

**开发态与交付态**：仓内生成文件以当前 manifest 为准；一期交付使用 `phase1_delivery` profile 重新生成。第一期包含 Core IM、企业、客服、频道基础、朋友圈、附近的人，以及群投票、群日程、群作业。本次默认与一期候选组合增选一对一音视频 `rtc`，其余二期和三期功能仍按交付白名单关闭。生成物中的功能键与服务端 profile 必须一致，不能仅凭入口可见认定能力已验收。

**本次音视频范围 A**：仅两个已登录 imboyapp 用户的一对一语音/视频，保留服务端好友与黑名单规则。聊天入口限 `C2C`；联系人页仍要求好友且非本人。公共呼出、来电展示和接听会再次检查当前 `rtc` 开关，关闭期间不启动新通话；等待来电若在接听或异步检查时发现开关已关闭，则按既有拒接流程收尾。群通话需另外编译选入并开启 `rtc_group`，且父功能 `rtc` 同时开启；本次组合不选 `rtc_group`。访客、Web 坐席音视频和群通话不随本次开放。

**解除本地硬关闭**：从 `_localDisabledKeys` 删除对应 `FeatureKeys.*` 常量即可，功能代码保留。

Feature visibility is controlled by the compiled product profile, local hard-disable rules and the remote snapshot. Phase 1 includes moments, nearby people and group collaboration; delivery artifacts must be regenerated from the matching profile.

The current default and phase-1 candidates add `rtc` for one-to-one calls between signed-in app users. Existing friendship and blocklist checks remain authoritative. Group calls require an independently selected `rtc_group` feature and its `rtc` parent; this delivery does not select `rtc_group` or add visitor/Web-seat calling. Entry visibility and local tests do not establish real-device media acceptance.

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

### 一期受控面 / Delivery-profile Controlled

| 功能 | 前端 | 后端 API | 开关 | 备注 |
|------|------|---------|------|------|
| 频道基础 `channel` | ✅ | ✅ | 📦 🟢 | 父开关，一期交付面内含 |
| 企业业务域 `enterprise_business` | ✅ | ✅ | 📦 🟢 | 组织/RBAC/工作空间 |
| 客服域 `customer_service` | ✅ | ✅ | 📦 🟢 | 坐席/排队/转接 |
| 朋友圈 `moment` | ✅ | ✅ | 📦 🟢 | 动态流/发布/点赞/评论/通知中心 |
| 附近的人 `location` | ✅ | ✅ | 📦 🟢 | 定位权限与可见性受用户设置控制 |
| 群投票/日程/作业 `group_vote/group_schedule/group_task` | ✅ | ✅ | 📦 🟢 | 创建后发布群消息卡片，点击进入详情 |
| 一对一音视频 `rtc` | 现有通话与 LiveKit SFU 实现 | 既有签票和好友/黑名单校验 | 编译面与运行开关共同控制 | 聊天、联系人语音/视频四入口；真实双端媒体验收仍须执行 |

### 开发态可用 / Development-only（一期交付不生成入口）

以下功能不属于一期交付白名单；开发态是否可用以实际配置和实现为准。交付时必须同时限制生成路由、客户端入口与服务端调用。

| 功能 | 前端 | 后端 API | 开关（开发态） | 备注 |
|------|------|---------|--------------|------|
| 频道发现/邀请/订阅 `channelDiscover/Invitation/Order` | ✅ | ✅ | 🟢 依赖 `channel` | 一期交付仅保留 channel 基础 |
| 项目协作 `project` | ✅ | ✅ | 🟢 默认开 | — |
| Bot Webhook `bot_webhook` | ✅ | ✅ | 🟢 默认开 | 二期 Bot 域保留源码 |
| E2EE 端对端加密 `e2ee` | ✅ | ✅ | 🟢 开发态开；**phase1_delivery 关闭** | RSA-OAEP-256 + AES-256-GCM；UI 入口挂 `FeatureKeys.e2ee`（chat_setting_page / contact_setting_page / group_member_detail_page）；一期 OFF 不影响 TLS/企业托管加密/归档/历史/权限 |

### 关闭区 / Disabled

| 功能 | 前端 | 后端 | 关闭机制 | 现状与解除条件 |
|------|------|------|---------|--------------|
| 直播间 `liveRoom` | ✅ 完整（WHIP 推流） | 元数据 API 已实现；缺 WHIP/WHEP 媒体服务器 | 🔒 `_localDisabledKeys` + 编译面不含（双重） | 2026-09-10 产品决策：暂不做。需产品重新批准 + 移出硬关 + 入 manifest |
| 钱包 `wallet` | ✅ 完整（充值/流水/分页） | ✅ 已实现并通过测试（沙箱充值闭环；真实支付 SDK 待接入） | 编译面不含（manifest full-selected 未选 `wallet`） | 已移出 `_localDisabledKeys`，但加入 manifest 前 isEnabled 恒 false；真实支付 SDK（fluwx/tobias/stripe）接入后方可面向用户 |
| 群音视频通话 `rtc_group` | 保留既有实现 | `kind=group` 需要 `rtc` 与 `rtc_group` 双门 | 本次编译组合不含 `rtc_group`；一期交付锁保持关闭 | 群入口及调用前都复核子功能；服务端使用既有 5190 功能关闭响应。需另行选择产品能力与多端验收，不随一对一开放 |

---
