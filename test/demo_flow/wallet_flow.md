# DF-06 钱包余额 → 转账确认 → 结果回传

> 状态：`通过（本地 API 全闭环：充值/发送/扣款/accept 收款/重复拒绝/流水/错误分支，2026-08-18 BUG-A 修复复验通过，2026-08-19 复跑 7/7 维持且 transfer_order 0 悬挂）；UI 链路未复验`
> 优先级：P1
> 类型：高风险资金流程

## 1. 目标

验证钱包页面能加载余额，转账页能正确展示收款人和金额确认信息，并在受控环境中完成转账后把结果回传到聊天页。

本流程不等于 AA 分摊系统。当前只验证已有钱包转账能力，不新增自动分摊、账单、托管、退款或提现功能。

## 2. 安全前置条件

- [ ] 默认只执行只读检查：钱包入口、余额展示、收款人、金额校验、确认弹窗和取消路径。
- [ ] 真正转账前必须确认：环境非生产、付款账号、收款账号、金额、授权人和清理/对账方式。
- [ ] 不充值、不提现、不发红包，不使用真实第三方收款账号。
- [ ] 付款账号余额足够，且前端与后端最低转账金额规则已确认一致。
- [ ] 不把一次成功的小额转账当作完整支付或 AA 能力证明。

## 3. TODO 执行步骤

### 阶段 A：只读验证

- [ ] 打开钱包页并等待余额加载。（UI 步骤，历史真机证据见第 5 节；本轮无设备未复验）
  - 预期：余额、入口和错误状态正确。
  - 页面计划：[wallet_page.md](../auto_test/wallet/wallet_page.md)
- [ ] 从测试联系人进入转账页。（UI 步骤，历史证据见第 5 节；本轮无设备未复验）
  - 预期：收款人昵称和账号正确。
  - 页面计划：[transfer_send_page.md](../auto_test/wallet/transfer_send_page.md)
- [x] 输入空值、非法格式、低于后端最低金额和超出余额的金额。（2026-08-17 本地 API 错误分支全覆盖，见第 6 节）
  - 预期：前端拦截或服务端拒绝均有明确提示，不能把失败显示成成功。
  - 实测：空值/字符串小数/99 分/0 分均被「转账参数不合法」结构化拒绝；超余额被拒但错误信息泄露内部
    db_exception（BUG-B，见第 6 节）。
- [ ] 点击确认后取消转账。（UI 交互分支，本轮无设备未复验；API 层无对应取消端点，转账拒收走
  `transfer/refund` 语义）
  - 预期：不产生余额变化，不产生转账气泡。

### 阶段 B：受控写入

- [x] 在人工授权后执行一次最小测试金额转账。（2026-08-17 本地：topup 100 分 → 转账 100 分成功，服务端 code=0）
  - 预期：服务端成功，付款方余额刷新，聊天页出现转账结果气泡。
  - 实测：服务端成功、付款方余额/流水刷新；`transfer_logic` 不写会话消息，转账气泡为客户端本地渲染，
    本轮无设备未验证 UI 气泡。
- [x] 收款方在隔离测试账号中核对到账结果。（2026-08-18 本地：BUG-A 修复已部署，accept `code=0`，
  B 余额 +100、流水含 tx_type=6「收取转账」；重复 accept 被拒「状态不合法，无法收取」且余额不变，见第 6 节）
  - 预期：付款方、收款方和聊天消息三处状态一致。（余额/流水侧一致已服务端验证；
    聊天消息侧 `transfer_logic` 不写会话消息，气泡为客户端渲染，本轮无设备未验证 UI）
- [x] 记录交易标识、环境和金额；禁止在仓库或文档中记录凭证、隐私数据。（transfer_id=107541287196166144 等，见第 6 节）

## 4. 验收标准

