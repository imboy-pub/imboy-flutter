# IMBoy 全页面全功能自动化与核心领域深度验收计划

> 创建：2026-09-18
> 仓库：`/Users/leeyi/project/imboy.pub/imboyapp`
> 被测系统：Flutter/Dart 客户端 + Erlang/OTP/Cowboy 后端（`../imboy`）
> 测试控制面：Python stdlib + shell；本计划不引入第三方测试编排依赖
> 基线参考：`07c63637e329492e0295264556b31d18ea3ade94`，执行 Step 1 时必须重新记录当前 HEAD
> 配套提示词：`docs/plans/2026-09-18-auto-test-framework-hardening-prompts.md`
> 状态：`TODO`

## 1. 目标

在不修改 Flutter/Erlang 产品行为、不引入第三方编排依赖的前提下，允许按需重构全部 auto-test 资产，包括控制面、规格、页面台账、生成器、设备测试和旧入口；把 `test/auto_test` 改造成可测试、可重复执行、可自动验收且默认节省 Token 的测试控制面。再由它以“源码白盒发现 + 真客户端黑盒操作”的方式，模拟人工测试员逐页进入并把每个用户可见功能至少执行一次，同时对 E2EE 和企业协作领域做更深的多角色、安全与恢复验收。

完成后必须满足：

- `PASS` 只代表测试实际执行且没有 skip、失败或缺失断言证据。
- 同一个 `runner.target` 在一次计划中最多执行一次。
- 执行前验证最终生效的 App/API/WS 目标，不能只验证父进程环境变量。
- 当前源码页和集成测试文件必须被 catalog 收录或带原因显式排除。
- 每个当前可达页面、页面入口及用户可见操作必须进入 functional inventory；每个适用平台上的功能等价类必须实际执行一次，或带可验证原因明确 `BLOCKED/EXCLUDED`。
- E2EE、Enterprise/Organization、Workspace、Group、Channel、Moment 和 Project 的核心 capability 必须被 domain matrix 映射到 App/Backend 测试和证据等级，或带原因明确 `BLOCKED`。
- 涉及后端的结果和缓存必须绑定 Erlang 后端 HEAD、API/WS 目标和测试配置指纹。
- 机器完成发现、校验、影响分析、结果归类和像素预筛；AI 只处理异常和语义判断。
- fresh clone 能从已跟踪文件生成执行计划，不依赖被忽略的历史报告。
- 无设备 gate 与 Android 真机 + macOS 验收分层记录；设备授权不会放宽远程写入、第三方影响或视觉基线审批。

本计划中“所有页面的所有功能至少测试一次”的定义是：从路由、页面源码、现有页面台账、feature manifest 和集成测试反向生成可机读清单；每个可达页面的入口、按钮、菜单、表单提交、列表操作、手势、状态切换、错误/空态入口和导航结果都归入一个稳定 `function_id`，在 Android 真机和 macOS 中每个适用平台至少执行一次并检查可观察结果。共享组件的同一功能等价类可复用一次证据；纯展示元素、不可达死代码和平台不适用项可以排除，但必须有机器可校验的理由，不能由 AI 自行声称“已覆盖”。

本计划中“全面”的领域深度定义是：每个高风险 capability 都要同时给出正向路径、权限/租户负向路径、失败恢复路径、App 与 Backend 证据、环境前置和当前结论。全页面一次遍历不等于穷举所有输入排列、设备组合和像素，也不允许用单元测试冒充真机端到端证据。

“模拟人工真机测试”的定义是：由自动化控制面按真实用户操作顺序在 Android 真机和本机 macOS 客户端上执行登录、切换、点击、输入、发送、接收、重进和权限负向路径，并用 UI 状态 + API/WS/ACK + 本地持久化 + 后端密文/租户边界交叉取证。Python/shell 只是调度、判定和证据归档层；无设备测试是 preflight，不是最终真机验收。

## 2. 非目标

- 不修复 `lib/` 或 `../imboy/src/` 中的产品功能；测试暴露产品缺陷时记录并停止，不顺手改产品。
- 允许迁移/重构现有 1748 行页面台账、25 specs 和 130 个 integration tests，但不得删除有效断言来换取绿色；只有当前源码/API 合同能证明旧测试本身过期时才可修正测试断言并记录依据。
- 允许 Step 11/13/14 使用已连接 Android 真机和本机 macOS；但不连接远程/生产后端，不向真实第三方发消息、好友申请、邀请或通知，不执行资金操作。
- 不上传截图，不调用视觉模型，不登记或替换视觉基线。
- 不修改 `ios/*`、`macos/*`、`plugin/r_upgrade`，不新增第三方依赖。
- 不把历史报告、dry-run、静态校验或模型判断描述为真机 PASS。
- 不 reset、clean、stash、restore 或覆盖共享工作树中的既有改动；不 push、发布或部署。

## 3. 目标结构

```text
Git diff / 显式 scope
        |
        v
catalog --check -----> 页面/测试缺失或风险冲突：FAIL
        |
        v
impact plan ----------> 无影响：输出空计划并结束
        |
        v
requirements gate ----> 条件不足：BLOCKED，不启动 Flutter
        |
        v
unique target runner -> flutter test --machine
        |
        v
PASS / PASS_WITH_SKIPS / BLOCKED / FAIL
        |
        +---- PASS：仅写结构化结果和证据哈希，不调用 AI
        |
        +---- 其余：生成最小失败证据包，供 AI 诊断并汇入最终 HTML
```

权威数据分为三类：

| 数据 | 作用 | 是否跟踪 |
|---|---|---|
| `test/auto_test/catalog.json` | 可执行 target、源码映射、风险、requirements、显式排除 | 是 |
| `test/auto_test/functional_inventory.json` | 页面、入口、用户操作、预期结果、平台适用性和静态 required/excluded 归类 | 是 |
| `test/auto_test/domain_coverage.json` | E2EE/Enterprise/Organization/Workspace/Group capability、正负路径、证据要求和静态排除 | 是 |
| `test/auto_test/state/schema.json` | 当前状态和证据 manifest 的稳定 schema | 是 |
| `test/auto_test/reports/<run-id>/` | 日志、截图、machine events、临时 current state | 否 |

现有页面 Markdown 保留为人工功能台账；`README.md`、覆盖矩阵和 backlog 都是生成物，不能反向成为源码清单。

## 4. 状态、退出码和证据合同

### 4.1 状态

| 状态 | 定义 | 可作为自动门绿灯 |
|---|---|---:|
| `PASS` | 至少一个测试实际执行；0 skip；0 fail；关键断言/完成事件存在 | 是 |
| `PASS_WITH_SKIPS` | 有成功执行，也有 skip | 否 |
| `BLOCKED` | requirements、设备、凭证、授权或环境不足，测试体未完整执行 | 否 |
| `FAIL` | 断言失败、未处理异常、超时、runner/采集器错误 | 否 |
| `FLAKY` | 仅可重试的基础设施失败在不改代码/数据时结果不稳定；保留全部尝试 | 否 |
| `PLANNED` | 仅生成计划，未执行 | 否 |

三个状态层严格分离：`scheduler_state = WAITING | READY | RUNNING | DONE | INTERRUPTED`；单 target 使用上表 `test_status`；Step/领域汇总使用 `scope_verdict = PASS | PARTIAL | BLOCKED`。断言 `FAIL`、`PASS_WITH_SKIPS`、`FLAKY` 或残留 `PLANNED` 汇总为 `PARTIAL`，环境/授权不足且目标未执行汇总为 `BLOCKED`；框架步骤应生成的产物缺失或验收失败时 scheduler 为 `INTERRUPTED`，不能伪装成 `DONE`。

依赖边分两类：`H`（verified artifact）要求前置 Acceptance `PASS` 且产物有效；`S`（terminal evidence）接受前置 `DONE` 或 `INTERRUPTED`。`DONE` 时把 `BLOCKED/FAIL/FLAKY` 精确传播到依赖它的 capability/function/shard；`INTERRUPTED` 且缺所需产物时，下游不执行对应动作，收敛为 `DONE + BLOCKED_UPSTREAM`，不能永久停在 `WAITING`。Step 15 是 always-run finalizer，等待所有可达工作进入终态后必须生成汇总；不相关的 ready 工作继续执行。

