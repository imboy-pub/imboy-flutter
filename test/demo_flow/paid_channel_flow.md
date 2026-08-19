# DF-13 付费频道 → 订单 → 购买后解锁

> 优先级：P1
> 状态：`本地 mock 闭环通过（API 级，2026-08-19 复跑 6/6 维持，fixture 标记 DEMO-FLOW-20260819）/ 生产付费验收阻塞`
> 风险等级：资金/权益写入，默认阻塞

## 1. 目标

验证测试环境中付费频道的 paywall、订单创建、订单详情和购买后内容权限变化。

## 2. 前置条件

- [x] 付费频道能力已在非生产环境启用。（2026-08-17：本地后端 alpha.27 + fixture 频道 type=2 + channel_price 9.90 元。2026-08-18：本地后端升级 alpha.36 后以新 fixture 复跑，能力不变）
- [x] 准备测试价格、测试付款账号和测试频道，不使用真实资金。（2026-08-17：本地 wallet 资金为 mock；topup 仅非生产可用并已验证）
- [x] 已确认待支付订单取消、支付失败回收和退款权益回滚规则；重复购买仍需隔离环境验收。
- [ ] 没有测试订单或测试钱包时只做页面入口检查。（本轮有测试订单与 mock 钱包，未走页面入口检查分支）

## 3. TODO 步骤

- [x] 订阅者打开付费频道详情。（2026-08-17 API 级：`GET /api/v1/channel/1786968559671002` → type=2、price=990 分、is_subscribed=false、has_purchased=false；`GET messages` → 非 0 code「付费频道需要先购买」。UI paywall 页面未覆盖）
  - 预期：未购买内容显示 paywall，价格和购买入口清楚。
  - 页面计划：[channel_detail_page.md](../auto_test/channel/channel_detail_page.md)
- [x] 创建测试订单并查看订单列表和订单详情。（2026-08-17 API 级：订单 CH1786968655121167089，amount=9.90 元，payment_method=wallet；`GET channel/orders/my` 回读命中；`GET channel/order/{orderNo}` status=1）
  - 预期：订单状态、金额、频道和付款方一致。
  - 页面计划：[channel_order_list_page.md](../auto_test/channel/channel_order_list_page.md)、[channel_order_detail_page.md](../auto_test/channel/channel_order_detail_page.md)
- [x] 在人工授权后完成测试购买。（2026-08-17：任务授权「本地 mock 充值允许、最小金额、仅限本地测试账号」；本地 mock topup 990 分（余额 0→990）→ wallet 支付扣 990（余额 990→0）→ has_purchased=true、订阅生效、fixture 内容解锁回读；退款回收后 has_purchased=false、paywall 恢复、余额回补 990、订单 status=2(refunded)）
  - 预期：订单成功，频道内容接口解锁，刷新后权益仍保持。
- [x] 自动化已覆盖失败/取消订单不解锁内容的契约；真实隔离环境仍待执行。（2026-08-17：本地隔离环境已执行成功购买+退款回收闭环；「真实隔离环境」若指独立部署的验收环境，仍待执行）
  - 预期：订单状态和频道访问权限一致。

## 4. 验收标准

- [x] paywall、订单、购买结果和实际内容接口权限四处状态一致。（2026-08-17 API 级全链断言通过；生产环境不适用）
- [x] 未开启付费能力时结果为 `阻塞`，不能用普通订阅通过替代。（生产端点按安全协议未执行任何写入，保持阻塞口径）
- [x] 不把购买频道描述为钱包转账或 AA 结算。

## 5. 当前覆盖与阻塞

- 当前页面计划已明确付费功能未开启和无真实订单时阻塞。
- 涉及资金或权益写入，默认不执行真实购买。
- 2026-08-12：后端订单取消接口、客户端订单详情取消入口和 mock 闭环测试已补齐；默认安全模式下未执行资金/权益写入，真实隔离支付仍保持 `BLOCKED`。
- 2026-08-17：**本地 mock 闭环打通（API 级，`dart test` 全绿 6/6）**——paywall → mock topup → 订单创建（wallet 网关）→ 支付 → 订单列表/详情回读 → 内容解锁 → 余额扣款回读 → 退款回收（权益与余额均恢复）。生产环境付费能力仍未启用（生产 discover 全部 type=0、账号零余额），生产付费验收维持 `BLOCKED`。
- 2026-08-18：后端升级 alpha.36 后全链复跑 6/6 维持通过（新 fixture 已清理无残留）；生产只读探针复核 discover 仍 7 项全部 type=0（无付费样本），生产付费维持 `阻塞`，未向生产发送任何写入/付费请求。
- 不能用普通频道订阅或订单列表出现替代购买后权益闭环证据。

