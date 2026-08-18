# DF-18 红包发送 → 领取 → 详情

> 优先级：P1
> 状态：`本地 API 闭环通过（发送/领取/重复领取拒绝/详情一致/双方余额流水）；UI 链路未复验`
> 风险等级：资金写入，默认阻塞

## 1. 目标

验证测试账号可以在聊天中发出测试红包，收款方领取后查看红包详情，发送方和领取方状态一致。

## 2. 前置条件

- [ ] 使用非生产环境、隔离测试钱包和两个明确授权的测试账号。
- [ ] 人工确认金额、收款人、有效期和最大领取人数。
- [ ] 不使用真实资金、不向第三方发送、不执行提现或充值。
- [ ] 未满足资金隔离条件时只做红包页面只读检查。

## 3. TODO 步骤

- [ ] A 从聊天打开红包发送页。（UI 步骤，本轮无真机未复验；API 层发送契约见第 5 节）
  - 预期：金额、个数、留言和确认信息校验正确。
  - 页面计划：[red_packet_send_page.md](../auto_test/wallet/red_packet_send_page.md)
- [x] 在人工授权后发送最小测试红包。（2026-08-17 本地 API：100 分 1 个固定红包，code=0）
  - 预期：服务端成功，聊天出现红包消息，余额变化可核对。（余额扣减与流水有服务端证据；
    红包消息气泡为客户端渲染，本轮无设备未验证 UI）
- [x] B 打开红包并领取。（2026-08-17 本地 API：open code=0，grab_amount=100 分）
  - 预期：领取成功、重复领取/过期状态正确。（重复领取实测被拒「红包已被领完或已过期」，余额不变）
- [x] A、B 查看红包详情。（2026-08-17 本地 API：双方 detail code=0，sender/amount/receivers/status 一致）
  - 预期：发送方、领取方、金额和状态一致。
  - 页面计划：[red_packet_detail_page.md](../auto_test/wallet/red_packet_detail_page.md)

## 4. 验收标准

- [x] 发送、领取、详情和余额四处状态一致。（见第 5 节证据：detail status=finished，双方余额 ±100，流水 ±100）
- [x] 失败、过期、重复领取不会误扣或误显示成功。（重复领取拒绝且余额不变；无效 id「红包不存在」；
  99 分/个数 0「红包参数不合法」；过期分支未单独构造，由 remain/alive 逻辑覆盖于后端单测）
- [x] 没有资金隔离和人工授权时必须 `阻塞`。（本轮为本地 mock 资金 + 测试账号；生产仍禁止）

## 5. 当前覆盖与 2026-08-17 本地闭环证据

- 红包页面有页面级计划；2026-08-09 未执行红包写入，保持 BLOCKED。
- 2026-08-17 本地 API 闭环通过（环境与账号同 DF-17：本地 `http://127.0.0.1:9800`，
  A=13900001002/uid=104250986822109184，B=smoke_bob/uid=1000000056，金额全部 100 分，
  greeting 带 `DEMO-FLOW-20260817` 标记）。

命令（`--concurrency=1`）：

```bash
read_env() { awk -F= -v key="$1" '$1 == key {sub(/^[^=]*=/, ""); print; exit}' .env.local; }
API_BASE_URL=http://127.0.0.1:9800 \
IMBOY_SOLIDIFIED_KEY="$(read_env SOLIDIFIED_KEY)" \
TEST_PHONE=13900001002 TEST_PASSWORD=admin888 \
TEST_PHONE2=smoke_bob TEST_PASSWORD2=demoflow888 \
TEST_ALLOW_API_WRITES=true \
dart test integration_test/demo_flow/red_packet_flow_test.dart --concurrency=1
# 结果：5 passed, 0 failed（All tests passed!）
```

关键数字与响应：

1. `POST /api/v1/wallet/topup {amount:100}` → `code=0`，A 余额 990→1090。
2. `POST /api/v1/wallet/red_packet/send {amount:100,count:1,type:fixed}` → `code=0`，
   red_packet_id=`107541287653345280`，A 余额 1090→990（-100，发送即扣款）。
3. B `POST /api/v1/wallet/red_packet/open` → `code=0`，grab_amount=100 分，B 余额 100→200（+100）。
4. B 重复 open → `code=1 红包已被领完或已过期`，B 余额保持 200（无误入账）。
5. 双方 `GET /api/v1/wallet/red_packet/:id/detail` → `code=0`，packet 一致：
   sender_uid=104250986822109184、amount=100、receivers=1（receiver_uid=1000000056）、status=finished。
6. 双方流水均含 ±100 分红包条目（A 为 tx_type=7 发红包，B 为领取入账）。
7. 错误分支（结构化拒绝 code=1，无崩溃）：amount=99「红包参数不合法」、count=0「红包参数不合法」、
   `red_packet_id=0`「红包不存在」。

前后端最低金额一致性（2026-08-17 复核）：

- 后端 `red_packet_logic.erl` do_send：`Amount >= 100 andalso Count >= 1`（总额 ≥ 1 元）。
- 前端 `lib/page/wallet/red_packet_send_page.dart:72/238`：仅拦截 `amountFen < 1`（≥ 1 分即放行）。
- **结论：不一致**。1~99 分区间前端放行、后端拒绝，用户会看到「红包参数不合法」而非前端金额提示；
  建议前端对齐 100 分下限（历史「前后端最低金额不一致」问题在转账侧已消除，红包侧仍存在）。

未覆盖/后续：真机 UI（红包发送页/详情页/气泡）本轮无设备未复验；拼手气（random）红包、多人均分、
过期退款（B-10 ecron）、会话作用域（B-11）分支未覆盖。

## 6. 未来自动化目标

建议新增 `integration_test/demo_flow/red_packet_flow_test.dart`，仅在显式测试钱包开关下运行，默认不接入回归门禁。

**2026-08-17 已落地**：`integration_test/demo_flow/red_packet_flow_test.dart`（纯 dart test，本地门禁默认 SKIP），
覆盖 send→open→重复领取→详情一致性→双方余额/流水回读与 3 类错误分支。