### 4.2 退出码

```text
0  = 全部目标 PASS
1  = 至少一个 FAIL
2  = 无 FAIL，但存在 PASS_WITH_SKIPS、FLAKY、BLOCKED 或 PLANNED
64 = 参数、schema 或 catalog 使用错误
```

### 4.3 最小证据 manifest

每个执行结果至少包含：

```json
{
  "schema_version": 1,
  "run_id": "<run-id>",
  "head": "<40-char sha>",
  "backend_head": "<40-char sha-or-NOT_APPLICABLE>",
  "tested_tree_sha256": "<sha256>",
  "catalog_sha256": "<sha256>",
  "target": "integration_test/..._test.dart",
  "target_sha256": "<sha256>",
  "runner_sha256": "<sha256>",
  "config_sha256": "<sha256>",
  "dependency_closure": {"algorithm": "catalog-v1", "manifest_path": "closure.json", "manifest_sha256": "<sha256>", "content_sha256": "<sha256>"},
  "environment": {"app_env": "local", "api_host": "127.0.0.1", "ws_host": "127.0.0.1", "backend_profile": "<redacted-fingerprint>"},
  "device": {"id": "<redacted-or-id>", "platform": "android", "state_generation": "<fingerprint>"},
  "fixture": {"namespace": "<run/shard>", "marker": "<redacted>", "generation": "<fingerprint>", "accounts": "<anonymous-fingerprint>"},
  "result": {"status": "PASS", "executed": 1, "skipped": 0, "failed": 0},
  "command_fingerprint": "<sha256>",
  "artifacts": [{"path": "events.jsonl", "sha256": "<sha256>"}]
}
```

`dependency_closure` 只能由 catalog 的 `sources/dependencies`、runner 和相关配置确定性生成，不临时推断 Dart 全仓 import 图。精确 HEAD cache 与跨 HEAD compatibility rebind 是两个机制：HEAD 变化时 cache 必须 miss；只有 B/C 级纯单元/合同结果可在上述 closure/hash 全相等时生成指向最终 HEAD 的 rebind 记录。A 级真机、E2EE 和 `local-write` 证据必须在最终 App/Backend HEAD 上执行，并绑定 App build、runner 和配置 hash，不跨 commit 复用。不得写入密码、验证码、access token、私钥、完整手机号或未脱敏第三方标识。

`backend_head = NOT_APPLICABLE` 仅允许 target 的 requirements 中不存在任何 `backend.*`、API、WS、持久化或跨客户端 oracle；否则 schema 校验失败。`required_evidence_level` 的最低值由 capability 类型固定：纯函数/静态工具最低 C，App/Backend 合同最低 B，真客户端聊天、跨角色写入和本计划要求的全页面设备操作最低 A；spec 只能提高不能降低。

## 5. Token 预算规则

- 默认不读取全部页面 Markdown、完整 `task_state.json` 或历史 reports。
- catalog、状态和测试结果由脚本汇总；AI 只读取受影响 target 及其直接 source/dependency。
- 一个失败证据包最多包含 6 个源码文件、120 行日志、1 次最近 PASS 摘要和本次 diff。
- PASS 不进入 AI；同一 `(App HEAD, Backend HEAD, target hash, dependency hash, environment fingerprint, device)` 不重复分析。
- 单个工作包汇报不超过 120 行；日志只给首个失败、统计和证据路径，不粘贴完整输出。
- 不为已能由 stdlib、Flutter machine events 或 ImageMagick 判断的事项调用模型。

## 6. 执行波次

```text
Wave 0: Step 1 现有实现只读基线 + 匿名夹具
Wave 1: Step 2 目标/截图模块 || Step 3 结果解析模块 || Step 4 schema/policy 模块
Wave 2: Step 5 集成 Wave 1，接入 CLI、catalog 与双向资产发现
Wave 3: Step 6 状态、证据和缓存
Wave 4: Step 7 CI/统一验收入口
Wave 5: Step 8 框架当前 HEAD 收口
Wave 6: Step 9 全页面功能清单、领域 capability 矩阵、隔离夹具与零交互 preflight 决策快照
Wave 7: Step 10 E2EE 确定性门 || Step 12 Enterprise/Organization 合同门
Wave 8: Step 11 Android 真机 + macOS E2EE 协同路径
Wave 9: Step 13 Workspace/Group 真机多角色验收
Wave 10: Step 14 Android 页面 shards || macOS 页面 shards；最终单写者汇总
Wave 11: Step 15 当前 HEAD 总收口
```

并行上限按“同时活跃”计算，不限制会话内累计创建数：任一时刻包括 Coordinator 在内最多 8 个 active agent，因此最多 7 个 worker。已完成/停止的 agent 不计入上限；优先复用已有 agent。`RUN_ROOT/coordinator.json` 维护 agent_id、step、status 和 leases；每次创建前机器断言 `ACTIVE worker < 7`。只有依赖图同一 Wave 且文件、设备、后端和 fixture 租约互斥的工作才能并行。只有 Coordinator 可以创建 agent；每个 ready Step 默认只分配一个 primary worker，审查角色复用或在实现后串行执行，禁止把多个完整 `/ecc:orchestrate` chain 同时启动而突破上限。

启动时若发现另一个有效 active Coordinator 或 RUN_ROOT 与仓库/基线不匹配，本会话不得接管、创建 worker、获取共享 lease 或修改仓库。它只创建独立只读 blocked RUN_ROOT，采集不争用资源的 HEAD/status/coordinator/lease 摘要，并用已验收 renderer 生成本会话唯一 `test-report.html`；若 renderer 尚不可用，只可用 Python stdlib `html.escape` 的固定最小模板。Overall=`BLOCKED`，reason=`BLOCKED_ACTIVE_COORDINATOR` 或 `BLOCKED_RUN_ROOT_MISMATCH`。即使只读探测失败，也生成最小脱敏 BLOCKED HTML 后结束，不向用户提问。

当前 `scripts/auto_test.py` 共 801 行，同时承担 schema 校验、计划、执行、截图入口、页面发现、覆盖生成、视觉和报告职责。Wave 1 的三个 writer 必须各自只写新模块及自身测试：Step 2 可写 capture/target config，Step 3 可写 result parser/runner，Step 4 可写 schema/policy；三者均不得修改 CLI 入口 `scripts/auto_test.py`、公共 `__init__`、共享类型或 test helper。Coordinator 在 Wave 启动前写入精确 owned-path manifest；跨边界需求只记录给 Step 5。Step 5 是唯一公共 bootstrap/CLI 集成 writer。worker 不提交；Coordinator 在 Wave 结束、检查共享 diff 后按 Step 精确暂存和本地提交，并在该 commit HEAD 重跑本 Step Acceptance 后才生成权威证据。

运行资源使用显式 lease：`CONTROL_ENTRY`、`CATALOG_GENERATOR`、`DOC_GENERATOR`、`GIT_COMMIT`、`ANDROID_DEVICE:<id>`、`MACOS_DEVICE`、`BACKEND_EXEC`、`FIXTURE_NAMESPACE:<run/shard>`。lease 位于 `RUN_ROOT/leases/`，用原子目录创建获取，临时文件完整写入并 fsync 后原子 rename 为 `owner.json`；记录 run/step/agent/process/resource/acquired_at/heartbeat。heartbeat 最多间隔 30 秒，超过 120 秒只标记 stale，不自动抢占；无 owner、截断 JSON 或 schema 错误一律 `CORRUPT_LEASE` 并 fail closed。Coordinator 只有在确认原 agent/子进程/设备进程不活跃、核对 fixture 写入清单并记录 recovery 后才能接管。tooling tests 必须覆盖并发获取、空 owner、截断 owner、心跳、崩溃恢复和重复释放。Android 和 macOS 可各跑一个 shard，单设备不得开两个 Flutter/Patrol 进程；所有 Backend build/DB 命令共用 `BACKEND_EXEC` 串行。提交时仅 Coordinator 持 `GIT_COMMIT`，使用精确路径的仓库既有 scoped-commit 方法或 `git commit --only`，不得让 worker 争用 index。禁止并行 worker 共用账号、org/workspace 或 run marker 写数据。