### 2026-08-17 证据（本地 API 级）

Fixture：`PAID_FIXTURE_MARKER=imboy-paid-fixture-DEMO-FLOW-20260817 PAID_FIXTURE_OWNER_UID=106571324662745088 PAID_FIXTURE_BUYER_UID=104250986822109184 bash imboy/scripts/paid_channel_fixture.sh create` → `TEST_PAID_CHANNEL_ID=1786968559671002`（type=2、9.90 元、1 条 fixture 内容）。

执行：`API_BASE_URL/TEST_PHONE/TEST_PASSWORD=<scripts/test.env> IMBOY_ENV_PRO=.env.local TEST_PAID_CHANNEL_ID=1786968559671002 TEST_ALLOW_PAID_CHANNEL_WRITES=true TEST_ALLOW_API_WRITES=true dart test integration_test/demo_flow/paid_channel_flow_api_test.dart --concurrency=1 --reporter expanded` → `All tests passed!`（6/6）。

关键数字（buyer=104250986822109184）：

1. 购买前：详情 price=990 分、is_subscribed=false、has_purchased=false；内容接口被拒 msg=「付费频道需要先购买」。
2. mock topup：`POST /api/v1/wallet/topup {amount:990}` code=0，余额 0 → 990（分），balance 回读一致。
3. 订单：`POST /api/v1/channel/{id}/order {payment_method:wallet}` → order_no=CH1786968655121167089、amount=9.90；`POST /api/v1/channel/order/pay` code=0 → 订单 status=1（paid）。
4. 解锁：详情 has_purchased=true、is_subscribed=true；messages code=0 且列表含 fixture 内容；余额扣减 990 回到 0。
5. 回读：`GET channel/orders/my` 命中该订单。
6. 退款回收：`POST /api/v1/channel/order/refund` code=0 → has_purchased=false、is_subscribed=false、messages 重新被 paywall 拒绝、余额回补至 990、订单 status=2。
7. 清理：fixture 脚本 `cleanup`（DELETE 1），`inspect` 确认无残留。

### 2026-08-18 复跑（本地 API 级，后端升级 alpha.36 后回归）

环境：`http://127.0.0.1:9800/healthz` → alpha.36 db=up。Fixture：新 marker `imboy-paid-fixture-DEMO-FLOW-20260818`（owner/buyer UID 沿用 08-17 已确认值）→ `TEST_PAID_CHANNEL_ID=1787029025720985`。

结果：`dart test` 全绿 **6/6**，链路行为与 08-17 一致：

1. paywall：详情 price=990 分、内容被拒（「付费频道需要先购买」）。
2. mock topup 990 分：余额 990 → 1980（起始 990 为上轮退款回补的遗留余额，非本轮新增风险）。
3. 订单 CH1787029034030920635（wallet 网关）支付成功 status=1；`orders/my` 回读命中。
4. 解锁回读通过；余额扣减 990 回到 990。
5. 退款回收：has_purchased=false、余额回补至 1980、订单 status=2。
6. 清理：`cleanup`（DELETE 1）后 `inspect` 输出为空、exit=0，无残留。

三重门禁复核：不带门禁变量运行 → `0 passed, 6 skipped`（All tests skipped），未发出任何请求。

生产付费阻塞复核（2026-08-18，只读探针，与 api_test_client 同源签名）：`GET /api/v1/channels/discover` → code=0、7 项、type 分布 `{0:7}`（**仍无 type=2 付费频道样本**）；`GET /api/v1/channels/subscribed` → 0 项。生产付费验收维持 `阻塞`（无样本 + 生产禁写红线）。

### 2026-08-19 复跑（本地 API 级，fixture 标记 DEMO-FLOW-20260819）

环境：`http://127.0.0.1:9800/healthz` → alpha.36 db=up（imboy main@e6d785d0，未重启）。Fixture：新 marker `imboy-paid-fixture-DEMO-FLOW-20260819`（owner/buyer UID 沿用已确认值 106571324662745088 / 104250986822109184）→ `TEST_PAID_CHANNEL_ID=1787117025494239`。测试文件退款原因字符串同步更新为 `DEMO-FLOW-20260819 自动化回收`。

