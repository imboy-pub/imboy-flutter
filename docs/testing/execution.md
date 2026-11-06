# 测试执行合同 / Test execution contract

统一入口是 `scripts/auto_test.py execution-*`；`scripts/run_test_suite.sh` 只作兼容转发。
归属、profile 与矩阵声明保存在 `test/auto_test/execution_contract.json`，实现在既有
`auto_test_lib` 中。原 AI 页面规格/catalog 继续负责页面需求映射，不代表全仓执行归属。

## 套件职责

| 主套件 | 对象 | 条件 |
|---|---|---|
| unit | 纯逻辑、模型、协议 | 宿主 Flutter VM |
| widget | 页面、组件、导航、状态 | 宿主 Widget runner |
| component | 模拟 HTTP/服务、无设备集成及字体加载合同 | 合成 fixture；浏览器/系统字体目标声明各自平台与依赖 |
| sqlite-ffi | 临时数据库、迁移 | SQLite 动态库；浏览器目标需 WASM/Chrome |
| crypto-ffi | Rust/vodozemac 加密与宿主 harness | 与锁定依赖一致的原生库 |
| backend-contract | 真实 API/WS、无设备 API 流程 | 隔离后端、测试账号、签名材料 |
| golden | 像素比较 | 固定 SDK/engine、字体、平台和已批准基线 |
| route-smoke | 路由页面烟雾 | 每条路由独立进程；守卫合同单独保留 |
| device-single | 单设备业务流程、受控 SQLite 中断重放 | 声明的平台/设备；联网目标需隔离后端，离线目标遵守自身 fixture 合同 |
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
python3 scripts/auto_test.py execution-matrix --plan "$REPORT_DIR/pr-plan.json" \
  --output "$REPORT_DIR/host-matrix.json"
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

### pre-push hook

`lefthook.yml` 的 `api-contract-tests` 保留既有可选后端语义；默认调用
`execution-check`，归属错误会阻止 push，后端明确记为 `OUT_OF_SCOPE`。
静态归属通过不代表 API/WS 或任何业务测试通过。显式选择后端后，脚本把 Linux/macOS
本机平台交给同一 `backend` profile；统一运行器记录机器事件、结果与证据，环境缺失、
未批准 skip、零执行或非零退出会阻止 push。脚本不读取 `scripts/test.env`，不自行探活，
不打印账号；环境必须按下文隔离后端合同显式注入。

```bash
bash scripts/pre_push_gate.sh
# 只生成本机 backend 计划，不访问后端，也不执行测试
bash scripts/pre_push_gate.sh --dry-run --output "$REPORT_DIR/backend-plan.json"
# 隔离 fixture 已准备后显式执行；也可 IMBOY_PRE_PUSH_BACKEND=1 git push ...
bash scripts/pre_push_gate.sh --backend --artifact-dir "$REPORT_DIR/pre-push-backend"
```

原 `IMBOY_SKIP_PRE_PUSH=1` 仍可显式退出该 hook；输出 `OUT_OF_SCOPE`，表示归属及后端
均未执行，不产生业务通过结论。该变量不会改变远端 CI 的执行合同。

### Web Shell

`web-shell` profile 由合同中的目录前缀接管目标，保留各目标实际平台；完整专项包含
Linux、macOS 和 Chrome 的适用实例。本机兼容脚本选择本机宿主加 `web`，浏览器专属
目标不会发往 VM。`--dry-run` 在 SDK、资产、分析及构建检查前直接生成同一计划。

```bash
python3 scripts/auto_test.py execution-plan --profile web-shell --output "$REPORT_DIR/web-shell-all.json"
bash scripts/verify_web_shell.sh --dry-run --output "$REPORT_DIR/web-shell-local.json"
bash scripts/verify_web_shell.sh --quick --no-server --artifact-dir "$REPORT_DIR/web-shell-quick"
bash scripts/verify_web_shell.sh --no-server --artifact-dir "$REPORT_DIR/web-shell-build"
```

