# 测试、视觉证据与结果判级合同

版本1.1｜计划ID：`imboy-enterprise-uiux-v1`。COMMANDS.json定义命令ID，T04生成本机`commands.resolved.json`。本文件不包含Dart实现。

## 1. 命令必须能定位执行对象

每条命令记录：argv数组、cwd真实路径、所需文件及producer_task、使用的资源锁、输入指纹、timeout策略、预期case集合和成功条件。不得把“运行现有测试”“自行检查”填成可执行命令；也不得把包静态检查当成本卡真实行为验证。

T00—T04只用已提供的包校验器/Git和只读取证，不依赖未创建的T04工具。T04解析：Flutter/FVM wrapper真实argv、P1/P2/P3既有测试、i18n生成命令及支持locale、feature测试夹具入口、golden存储模式。`${...}`是声明过的本机绑定，不允许执行未解析值、shell eval、空argv或不存在目录。

Flutter wrapper若需要多个argv（例如FVM），解析为数组前缀后展开，不能把`fvm flutter`当成一个可执行文件。用户HEAD与研究SHA不同属正常，不能因此reset或升级SDK。

## 2. 测试层级与失败统计

| 层级 | 验什么 | 必须的反例/边界 |
|---|---|---|
| 结构与交互 | 真Widget/真shell组装、字段顺序、折叠/返回/点击次数、gate保留 | 假detailEntry不能替代真实企业路由；隐藏字段在Semantics也不得出现 |
| 几何与无障碍 | 有授权字体后的真实文本尺寸、48命中、亮暗对比、scale2、键盘 | overflow/不可达按钮/字体clamp/小目标必须能使测试失败 |
| Golden | MATRIX.json中的每个配置及明确baseline | 缺图、错环境、未批准替换不能跳过 |
| 业务调用回归 | 请求/参数/顺序/次数/权限不变量 | UI样式变化不得改变claim/CAS/org/workspace/分页/SSO |
| 最终全量 | 冻结候选K的实际Flutter全量入口 | 不关套件、不放宽analyze、不新增skip以追绿 |
| 原生 | iOS/Android真机与macOS窗口/键盘/读屏 | TargetPlatform模拟不是原生证据 |

日志优先保存Flutter JSON reporter和真实进程退出码。指定范围内：expected_tests=executed_tests、required_skip=0、fail=0。全量：既有合法skip逐ID与W0清单对齐；新增/改变skip必须独立说明，不能将既有skip简单全禁导致永远卡住，也不能无理由继承。引入的必需用例始终不可skip。全量既有失败仍不能算PASS。

连续动画/加载态不得无条件pumpAndSettle至永不结束；采用冻结时钟、禁用非必要动画或有界pump并核对状态。任何Flutter错误不得因tearDown清空异常而被吞掉。配置切换后恢复locale/platform/MediaQuery，防止顺序依赖；测试源不得联网拉取客户数据/图片。

## 3. 结构矩阵与312张图不混账

MATRIX.json逐项列出312个配置ID：13场景 × 2宽(360/1280) × 2主题 × 2缩放(1/2) × 3TargetPlatform(android/ios/macos)。基准高800、DPR=1、locale=zh-CN。P1=120，P2=72，P3=120。保留V1覆盖量，未为缩短计划删除平台或大字组合。

每个配置分别记录结构结果、candidate_image、sealed_baseline、comparison、review；截图存在不等于全部字段PASS。P1/P2/P3在T22/23/24做结构与无障碍，`.a`生成图，`.b`逐图审查/封存/普通比较。该拆分使生成成功不再自动变成批准。

额外定向Widget场景（不伪装包含在312图内）：360×320短窗口；360×800上keyboard inset=300；en-US长文案；1280真实shell的窄内容区；空/未知来源；feature关闭；焦点从折叠面板移出；分页错误保留已有内容。原生系统字体设置不是精确TextScaler=2.0，分别记录。