## 7. 工作包台账

台账分两列：`scheduler_state` 只允许 `WAITING/READY/RUNNING/DONE/INTERRUPTED`；`scope_verdict` 只允许空值、`PASS/PARTIAL/BLOCKED`。

### 7.1 当前源码事实（Step 1 必须重采样）

以下是制定台账时从当前工作树实测得到的定位信息，不是可永久沿用的 PASS：

- `scripts/auto_test.py` 801 行，现有 25 份 JSON spec；`run()` 按 spec 循环，只按子进程退出码判定，重复 target 会重复启动。
- `scripts/capture_integration_screenshots.py` 111 行；Android/iOS 成功截图后仍访问未定义的 `shot.stdout`，且没有 macOS 截图实现。截图不是功能 PASS 的必要条件，Flutter machine event 与业务 oracle 才是。
- `scripts/run_test_suite.sh` 374 行，已有设备发现、本地 API 检查和分层运行；但它把 exit 0 直接记为 PASS，只自动选 Android/iOS，不执行 macOS，并且 quick 模式只发现 `test/unit_test`。
- `scripts/run_all_integration_tests.sh` 带固定设备、远程生产地址和账号默认值，且按日志关键词判断结果；必须由 Step 7 收编为 fail-closed 兼容入口，不能继续作为第二套 runner。
- 当前有 130 个 `integration_test/**/*_test.dart`，其中 106 个含 skip 标记、2 个含 TODO、仅 27 个含截图检查点；文件存在、历史“已通过”或退出 0 都不能证明本轮执行。
- 当前有 164 个 `lib/page/**/*_page.dart`；Organization、Enterprise、Customer Service 另有 9 个 `lib/modules/**/presentation/*_page.dart`，合计至少 173 个页面文件。现有 155 份页面台账/1748 行功能点遗漏上述 9 页，且不能覆盖动态菜单、弹窗或非 `_page.dart` 路由目标。
- 当前路由相关文件分布在 `lib/config/router/**` 及三个企业模块 route 文件，共发现 148 处 `GoRoute(`；产品 profile 是 `../imboy/config/product-feature-manifest.json` 的 `full-selected`，当前选择 13 个非 core feature。
- 当前两仓 HEAD 上执行 `python3 ../imboy/scripts/generate_product_features.py --check --require-profile full-selected` 会报告 `lib/config/router/generated_product_feature_routes.dart` 为 stale；`scripts/run_test_suite.sh` 在解析参数前就运行同一检查，因此当前 full/quick 入口会先被该跨仓漂移阻断。Step 1 必须重新取证，Step 5/7 只能把它建模为 profile-dependent targets 的 `BLOCKED_PRODUCT_DRIFT`，不得擅自重生成产品路由或绕过检查；这不是 scheduler `INTERRUPTED`，不阻断静态 inventory、框架实现和不依赖该 profile 的测试。
- App 企业合同测试实际位于 `test/organization/`、`test/enterprise/`、`test/customer_service/`，不全在 `test/unit_test/`；后端已有 `make e2ee-verify`、`make eunit-local t=...` 及 enterprise/customer-service feature matrix 脚本。
- `test/auto_test/reports/` 已被忽略，而 `task_state.json`、页面台账、25 specs 和三个 AI 索引是 tracked 历史资产；迁移必须保留读取兼容性，不批量伪造新 PASS。

### 7.2 工作包与所有权

`控制面` 包括 `scripts/auto_test.py` 及必要时拆出的 `scripts/auto_test_lib/**`；`tooling tests` 固定放在 `test/tooling/auto_test/**`，不得放需要设备的 Dart `*_test.dart` 到 `test/`。

| Step | 工作包与现有入口 | 直接依赖 | 独占写所有权 | scheduler_state | scope_verdict |
|---|---|---|---|---|---|
| 1 | 重采样两仓、页面/路由/测试/spec/skip/TODO 基线；建立五类匿名 machine-event 夹具与接口草图 | 无 | `test/tooling/auto_test/fixtures/**`、本 run 基线证据；App/Backend 其余只读 | READY |  |
| 2 | 修复 capture 未定义变量；统一 `auto_test.py` 与 capture 的最终 APP/API/WS/secret-free command 配置 | H:1 | capture/config 新模块、截图脚本和对应 tooling tests | WAITING |  |
| 3 | 用 machine events 判定 executed/skipped/failed；按 target 合并 spec，只执行一次；统一 report 退出码 | H:1 | runner/result/report 新模块及 tooling tests | WAITING |  |
| 4 | 把现有自由文本 `runner.requires`、`safe_to_execute` 和 P0/P1/P2 风险迁移为有限枚举与 fail-closed preflight | H:1 | schema/policy/迁移新模块、fixtures 与 tests | WAITING |  |
| 5 | 集成 Wave 1；发现 routes、页面、integration targets 和动态入口并生成唯一 catalog/impact | H:2, H:3, H:4 | `scripts/auto_test.py` 唯一公共/CLI writer、spec 迁移、discovery/catalog/impact 及生成物 | WAITING |  |
| 6 | 迁移 state/evidence/cache；缓存绑定两仓、目标、环境、设备和 fixture | H:5 | state/evidence/cache 模块、`test/auto_test/state/**`、迁移/脱敏/cache tests | WAITING |  |
| 7 | 让 CI、两个旧 runner 复用同一 gate/result parser；删除硬编码远程/账号/device 默认行为 | H:6 | gate、runner、`.github/workflows/quality.yml`、测试文档及 tooling tests | WAITING |  |
| 8 | 框架当前 HEAD 轻量双跑和兼容冒烟 | H:7 | 默认只读；仅可修 Step 1-7 引入的控制面/测试回归 | WAITING |  |
| 9 | 生成全功能 inventory/领域矩阵、运行时发现合同和隔离 fixture；补企业模块缺失台账 | H:8 | inventory/domain/fixture 生成器与 tests、两个 JSON 和企业台账 | WAITING |  |
| 10 | 运行 App E2EE 与 Backend `make e2ee-verify`/所需真 PG 模块 | H:9 | App 可与 Step 12 并行；Backend 持 `BACKEND_EXEC`；只可改控制面/夹具/编排 | WAITING |  |
| 11 | 执行跨平台 E2EE；在 D2 满足时补 C2C/C2G 真聊天 A 级证据 | S:10, H:9 | E2EE tests/spec、设备 runner 和脱敏证据；不得用默认设备 ID | WAITING |  |
| 12 | 执行企业 App 合同、Backend scoped EUnit 与 feature-matrix | H:9 | App 可与 Step 10 并行；Backend 持 `BACKEND_EXEC`；企业测试/spec | WAITING |  |
| 13 | Android/macOS 执行 Workspace/Group 多角色、跨租户和协作路径 | H:9, S:11, S:12 | Workspace/Group tests/spec、设备 runner、D2 fixture 与证据 | WAITING |  |
| 14 | Phase A 单 writer 补测试并做 20 页试点；Phase B 按稳定 shard 全量执行并深测 Channel/Moment/Project | H:9, S:10, S:11, S:12, S:13 | Phase A 单 writer；Phase B 两个只读平台 worker 写独立 shard，Coordinator 独占汇总 | WAITING |  |
| 15 | 当前 HEAD 双跑、inventory/domain 零差集、八域裁决和唯一 HTML 报告 | S:8, S:10, S:11, S:12, S:13, S:14；always-run | 默认只读 finalizer；只生成 ignored `RUN_ROOT/test-report.html` | WAITING |  |

