# 测试执行合同 / Test execution contract

统一入口是 `scripts/auto_test.py execution-*`；`scripts/run_test_suite.sh` 只作兼容转发。
归属、profile 与矩阵声明保存在 `test/auto_test/execution_contract.json`，实现在既有
`auto_test_lib` 中。原 AI 页面规格/catalog 继续负责页面需求映射，不代表全仓执行归属。

## 套件职责

| 主套件 | 对象 | 条件 |
|---|---|---|
| unit | 纯逻辑、模型、协议 | 宿主 Flutter VM |
| widget | 页面、组件、导航、状态 | 宿主 Widget runner |
| component | 模拟 HTTP/服务、无设备集成 | 合成 fixture；浏览器专属目标另标 web |
| sqlite-ffi | 临时数据库、迁移 | SQLite 动态库；浏览器目标需 WASM/Chrome |
| crypto-ffi | Rust/vodozemac 加密与宿主 harness | 与锁定依赖一致的原生库 |
| backend-contract | 真实 API/WS、无设备 API 流程 | 隔离后端、测试账号、签名材料 |
| golden | 像素比较 | 固定 SDK/engine、字体、平台和已批准基线 |
| route-smoke | 路由页面烟雾 | 每条路由独立进程；守卫合同单独保留 |
| device-single | 单设备业务流程 | 声明的平台、设备和隔离后端 |
| device-pair | 双端消息、RTC、跨平台加密 | 成组角色、平台拓扑及编排器 |
| native-ui | Patrol、权限与系统 UI | Android instrumentation 与本次 JUnit |
| tooling | Python unittest、现有 CASES/恢复自检 | Python；部分源码契约需并排后端源码 |

独立目标只有一个主套件，profile 可以引用多个套件/目标。目录规则只接管已知家族，
分类还检查源码、辅助 import 闭包、绑定、FFI、像素断言和平台注解。例外必须注明依据。
驱动、聚合、被宿主 wrapper 包含的测试、fixture 显式分类；`all_tests.dart` 不能代表全量。

## 精确命令

从仓库根运行；报告放在仓外。

```bash
REPORT_DIR="${TMPDIR:-/tmp}/imboy-execution-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$REPORT_DIR"

# 归属硬门禁，不运行业务测试
bash .github/scripts/validate_ci_test_paths.sh
python3 scripts/auto_test.py execution-check \
  --output "$REPORT_DIR/ownership.json" --inventory "$REPORT_DIR/ownership.md"

# 无 SDK、设备、凭证也可生成计划
python3 scripts/auto_test.py execution-plan --profile pr --output "$REPORT_DIR/pr-plan.json"
python3 scripts/auto_test.py execution-plan --profile full --output "$REPORT_DIR/full-plan.json"
bash scripts/run_test_suite.sh --mode full --dry-run --output "$REPORT_DIR/full-plan.json"

# 本机 PR 分片；Linux 使用 --platform linux
bash scripts/run_test_suite.sh --profile pr --platform macos --artifact-dir "$REPORT_DIR/pr-macos"

# 完整回归，不加过滤；缺任何必需环境均阻塞
bash scripts/run_test_suite.sh --profile full --artifact-dir "$REPORT_DIR/full"

# 专项（均支持 --dry-run）
bash scripts/run_test_suite.sh --profile sqlite --platform macos --artifact-dir "$REPORT_DIR/sqlite"
bash scripts/run_test_suite.sh --profile e2ee --platform macos --artifact-dir "$REPORT_DIR/e2ee"
bash scripts/run_test_suite.sh --profile routes --platform macos --artifact-dir "$REPORT_DIR/routes"
bash scripts/run_test_suite.sh --profile backend --platform macos --artifact-dir "$REPORT_DIR/backend"
bash scripts/run_test_suite.sh --profile golden --artifact-dir "$REPORT_DIR/golden"
bash scripts/run_test_suite.sh --profile web --artifact-dir "$REPORT_DIR/web"
bash scripts/run_test_suite.sh --profile device-single --platform android --artifact-dir "$REPORT_DIR/android"
bash scripts/run_test_suite.sh --profile device-pair --artifact-dir "$REPORT_DIR/pairs"
bash scripts/run_test_suite.sh --profile native-ui --platform android --artifact-dir "$REPORT_DIR/native"
python3 scripts/auto_test.py execution-run --profile tooling --platform linux --artifact-dir "$REPORT_DIR/tooling"

# 对账必需实例；缺文件、失败或取消都不能通过
python3 scripts/auto_test.py execution-summary --plan "$REPORT_DIR/full-plan.json" \
  --results "$REPORT_DIR/full" --output "$REPORT_DIR/full-summary.json"
```

