# imboyapp 真机 QA 进度台账 / Real-Device QA Progress Ledger

> 设备：Android MRD AL00（adb `XWE6R19916004085`），包名 `imboy.chat`，账号"小鱼儿2🐠"（pro 后端）。
> 每轮只推进一个模块；测完更新状态并附一行结果。权威编目见 `full-app-test-checklist.md` §4。
>
> 状态：TODO / DOING / DONE

| # | 模块 | 状态 | 结果（功能点/bug/已修） |
|---|------|------|----------------------|
| 1 | 朋友圈 moment（流/详情/发布/可见性/通知） | DONE | 6 功能点验证，0 新 bug，红框修复(eb71ea2c)真机复验通过；1 存疑(单条图 URL 失效) |
| 2 | 联系人 contact 全套（列表/加好友/资料/附近/设置） | TODO | |
| 3 | 我的/设置 mine（21 项设置） | TODO | |
| 4 | 群协作 group（列表/成员/文件/相册/投票/日程/任务） | TODO | |
| 5 | 频道 channel（列表/发现/详情/管理/订单/退款/付费墙） | TODO | |
| 6 | 个人资料 personal_info（字段编辑/隐私 5 开关） | TODO | |
| 7 | 用户标签 user_tag（列表/详情/选好友/新建/关系） | TODO | |
| 8 | 钱包 wallet（5 页） | TODO | |
| 9 | 二维码/扫码/搜索 qrcode/scanner/search | TODO | |
| 10 | 聊天设置/通话 chat_setting/call | TODO | |
| 11 | E2EE 页（11 页） | TODO | |

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

### 轮 1b — 2026-07-11 — 🔴 用户报告：朋友圈拍照上传失败（已定位根因）
- **真机复现**：拍照→预览确认→toast「媒体上传失败」。
- **根因**：后端读写 endpoint 不对称——presign PUT 用 `IMBOY_GARAGE_ENDPOINT=http://garage:3900`（docker 内网），客户端 put_url 不可达+签名 host 绑死内网。详见 checklist P0 发现区。
- **处置**：涉及生产配置+对外，停下问人。用户拍板「仅改生产 env→https://s3.imboy.pub，由用户亲自执行」。我不碰生产配置，仅存档诊断+给操作指引。0 代码改动。
- **待办**：①用户改生产 env+确认 nginx 放行 PUT/HEAD/DELETE；②客户端 `_uploadFile` 静默吞异常可诊断性缺陷待后续修。