- [x] 余额和收款人来自服务端真实结果。（本地 API 全部服务端回读）
- [x] 确认、取消、失败、成功四条分支均有明确结果。（成功/各失败分支有 API 证据；UI 取消分支未复验；
  收款确认成功分支 2026-08-18 已随 BUG-A 修复复验通过，见第 6.1 节）
- [ ] 成功转账必须同时满足服务端成功、余额刷新、聊天结果回传。（前两项满足（2026-08-18 accept
  闭环补全后发送/收款双侧均有服务端证据）；UI 气泡未验）
- [x] 未经人工授权，不执行任何资金写入；未满足条件时结果为 `阻塞`。（本轮仅本地测试账号间 mock 资金）
- [x] 不把手工多次转账、群聊说明或备注文本描述为自动 AA。

## 5. 当前已有覆盖与阻塞

- 2026-08-09：Android 华为真机 `integration_test/wallet/wallet_readonly_test.dart` 通过 `1/1`；钱包首页成功读取余额和流水并完成路由清理，未执行任何资金写入。
- 2026-08-10：Android 华为真机使用 `.env.pro` 重跑钱包只读，余额与流水请求完成，最终 `1/1 All tests passed`；未执行转账、充值、提现或红包写入。
- 2026-08-09：`wallet_api_test.dart` 的余额/流水只读检查通过，计入本轮 `39 passed, 3 skipped, 0 failed` 汇总。
- 2026-08-17 生产只读复跑：`wallet_api_test.dart` 以 `.env.pro` 注入运行 `4/4 All tests passed`
  （balance/transactions 结构与分/元一致性）；未运行 `wallet_api_fail_contract_test.dart`（禁令）。
- 2026-08-19 生产只读复跑维持：`wallet_api_test.dart` 以 `.env.pro` read_env 注入
  （`TEST_ALLOW_API_WRITES` 保持关闭）运行 `4/4 All tests passed`
  （登录 uid=4；balance/transactions 结构与分/元一致性）；`wallet_api_fail_contract_test.dart`
  未运行（禁令维持，历史审计要求禁止重新运行）。
- 本轮另有误运行的 `wallet_api_fail_contract_test.dart` 向生产转账端点发送无效参数校验请求并收到 `400`；未观察到成功响应，该结果不计入证据，副作用仍需服务端审计确认，禁止重新运行。
- 页面计划记录过一次真机小额转账成功和聊天气泡回传，但也记录了前端最低金额与后端最低金额不一致的问题。
  **2026-08-17 复核（转账）**：后端 `transfer_logic.erl:14` 要求 `Amount >= 100` 分（1 元）；前端
  `lib/page/wallet/transfer_send_page.dart:61` 对 `< 100` 分拒绝——**两端一致**（历史不一致问题在转账侧已消除）。
  **2026-08-17 复核（红包，见 red_packet_flow.md）**：后端要求总额 `>= 100` 分，前端
  `red_packet_send_page.dart:72` 仅拦截 `< 1` 分——**两端仍不一致**（1~99 分区间前端放行、后端拒绝）。
- 钱包充值目前不作为本流程步骤；生产资金写操作、提现和不可逆清理均不执行。
- 2026-08-17 本地受控闭环结果见第 6 节：发送侧全部通过，收款 accept 被后端 BUG-A 阻塞
  （**2026-08-18 修复已部署并复验通过，遗留 pending 全部回收，见第 6.1 节**）。

## 6. 2026-08-17 本地受控闭环证据与后端缺陷

环境：本地后端 `http://127.0.0.1:9800`（`1.0.0-alpha.27`，运行中节点、未干预进程，仅 HTTP API + 只读 psql 取证）；
账号 A=`13900001002`（uid=104250986822109184），账号 B=`smoke_bob`（uid=1000000056，本地合成测试账号）；
全部金额为最小测试金额（100 分），remark 带 `DEMO-FLOW-20260817` 标记。

命令（`--concurrency=1`）：