`--platform`、`--product-profile`、`--suite`、`--target`、`--variant` 是显式范围过滤；过滤后的 full 记为
`scope=scoped`，不能签发 `complete_regression=true`。执行身份保留目标、平台、产品 profile、
角色及必要 variant；不能按文件去重。分片消费同一个冻结计划，最后汇总全部 `results.json`。
配对组必须交给能协调完整角色集合的控制器，不能拆成普通单设备遍历。

### 多宿主 / 多产品执行

`--worker-*` 只选择执行分片，不改原计划。宿主分片按其负责套件分配，避免与设备控制器重复。
先冻结 full-plan.json，执行 `execution-gates` 收集一次公共前置证据，再分派 worker。Linux worker 可执行下列命令。macOS 宿主 worker 还需逐项传入其负责的 `--worker-suite`，将 device-single、device-pair、native-ui 留给对应控制器：

```bash
python3 scripts/auto_test.py execution-gates --plan "$REPORT_DIR/full-plan.json" \
  --artifact-dir "$REPORT_DIR/full-gates"
python3 scripts/auto_test.py execution-run --plan "$REPORT_DIR/full-plan.json" \
  --worker-platform linux --worker-product-profile phase1_delivery \
  --artifact-dir "$REPORT_DIR/full-linux"
# 配对控制器不按 platform 拆角色；可同时连接 Android/macOS，按元数据编排。
python3 scripts/auto_test.py execution-run --plan "$REPORT_DIR/full-plan.json" \
  --worker-suite device-pair --worker-product-profile phase1_delivery \
  --artifact-dir "$REPORT_DIR/full-pairs"
```

macOS/浏览器/设备其他套件同样声明分片，每个已选实例应恰有一份结果。跨产品在独立
worktree 准备真实生成物，源提交/执行合同/测试代码保持一致；仅受生成器校验的产品生成物
允许作为构建变体。结果保存已验证的产品产物指纹，错误 profile 或缺 feature 仍阻塞。
`--worker-product-profile full-selected` 不会自动构建/启用 feature。全部结果与前置检查收集后，
用原完整计划 execution-summary，并传入 `--results "$REPORT_DIR/full-gates"` 及各分片目录；分片成功不代表完整回归通过。日志、原始/逐目标事件及进程 receipt 随结果上传，汇总重新核验文件、SHA256、退出码与解析计数，缺证据也会阻塞。

## PR、覆盖率与门禁

PR 包含逻辑、Widget、模拟集成、SQLite、加密 FFI、工具目标，含原来 `test/unit_test/`
以外的业务目录。真实后端、Golden、路由、浏览器、设备/双端/Patrol 有明确专项；full 纳入
全部适用目标。无可靠影响映射时，保守执行所选 profile 全目标，不猜测是否能裁掉测试。

主 CI 冻结计划，Linux/macOS worker 共用。质量和跨仓契约工作流由主 CI 调用；稳定的
`IMBoy Test Summary` 使用 `if: always()` 对账实例与上游任务。上游不使用 workflow paths
过滤。分支保护应选择该汇总检查，仓库设置需维护者另行配置。

`--coverage` 给已声明可统计的实例增加收集参数，与业务测试同次执行，不重新选文件。
路由、后端、Golden、设备和工具不混入宿主覆盖率。原 38% 门槛保留，实际扩大范围后的
覆盖率须在环境完整的 runner 核验，不自动降低门槛。

```bash
python3 scripts/auto_test.py execution-run --profile pr --platform linux --coverage \
  --artifact-dir "$REPORT_DIR/coverage"
python3 scripts/auto_test.py execution-coverage \
  --input "$REPORT_DIR/coverage/coverage/lcov.info" --minimum 38
```

