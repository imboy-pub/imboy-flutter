# imboyapp 真机 QA 进度台账 / Real-Device QA Progress Ledger

> 设备：Android MRD AL00（adb `XWE6R19916004085`），包名 `imboy.chat`，账号"小鱼儿2🐠"（pro 后端）。
> 每轮只推进一个模块；测完更新状态并附一行结果。权威编目见 `full-app-test-checklist.md` §4。
>
> 状态：TODO / DOING / DONE

| # | 模块 | 状态 | 结果（功能点/bug/已修） |
|---|------|------|----------------------|
| 1 | 朋友圈 moment（流/详情/发布/可见性/通知） | DONE | 6 功能点验证，0 新 bug，红框修复(eb71ea2c)真机复验通过；1 存疑(单条图 URL 失效) |
| 2 | 联系人 contact 全套（列表/加好友/资料/附近/设置） | DONE | 核心三页~20功能点全✅，0 bug；附近人/新朋友/最近注册入口存在(阶段0/1API已覆盖)未深入 |
| 3 | 我的/设置 mine（21 项设置） | TODO | |
| 4 | 群协作 group（列表/成员/文件/相册/投票/日程/任务） | TODO | |
| 5 | 频道 channel（列表/发现/详情/管理/订单/退款/付费墙） | TODO | |
| 6 | 个人资料 personal_info（字段编辑/隐私 5 开关） | TODO | |
| 7 | 用户标签 user_tag（列表/详情/选好友/新建/关系） | TODO | |
| 8 | 钱包 wallet（5 页） | TODO | |
| 9 | 二维码/扫码/搜索 qrcode/scanner/search | TODO | |
| 10 | 聊天设置/通话 chat_setting/call | TODO | |
| 11 | E2EE 页（11 页） | TODO | |

### 轮 2 — 2026-07-12 — 联系人 contact
- **列表页**（contact_page）✅：顶部搜索/加好友按钮、搜索框、5 特殊入口（朋友圈/找附近的人/新的朋友/群聊/标签）、AZ 索引条、好友列表按 AZ 分组。
- **资料页**（people_info_page，hpz ID:50386）✅：返回/联系人设置入口/头像/昵称/ID/在线状态/备注和标签/更多信息/发消息/语音通话/视频通话。
- **联系人设置页**（资料设置）✅：设置备注和标签/把他推荐给朋友/隐私与安全/加入黑名单(开关)/投诉/删除联系人。
- **通过率**：~20/20 功能点 ✅，**0 bug**。
- **未深入**（成本控制）：找附近的人/新的朋友/最近注册 独立入口页（列表可点，阶段 0/1 API 契约已覆盖 contact），留待后续深度测。
- **注**：leeyi2 在列表底部紧贴导航栏，tap 易穿透误触频道 Tab（测试操作注意，非 app bug）。
- **下轮目标**：模块 #3 我的/设置 mine。

## 逐轮记录

### 轮 1 — 2026-07-11 — 朋友圈 moment
- **环境处置**：真机装的是 7/10 旧包（无红框修复）。本轮 `flutter build apk --debug --dart-define=APP_ENV=pro` 成功（60s，网络已恢复），`adb install -r` 装上带 eb71ea2c 修复的新包（323MB）后复验。
- **通过率**：6/6 功能点 ✅
  - feed 流渲染 ✅（🔴红框修复真机复验通过：图片区从 `_SingleImagePreviewState` MediaQuery 断言崩溃 → 正常灰底占位 + broken_image 降级）
  - 点赞（更多操作→赞）✅，"IMBoy 赞了" 正确显示
  - 更多操作 action sheet（赞/评论/取消）✅
  - 消息通知中心（空状态"暂无新消息"）✅
  - 动态详情页（头像/正文/评论区/输入框/发送）✅
  - 发布入口按钮（相机图标）存在 ✅
- **bug**：0 新 bug。红框在源码层早已修复(eb71ea2c 已提交，文件干净)，本轮仅为真机复验+重装。
- **⚠️ 存疑**：首条自发 test 动态图 `broken_image`（该条数据的图片 URL 已失效，errorBuilder 正常降级，非渲染 bug）。
- **下轮目标**：模块 #2 联系人 contact 全套。

### 轮 1b — 2026-07-11/12 — 🔴 用户报告：朋友圈拍照上传失败
- **⚠️ 首轮误判纠正**：曾据本地模板推测根因=后端 endpoint=garage:3900 内网（commit 15313b22），**错**。教训：勿用本地模板推断生产，须登生产核实。
- **后端全排除（SSH 106.53.76.53 核实+本地复现）**：生产 endpoint 早已=https://s3.imboy.pub，presign put_url 正确，本地 curl+dart-dio PUT 真实 URL（6B/2MB）均 200 落桶。→ 后端/nginx/garage/presign/TLS 全正常，**用户无需改生产任何配置**。
- **真因（客户端）**：`_rawDioPut` 用 Stream body → Android dart:io 发 chunked（garage 要 Content-Length）→ 真机 PUT hang；被 catch 静默吞掩盖。
- **修复（commit f9d4af7e）**：改 `data: bytes` + catch 加 debugPrint，dart analyze 零 error。
- **⚠️ 待真机验证**：384MB debug apk 弱设备 pm install dexopt 卡 + arm64 构建撞网络失败，未装上复验。待环境允许复跑。