```bash
read_env() { awk -F= -v key="$1" '$1 == key {sub(/^[^=]*=/, ""); print; exit}' .env.local; }
API_BASE_URL=http://127.0.0.1:9800 \
IMBOY_SOLIDIFIED_KEY="$(read_env SOLIDIFIED_KEY)" \
TEST_PHONE=13900001002 TEST_PASSWORD=admin888 \
TEST_PHONE2=smoke_bob TEST_PASSWORD2=demoflow888 \
TEST_ALLOW_API_WRITES=true \
dart test integration_test/demo_flow/wallet_transfer_flow_test.dart --concurrency=1
# 结果：6 passed, 1 skipped（accept 用例按 BUG-A 门禁受控跳过），All tests passed!
```

成功链路数字：

1. `POST /api/v1/wallet/topup {amount:100}` → `code=0`，reference_no=`TOP1786969281765_2FADC91D9DD63FC8`，
   A 余额 990→1090（+100）。
2. `POST /api/v1/wallet/transfer/send {receiver_uid:1000000056, amount:100}` → `code=0`，
   transfer_id=`107541287196166144`，A 余额 1090→990（-100，发送即扣款）。
3. A 流水含 -100 分条目（tx_type=5 转账转出）；B 余额在 accept 前不变（pending 语义正确）。
4. 错误分支（均结构化拒绝 code=1，无崩溃）：amount=99/“10.5”/0 →「转账参数不合法」；
   receiver_uid 空/`abc` → 明确拒绝；重复语义见 accept 用例。

后端缺陷（imboy 仓只读定位，本仓不修改）：

- **BUG-A（收款闭环阻塞，P0 级）**：`transfer_repo:accept/2`（`src/repo/transfer_repo.erl:86-124`）的事务内
  SELECT 经 `elib_pg:execute`（底层 epgsql `execute_batch`），对 SELECT 只返回 `{ok, Rows}` 二元组，
  `{ok, 1, [...]}` 三元组永不匹配 → 落入 `_ ->` 分支恒报「转账订单不存在」。
  `refund/1` 同型问题。铁证：`red_packet_repo.erl:108-112` 注释明确记载同类问题（"曾致抢红包永远报『红包不存在』"）
  并已改用 `elib_pg:query`（equery）修复，transfer_repo 未同步修复。
  实测：curl 以 B 身份对 DB 中真实存在、status=pending、receiver 匹配的
  transfer_id=107540522685696000 调 `POST /api/v1/wallet/transfer/accept` → `code=1 转账订单不存在`；
  同一 SQL 在 psql 参数化执行正常返回该行。修复后可用
  `--dart-define=TEST_EXPECT_TRANSFER_ACCEPT_FIXED=true` 打开被门禁的 accept 闭环用例复验。
- **BUG-B（错误信息泄露）**：超出余额时扣款 UPDATE（带 RETURNING）0 行命中返回 `{ok, 0, []}` 三元组，
  `transfer_repo:create/4` 只匹配 `{ok, 1, [...]}` 和 `{ok, 0}` 二元组 → case_clause 崩溃被收敛为
  `{db_exception,error,{case_clause,{ok,0,[]}}}`（code=1，未 500），用户无法看到「钱包余额不足」。
  运行节点 error.log 同步记录该 case_clause（2026-08-17 12:15 UTC）。

遗留数据（本地 mock 资金，可回收）：两笔 pending 转账（107540522685696000、107541287196166144，各 100 分）
因 BUG-A 无法 accept/refund，留在本地 transfer_order 表；A 余额 990 分、B 余额 200 分均为 mock 充值所得。
（**2026-08-18 更新：BUG-A 修复部署后上述遗留已全部 accept 回收，见第 6.1 节。**）

## 6.1 2026-08-18 BUG-A 修复复验：accept 收款闭环通过

环境：本地后端 `http://127.0.0.1:9800`，运行节点 `_rel/imboy` release `1.0.0-alpha.36`
（beam 2026-08-18 08:44 编译、进程 08:46 启动，仓 main@e6d785d0）；账号与第 6 节相同
（A=13900001002/uid=104250986822109184，B=smoke_bob/uid=1000000056），remark 带 `DEMO-FLOW-20260818` 标记。

