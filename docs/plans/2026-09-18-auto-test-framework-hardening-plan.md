# IMBoy 自动化测试框架可信化与低 Token 改造计划

> 创建：2026-09-18
> 仓库：`/Users/leeyi/project/imboy.pub/imboyapp`
> 被测系统：Flutter/Dart 客户端 + Erlang/OTP/Cowboy 后端（`../imboy`）
> 测试控制面：Python stdlib + shell；本计划不引入第三方测试编排依赖
> 基线参考：`07c63637e329492e0295264556b31d18ea3ade94`，执行 Step 1 时必须重新记录当前 HEAD
> 配套提示词：`docs/plans/2026-09-18-auto-test-framework-hardening-prompts.md`
> 状态：`TODO`

## 1. 目标

在不重写现有 Flutter 集成测试、不批量改写 155 份页面台账的前提下，把
`test/auto_test` 改造成可测试、可重复执行、可自动验收且默认节省 Token 的测试控制面。

完成后必须满足：

- `PASS` 只代表测试实际执行且没有 skip、失败或缺失断言证据。
- 同一个 `runner.target` 在一次计划中最多执行一次。
- 执行前验证最终生效的 App/API/WS 目标，不能只验证父进程环境变量。
- 当前源码页和集成测试文件必须被 catalog 收录或带原因显式排除。
- 涉及后端的结果和缓存必须绑定 Erlang 后端 HEAD、API/WS 目标和测试配置指纹。
- 机器完成发现、校验、影响分析、结果归类和像素预筛；AI 只处理异常和语义判断。
- fresh clone 能从已跟踪文件生成执行计划，不依赖被忽略的历史报告。
- 自动门不得替代真机、远程写入、第三方影响或视觉基线审批。

## 2. 非目标

- 不修复 `lib/` 中的产品功能或现有集成测试业务断言。
- 不补齐全部 1748 个功能点的 JSON 规格。
- 不在本计划中执行真机测试、连接远程后端、发送消息、申请好友、创建群/频道或资金操作。
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
        +---- 其余：生成最小失败证据包，供 AI 或人工诊断
```

权威数据分为三类：

| 数据 | 作用 | 是否跟踪 |
|---|---|---|
| `test/auto_test/catalog.json` | 可执行 target、源码映射、风险、requirements、显式排除 | 是 |
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
| `PLANNED` | 仅生成计划，未执行 | 否 |

### 4.2 退出码

```text
0  = 全部目标 PASS
1  = 至少一个 FAIL
2  = 无 FAIL，但存在 PASS_WITH_SKIPS、BLOCKED 或 PLANNED
64 = 参数、schema 或 catalog 使用错误
```

### 4.3 最小证据 manifest

每个执行结果至少包含：

```json
{
  "schema_version": 1,
  "head": "<40-char sha>",
  "backend_head": "<40-char sha-or-NOT_APPLICABLE>",
  "catalog_sha256": "<sha256>",
  "target": "integration_test/..._test.dart",
  "environment": {"app_env": "local", "api_host": "127.0.0.1", "ws_host": "127.0.0.1", "backend_profile": "<redacted-fingerprint>"},
  "device": {"id": "<redacted-or-id>", "platform": "android"},
  "result": {"status": "PASS", "executed": 1, "skipped": 0, "failed": 0},
  "command_fingerprint": "<sha256>",
  "artifacts": [{"path": "events.jsonl", "sha256": "<sha256>"}]
}
```

不得写入密码、验证码、access token、私钥、完整手机号或未脱敏第三方标识。

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
Wave 1: Step 2 截图/目标配置修复
Wave 2: Step 3 结构化结果与唯一 target
Wave 3: Step 4 requirements 与外部影响门
Wave 4: Step 5 catalog 与双向资产发现
Wave 5: Step 6 状态、证据和缓存
Wave 6: Step 7 CI/统一验收入口
Wave 7: Step 8 当前 HEAD 最终验收
```

所有写步骤串行执行。原因是 Step 2-Step 6 都可能修改 `scripts/auto_test.py`；并行写会增加冲突和复审 Token。只读检查可以并行，但不得产生或吸收其他会话 diff。

## 7. 工作包台账

状态只允许：`TODO`、`IN_PROGRESS`、`PASS`、`PARTIAL`、`BLOCKED`。