允许重构整个 auto-test 测试资产，但授权边界是测试控制面、测试代码、规格、台账和证据合同；`lib/**`、`../imboy/src/**`、迁移、运行中后端和真实业务数据仍不属于自动修改范围。若稳定定位必须新增产品侧 `Key`/`Semantics` 或注入点，记录具体 source/control 为 `BLOCKED_TESTABILITY`，不得在本计划内顺手修改产品代码。

## 8. Step 验收

## Step 1

### 基线和夹具

记录但不修改当前实现：

```bash
git rev-parse --show-toplevel
git rev-parse HEAD
git status --short
git -C ../imboy rev-parse --show-toplevel
git -C ../imboy rev-parse HEAD
git -C ../imboy status --short
python3 scripts/auto_test.py validate
python3 -m py_compile scripts/auto_test.py scripts/capture_integration_screenshots.py test/auto_test/regen_readme.py
find integration_test -type f -name '*_test.dart' | sort | wc -l
find lib/page -type f -name '*_page.dart' | sort | wc -l
find lib/modules -path '*/presentation/*' -type f -name '*_page.dart' | sort | wc -l
find test/auto_test -mindepth 2 -maxdepth 2 -type f -name '*_page.md' | sort | wc -l
rg -n 'GoRoute\(' lib/config/router lib/modules/{organization,enterprise,customer_service}/presentation | wc -l
rg -l 'markTestSkipped|skip:' integration_test -g '*_test.dart' | wc -l
rg -l 'TODO' integration_test -g '*_test.dart' | wc -l
```

同时把两仓启动时已有 dirty/untracked 路径、`git diff --binary`、`git diff --cached --binary` 的 SHA-256 和 untracked 文件逐文件 SHA-256 写入基线 manifest，后续只比较哈希，不读取无关内容；这用于证明任务没有吸收、覆盖或清理既有改动。生成供后续单元测试使用的最小匿名夹具：Flutter machine events 的 PASS、全 SKIP、PASS+SKIP、FAIL、runner crash 五类。夹具不得来自含凭证的真实日志。

Step 1 同时冻结 Wave 1 接口草图：`effective_target_config` 输入/输出字段、machine-event parser 的 record/result 类型、requirements/risk 枚举和错误码；只定义最小 JSON/dataclass 合同，不创建共享实现文件，避免 Step 2/3/4 各自发明接口。

Acceptance：

- `ATF-001`：记录 App/Backend HEAD、两个工作树及既有 dirty/untracked 哈希，以及当次 specs、integration tests、`lib/page` 页面、模块化页面、路由、台账、skip/TODO 数量与集合差；当前观测值只作对照，不写死为未来基线。
- `ATF-002`：五类 machine-event 夹具无凭证、可由 stdlib JSON parser 读取。
- `ATF-003`：未启动设备、网络、Flutter 测试或视觉模型。

Out of scope：修改生产代码、修复测试框架、更新页面台账状态。

## Step 2

### 截图和最终目标一致性

先写失败测试，再做最小修复：

- 删除成功采集后的未定义变量访问，Android/iOS 成功路径均只写一次目标文件。
- 提取一个共享命令构造函数，让 `run` 和 `capture` 使用同一份 APP/API/WS/密钥 override。
- preflight 校验的是即将传给子进程的最终配置；`APP_ENV=pro + local preflight URL` 等不一致组合必须 BLOCKED。
- 本地 Erlang/OTP/Cowboy 后端只允许只读探活与版本/配置指纹采集；本计划不负责启动、停止、迁移或修改后端。
- 命令、日志和 manifest 不得包含凭证明文。

Acceptance：

- `ATF-101`：模拟连续两个 checkpoint，保存 2 张截图且无 `NameError`。
- `ATF-102`：父子进程的 APP/API/WS 指纹一致；目标不一致测试失败关闭。
- `ATF-103`：远程目标、缺凭证、缺设备均在启动子进程前 BLOCKED。

Out of scope：真机截图、视觉基线、修改 Flutter 业务测试。

## Step 3

### 可信结果和唯一 target

- 使用 `flutter test --machine` 或等价结构化事件，不靠退出码或日志关键词判 PASS。
- 把五类夹具映射为第 4 节状态；0 个 executed 永远不能 PASS。
- 一次计划按 target 去重执行；case 只映射结果，不重复启动同一文件。
- 同一 target 若风险、runner type 或关键 requirements 冲突，`validate` 返回 64。
- `render-report` 返回与总结论一致的退出码。
- 在 report 模块实现唯一 stdlib HTML renderer；Step 3 用匿名 fixture 验证，Step 15 只调用该已验收 renderer，不临时拼接报告。

Acceptance：

- `ATF-201`：全 SKIP + exit 0 => `BLOCKED`，不是 PASS。
- `ATF-202`：PASS+SKIP => `PASS_WITH_SKIPS`/退出 2；`INFRA_FAIL -> PASS` => `FLAKY`/退出 2；三次同指纹 `INFRA_FAIL` => `BLOCKED/INFRA_RETRY_EXHAUSTED`；业务断言 FAIL 零重试/退出 1；HEAD/target/config/fixture/device 指纹变化开启新 attempt sequence。
- `ATF-203`：25 specs 中重复 target 只计划一次；冲突安全属性必须由测试证明被拒绝。
- `ATF-204`：stdlib HTML renderer 对动态文本转义、secret/PII 负向、稳定排序和重复生成字节一致；RUN_ROOT 面向用户的 `.html/.md` 报告扫描结果只有 `test-report.html`。

至少一份 parser 夹具必须由本地无设备 `flutter test --machine` 的真实输出脱敏派生并记录生成命令；纯手写 JSON 只覆盖负向边界。每个 required target 必须在 spec 中声明 `oracle_type` 和机器可观察完成条件；静态检查要求 Dart target 含 `expect/expectLater` 或白名单 oracle helper，运行结果要求 `oracle_count >= 1`。仅启动 App、导航成功、截图存在或进程 exit 0 的 target 必须拒绝为 PASS。退出码只作总闸，调用方必须读取 result JSON 的 `test_status`、`reason_code` 和 counts。

另提供三类重试序列夹具：`INFRA_FAIL -> PASS` 必须为 `FLAKY`；连续三次同指纹 `INFRA_FAIL` 必须为 `BLOCKED/INFRA_RETRY_EXHAUSTED`；业务断言 `FAIL` 必须零重试。HEAD、target、config、fixture 或设备状态指纹变化时必须开启新 attempt sequence，不能拼接成重试。

Out of scope：改写现有 130 个集成测试内部断言。

## Step 4

### requirements 和安全门

允许的 requirement 必须是有限枚举，例如：

```text
device.android | device.ios | device.macos
credentials.primary | credentials.peer
backend.local | backend.strict_e2ee
fixture.existing_group | fixture.disposable_account
authorization.business_write | authorization.external_readonly
```

风险模式固定为：`pure-local`、`device-readonly`、`local-write`、`external-impact`。

- 未知 requirement 或风险值在 validate 阶段失败。
- `local-write` 只允许解析后的全部地址都是本机 loopback（`127.0.0.0/8`、`::1`）或明确的本机 Unix socket；`private/dev` 只能作为附加 profile 标签，不能证明本机授权，任何非 loopback 地址都命中 `H2_REMOTE`。
- 后端参与的用例必须记录 Backend HEAD、API/WS host 和不含秘密的 profile fingerprint；无法确认后端身份时 BLOCKED。
- `external-impact` 的通用 runner 永远 BLOCKED；本计划不在执行期请求追加授权，环境变量也不能放宽边界。
- requirements 不满足时不得启动 Flutter、ADB、Patrol 或网络请求。

Acceptance：

- `ATF-301`：每个 requirement 有通过/缺失测试，未知值 fail closed。
- `ATF-302`：生产/远程写 target 即使设置通用 allow env 也不会自动执行。
- `ATF-303`：现有 specs 完成显式迁移，不能静默赋予更宽权限。

Out of scope：获取真实账号、决定联系方式、联系或影响第三方。

## Step 5