原框架、SQLite、E2EE 脚本保留；框架/SQLite 的 `--checks-only` 复用其静态合同，测试由
计划执行一次。Moment/E2EE/component/性能断言不再因多个 CI 步骤重复执行相同实例。
错误码/protobuf 契约保留；`regen_protobuf.sh --check` 在临时目录生成后比较，不覆盖工作区。

宿主 Flutter 进程每批最多 128 个目标，纯 unit/widget/component 使用 Flutter 默认并发；
SQLite、加密、后端及路由保留串行/进程隔离要求。分批不改变已选实例或覆盖率范围，
每批结果分别保存后统一对账、合并覆盖率。每个进程仍有 900 秒预算；超时会终止本次创建的
POSIX 进程组并冻结日志，保留已产生的机器事件，结果仍为阻塞。进程组监督当前支持 Linux/macOS；
不具备该能力的宿主在启动前阻塞。执行日志会显示批次、平台及目标数，便于定位执行进度。

## 新增测试

1. 放入合适家族，检查真实依赖是否适合该 runner。
2. `git add -N -- path/to/new_test.dart` 或正常精确暂存，使其进入 Git 发现范围；CI 扫提交中的
   全部跟踪文件，ignored/未跟踪临时产物不冒充测试。
3. 运行 `execution-check` 和 `execution-plan`，合法规则会自动纳入新文件。
4. 新家族或特殊目标在 rules/overrides 声明依据、平台、依赖、产品；配对另含角色与编排。
5. 审查 ownership.md 的新增接管、移入专项与归属变化；不得登记 disabled 绕过执行。

未知目录、多主规则命中、悬空路径/profile、无真实 runner、无主执行者的 included-test、
空计划均失败。支持目录中新增真实测试不能伪装成 helper。清单有效不是业务通过。

## 状态与计数

| reason_code | 含义 | 处理 |
|---|---|---|
| PLATFORM_NA | 该平台不适用 | 其他适用平台义务仍保留 |
| OUT_OF_SCOPE | 本次 profile/显式过滤未选择 | 不计本次已选通过；filtered full 不称完整 |
| ENV_MISSING | 缺 SDK/设备/后端/账号/密钥/库/基线/构建 | BLOCKED |
| UPSTREAM_FAILED | 前置失败、取消或缺前置证据 | BLOCKED，附具体依赖 |
| UNEXPECTED_SKIP | 已选且适用却发生未批准 skip | BLOCKED，退出 0 也不通过 |

缺结果、运行器异常、零执行、不完整事件、重复或过期证据另有精确原因码。
状态与原因分开。结果保存 commit/profile/suite/target/platform/product_profile/role/variant、
selected/status/reason_code/upstream、计数、日志、证据和全部尝试。
`executed = passed + failed + skipped`；`actually_run = passed + failed`。隐藏加载/setup 不充数。实例汇总使用最后一次尝试的计数；完整 attempts 保留每次计数，重试工作量须单独对 attempts 求和。
断言失败不重试洗绿；基础设施重试保留尝试，恢复后仍是 FLAKY。未批准部分 skip 也阻断，
不增加兜底 skip 白名单。存量硬编码 skip 需修复或建立可核验的适用合同。
联系人 RTC gate 在 phase1_delivery 与 full-selected 两个真实构建中执行；依赖已编译 RTC 回调的断言仅在 RTC 构建注册，full-selected 的产物核验保证该分支不会被缺 feature 的构建跳过。

## 环境合同

### 宿主、FFI、产品

使用仓库固定 Flutter/Dart，先 `python3 scripts/check_sdk_compatibility.py` 再 `flutter pub get --enforce-lockfile`。冻结计划后只运行 `.github/scripts/ci_patch_path_deps.sh --check`，不在执行阶段改写依赖源码。
专用测试 checkout 可用 `.github/scripts/ci_gen_env.sh` 生成合成 loopback 配置，不复制真实配置。
SQLite 需宿主 sqlite3。加密库沿用 `.github/scripts/ci_build_vod.sh` 按锁定插件构建，
`FRB_DART_LOAD_EXTERNAL_LIBRARY_NATIVE_LIB_DIR` 指向库目录；真实加载仍需机器事件验证。
框架产品合同需要并排 `imboy`、`imboyadmin` 源码（可指定 `IMBOY_BACKEND_ROOT`）；只读源码
不连接服务。当前 profile 以 manifest/生成物校验为准；额外 feature 需对应隔离构建，
不能仅添加 dart-define 冒充 full-selected。