结果：`dart test` 全绿 **6/6**，链路行为与 08-17/08-18 一致：

1. paywall：详情 price=990 分、内容被拒（「付费频道需要先购买」）。
2. mock topup 990 分：余额 1980 → 2970（期初 1980 为 08-18 期末遗留值，期间无其他 flow 动用该账号钱包，非本轮新增风险）。
3. 订单 CH1787117032728923983（wallet 网关）支付成功 status=1；`orders/my` 回读命中。
4. 解锁回读通过（has_purchased=true、is_subscribed=true、fixture 内容可读）；余额扣减 990 回到 1980。
5. 退款回收：has_purchased=false、is_subscribed=false、内容重新被 paywall 拒绝、余额回补至 2970、订单 status=2（+990 为 mock topup 增量留存，与上轮模式一致）。
6. 清理：`cleanup`（DELETE 1）后 `inspect` 输出为空、exit=0，无残留。

三重门禁复核：不带门禁变量运行 → `0 passed, 6 skipped`（All tests skipped），未发出任何请求。

生产付费阻塞复核（2026-08-19，只读探针并入 DF-05 本轮探针）：`GET /api/v1/channels/discover` → code=0、7 项、type 分布 `{0:7}`（仍无付费样本）；`subscribed` → 0 项。生产付费验收维持 `阻塞`（无样本 + 生产禁写红线，本轮对生产零写入零付费）。

## 6. 未来自动化目标

已新增 `integration_test/demo_flow/paid_channel_flow_test.dart`，只在显式非生产环境开关、测试频道和 `mock` 支付可用时运行。

2026-08-17 另新增纯 Dart 版 `integration_test/demo_flow/paid_channel_flow_api_test.dart`（`dart test` 无设备可跑，默认 SKIP；门禁 `TEST_ALLOW_PAID_CHANNEL_WRITES=true` + `TEST_ALLOW_API_WRITES=true` + `TEST_PAID_CHANNEL_ID`（环境变量或 dart-define）+ 非生产地址；channel id 优先读环境变量，因为 `dart test` 不支持 `-D` 传常量）。

测试 fixture 可用后端脚本 `imboy/scripts/paid_channel_fixture.sh` 准备：它会创建带唯一 marker 的 `type=2` 频道、有效价格和一条内容消息，不创建用户、不接触真实支付；测试结束后按 marker 删除频道即可级联回收 fixture 及测试订单。脚本默认只读，写操作必须同时满足本地/私网 PG、`PAID_FIXTURE_ALLOW_WRITES=true` 和确认词。

执行前需由测试负责人明确提供已存在的 owner/buyer UID，并确认 buyer 使用的登录账号与 UID 一致：

```bash
PAID_FIXTURE_OWNER_UID=<owner-uid> \
PAID_FIXTURE_BUYER_UID=<buyer-uid> \
PAID_FIXTURE_ALLOW_WRITES=true \
PAID_FIXTURE_CONFIRM=CREATE_LOCAL_PAID_FIXTURE \
bash /path/to/imboy/scripts/paid_channel_fixture.sh create
```

脚本输出的 `TEST_PAID_CHANNEL_ID` 作为集成测试参数。服务端也会重复校验价格边界和频道类型，不能只依赖管理端表单。

运行时必须同时提供：

```bash
flutter test integration_test/demo_flow/paid_channel_flow_test.dart -d macos \
  --dart-define=API_BASE_URL=http://127.0.0.1:9800 \
  --dart-define=TEST_PHONE=<test-account> \
  --dart-define=TEST_PASSWORD=<test-password> \
  --dart-define=TEST_PAID_CHANNEL_ID=<paid-channel-id> \
  --dart-define=TEST_PAID_CHANNEL_PAYMENT_METHOD=mock \
  --dart-define=TEST_ALLOW_PAID_CHANNEL_WRITES=true
```

测试会自动创建 mock 订单、确认频道解锁、退款并核对权限回收；真实商户支付仍保持阻塞，不以该 mock 结果替代生产支付验收。

清理必须使用创建时输出的 marker，并再次显式确认：

```bash
PAID_FIXTURE_MARKER=<fixture-marker> \
PAID_FIXTURE_ALLOW_WRITES=true \
PAID_FIXTURE_CONFIRM=CLEANUP_LOCAL_PAID_FIXTURE \
bash /path/to/imboy/scripts/paid_channel_fixture.sh cleanup
```