### catalog 和双向发现

建立 `test/auto_test/catalog.json`，一条记录对应一个唯一 target。catalog 至少包含 id、target、sources、dependencies、risk、requirements、tags、enabled；排除项包含 path、`exclusion_code` 和 details。`exclusion_code` 只允许 `PLATFORM_NA`、`FEATURE_DISABLED`、`UNREACHABLE_DEAD_CODE`、`DUPLICATE_EQUIVALENCE`；环境不足、缺账号、产品缺陷、TODO、skip 和测试不可定位都必须 `BLOCKED`，不能排除。

- 扫描全部 `integration_test/**/*_test.dart`，每个文件必须 catalogued 或 excluded。
- 扫描全部 `lib/page/**/*_page.dart`、`lib/modules/**/presentation/*_page.dart` 和已注册 route target；每个页面/路由目标必须 mapped 或 excluded。
- 校验台账首个页面路径存在，报告台账内部混入 provider 等非页面路径，但不强制一行只能引用页面。
- catalog 和覆盖 Markdown 使用稳定排序；`--check` 只比较，不改文件。
- impact 只用于 Step 1-8 和缺口修复回路的快速回归：输出变更直接命中的唯一 targets，再补固定 smoke 集；未映射源码显式 FAIL。它不能替代 Step 14 最终全量遍历，也不要求构建 Dart 全仓 import 图。

Acceptance：

- `ATF-401`：Step 1 当次发现的全部 integration test 文件均 catalogued/excluded；数量或集合漂移会使 CI 失败。
- `ATF-402`：Step 1 当次发现的 `lib/page`、模块化 presentation 页面及 route target 全部 mapped/excluded，缺失和反向悬空均为 0。
- `ATF-403`：连续生成两次字节一致，`catalog --check` 和覆盖生成物 `--check` 通过。

Out of scope：为每个页面补 E2E、修改 155 份台账中的历史测试结论。

## Step 6

### 状态、证据和缓存

- 保留现有 `task_state.json` 作为历史输入，不在迁移中丢失内容；新执行不再向其追加批次顶级字段。
- 新增稳定 state/evidence schema。运行态放 ignored reports；只有明确收口的候选 manifest 才允许进入已跟踪证据目录。
- fresh clone 从 catalog 得到完整 UNKNOWN 计划，不依赖被忽略的 STATUS/FINAL_REPORT。
- 精确 cache 键绑定 App/Backend HEAD、target/runner/config/dependency hash、API/WS/profile、设备/平台和 fixture 版本；任一 HEAD 或输入变化都必须 miss。A 级或 `local-write` 结果还绑定当前 RUN_ID、fixture namespace、run marker、角色/账号匿名指纹、seed/reset generation 和设备/E2EE session state generation，不得跨 run 或 commit 复用。
- compatibility rebind 不是 cache hit：只允许 B/C 级纯单元/合同证据在 evidence HEAD 为最终 HEAD 祖先、closure/runner/config/environment 内容哈希完全相同时，生成新的 rebind 记录；A 级、E2EE 真客户端和 `local-write` 必须在最终两仓 HEAD 重跑。两种机制必须调用同一判定函数并有正负测试。

Acceptance：

- `ATF-501`：缺少历史 reports 时仍能生成完整计划。
- `ATF-502`：精确 HEAD/输入相同才命中 cache；任一 HEAD、源码、测试、环境或设备变化都会 miss；B/C compatibility rebind 只在完整 closure 哈希相同通过，A/local-write 永远拒绝 rebind。
- `ATF-503`：状态、证据和 lease schema 拒绝凭证字段、未知状态、缺失 closure/hash、非法 `NOT_APPLICABLE`、降级证据等级、空/截断 owner 和重复 lease。

Out of scope：删除历史 reports、伪造旧证据、把旧 HEAD 的 PASS 提升为当前 PASS。

## Step 7

### CI 和统一验收入口

新增一个 stdlib/现有工具即可运行的统一 gate，例如：

```bash
bash scripts/check_auto_test_framework.sh
```

它至少串行执行：

```text
Python tooling unit tests
auto_test validate --strict
catalog --check
generated docs --check
credential/redaction negative tests
py_compile
git diff --check
```

CI 的无设备 job 只运行该 gate；不得在 PR job 中隐式启动设备、远程后端或视觉模型。`scripts/run_test_suite.sh` 复用同一 gate，不复制判断逻辑。旧 `scripts/run_all_integration_tests.sh` 必须改成调用统一 runner 的兼容壳或明确退役；不得保留固定设备、远程生产地址、账号默认值和日志关键词 PASS 判定。

Acceptance：

- `ATF-601`：本地统一 gate 连续两次退出 0，第二次不产生 diff。
- `ATF-602`：注入缺页、未知 requirement、全 SKIP 假绿、target 冲突和凭证字段时 gate 分别失败。
- `ATF-603`：CI 与本地调用同一入口；无网络/设备也能完成框架验收。

Out of scope：实际运行 Android/iOS/Patrol、修改发布流程。

## Step 8

### 框架当前 HEAD 验收

在所有写步骤完成后重新基线，执行统一 gate，并由独立审查 agent 只读核对：

```bash
git rev-parse HEAD
git status --short
bash scripts/check_auto_test_framework.sh
python3 scripts/auto_test.py plan --phase p0
git diff --check
```

检查文档命令、`--help`、错误退出码、证据脱敏、fresh-clone 逻辑和旧入口兼容性。不得为了得到绿色结论而放宽 fail-closed 规则。

Acceptance：

- `ATF-701`：ATF-001 至 ATF-603 均有命令、退出码、摘要和证据路径。
- `ATF-702`：本任务新增 diff/提交只包含计划拥有文件；启动前已有无关 dirty 项已记录且字节不变，无凭证、日志、截图或未授权业务改动。
- `ATF-703`：框架结论只能为 `PASS`、`PARTIAL` 或 `BLOCKED`；不得用框架 PASS 声称 E2EE 或企业功能 PASS。

Out of scope：本 Step 不执行真机产品验收、远程环境验收、发布判定和 push。

## Step 9

### 全页面功能清单、领域 capability 矩阵与隔离夹具

新增可机读的 `test/auto_test/functional_inventory.json`。每行至少包含 `function_id`、`page`、`route_or_entry`、`source`、`control`、`action`、`expected_oracle`、`platforms`、`requirements`、`fixture`、`test_target`、`disposition`、`exclusion_code` 和 details。`disposition` 只允许静态 `required/excluded`，排除码使用 Step 5 同一枚举，不得保存本轮 PASS/BLOCKED；运行结果只写 ignored `RUN_ROOT/results/**`。生成器必须扫描路由注册、`lib/page/**/*_page.dart`、`lib/modules/**/presentation/*_page.dart`、页面台账、feature manifest、可静态识别的菜单/弹窗入口和现有 integration tests；机器先产出静态集合差，AI 只审核无法静态判断的语义。页面存在但没有功能项、功能没有 oracle、target 或平台归属时校验失败。

另新增 `test/auto_test/domain_coverage.json`，每行至少包含 `capability_id`、`feature_key`、`domain`、`positive`、`negative`、`recovery`、`app_targets`、`backend_targets`、`required_evidence_level`、`requirements`、`fixture`、`disposition`、`exclusion_code` 和 details。matrix 同样只保存声明性要求，不保存运行 verdict；它必须从 `../imboy/config/product-feature-manifest.json` 和已生成的 App feature registry 取当前 `full-selected`/enterprise 启用集合；每个启用 feature 都必须映射至少一个 capability 或带枚举原因明确排除。设备执行发现清单外可交互入口时立即写 `RUN_ROOT/results/new_entries.jsonl` 的 `NEW_ENTRY`，当前项不得 PASS，并触发 Step 14 的有界 late-repair barrier。

证据等级固定为：

- `A`：Android/macOS 真客户端 -> 隔离后端 -> 对端/持久化的黑盒证据。
- `B`：当前 HEAD 可重放的 App/Backend 集成或合同测试。
- `C`：单元/组件/纯函数测试。
- `D`：文档、TODO、测试名、历史报告或静态推断，不可单独 PASS。