真实运行保留 SDK 检查、Web E2EE JS/WASM 资产检查、模块静态分析，以及未指定 `--quick`
时的 Web 构建；这些前置检查先写日志，再交统一 `execution-run` 执行测试。前置失败
以具体 `web-shell-*` 依赖记录为 `UPSTREAM_FAILED`，仍生成每个选中实例的结果，整体
非零退出。测试失败、零执行、未批准 skip 及运行器非零退出沿用统一判定。
`--quick` 只省略构建和预览，测试范围不变。`--artifact-dir` 必须在仓外，未指定时创建
临时目录；静态/构建日志在该目录，计划、机器事件、结果和汇总在其 `tests/` 子目录。
默认构建后可启动仅绑定 loopback 的预览服务器；`--no-server` 关闭此步骤。
人工浏览器检查不构成自动化像素或业务通过证据，本机专项也不代表其他宿主或完整回归通过。

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

主 CI 冻结计划，`execution-matrix` 按已选实例生成 `(platform, suite)` worker，Linux/macOS
各套件分别执行，artifact 保留独立目录。矩阵分区不改变 target/product/role/variant 身份，
并集必须覆盖原计划全部已选实例。该命令拒绝空计划或包含设备、配对、Patrol 的计划，
这些目标继续交给其专项编排器。质量和跨仓契约工作流由主 CI 调用；稳定的
`IMBoy Test Summary` 使用 `if: always()` 对账实例与上游任务。上游不使用 workflow paths
过滤。分支保护应选择该汇总检查，仓库设置需维护者另行配置。

`--coverage` 给已声明可统计的实例增加收集参数，与业务测试同次执行，不重新选文件。
路由、后端、Golden、设备和工具不混入宿主覆盖率。原 38% 门槛保留，实际扩大范围后的
覆盖率须在环境完整的 runner 核验，不自动降低门槛。CI 在全部 Linux worker 结束后，
先对账每个 coverage_eligible 实例，再核验原始进程、实际 `--coverage` 参数、LCOV 路径与
SHA-256，最后按源文件/行合并，原阈值只检查一次。缺 worker、某个 worker 没开启收集、
证据漂移、非零退出或未批准 skip 都会阻止覆盖率检查通过，即使剩余 LCOV 已超过阈值。

```bash
python3 scripts/auto_test.py execution-run --plan "$REPORT_DIR/pr-plan.json" \
  --worker-platform linux --coverage --artifact-dir "$REPORT_DIR/coverage-linux"
python3 scripts/auto_test.py execution-coverage \
  --plan "$REPORT_DIR/pr-plan.json" --results "$REPORT_DIR/coverage-linux" --platform linux \
  --output "$REPORT_DIR/coverage/lcov.info" --minimum 38
```

合并目录同时保存 `lcov.summary.json`，列出应有/已核验实例、缺失证据及百分比。
`execution-coverage --input <lcov>` 保留为单份文件的数值测量命令，不证明执行计划完整。
覆盖率范围只涵盖指定平台；其他平台和非统计目标仍由最终 `execution-summary` 对账。

`test/uiux/contract/font_contract_test.dart` 的五个用例保持完整，主归属为 component，
在 PR/full 的 macOS 上执行。它验证现有 macOS 授权字体、CJK 字形、FontLoader 及错误分支，
没有像素比较，因而不要求 Golden 图片基线。执行前从 `golden_font_loader.dart` 读取既有
登记并核对本地字体 SHA-256；缺文件或不匹配报告 ENV_MISSING。Linux 为 PLATFORM_NA，
不删除 macOS 义务。登记格式变化要求同步审查适配器，禁止分发、下载替代系统字体或添加 skip。

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
profile 的目录前缀必须指向至少一个已归属可执行目标；合法前缀下的新文件自动进入计划。
需要阶段控制的 kill-replay 必须声明现有 controller 和证据 verifier，不能回落成普通单设备命令。

## 状态与计数

| reason_code | 含义 | 处理 |
|---|---|---|
| PLATFORM_NA | 该平台不适用 | 其他适用平台义务仍保留 |
| OUT_OF_SCOPE | 本次 profile/显式过滤未选择 | 不计本次已选通过；filtered full 不称完整 |
| ENV_MISSING | 缺 SDK/设备/后端/账号/密钥/库/基线/构建 | BLOCKED |
| UPSTREAM_FAILED | 前置失败、取消或缺前置证据 | BLOCKED，附具体依赖 |
| UNEXPECTED_SKIP | 已选且适用却发生未批准 skip | BLOCKED，退出 0 也不通过 |

