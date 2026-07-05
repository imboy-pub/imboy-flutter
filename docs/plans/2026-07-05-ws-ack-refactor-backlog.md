# WS ACK 排查收官 + 两项结构性重构待办 / Backlog

> 最后更新 / Last updated：2026-07-05 CST
> 关联仓：`imboyapp`(Flutter)、`imboy`(Erlang 后端，路径 `../imboy`)

## 一、已完成：WS ACK 重发死循环根治

**现象**：webrtc 通话中，客户端出站消息反复 `消息确认超时` 并重发；服务端回
`CLIENT_ACK_ERROR`，帧 `id=` 为空、`type=MSG_DIRECTION_UNSPECIFIED`（无帧头降级 JSON）。

**根因链（已闭环）**：客户端对入站 webrtc 信令发 `CLIENT_ACK,WEBRTC,<msgId>,<did>`
（`lib/service/websocket.dart:756`）→ 后端 `validate_ack_params` 白名单只有
`C2C/C2G/S2C/C2S`（`imboy/src/api/websocket_handler.erl:671`）→ 判 `invalid_type` →
`cancel_timer` 不执行（`ok` 分支才调，`websocket_logic.erl:54` 置 `ack_received`）→
`ack_received` 不置位 → 服务端按间隔列表重投（`message_ds.erl:send_next_loop`，
重投**本就有界**）→ 客户端再 ACK → 再被拒 → 循环。

**已提交（均未 push）**：

| commit | 仓 | 作用 |
|---|---|---|
| `dde069c8` | imboy | **根因**：`validate_ack_params` 接受 `WEBRTC` 类型 |
| `b5445512` | imboy | 纵深：`CLIENT_ACK_ERROR` 回显 `id`（对称 `CONFIRM`） |
| `8e972b21` | imboyapp | 前端 #3/#4：`type=*_SERVER_ACK` 清机制A；新增 `ackRejected` |
| `179df654` | imboyapp | 前端：ACK 帧 `id` 跨字段兜底 + 原始帧自诊断 |

**完整性验证**：客户端全部出站 ack `type` = {C2C, C2G, S2C, C2S, WEBRTC}，后端白名单已全覆盖；
protobuf 路径 `ack_direction_to_type(Bin)->Bin` 直通 WEBRTC。无隐藏拒绝源。

**遗留**：后端两 commit 仅过 `epp_dodger` 语法检查，**部署前须在 `imboy` 仓跑完整
`make` + dialyzer**。

---

## 二、待办：两项结构性重构（本 bug 之外，需独立立项）

> 依赖关系：**先做 A（协议层）再做 B（状态机）**。B 的单一清除入口需 A 定下确认信道后才好收敛。
> 每个新会话开头先 `git log --oneline -8` 确认上述 6 提交都在，避免冲突。

### 提示词 A —— v2 二进制 ack 无法确认 Xid 出站消息（前后端协议）