生成器按第 4.3 节 capability 类型推导最低证据等级；spec 只能上调。任何手工降低、缺失 App/Backend target 或用 D 级填充 B/A 要求都使 `domain --check` 失败。

Wave 6 结束时自动生成零交互 preflight 决策快照，把当前 route drift、本地 Backend 身份/可用性、D2 专用账号与 fixture 可用性映射到具体 target/capability/shard。无法满足的项直接标 `BLOCKED` 并给出安全替代，其他项继续；不得暂停等待用户输入。

必须覆盖的 capability 集：

- E2EE：policy/plaintext rejection、C2C Olm、C2G Megolm + room-key-over-Olm、multi-device fan-out、OTK/fallback/rotation、identity/trust change、replay/tamper/order、attachment、backup/recovery、history/member boundary、log/metadata privacy。
- Enterprise/Organization：organization lifecycle、owner/member/department/invitation、default Workspace、enterprise identity/contact/conversation/message/asset、CS queue/claim/transfer/close/rating、suspend/offboarding/retention/audit。
- Workspace/Group：workspace create/switch/archive/isolation、member/role/invite、group create/join/remove/transfer/mute、group E2EE、notice/task/vote/schedule/file/album/tag/category、跨租户 IDOR 与反向悬空。
- Channel：create/edit/delete、admin/subscriber/invitation、publish/edit/revoke/pin/reaction/comment、discover/search/sync/unread、workspace binding、付费订单仅做隔离 mock/本地 fixture，不真实支付。
- Moment：create/feed/detail/delete、visibility、like/comment/reply/mention、media/draft/retry、notify/report、朋友/非朋友/私密可见性边界。
- Project：create/update/status、member/invite/remove/owner transfer、task create/assign/status、milestone、channel link/unlink、pinned/resources/activity/related-posts 聚合与 workspace 边界。

Acceptance：

- `DOM-001`：当前所有可达页面与用户可见功能均在 functional inventory 中；页面、功能、target 和平台适用性可双向追溯，遗漏或无理由排除使校验失败。
- `DOM-002`：当前 `full-selected`/enterprise 启用 feature 与上述 capability 全部在 matrix 中可双向追溯；App/Backend target 均存在，TODO/skip/skeleton 在 `RUN_ROOT` 结果中归为 `PLANNED/BLOCKED`，不会写回 tracked matrix。
- `DOM-003`：隔离 fixture 合同至少定义六个匿名账号别名：org A 的 owner/admin/member/nonmember、org B 的 owner/member，其中两名为互异 C2C/C2G 设备身份；每个并行 shard 使用独立 namespace、账号集、org/workspace 和 marker。账号不足时串行或 BLOCKED，不共享写 fixture；合同不含凭证。

Out of scope：创建真实账号或数据、修产品缺陷、把 D 级证据升为 PASS。

## Step 10

### E2EE App/Backend 确定性安全门

按 Step 9 matrix 运行现有客户端 E2EE 专项单元/集成测试和后端 E2EE EUnit/合同测试。后端源码保持只读，命令必须从 `../imboy` 执行并记录 Backend HEAD。

必须验证 fail-closed：明文降级被拒绝、错误设备/身份/签名被拒绝、replay/tamper 被拒绝、C2C 不误用 Megolm、C2G room key 按设备分发、附件/备份/恢复不泄密、群历史不穿越成员边界。

Acceptance：

- `E2EE-001`：App 和 Backend 映射的 B/C 级测试均实际执行，证据绑定两仓 HEAD，0 skip/0 fail。
- `E2EE-002`：明文降级、replay/tamper、错身份/设备、跨成员历史和日志泄密的负向测试全部 fail closed。
- `E2EE-003`：任一未执行、skip、TODO 或只有 D 级证据的 capability 留在 `BLOCKED/PLANNED`，不会拉高总结论。

Out of scope：修改 Erlang/Flutter 产品逻辑、启停后端、使用真实用户数据。

## Step 11

### Android 真机 + macOS E2EE 人工路径自动化

先用 `flutter devices` 确认当次 Android 真机 ID 和 macOS target，禁止使用 Android 模拟器或脚本内的过期默认 ID。先执行不连后端、不登录、不写业务数据的跨端互操作：

```bash
ANDROID_DEVICE_ID=<listed-android-id> bash scripts/run_cross_platform_e2ee_interop.sh
ANDROID_DEVICE_ID=<listed-android-id> bash scripts/run_cross_platform_e2ee_group_interop.sh
```

若已有当次可验证的本地隔离 Erlang 后端、两个明确归属的专用测试账号和可销毁 fixture，再按 matrix 执行 C2C/C2G 真聊天路径：Android 发送 -> macOS 接收/解密/回复 -> Android 接收/解密 -> 重启后重进会话。同时取证 UI 明文、WS/ACK、本地密钥/消息持久化和后端仅存密文。任一前置无法确认时停在 `BLOCKED`，不自行启动/迁移后端，不使用他人账号。

Acceptance：

- `E2EE-101`：Android/macOS C2C Olm/PFv3 和 C2G Megolm/Olm 离线互操作实际执行，0 skip/0 fail，证据含脱敏设备指纹。
- `E2EE-102`：满足隔离前置时，C2C/C2G 双向真聊天、重启重进和后端密文检查均 PASS；不满足时精确 `BLOCKED`。
- `E2EE-103`：截图/日志/证据不含密钥、token、密码、完整手机号或真实联系人，不上传外部模型。

Out of scope：iOS、远程/生产后端、未确认归属账号、修产品缺陷。

## Step 12

### Enterprise/Organization 合同与租户边界

在无设备阶段运行 `test/organization/`、`test/enterprise/`、`test/customer_service/` 以及 Workspace/Group 相关 App 单元/合同测试与 Backend scoped EUnit/集成测试；从 App 仓执行 `../imboy/scripts/enterprise_business_feature_matrix.sh` 和 `../imboy/scripts/customer_service_feature_matrix.sh` 验证编译裁剪，不另造 feature matrix。覆盖 organization owner/member/department/invitation/default workspace，enterprise identity/contact/conversation/message/asset/CS，以及 workspace/group 的 scope、role、archive、member subset 和 IDOR 负向路径。

`integration_test/enterprise/enterprise_cs_e2e_test.dart` 等含 `TODO`、skeleton 或默认 skip 的文件只能作为缺口证据，不得因为文件存在或命令退出 0 而 PASS。

Acceptance：

- `ENT-001`：Organization/Enterprise 的 App 和 Backend B/C 级测试都在当前两仓 HEAD 执行，租户/身份/角色负向路径不少于正向 capability 的对应边界。
- `ENT-002`：owner invariant、默认 Workspace、成员生命周期、enterprise message/asset/CS、suspend/offboarding/retention 均有实际断言或明确 `BLOCKED`。
- `ENT-003`：跨 org/workspace 访问、非成员、降权后旧 token、已归档/暂停租户路径 fail closed；TODO/skeleton/skip 不假绿。

Out of scope：修改 Backend 产品代码、执行生产数据迁移、把企业用例骨架冒充完整 E2E。

## Step 13

### Enterprise/Workspace/Group 真机多角色验收

复用 Step 9 的隔离 fixture，在 Android 真机和 macOS 上按人工用户路径验收：登录 -> Personal/Workspace 切换 -> Organization/Workspace 选择 -> 项目/频道/群浏览 -> 角色可见性 -> 本地测试数据写入 -> 对端接收 -> 降权/切换/重启后重验。

至少覆盖 owner/admin/member/nonmember 四角色，org A/B 和 workspace A/B 交叉租户边界，以及 Group 的 create/join/remove/transfer/mute、E2EE、notice/task/vote/schedule/file/album/tag/category。每个业务写用唯一 marker 并仅命中专用 fixture；清理只允许删除本 run marker 创建的数据。

Acceptance：