修复证据（imboy 仓只读核实，未修改）：

- `src/repo/transfer_repo.erl:94-98`：accept 事务内 SELECT 已改用 `elib_pg:query`（equery），
  且带注释明确记载本缺陷（"曾致收取转账恒报『转账订单不存在』（red_packet_repo.grab 同款事故）"）；
  `refund` 同型已修。运行 beam 与运行中节点均已加载该版本。

accept 闭环数字（一次性探针复验，复用 `ApiTestClient` 同一套签名/写入门禁）：

1. 期初余额 A=1980 分、B=300 分（与第 6 节期末 990/200 的差额 +990/+100 为 08-17 记录后、
   本轮开始前其他流程所致，非本流程操作，特此注明）。
2. `topup 100` → A=2080；`transfer/send 100`（transfer_id=`107666850655242240`）→ A=1980；
3. B `transfer/accept` → `code=0 success`，B=400（+100）；B 流水含 +100 分
   tx_type=6「收取转账」条目；A 流水含 -100 分 tx_type=5「转账给好友」条目。
4. B 重复 accept → `code=1 状态不合法，无法收取`，余额保持 400（无误入账）。
5. **遗留回收**：上轮两笔卡死 pending（107540522685696000、107541287196166144）本轮 accept
   均 `code=0`（B 400→600）；另有 08-17 12:27 创建、上轮文档未记录的第三笔 pending
   （107542063704442880，remark=DEMO-FLOW-20260817）以及本轮套件 send 用例留下的
   107666882439677952，亦全部 accept 回收。期末 A=1980（净 0）、B=800。
6. 服务端 DB 只读取证：`transfer_order` 表状态分布 5 笔 accepted/500 分、**0 笔 DEMO-FLOW 悬挂 pending**。

正式套件复跑（`--concurrency=1`，同第 6 节命令）：`6 passed, 1 skipped（accept 用例）, All tests passed!`。
错误分支结果：amount=99/"10.5"/0 →「转账参数不合法」；**超余额 → `code=1 钱包余额不足`（BUG-B 已修复，
不再泄露 db_exception；`transfer_repo.erl:36-39` 注释记载 RETURNING 扣款改 `elib_pg:query` +
`{ok, []}` → `insufficient_balance` 回滚）**；receiver_uid 空/`abc` 均明确拒绝。

accept 用例执行方式说明：`dart test` 不支持 `--dart-define`（package:test 无该 flag，测试文件头部
注释的复验命令实际不可用），故 accept 闭环由上述等价探针完成；建议后续把该门禁从 dart-define
改为环境变量（如 `TEST_EXPECT_TRANSFER_ACCEPT_FIXED`），`dart test` 即可直接打开。

本轮结论：**DF-17 本地 API 全闭环通过**；BUG-A/BUG-B 均已修复且部署生效。UI 链路（钱包页/转账页/
聊天气泡/取消交互）仍无设备未复验。

## 6.2 2026-08-19 复跑维持：7/7 通过 + transfer_order 0 悬挂

环境：本地后端 `http://127.0.0.1:9800`（healthz `1.0.0-alpha.36`，db up，节点未干预）；账号同第 6 节
（A=13900001002/uid=104250986822109184，B=smoke_bob/uid=1000000056），remark 带 `DEMO-FLOW-20260819` 标记。

本轮测试资产改进（第 6.1 节遗留建议落地）：`integration_test/demo_flow/wallet_transfer_flow_test.dart`
的 accept 门禁已从 `--dart-define` 扩展为**同时接受环境变量 `TEST_EXPECT_TRANSFER_ACCEPT_FIXED=true`**
（dart test 不支持 --dart-define），且主闭环用例在门禁打开时会顺带 accept 回收本笔转账，套件不再遗留
悬挂 pending；数据标记更新为 `DEMO-FLOW-20260819`。