视觉字体缺失时结构/业务测试继续，所有视觉/真实文字尺寸义务留BLOCKED_GOLDEN_ENV。Ahem或不稳定系统fallback不得签视觉PASS；字体二进制不随本包分发。[Flutter golden官方说明](https://api.flutter.dev/flutter/flutter_test/matchesGoldenFile.html)

## 4. Golden更新、批准、存储与恢复

### 4.1 两种合法存储模式，W0择一冻结

**TRACKED**：仓库已经允许本范围PNG入Git，则每页baseline与manifest按本卡提交；普通测试读取固定版本。不得为了方便更改全仓ignore。

**EXTERNAL_PINNED**：遵守既有“不跟踪PNG”策略，sealed图放`@runtime/golden/pN/sealed/<manifest-hash>/`，导出本计划专用baseline归档及SHA-256清单；测试环境显式绑定`UIUX_GOLDEN_BASELINE_ROOT`。新的本计划必需golden测试在目录/图/manifest不存在时失败，而不是skip。机器搬迁先恢复同hash归档；不能“先update再说”。T29至少做一次临时目标目录hydration、普通比较与删除一张图会失败的演练。归档不含字体、凭据或生产数据。

哪种模式都不因为fresh checkout没有baseline而自动通过。EXTERNAL_PINNED不代表CI已经部署了取包步骤；本次只证明本地候选及可恢复归档，CI部署另列NOT_RUN，不冒充远端门通过。

### 4.2 严格流水

`布局/交互断言 → candidate图及expected-diff → 视觉审查记录 → 工程baseline封存 → 不带update普通比较`

candidate生成前保存旧sealed hash；update只写新的candidate输出目录，不覆盖sealed。每张review记录：config_id、需求/Task、before来源或NEW_SCENARIO原因、after/diff hash、检查结果、reviewer身份与模式。无旧图时只能明确NEW_SCENARIO，不能用新图复制一份假before。W0旧截图若未有真实字体，不作为可读性before；可用保留基线的临时源码快照叠加纯测试夹具补拍，不接管或重建原候选worktree。

完全相同像素且对应语义断言等价，可按等价图组审查；仍需为每个配置ID映射结论。不能靠宽度、主题或平台“应该相同”跳图。超过单卡0.5人日审查预算拆该页子卡，继承剩余图片集合。

`SELF_REVIEW_ONLY`只表示工程自审封存，可用于本地回归候选；不伪称独立审查或人工UX批准。具备独立审查能力时优先不同审查者；没有则保留模式并在UX阶段进行人工确认。作者不可静默扩大diff容差、掩码文字区域或删除失败场景。

### 4.3 缺图/跳过/场景漂移的负例

必须测试：删除一张必需图→失败；manifest漏一配置→失败；图hash变化→失败；SDK/字体环境hash变化→拒绝比较；update退出0但review缺失→不能封存；必需case新增skip→gate失败。成功日志不是这些反例的替代品。

## 5. 每批门禁与执行时机

完整argv见COMMANDS.json，实际本机解析见T04的`commands.resolved.json`。默认Flutter重型进程并发数1；不影响代码编写三lane并行。

| 节点 | 必需任务/命令 | 可继续与禁止判定 |
|---|---|---|
| M0 | T00—T04.c；包校验、scope/lock/state实际正反例 | 旧analyze/旧套件记录baseline；某页有外来dirty只阻塞该页；不宣称零问题 |
| M1 | T05/T06/T07—09；harness/copy/fixture测试、定向analyze | 字体T05.a是独立视觉能力，不阻塞实现与调用回归 |
| M2 | T10—21各页定向测试、scope、analyze | P2可先入B3，不等P1；整批状态仍列全页结论 |
| M3 | T22—24及各.a/.b；三页旧回归与T25—27；scope/analyze | 保留312逐配置manifest、普通比较及review_mode |
| M4A | T29在K上执行下面命令 | 任一必需门失败/阻塞/未知即PARTIAL_BLOCKED；不能用报告成功代替 |
| M4B | M4A+T30/31/32各自iOS及.a Android/.b macOS | 仅有真实平台记录才UX_ACCEPTED；恢复实证另列 |

本机已解析Flutter入口后，M4A概念顺序如下（`flutter`须替换为真实wrapper argv）：

```sh
python3 tool/uiux/recovery_contract_test.py
python3 tool/uiux/check_state.py --plan-id imboy-enterprise-uiux-v1
python3 tool/uiux/check_scope.py --base "$UIUX_BASE_SHA"
flutter analyze --fatal-infos --fatal-warnings
flutter test test/uiux/contract test/uiux/p1 test/uiux/p2 test/uiux/p3 --reporter json
flutter test test/uiux/golden --reporter json
flutter test --reporter json
git diff --check "$UIUX_BASE_SHA" HEAD
```

这些都是T04/T05/B3创建或核验后才运行的命令，不声称当前包带了Flutter实现。命令均保存原始exitcode；不带pipefail的tee管道禁止当证据。目录必须含预期用例，不能跑空目录。T29的state检查校验当前运行状态与已完成前置，不能要求T29预先ACCEPTED，避免自环。

全量Flutter只在最终候选冻结后运行一次；真实修复改变了代码/测试/依赖时再运行。报告附件R不修改K，按独立report-only门验证，避免每写一次结论就重跑全量。Erlang EUnit=N/A；原生integration_test不包含在普通flutter test里时须明确NOT_RUN或另列证据。

## 6. 行为trace不变量

按T01—03本机基线确定可观察方法，测试只用合成数据。trace比较保留事件类型、业务顺序、API路径、org/workspace、channel/session ID、query/tag/essence/page、expected_version、回调次数和返回导航级数；只可归一化已登记的非业务随机trace_id/时间戳。不得删除CAS版本、身份/作用域字段来“让trace一致”。

P1搜索/筛选展开收起：请求数不变，提交才走原查询；频道返回/更多/DM及发布权限不变。P2资源gate、排序、OA entries、appsUrl、桥签发参数及Android条件入口不变。P3掩码、摘要数据来源、源wire值、队列计数、SSE刷新、分页、接单冲突/容量/禁用语义不变。请求与权限回归失败只允许展示层修复；域层缺陷记录范围外。

## 7. 结果判级，不写“100%”掩盖待验

| 维度 | 条件 |
|---|---|
| PLAN_STATIC_CHECK_PASS | 包结构/依赖/引用/负例校验通过；不是本机执行 |
| IMPLEMENTATION_COMPLETE | 必需实现卡及相应定向测试完成；可能仍有全量/视觉/环境阻塞，不是正式自动验收等级 |
| LOCAL_CANDIDATE_PASS | 39个自动前置及T29最终K门全部满足，范围内未关闭缺陷为0，312配置及封存普通比较齐全 |
| UX_ACCEPTED | LOCAL_CANDIDATE_PASS + 九张原生平台人工卡通过；工程自审样张在人工UX阶段确认 |
| RECOVERY_PROTOCOL_TEST_PASS | T28调用实际控制模块的临时Git故障套件通过 |
| CROSS_SESSION_RESUME_VERIFIED | T28.m真实新会话恢复成功；独立于UX等级 |
| PARTIAL_BLOCKED | 任一必需自动义务不可达/失败/缺证据；保留其余卡的真实完成结果 |

报告至少列：自动通过数/必需数、人工通过数/必需数、未验数、阻塞数、golden执行/比较/审查数、scope缺陷数、K与当前HEAD、真实恢复状态。N/A只能用于原条件本就不适用的人工场景，不能删除本版必需UI要求或golden配置。

### 证据指纹与原生构建补充

render_environment_hash只覆盖会影响渲染的SDK/engine/OS/字体/locale/platform/viewport/DPR/时钟/feature/fixture/动画输入；candidate/sealed存储路径另记execution环境，不因文件从candidate复制到sealed就伪判字体环境变化。final普通比较使用三页sealed manifest合成的只读根目录，并记录组合hash；单页审查只绑定本页根。

原生卡的构建产物必须记录来源K、构建命令与输入manifest。优先使用在K准备的测试产物；缺少产物时在本计划登记的临时源码快照中按K构建，不新建/替换原候选worktree，不偷偷从报告R的HEAD构建再把SHA写成K。构建与账号/设备准备是明确前置，缺环境MANUAL_PENDING；不能把这一缺口藏在“3步人工观察”里。T04必须登记各平台已有构建入口，未核实不臆造命令。