- `WG-001`：Android/macOS 均走过 Personal/Workspace 切换、工作区选择、群/频道/项目导航、重启恢复，无静默 skip。
- `WG-002`：owner/admin/member/nonmember 权限和 org/workspace/group 租户隔离的正负路径都有 UI + API 双证据，跨 scope/IDOR 请求被拒绝。
- `WG-003`：Group 协作核心 capability 均已执行或在 matrix 中以具体环境/产品缺口 `BLOCKED`；无真实第三方影响。

Out of scope：远程/生产租户、真实员工或联系人、不可逆清理、修产品缺陷。

## Step 14

### 全页面一次遍历与 Channel/Moment/Project 真机业务闭环

Step 14 分两阶段。Phase A 由唯一 repair writer 根据 inventory 补齐/修正测试与 spec，局部验证后提交，并在该 commit HEAD 重跑相关 Acceptance；随后冻结测试源码、inventory 和 runner。先选取覆盖简单展示、表单、列表、媒体、企业、E2EE 的 20 页代表性 pilot，在 Android/macOS 各执行一次。pilot 使用独立 `FIXTURE_NAMESPACE:<run/pilot/platform>`，但与正式 shard 使用完全相同的冻结 runner/oracle，标记 `CALIBRATION_AND_COVERAGE`：有效结果计入 FULL-002，Phase B 必须排除这些 function/platform 对，避免重复。每个平台至少取得 30 个 function duration 样本，不足则扩展 pilot；记录 setup/P50/P95、失败率和设备分钟数，再按 30-45 分钟/device 自动计算 shard。若后续提交改变最终 HEAD，pilot 与其他 A 级证据一并失效重跑。

Phase B 才全量模拟人工操作：两个设备 worker 仅读仓库，分别只写 `RUN_ROOT/shards/android/**` 和 `RUN_ROOT/shards/macos/**`，Coordinator 持 `DOC_GENERATOR` 独占汇总。每个平台 shard 使用独立 `FIXTURE_NAMESPACE:<run/platform/shard>`、账号集、org/workspace 和 marker；跨设备共享对象的 journey 由一个 worker 同时持两个设备 lease 串行执行，禁止两个并行 worker 共享写 fixture。首次 `NEW_ENTRY`/测试缺口触发唯一一次 late-repair barrier：暂停全部设备 worker，集中修复、提交、冻结 v2，清空并重跑此前所有 A/E2EE/local-write 结果（含 pilot）。冻结 v2 后再发现缺口只记 `BLOCKED_DISCOVERY_GAP` 并继续其他项，不再提交或形成无限修复循环。设备 worker 不直接改测试、spec、inventory 或 runner。

从正常产品入口进入每个页面，对每个适用的 `function_id` 执行一次操作并断言 `expected_oracle`，然后返回、重进或切换到下一项。禁止仅调用 widget、route 或测试 helper 绕过真实 UI；同一共享功能等价类允许复用一条证据，但证据必须反向关联所有被核销项。平台不适用、环境不足或产品缺陷必须逐项记录，不能静默 skip。Step 11/12/13 的 `BLOCKED/PARTIAL/FAIL` 只阻断明确依赖对应 fixture/capability 的 function shard，其他页面和只读功能继续执行。

在各 shard 自己的隔离 fixture 上，再执行三组可重放高风险人工路径：

- Channel：创建 -> 编辑 -> 管理员/订阅/邀请 -> 发布 -> 评论/反应/置顶/撤回 -> 未授权角色拒绝 -> 重启后持久化。付费频道只使用 mock 支付或本地可逆 fixture，不调用真实支付。
- Moment：发布文字/本地测试媒体 -> feed/detail -> like/comment/reply/mention -> visibility 边界 -> 删除/失败草稿/重试 -> 通知去重。
- Project：create -> member/owner/role -> task/assignee/status -> milestone -> channel link -> pinned/resources/activity/related-posts -> archive/scope 负向 -> 重启恢复。

每条路径必须同时检查 UI、API 结果、本地持久化和跨角色/跨 workspace 不可见性。只能操作当次 run marker 所有的数据。

重试只用于分类明确的基础设施失败（设备断连、runner 在测试体前崩溃、ADB/Flutter transport timeout），同一不变输入最多自动重试 2 次；业务断言、权限拒绝和安全负向失败不重试。基础设施重试后通过仍标 `FLAKY`；三次均未进入可靠测试体则标 `BLOCKED` 且 `reason_code=INFRA_RETRY_EXHAUSTED`。保存各次事件并继续其他 shard，不得靠重试把不稳定结果提升为 PASS。

Acceptance：

- `FULL-001`：当前所有可达页面、入口和用户可见功能都有稳定 `function_id`、操作、oracle、平台和 target；清单双向差集为 0，无理由排除为 0。
- `FULL-002`：Android 真机和 macOS 上每个适用 `function_id` 恰有一次本轮执行结果与脱敏证据；0 executed、静默 skip、截图存在但无结果断言均不能 PASS。
- `FULL-003`：执行可按 shard 续跑且不重复已通过项；按平台精确给出 discovered/applicable/pass/fail/flaky/blocked/excluded 数量和非 PASS ID，并验证 `discovered = applicable + excluded`、`applicable = pass + fail + flaky + blocked`，最终 `PLANNED/UNKNOWN = 0`，不让 AI 重读 PASS 日志。
- `CPM-001`：Channel 创建/管理/发布/互动/订阅/邀请/持久化与权限负向路径均有 Android/macOS + API 证据，付费不产生真实资金影响。
- `CPM-002`：Moment 发布/feed/互动/可见性/删除/草稿恢复/通知去重均有正负证据，私密和非朋友内容不泄漏。
- `CPM-003`：Project 成员/任务/里程碑/频道关联/聚合/归档与 workspace 隔离均实际执行或明确 `BLOCKED`，无静默 skip。

Out of scope：真实支付、远程/生产数据、真实好友/订阅者通知、不可逆清理、修产品缺陷。

## Step 15

### 当前 HEAD 总收口

重新记录 App/Backend HEAD 和工作树，连续两次执行统一框架 gate，并运行 functional inventory/domain coverage `--check`。逐项验证证据：B/C 证据若不是最终 HEAD，只能按第 4.3 节生成 compatibility rebind；A/E2EE 真客户端/`local-write` 必须是最终两仓 HEAD，否则重跑。即使上游存在 BLOCKED/FAIL/INTERRUPTED，本 Step 也必须执行并生成整个会话唯一的报告文档 `RUN_ROOT/test-report.html`，不得再生成其他面向用户的 Markdown 或 HTML 总结文档。

`test-report.html` 必须是可离线打开、无外部资源的 UTF-8 单文件，由 stdlib 对结构化证据确定性生成并转义所有动态文本；包含两仓 HEAD/dirty 基线、执行环境、pilot 估算与实际耗时、Step 1-15 状态/commit、Acceptance 证据、八域 verdict、页面/function 精确计数、FAIL/FLAKY/BLOCKED/NEW_ENTRY、需要用户决定的事项和证据相对链接。报告不得嵌入 token、密码、私钥、完整手机号、真实联系人或截图二进制；重复生成字节一致。

Acceptance：

- `FINAL-001`：所有 Acceptance ID 均有命令、退出码、摘要、当前两仓 HEAD 和证据路径/hash；无无主、过期或仅 D 级 PASS。
- `FINAL-002`：functional inventory 每个适用项和 domain matrix 每个 required capability 是 `PASS` 或有可复现原因的 `BLOCKED`；缺失、UNKNOWN、skip、TODO 或无证据排除使全量/对应领域不得 PASS。
- `FINAL-003`：双跑 gate 退出 0 且第二次不新增 diff；本任务新增 diff/提交只含计划拥有文件，启动前无关 dirty 项保持字节不变，无凭证/用户数据/未授权改动，无 push。
- `FINAL-004`：只生成一个面向用户的 `test-report.html`；离线打开结构完整，八域/计数/阻塞/需决策项与结构化证据一致，HTML 转义与脱敏负向测试通过，重复生成字节一致。

