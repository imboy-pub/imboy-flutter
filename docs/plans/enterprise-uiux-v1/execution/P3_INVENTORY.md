# P3 Inventory — 客服坐席工作台（T03 勘察报告）

勘察基线：integration HEAD `c61cd8d46e276496b2ddae8b89b17d6fe6856ddc`。方法：只读源码；未运行应用/设备。

## 0. 三态视图与数据合同

| 视图 | 符号 | 数据源（不变） |
|---|---|---|
| 待接 | `CsQueueView`（`lib/modules/customer_service/presentation/cs_queue_view.dart:32`）→ `_QueueTile`（L212） | `GET /cs/organizations/:org/seats/sessions/queue`；SSE queue.changed 刷新 |
| 处理中/已关闭 | `CsSessionListView`（`cs_session_list_view.dart:37`）→ `_SessionTile`（L127）；status wire 白名单 active/closed（L32-35） | `GET /cs/organizations/:org/seats/sessions?status=`；SSE session.changed |

行项目 DTO `CsQueueItem`（`infrastructure/cs_api.dart:176-227`）：sessionId/contactId/contactName/waitingSince(毫秒串)/version(CAS)/status/source/hasLastMessage/lastMessagePreview(服务端解密摘要，≤64码点)/organizationId/conversationId/assigneeIdentityId。

## 1. 字段逐项核验

| 字段 | 现状（符号） | 判定 |
|---|---|---|
| 掩码姓名 | 三态同调 `csMaskContactName(item.contactName)`（queue L228 / session L136）；纯函数：空→`**`、单字→`X*`、多字→`X**`（`domain/cs_seat_gate.dart:80-85`）；单测 `cs_seat_gate_test.dart:126-135`。Semantics/tooltip 未见恢复原名的路径 | 已核验（共用） |
| 安全摘要 | 三态共用 `csQueuePreviewText`（cs_queue_view.dart:192-210，session 侧 import L23-24）：preview 非空→真实摘要（1行省略）；空+hasLastMessage→`SizedBox.shrink()`（2026-10-02 裁决：不展示「[加密消息]」占位、不猜测附件类型）；无消息→`t.common.dataNotFound` 兜底 | 已核验（共用） |
| hasLastMessage | 仅作为「摘要缺失时是否留空」的判据（L201-203），不单独展示 | 已核验 |
| source | 见 §3（NEEDS_FIX） | — |
| waitingSince | 仅待接态展示：`csWaitingSince`（`domain/cs_queue_format.dart:32`）→ minutes/hoursMinutes/daysHours/justNow 本地化（queue L148-161，caption2 iosOrange，位于姓名右侧 Wrap） | 已核验（仅待接） |
| version（CAS） | `_claim`：version<=0 拒发 CAS 先刷新（L87-92）；`expectedVersion` 必带（L100） | 已核验（不变） |
| 未读数 | DTO 无未读字段（cs_api.dart:176-227 全字段枚举） | **不在本版**（PRD §6：不新增） |
| 末条时间 | DTO 无末条时间戳字段（仅 hasLastMessage/lastMessagePreview 元数据） | **不在本版**（同上；不以 waitingSince 替代） |

## 2. P3-01/P3-02/P3-05 — **VERIFY_EXISTING**

- P3-01：掩码、摘要三态同函数同规则；仅等待时长与动作按状态差异（queue=接入按钮 L296-318；active/closed=整行 InkWell+chevron L139-214）。
- P3-02：摘要缺失不臆测、无「加密消息」占位、无消息复用现有兜底——与 PRD P3-02 完全一致（含产品裁决注释）。
- P3-05：claim（CAS/409/容量满/禁用语义，L85-146）、org/workspace 逐字校验、onPageMeta 服务端计数、SSE 刷新、跳转仅携带服务端投影事实（L114-121 / session L96-104）均未动。

## 3. P3-03 来源可读、未知安全 — **NEEDS_FIX**

现状（两处同型，queue L278-280 / session L190-192）：

```dart
item.source == 'widget' ? 'Web' : '${t.sourceLabel}: ${item.source}'
```

- `widget` → 显示硬编码英文 `'Web'`：非 i18n（PRD 口径 widget→「网页咨询」走本地化文案）。
- **未知非空 source → 直接输出 wire 原值**（`${item.source}`）：违反「未知非空→其他渠道；可见文字/读屏/tooltip 不输出未知 wire 值」。
- 空 source → 整行来源区隐藏（L265/L177 `if (item.source.isNotEmpty)`）：PRD 口径为「空→来源未知」展示（三态信息骨架含来源层）。
- 修复边界（T14）：仅展示层映射，wire 值与请求不变；新文案进 i18n 源并全 locale 生成。

## 4. P3-04 最小行高/大字一致 — **部分待证（结构差异已记录）**

- name→summary→source 顺序三态一致 ✓（queue L241-292 / session L163-205）。
- **结构差异**：`_SessionTile` 有 36×36 通用人物图标占位容器（L148-160），`_QueueTile` 无——三态行骨架不完全一致，待 T14 按 PRD §6.1 骨架对齐裁决（PRD 骨架未含头像；通用占位非真实头像，不涉隐私）。
- 行高≥88、scale2 动态增高：静态不可证，留 T14 几何断言（B2）。

## 5. 既有测试索引（P3 相关）

| 文件 | 覆盖 |
|---|---|
| `test/customer_service/cs_queue_layout_test.dart` | 待接队列行布局/摘要/来源 |
| `test/customer_service/cs_seat_gate_test.dart` | 掩码函数矩阵、坐席 gate |
| `test/customer_service/cs_seat_contexts_test.dart` | seat-contexts 权威聚合 |
| `test/customer_service/cs_api_contract_test.dart` | wire 合同（含 last_message 投影） |
| `test/customer_service/cs_session_preview_scope_test.dart` / `cs_session_page_test.dart` | 会话页/预览口径 |
| `test/customer_service/ux_matrix/cs_pages_ux_matrix_test.dart` | 旧计划 UX 矩阵（P3 页） |

## 6. 判定汇总

| 项 | 判定 | 一句话依据 |
|---|---|---|
| P3-01 | VERIFY_EXISTING | 掩码/摘要三态同函数；等待与动作按态差异 |
| P3-02 | VERIFY_EXISTING | 缺摘要=不渲染（无占位臆测）；无消息=dataNotFound |
| P3-03 | NEEDS_FIX | widget→硬编码 'Web' 非本地化「网页咨询」；未知非空外露 wire 值；空=隐藏而非「来源未知」 |
| P3-04 | 待证+结构差异 | 顺序一致✓；session 有 36 占位图标而 queue 无；行高/scale2 需 T14 几何断言 |
| P3-05 | VERIFY_EXISTING | claim/CAS/计数/SSE/跳转参数零变化（T27 回归证明） |

未核验（设备依赖）：真机三态渲染、大字实测、读屏播报。不阻塞源码 inventory。