| Step | 工作包 | 依赖 | 独占所有权 | 状态 |
|---|---|---|---|---|
| 1 | 冻结当前事实和验收夹具 | 无 | 现有 App/Backend 实现只读；只允许新增匿名夹具和基线证据 | TODO |
| 2 | 修复截图采集和目标配置漂移 | 1 | `scripts/capture_integration_screenshots.py`、capture 相关代码/测试 | TODO |
| 3 | 结构化结果、SKIP 防假绿、唯一 target | 2 | `scripts/auto_test.py` runner/report 相关代码/测试 | TODO |
| 4 | 类型化 requirements 和外部影响门 | 3 | requirements schema、runner preflight 相关代码/测试 | TODO |
| 5 | catalog、页面/测试双向发现和 impact | 4 | catalog、生成器、覆盖生成物及相关测试 | TODO |
| 6 | 当前状态、证据 manifest 和本地缓存 | 5 | state schema、旧状态迁移器、证据/缓存相关测试 | TODO |
| 7 | CI 与单一自动验收入口 | 6 | gate 脚本、CI、测试文档 | TODO |
| 8 | 当前 HEAD 收口审查 | 7 | 只读；仅允许修复本计划回归 | TODO |

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
find test/auto_test -mindepth 2 -maxdepth 2 -type f -name '*_page.md' | sort | wc -l
```

生成供后续单元测试使用的最小匿名夹具：Flutter machine events 的 PASS、全 SKIP、PASS+SKIP、FAIL、runner crash 五类。夹具不得来自含凭证的真实日志。

Acceptance：

- `ATF-001`：记录 App/Backend HEAD、两个工作树、25 specs、测试文件/页面/台账数量及当前漂移。
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

Acceptance：

- `ATF-201`：全 SKIP + exit 0 => `BLOCKED`，不是 PASS。
- `ATF-202`：PASS+SKIP => `PASS_WITH_SKIPS` 且退出 2；FAIL => 退出 1。
- `ATF-203`：25 specs 中重复 target 只计划一次；冲突安全属性必须由测试证明被拒绝。

Out of scope：改写现有 130 个集成测试内部断言。

## Step 4

### requirements 和人工门

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
- `local-write` 只允许 localhost/loopback/private/dev 明确目标。
- 后端参与的用例必须记录 Backend HEAD、API/WS host 和不含秘密的 profile fingerprint；无法确认后端身份时 BLOCKED。
- `external-impact` 的通用 runner 永远 BLOCKED；环境变量不能替代本轮用户人工确认。
- requirements 不满足时不得启动 Flutter、ADB、Patrol 或网络请求。

Acceptance：

- `ATF-301`：每个 requirement 有通过/缺失测试，未知值 fail closed。
- `ATF-302`：生产/远程写 target 即使设置通用 allow env 也不会自动执行。
- `ATF-303`：现有 specs 完成显式迁移，不能静默赋予更宽权限。

Out of scope：获取真实账号、决定联系方式、联系或影响第三方。

## Step 5

### catalog 和双向发现

建立 `test/auto_test/catalog.json`，一条记录对应一个唯一 target。catalog 至少包含 id、target、sources、dependencies、risk、requirements、tags、enabled；排除项包含 path 和 reason。

- 扫描全部 `integration_test/**/*_test.dart`，每个文件必须 catalogued 或 excluded。
- 扫描全部 `lib/page/**/*_page.dart`，每个页面必须 mapped 或 excluded。
- 校验台账首个页面路径存在，报告台账内部混入 provider 等非页面路径，但不强制一行只能引用页面。
- catalog 和覆盖 Markdown 使用稳定排序；`--check` 只比较，不改文件。
- impact 只输出变更直接命中的唯一 targets，再补固定 smoke 集；未映射源码显式 FAIL，不扫描全仓交给 AI。

Acceptance：

- `ATF-401`：当前 130 个测试文件全部 catalogued/excluded，数量漂移会使 CI 失败。
- `ATF-402`：当前 164 个页面全部 mapped/excluded，缺失和反向悬空均为 0。
- `ATF-403`：连续生成两次字节一致，`catalog --check` 和覆盖生成物 `--check` 通过。

Out of scope：为每个页面补 E2E、修改 155 份台账中的历史测试结论。

## Step 6

### 状态、证据和缓存

- 保留现有 `task_state.json` 作为历史输入，不在迁移中丢失内容；新执行不再向其追加批次顶级字段。
- 新增稳定 state/evidence schema。运行态放 ignored reports；只有明确收口的候选 manifest 才允许进入已跟踪证据目录。
- fresh clone 从 catalog 得到完整 UNKNOWN 计划，不依赖被忽略的 STATUS/FINAL_REPORT。
- 缓存键至少绑定 App HEAD、Backend HEAD、target hash、dependency hash、API/WS/profile 指纹、设备/平台和 fixture 版本。
- 任何输入变化都会失效；缓存只复用执行结果，不复用 AI 文字判断。

Acceptance：

- `ATF-501`：缺少历史 reports 时仍能生成完整计划。
- `ATF-502`：相同输入命中缓存；App/Backend HEAD、源码、测试、环境或设备任一变化都会 miss。
- `ATF-503`：状态和 manifest schema 拒绝凭证字段、未知状态和缺失证据哈希。

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

CI 的无设备 job 只运行该 gate；不得在 PR job 中隐式启动设备、远程后端或视觉模型。`scripts/run_test_suite.sh` 复用同一 gate，不复制判断逻辑。

Acceptance：

- `ATF-601`：本地统一 gate 连续两次退出 0，第二次不产生 diff。
- `ATF-602`：注入缺页、未知 requirement、全 SKIP 假绿、target 冲突和凭证字段时 gate 分别失败。
- `ATF-603`：CI 与本地调用同一入口；无网络/设备也能完成框架验收。

Out of scope：实际运行 Android/iOS/Patrol、修改发布流程。

## Step 8

### 当前 HEAD 最终验收

在所有写步骤完成后重新基线，执行统一 gate，并人工审查：

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
- `ATF-702`：工作树只包含本计划拥有的文件；无凭证、日志、截图或未授权业务改动。
- `ATF-703`：最终结论只能为 `PASS`、`PARTIAL` 或 `BLOCKED`；设备/远程/视觉仍未执行时不得声称产品 E2E PASS。

Out of scope：真机产品验收、远程环境验收、发布判定和 push。

## 9. 自动验收矩阵

| Acceptance | 自动化方法 | 证据 |
|---|---|---|
| ATF-101/102/103 | Python mock/subprocess 单元测试 | unittest 输出 |
| ATF-201/202/203 | machine-event fixtures + runner 单元测试 | 结构化结果 JSON |
| ATF-301/302/303 | requirement/risk 参数化负向测试 | unittest 输出 |
| ATF-401/402/403 | catalog 双向集合差和重复生成 | catalog check 输出/hash |
| ATF-501/502/503 | 临时目录 fresh-state/cache/schema 测试 | unittest 输出 |
| ATF-601/602/603 | 统一 gate 自检和负向 fixture | gate summary |
| ATF-701/702/703 | 最终审查 | `FINAL_STATUS.md` 或终端报告 |

建议 Python 测试目录：`test/tooling/auto_test/`。只能使用 Python stdlib，不引入 pytest、JSON Schema 包或 mock server 依赖。

## 10. 人工门

以下动作不属于本计划的自动授权：

- `H1_DEVICE`：连接或操作真实 Android/iOS/macOS 设备。
- `H2_REMOTE`：访问非本机后端，尤其是生产、共享 staging 或真实用户数据。
- `H2_BACKEND_MUTATION`：启动/停止 Erlang 节点、执行迁移、写后端数据或修改 Cowboy/API 代码。
- `H3_EXTERNAL_IMPACT`：发送消息、好友申请、邀请、通知、邮件、通话或其他第三方影响。
- `H4_VISUAL_UPLOAD`：上传截图到任何模型或外部服务。
- `H5_BASELINE_REPLACE`：登记或替换视觉基线。
- `H6_RELEASE`：push、发布、部署、生产迁移或流量切换。

命中任一人工门时输出 `BLOCKED`、所需输入和下一条安全命令，然后停止，不用环境变量或历史对话值代替用户本轮确认。

## 11. 停止条件

遇到以下任一情况，停止当前 Step 并报告：

1. 当前 HEAD 或拥有文件出现其他会话未预期修改，无法无损兼容。
2. 修复需要改动 Flutter 产品业务逻辑或现有测试的产品断言。
3. 需要新增第三方依赖才能继续。
4. 需要真实设备、凭证、远程环境、截图上传或第三方影响。
5. 无法区分 SKIP、基础设施失败和业务断言失败。
6. catalog 无法为新增源码确定映射且不存在可解释的 exclude reason。
7. 测试或 gate 连续两次出现同一非确定性失败，且无可复现根因。
8. 验收只能通过删除负向测试、放宽 fail-closed 或把 BLOCKED 当 PASS。

## 12. 每步交付格式

```text
Step:
Base SHA:
Owned files:
Files changed:
Acceptance IDs:
Commands + exit codes:
Result summary:
Evidence paths + SHA-256:
Token-saving measures used:
Remaining risks:
Human gates reached:
Verdict: PASS / PARTIAL / BLOCKED
Local commit:
```

验证通过后按 Step 独立本地提交，作者/提交者使用 `leeyi <leeyisoft@qq.com>`；只 stage 本 Step 拥有文件，不包含并行会话改动。不得 push。

## 13. 完成定义

只有同时满足以下条件，本计划才能标记 `PASS`：

- 统一 gate 在当前 HEAD 连续执行两次均退出 0 且不产生 diff。
- 五类 machine-event 结果、target 去重、风险冲突、requirements、catalog、cache 和脱敏负向测试全部通过。
- 当前页面和 integration test 资产均 catalogued 或有显式排除原因。
- fresh clone 场景不依赖 ignored reports 即可生成完整计划。
- CI 和本地复用相同 gate，没有复制一套判断。
- 未执行的设备、远程、视觉和外部验收明确保持 `BLOCKED/NOT_RUN`。