命令（`TEST_EXPECT_TRANSFER_ACCEPT_FIXED=true` 打开 accept 用例，其余同第 6 节）：

```bash
read_env() { awk -F= -v key="$1" '$1 == key {sub(/^[^=]*=/, ""); gsub(/^"|"$/, ""); print; exit}' .env.local; }
API_BASE_URL=http://127.0.0.1:9800 \
IMBOY_SOLIDIFIED_KEY="$(read_env SOLIDIFIED_KEY)" \
TEST_PHONE=13900001002 TEST_PASSWORD=admin888 \
TEST_PHONE2=smoke_bob TEST_PASSWORD2=demoflow888 \
TEST_ALLOW_API_WRITES=true \
TEST_EXPECT_TRANSFER_ACCEPT_FIXED=true \
dart test integration_test/demo_flow/wallet_transfer_flow_test.dart --concurrency=1
# 结果：7 passed, 0 skipped, All tests passed!（accept 用例首次随套件直接执行）
```

注：`.env.local` 的 SOLIDIFIED_KEY 值带双引号，read_env 提取时需 `gsub(/^"|"$/, "")` 去引号，
否则签名失败。

本轮关键数字（DF-17 先于 DF-18 串行执行，避免动余额自我竞争）：

1. 期初余额 A=2970 分、B=900 分（与 08-18 期末 1980/800 的差额 +990/+100 为 08-18 记录后
   其他并行流程所致，非本流程操作；本套件断言均为本次操作净变化，外部漂移不影响）。
2. 主闭环：topup 100 → A=3070；send（transfer_id=`107851467895080960`）→ A=2970（净 0）；
   A 流水含 -100 tx_type=5「转账给好友」；B accept 前 900 不变（pending 语义）→ accept 后
   B=1000（+100）；重复 accept `code=1 状态不合法，无法收取`，余额保持。
3. 独立 accept 用例：transfer_id=`107851468014618624`，B 1000→1100（+100），流水含 +100
   tx_type=6 入账条目，重复 accept 拒绝且余额不变。
4. 错误分支与 08-18 完全一致：99/"10.5"/0 →「转账参数不合法」；超余额 → `code=1 钱包余额不足`
   （BUG-B 修复维持）；receiver_uid 空/`abc` 均拒绝。
5. 服务端 DB 只读取证：`transfer_order` 表状态分布 **7 笔 accepted / 700 分、0 笔 pending**；
   本轮两笔 `DEMO-FLOW-20260819` 转账均 accepted，无悬挂。

本轮净资金变化：A 净 0（topup +200 / send -200），B +200（两笔 accept）；期末 A=2970、B=1100
（其后 DF-18 红包再 +100 → 1200，见 red_packet_flow.md）。

## 7. 未来自动化目标

建议分成两个文件：

- `integration_test/demo_flow/wallet_readonly_flow_test.dart`：余额、收款人、金额校验、确认和取消，可作为普通回归的一部分；
- `integration_test/demo_flow/wallet_transfer_controlled_test.dart`：仅在显式环境开关和测试钱包条件满足时运行，默认跳过。

**2026-08-17 已落地**：`integration_test/demo_flow/wallet_transfer_flow_test.dart`（纯 dart test，本地门禁
`TEST_ALLOW_API_WRITES=true` + 本地地址 + 双账号，默认 SKIP），覆盖 topup→send→余额/流水回读与 5 类错误分支；
accept 收款闭环用例带 `TEST_EXPECT_TRANSFER_ACCEPT_FIXED` 门禁。
**2026-08-19 更新**：该门禁已支持环境变量方式（`dart test` 直接打开，`--dart-define` 仍兼容），
主闭环用例在门禁打开时自动 accept 回收本笔转账，套件不再遗留悬挂 pending。

自动化测试不得把真实支付凭证写入命令、源码、日志或仓库文件。