缺结果、运行器异常、零执行、不完整事件、重复或过期证据另有精确原因码。
聚合 CI job 失败/取消只证明该 job 未成功，不能推断它的所有子门禁都失败。
汇总保留已核验的独立门禁结果；没有独立收据的子门禁记为缺证据，具体聚合 job 的
failure/cancelled 仍使最终结果阻断。这里的 missing 不等于该子门禁没有运行。
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
FTS v38 草稿的宿主、Chrome/WASM 和原生 SQLCipher 三类验收及注册前阻塞，见
[SQLite 迁移验证矩阵](../sqlite-migration-test-matrix.md#消息-fts-v38-的注册前验证--message-fts-v38-admission)。
原生草稿使用合成临时库，属于显式 offline 目标；它不需要后端账号，但仍要求合格设备和
真实加密驱动。The FTS draft's offline classification removes backend prerequisites, not native driver obligations.
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
fonts 文件 SHA-256，及 baselines 按 target 列出的基线文件 SHA-256。`baselines` 始终只接受
仓内文件；普通 `fonts` 也限于仓内。实际 import 闭包使用 `golden_font_loader.dart` 的目标
（当前 p1/p2/p3 及 `test/enterprise_oa/t15_enterprise_layout_test.dart`）必须额外绑定
该 loader 真正加载的全部字体，不能用无关仓内字体替代：

- 文本字体使用 `kGoldenFontAssets` 已登记的精确绝对路径、SHA-256 和非空许可说明。
  manifest 的 `fonts` 必须包含该路径且哈希与源码一致。
- 图标字体从 `kGoldenIconFontAssets` 严格读取 literal path/family，并按路径去重。
  manifest 的 `fonts` 必须包含全部实际路径，由基线维护者固定各文件 SHA-256。
  当前是 MaterialIcons 和 Cupertino 两个文件；后者注册两个 family。
- 只有这些已登记的精确路径可作为仓外字体；任意路径、别名或仓内 symlink 越界均不获例外。
  缺文本/图标文件、字节与哈希不符、清单漏项或登记格式不明确均为 ENV_MISSING。
  执行器不复制、下载或提交系统字体，也不允许图标缺失后静默降级为方块。
- 使用该 loader 的 Golden 还校验真实 `flutter --version --machine` 的 frameworkVersion
  与 `kFlutterVersionPin` 一致，并核对清单的 frameworkRevision/engineRevision。
  当前专项登记为 Flutter 3.47.7；普通 PR 使用 3.47.5，PR 成功不能证明该像素环境就绪。
  原有本机字体路径和专项准备见 [专项 fixture 说明](specialist-fixtures.md)。

预检通过只证明声明的输入当前可用，像素通过仍须实际比较已批准基线并核验机器事件。
CI 不能直接跳过后算通过。回归不生成/更新基线。显式 `flutter test <target> --update-goldens`
只用于基线维护，产物须人工审查，该命令成功不是像素回归通过。

验收三目标、MC owned session/coordinator、租约及专项 fixture 的字段与解除步骤，见
[专项 fixture 与证据合同](specialist-fixtures.md)。

## 手动工作流与修改后验证

`integration_test.yml` 仅手动，默认生成计划；执行需带 `imboy-test` 标签的隔离 self-hosted
runner；多产品执行可预配置 `IMBOY_EXECUTION_WORKTREE` 为同一提交的独立产品 worktree，防止 checkout 覆盖已准备的生成物。该目录仍接受完整源码/产品指纹校验。完整配对拓扑将 platform 选为 `all`，所选 product 必须与该 runner 预先准备的生成物一致。环境不齐不恢复自动触发。已不存在脚本的旧 YAML automation 入口由此接替。
手动 Golden 先用 SDK 检查的 `--dart-only` 核验源码钉版一致性与 Dart 依赖约束，再由统一 Golden preflight 核验实际 Flutter 钉版、framework/engine 和基线环境；其他 profile 仍执行完整 SDK 检查。
修改后运行对应工具、归属和业务验证，回复分别报告静态清单、工具、Flutter、后端契约、
设备/双端、完整回归等级。缺环境时继续独立验证，列出解除条件，不把模拟 runner 当业务验证。