Out of scope：修复新发现的产品缺陷、远程验收、视觉基线审批、发布判定和 push。

## 9. 自动验收矩阵

| Acceptance | 自动化方法 | 证据 |
|---|---|---|
| ATF-001 | 两仓 HEAD/status/count/diff manifest 重放 | baseline manifest + staged/unstaged/untracked SHA-256 |
| ATF-002 | 五类匿名 fixture JSON 解析 + secret pattern scan | unittest 输出 + fixture hash |
| ATF-003 | Flutter/ADB/Patrol/网络子进程与套接字前后差分 | 本 run 新增 child/socket manifest 均为空 |
| ATF-101/102/103 | Python mock/subprocess 单元测试 | unittest 输出 |
| ATF-201/202/203/204 | machine-event/retry fixtures + runner/HTML renderer 单元测试 | 结构化结果 JSON + deterministic HTML |
| ATF-301/302/303 | requirement/risk 参数化负向测试 | unittest 输出 |
| ATF-401/402/403 | catalog 双向集合差和重复生成 | catalog check 输出/hash |
| ATF-501/502/503 | 临时目录 fresh-state/cache/schema 测试 | unittest 输出 |
| ATF-601/602/603 | 统一 gate 自检和负向 fixture | gate summary |
| ATF-701/702/703 | 框架收口 | framework summary |
| DOM-001/002/003 | 页面/功能清单 + manifest/matrix 双向差集 + fixture schema | inventory/domain coverage report |
| E2EE-001/002/003 | App E2EE 专项 + Backend EUnit/合同测试 | B/C 级结构化证据 |
| E2EE-101/102/103 | Android/macOS 互操作 + 隔离真聊天 | A 级脱敏设备证据 |
| ENT-001/002/003 | Enterprise/Organization App + Backend 合同/负向测试 | tenant/role evidence |
| WG-001/002/003 | Android/macOS Workspace/Group 多角色流程 | UI + API + persistence evidence |
| FULL-001/002/003 | Android/macOS 全页面功能一次遍历 | per-function events + inventory summary |
| CPM-001/002/003 | Android/macOS Channel/Moment/Project 业务闭环 | UI + API + scope evidence |
| FINAL-001/002/003/004 | 当前 HEAD 双跑 gate + 领域裁决 + 单文件报告校验 | `RUN_ROOT/test-report.html` |

建议 Python 测试目录：`test/tooling/auto_test/`。只能使用 Python stdlib，不引入 pytest、JSON Schema 包或 mock server 依赖。

## 10. 已授权范围与零介入决策

本轮已授权：

- `D1_ANDROID_MACOS`：使用当次 `flutter devices` 可见的 Android 真机和本机 macOS，执行 Step 11/13/14 的自动化用户路径。
- `D2_ISOLATED_FIXTURE_WRITE`：当 API/WS 目标、Backend HEAD/profile、专用账号归属和可销毁 fixture 全部验证为本地隔离测试环境时，允许向该 fixture 发测试消息、创建/编辑本 run 的 org/workspace/group/channel/moment/project 数据并定向清理。

以下动作不属于本计划的自动授权：

- `H1_DEVICE_OTHER`：iOS、Android 模拟器或 D1 之外的设备/平台。
- `H2_REMOTE`：访问非本机后端，尤其是生产、共享 staging 或真实用户数据。
- `H2_BACKEND_MUTATION`：启动/停止 Erlang 节点、执行迁移、写 D2 之外的后端数据或修改 Cowboy/API 代码。
- `H3_EXTERNAL_IMPACT`：向 D2 之外的账号发送消息、好友申请、邀请、通知、邮件、通话或其他第三方影响。
- `H4_VISUAL_UPLOAD`：上传截图到任何模型或外部服务。
- `H5_BASELINE_REPLACE`：登记或替换视觉基线。
- `H6_RELEASE`：push、发布、部署、生产迁移或流量切换。

执行期间不得向用户提问、等待确认或暂停会话。命中任一未授权边界时，停止对应动作，把工作包记为 `DONE`、相关 target/capability 记为 `BLOCKED`，记录当前条件下的最优安全替代和未来所需决策，然后继续所有不依赖该能力的 ready 节点。路由 drift、后端未运行、D2 账号/fixture 无法确认也按此规则处理，不自行修产品、启动/迁移后端或使用未知账号。所有需用户决定的事项只在最终 `test-report.html` 集中列出。

## 11. 停止条件

遇到以下任一情况，停止当前动作或 Step、保存可用证据并继续独立节点；不得中途向用户提问。只有仓库完整性或控制面已无法保证时才将 scheduler 记为 `INTERRUPTED`，但仍应尽最大可能执行 Step 15 生成 HTML 报告：

1. 当前 HEAD 或拥有文件出现其他会话未预期修改，无法无损兼容。
2. 修复需要改动 Flutter 产品业务逻辑或现有测试的产品断言。
3. 需要新增第三方依赖才能继续。
4. 需要 D1/D2 之外的设备或凭证、远程环境、截图上传或第三方影响。
5. 无法区分 SKIP、基础设施失败和业务断言失败。
6. catalog 无法为新增源码确定映射且不存在合法的枚举 `exclusion_code`。
7. functional inventory 中存在可达页面或用户操作未登记、无 oracle、无平台归属或被静默 skip。
8. 基础设施失败的 2 次自动重试已耗尽，仍无法得到确定性分类。
9. 验收只能通过删除负向测试、放宽 fail-closed 或把 BLOCKED 当 PASS。

## 12. 每步内部证据记录

以下字段写入 `RUN_ROOT` 的结构化 JSON/JSONL，不生成额外面向用户的 Markdown 或 HTML 文档：

```text
Step:
Scheduler state:
Scope verdict:
Target status counts:
Base SHA:
Owned files:
Files changed:
Acceptance IDs:
Commands + exit codes:
Result summary:
Evidence paths + SHA-256:
Token-saving measures used:
Remaining risks:
Blocked decisions for HTML report:
Local commit:
```

写步骤先完成局部验证，再按 Step 独立本地提交，随后必须在该确切 commit HEAD 重跑 Acceptance 并生成权威证据；作者/提交者使用 `leeyi <leeyisoft@qq.com>`，只 stage 本 Step 拥有文件，不包含并行会话改动。后续修改按 dependency closure 精确失效旧证据。纯执行/只读 Step 无 diff 时记录 `NO_COMMIT_READ_ONLY`，不创建空提交。不得 push。

## 13. 完成定义

只有同时满足以下条件，本计划才能标记 `PASS`：

- 统一 gate 在当前 HEAD 连续执行两次均退出 0 且不产生 diff。
- 五类 machine-event 结果、target 去重、风险冲突、requirements、catalog、cache 和脱敏负向测试全部通过。
- 当前页面和 integration test 资产均 catalogued 或有显式排除原因。
- 所有可达页面和用户可见功能均进入 functional inventory；Android 真机和 macOS 上的每个适用项恰有一次本轮实际执行证据，或有机器可复验的 `BLOCKED/EXCLUDED` 原因。
- fresh clone 场景不依赖 ignored reports 即可生成完整计划。
- CI 和本地复用相同 gate，没有复制一套判断。
- `full-selected`/enterprise 每个启用 feature 都映射到 domain capability 或有明确排除理由。
- All Pages/Functions、E2EE、Enterprise/Organization、Workspace/Group、Channel、Moment、Project 分别出 verdict；任一 required capability 缺失、skip、TODO 或证据等级不足时，对应领域不得 PASS。
- Android 真机 + macOS 人工路径自动化已执行，或因缺少可复现前置明确 `BLOCKED`；无设备测试不得冒充 A 级证据。
- 未执行的远程、视觉和外部验收明确保持 `BLOCKED/NOT_RUN`。
- 整个会话只有一个面向用户的报告文档 `RUN_ROOT/test-report.html`，所有内部 JSON/event/log 都由它索引，不生成第二份总结报告。