```
背景:imboyapp(Flutter,/Users/leeyi/project/imboy.pub/imboyapp)+ imboy(Erlang 后端,
/Users/leeyi/project/imboy.pub/imboy)。上一轮已修复 WS ACK 重发死循环(根因是后端
validate_ack_params 白名单缺 WEBRTC,commit dde069c8;另有 b5445512/8e972b21/179df654)。
本轮处理一个更深的结构性缺陷,请勿回退上述提交。

问题:所有消息 id 都是 Xid base32hex 字符串(MessageModel.id 为 String,如
d94ie58821h5446u8ctg),但 v2 二进制 ack 帧承载的是 8 字节 uint64 数字。
- 客户端:lib/service/websocket.dart:562-574 的 FrameType.ack 分支用 getUint64 解出
  数字,再 AckManager.ackConfirmed(数字.toString())。数字串与 Xid 串永不相等;且
  ackConfirmed 只清「机制C」(AckManager._pendingAcks,入站收据),既不清「机制A」
  (_pendingMessages,websocket.dart:63/74)也不触发「机制B」(MessageRetry,
  message_retry.dart:34)。→ 凡 Xid-id 的出站消息(webrtc + 全部 C2C)靠二进制 ack
  确认是结构性死路。
- 后端:include/imboy_frame.hrl:56 FRAME_TYPE_ACK=0x03,载荷 8 字节 uint64;
  src/api/websocket_handler.erl:247-264 dispatch;msg_to_v2_frame_type/1(约 :800-809)
  把 CLIENT_ACK_CONFIRM/ERROR 映射成默认 MSG_S2C(0x23)而非 ACK(0x03)。
- 正常确认另有一条 JSON 路径:type=*_SERVER_ACK → lib/service/message.dart:337
  processMessage → _receiveServerAck(:1153)→ RemoveFromRetryQueue + updateStatus(sent)。

任务:先只读分析,给出两个方案的取舍(A:二进制 ack 改带字符串 id / 变长载荷;
B:Xid-id 消息统一走 JSON *_SERVER_ACK 确认、二进制 0x03 仅用于确有 uint64 id 的场景),
明确前后端各自改动点与兼容性(灰度、旧客户端),经我确认方案后再实现。

约束:Android 真机调试(禁模拟器);dart analyze lib 必须零 issue;后端改动至少过
epp_dodger 语法检查、部署前提示跑完整 make+dialyzer;预提交钩子会 dart-fmt 重排需重新
提交;commit-msg 首行 ≤90 字节;不要 push;联系方式/身份类改动需人工确认。
验收:构造 Xid-id 出站消息的单元/集成测试证明其能被正确确认(机制A 清除、机制B 停重发、
DB status→sent),并在真机 webrtc + C2C 各验一次不再出现"消息确认超时"噪声。
```

### 提示词 B —— 三套确认/重试机制收敛为单一出站状态机（纯前端）

```
背景:imboyapp(Flutter,/Users/leeyi/project/imboy.pub/imboyapp)。上一轮修复 WS ACK
死循环时确认:出站消息的"待确认/重试"实际是三套互不相通的机制,是这类 bug 反复难定位
的根。请勿回退近期提交(dde069c8/b5445512/8e972b21/179df654)。

三套机制现状:
- 机制A:lib/service/websocket.dart:63 _pendingMessages / :74 _confirmationTimers。
  出站消息 5s/10s 超时判定,仅由 _handleMessageConfirmation(:1150)清除;上一轮已让
  type=*_SERVER_ACK 也清它(#3),但本质仍是与 B 重叠的第二套。
- 机制B:lib/service/message_retry.dart:34 _retryQueue。真正的重发引擎,按
  messageSendRetryIntervals(:285)重投,由 RemoveFromRetryQueueRequestedEvent 清除
  (message.dart:_receiveServerAck)。
- 机制C:lib/service/ack_manager.dart _pendingAcks/_activeTimers。这是"我方对入站消息
  回的 CLIENT_ACK 收据"的重发,与出站投递无关——本轮不要并入,保持独立。

目标:把机制 A、B 收敛为单一「出站消息确认状态机」,键统一用 Xid 字符串,单一超时+退避+
上限来源,单一清除入口(SERVER_ACK / action-ACK / v2 ack 都汇聚到它)。消除机制A 对正常
消息的历史噪声与 A/B 语义重叠。机制C 维持现状不动。

任务:先只读梳理三套机制的全部登记点/清除点/计时器,画出目标状态机(状态、迁移、
超时、退避、上限、幂等),经我确认设计后再实现;实现须小步、每步 dart analyze 通过。

约束:Android 真机调试(禁模拟器);dart analyze lib 零 issue;先写测试(纯函数契约 +
SQLite ffi in-memory);预提交钩子 dart-fmt 会重排需重新提交;commit-msg 首行 ≤90 字节;
不要 push。参考 lib/service/CLAUDE.md 的初始化顺序与服务清单。
验收:①正常 C2C 出站不再打"消息确认超时";②弱网/断连重发按新状态机的退避与上限收敛,
不双重重发;③已确认消息不被重投(幂等);④覆盖 loading→sent、loading→error→retry→上限
放弃 的状态迁移测试。
```