### 隔离后端

先准备可丢弃后端、数据库、合成账号/消息/群组；API/WS 必须显式提供字面 loopback 地址，
不能退回生产地址。Android 真机可为隔离服务建立明确端口转发。

```bash
export IMBOY_TEST_ISOLATED=true
export IMBOY_APP_ENV=local
export IMBOY_API_BASE_URL_OVERRIDE=http://127.0.0.1:9800
export IMBOY_WS_URL_OVERRIDE=ws://127.0.0.1:9800/api/v1/ws
# 从本地隔离 fixture 配置注入，不在文档中填写真实值：
# IMBOY_TEST_PHONE / IMBOY_TEST_PASSWORD
# IMBOY_SOLIDIFIED_KEY_OVERRIDE / IMBOY_SOLIDIFIED_KEY_IV_OVERRIDE
```

写操作另需允许合成数据写入，按目标 required_env 准备会话/群组/成员/peer 身份。
WS 缺密钥、账号、后端在执行前阻塞；运行时 skip 也不能变绿。

### 设备、双端、Patrol

显式配置 `IMBOY_TEST_DEVICE` 或 `IMBOY_EXECUTION_DEVICE_ANDROID/IOS/MACOS`；发现时核对平台，
Android 沿用真机约束。配对角色配置 `IMBOY_EXECUTION_DEVICE_SENDER/RECEIVER/FINAL`，RTC
配置 `CALLER/CALLEE`；角色凭证用 `IMBOY_<ROLE>_TEST_PHONE/TEST_PASSWORD`，不能误用同一身份。
跨端向量沿用 Android sender → macOS receiver → Android final；RTC 双端并发并先等接收就绪。
前置角色失败会阻塞依赖角色。j16c 消息注入和 j28b 旧客户端原本依赖仓库外 fixture，需提供
`IMBOY_DND_PAIR_DRIVER` / `IMBOY_DND_PAIR_DRIVER_SHA256` 或
`IMBOY_LEGACY_PAIR_DRIVER` / `IMBOY_LEGACY_PAIR_DRIVER_SHA256`。路径必须是现存 Python
脚本的绝对路径且哈希一致，脚本在同一隔离环境中接收 `--target`、`--primary-log`、
`--orchestration`，输出标准 machine 事件；缺脚本/哈希为 ENV_MISSING。主目标和 companion
都通过才可签发该角色通过，不能用旧单端日志替代对端证据。Patrol 独立读取本次 JUnit，旧 XML、仅启动成功、零 Dart 用例、
意外 skip 都不通过。iOS 原生工程仍遵守保留区规则。

### Golden

设置 `IMBOY_GOLDEN_ENVIRONMENT` 指向环境 JSON，声明 platform/frameworkRevision/engineRevision、
fonts 文件 SHA-256，及 baselines 按 target 列出的基线文件 SHA-256。缺条件为 ENV_MISSING；
CI 不能直接跳过后算通过。回归不生成/更新基线。显式 `flutter test <target> --update-goldens`
只用于基线维护，产物须人工审查，该命令成功不是像素回归通过。

验收三目标、MC owned session/coordinator、租约及专项 fixture 的字段与解除步骤，见
[专项 fixture 与证据合同](specialist-fixtures.md)。

## 手动工作流与修改后验证

`integration_test.yml` 仅手动，默认生成计划；执行需带 `imboy-test` 标签的隔离 self-hosted
runner；多产品执行可预配置 `IMBOY_EXECUTION_WORKTREE` 为同一提交的独立产品 worktree，防止 checkout 覆盖已准备的生成物。该目录仍接受完整源码/产品指纹校验。完整配对拓扑将 platform 选为 `all`，所选 product 必须与该 runner 预先准备的生成物一致。环境不齐不恢复自动触发。已不存在脚本的旧 YAML automation 入口由此接替。
修改后运行对应工具、归属和业务验证，回复分别报告静态清单、工具、Flutter、后端契约、
设备/双端、完整回归等级。缺环境时继续独立验证，列出解除条件，不把模拟 runner 当业务验证。
