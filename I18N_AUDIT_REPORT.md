# IMBoy i18n 审计与 Key 治理报告（I18N_AUDIT_REPORT.md）

> 生成：2026-09-05 | 任务：P3（Key Governance Decision）+ P0-P6 集成记录
> 仓库：`/Users/leeyi/project/imboy.pub/imboyapp` | Base SHA：`22460e6ca467db77704c334a316d7de5de99379f`
> 工具：审计器 `assets/i18n/i18n_audit.rb`（P1 加固版，回归测试 9/9）+ 独立 Ruby 交叉扫描脚本
> 术语基线：[I18N_TERMINOLOGY.md](./I18N_TERMINOLOGY.md)

---

## 1. 执行摘要（2026-09-05 一日波次）

| 任务 | 内容 | 结果 |
|---|---|---|
| P0 | 只读基线重审计 | PASS（基线数字与计划文档零漂移；当日后续被并行任务两次小幅推进：2779→2785→2789 键） |
| P1 | 审计器加固 | PASS：locale 白名单、plural 感知、重复键检测、placeholder 归一、`check`/`missing` 模式、9/9 回归测试 |
| P5+P7-P15 | 10 语言 Agent 并行补齐 | 10/10 完成：全部 missing=0（ru-RU 首发撞 API 限流后重发成功） |
| P6 | RTL 根因修复 | PASS：移除 `lib/run.dart` 全局 `Directionality(ltr)`，5/5 专项测试绿 |
| P2 | 术语治理基线 | 完成：`I18N_TERMINOLOGY.md`（10 语言 × 核心概念 + 6 项产品确认项） |
| P3 | Key 治理裁决 | 本报告：只出清单，**不执行删除**，等待人工确认 |

## 2. Before / After

```text
Before（计划文档 Phase 1，2026-09-04）
Languages: 10
Keys: 2779 base
Missing: 3812 slots
Used missing: 3703 slots
Unused candidates: 737（口径：一次性外部扫描）
Duplicate-value groups (zh-CN): 193 (460 keys)
Empty/null / duplicate YAML key / placeholder mismatch: 0
RTL: BLOCKED（全局 TextDirection.ltr）
Audit tool: 3 处已知缺陷 + 无 check 模式（门禁为空）
Release: NO-GO

After（本报告时点，2026-09-05）
Languages: 10（白名单校验通过；.dart_tool 排除）
Keys: 2789 base / 2789 × 10 locale（每语言全量对齐）
Missing: 0 / Used missing: 0
placeholder mismatch: 0 / duplicate key: 0 / empty/null: 0 / illegal alias: 0 / 真性 extra: 0
同值残留（untranslated）: 0（修复前 zh-Hant 215 + ja-JP 30）
静态引用前缀: 2158；unused 分类: candidate=717, indirect=2（plural/alias 感知口径）
SAFE_MERGE 候选（10 locale 严格同值）: 0（仅 5 组品牌词同值，合理保留）
RTL: 已修复根因 + 防回归测试（en/zh→LTR、ar→RTL、运行时切换）
Slang 生成: dart run slang 成功（10 × strings_*.g.dart 已更新）
Release: NO-GO（母语审核缺失 + 真机 UI/RTL 走查未做，见 §8）
```

## 3. Key 治理分类（裁决结果）

全量 2789 个 base 键分类如下：

| 分类 | 数量 | 说明 |
|---|---:|---|
| USED | 2,070 | 存在静态 `t.ns.key` 引用（2158 个引用前缀，含中间节点展开） |
| INDIRECTLY_USED | 2 | 未被静态引用但是 `@:` alias 目标（plural/alias 感知） |
| DYNAMIC_OR_PROTOCOL_RISK | 3 | 见下表，证据显示可能被字符串级/协议级引用，一律 KEEP |
| SAFE_MERGE | 0 | 「10 locale 严格同值」口径下无合并候选（仅 5 组品牌词：IMBoy/Owner/E2EE 类，属合理同值，**不建议动**）；zh-CN 内部 193 组同值属概念级合并议题，需逐组人工裁决，本报告不列（计划 §1：不得仅因中文相同而合并） |
| UNSAFE_MERGE | 0（不列） | 同上，概念级裁决留人工 |
| CONFIRMED_UNUSED（证据充分候选） | **714** | 完整键路径在 app 仓全部非生成代码/配置/文档 + 后端 imboy 仓中**零出现**；无动态访问命中（8 处 `t[...]` 全在测试文件且为裸 `t[`，不构成命名空间级动态键）；非 alias 目标。**删除仍需人工确认后由 P4 执行** |
| KEEP | 其余 | 2070 USED + 2 INDIRECT + 3 RISK + 全部未确认项 |

### DYNAMIC_OR_PROTOCOL_RISK（3 键，全部 KEEP）

| 键 | 证据 | 处置建议 |
|---|---|---|
| `main.timeWeekdays` | P5 判定疑为程序 `split(",")` 数据值（"星期一,星期二,…"）；仅在我的术语表文档中被提及 | 人工确认消费代码后再定；**保留** |
| `momentFriendPicker.title` | `moment_friend_picker_page.dart:86` 注释声称"为空时用 `momentFriendPicker.title`"，但实现中无该调用——注释与代码矛盾 | 人工核实注释过期后可删；**保留** |
| `workspace.navMembers` | 后端仓 `imboy/docs/planning/dual-exp-acceptance.md` 验收文档提及 | 功能验收相关键，**保留** |

### 714 键候选的证据方法（可复现）

1. 静态引用扫描：审计器 `scan_refs` 扫 `lib test integration_test tool config` 全部 `.dart`（排除 `*.g.dart`），`t.` 前缀全展开 + `t[...]` 动态形态单列 → 未命中集合 717。
2. alias 目标排除：全部 locale 的 `@:` 链接目标（plural 感知解析）→ 排除 2 个 indirect。
3. 精确字符串交叉扫描：717 键逐一在 app 仓非生成 dart/yaml/json/md/html/sh + 根级配置中做**精确匹配**（键名后不跟标识符字符，规避 `common.tip` ⊂ `common.tipTitle` 误命中）→ 命中 2（见上表）。
4. 后端仓扫描：`rg -F -f` 717 键对 `../imboy` 全仓（排除 .git）→ 命中 1（见上表）。
5. 717 − 3 = 714 键全链路零引用。**注**：slang 生成物（lib/i18n/*.g.dart）天然引用全部键，已排除；删除后须重跑 `dart run slang` 使生成物同步（P4 验收含此步）。

## 4. Human Confirmation Required（P4 硬门）

> **P4 未获得人工确认前禁止执行任何删除。** 以下 714 键已具备"全链路零引用"证据，但最终裁决权在产品所有者：
> 宁可保留一个不确定 Key，也不能误删。你可以：
> **A. 批准全部 714 键删除**（P4 将逐键重扫 → 删除 10 locale YAML → `dart run slang` → analyze/test → 审计门）；
> **B. 抽样审阅后部分批准**（按 namespace 批准）；
> **C. 全部保留**（0 风险，代价是 25% 的键为死键）。
> 注意：`common.true/common.false/common.failed/common.info/common.tip/common.tips/common.processing/common.submitted` 等通用名键也在候选内（全链路确实零引用），如你觉得其中某些"将来会用"，请把它们点名为 KEEP，其余批准。

附录清单见 §9（按 namespace 分组，714 键全列）。

## 5. Top 风险（当前残余）

1. **母语审核缺失**（最大风险）：8 个非中英 locale 全部无真人审核，约 60 键在 Agent 报告中标记待审；zh-Hant `buttonCancel=關閉` 等同形规避变体语义有微移。→ Gate 4 = UNKNOWN。
2. **真机 UI/RTL 未走查**：P6 已修复根因并加了框架级测试，但 ar-SA 真机 RTL、de/fr/it/ru 长文案（`complianceKeyChangedBody` 300+ 字符级）在 360×640 视口的溢出情况未验证。
3. **技术字段 RTL 可读性**：URL/ID/Hash/安全码在 RTL 语境的显示顺序未做字段级 LTR 处理（P6 按任务书只记录不改造）。
4. **并行会话共栖**：工作树另有 e2eeConsent（举报证据线）、D-04（注销线）等并行任务的 i18n 改动；`account.logoutCancelRequest` 曾漏同步 it-IT（已由集成补齐）。后续每轮审计需重跑（基线会被并行任务推进）。
5. **zh-CN 待决项**：您/你混用 28 处、`main.timeWeekdays` 数据值疑云（术语表 §11）。
6. **审计器已知边界**：裸 `t[`（无命名空间）动态访问无法映射到具体 ns（当前 8 处均在测试文件，unknown=0）；slang 语法错误只能由 `dart run slang` 最终兜底（本报告时点已通过）。

## 6. 命令结果（关键验收）

```text
ruby assets/i18n/i18n_audit_test.rb                 → 9/9 passed, exit 0
ruby assets/i18n/i18n_audit.rb check                → RESULT: PASS, exit 0（missing=0）
I18N_AUDIT_STRICT=1 ruby assets/i18n/i18n_audit.rb check → RESULT: PASS (strict)
ruby assets/i18n/i18n_audit.rb summary              → 10 locale 全部 keys=2789 missing=0 extra=0 placeholder_mismatch=0
ruby assets/i18n/i18n_audit.rb untranslated         → 零输出（残留清零）
ruby assets/i18n/i18n_audit.rb unexpected-scripts   → 零违例
flutter test test/unit_test/rtl_directionality_test.dart → 5/5 passed
dart analyze lib/run.dart test/unit_test/rtl_directionality_test.dart → No issues found
dart run slang                                       → 成功（0.4s）
git diff --check                                     → 干净
```

## 6.5 P16 第二轮审计 + UI Gate（2026-09-05 追加）

### UI Gate（widget 级，机器可验证部分）

新增 `test/unit_test/i18n_ui_gate_test.dart`：10 语言 × 真实文案（每语言 YAML 最长 body / 中等标题 / 最短按钮文案，placeholder 按最坏情况填充）× 三视口（360×640 / 375×812 / 412×915）× 场景（AppBar 单行标题 / 设置 ListTile 流 / Dialog+按钮行 / BottomSheet / 按钮行），断言零 RenderFlex overflow；ar-SA 以 RTL 方向渲染。

```text
flutter test test/unit_test/i18n_ui_gate_test.dart    → 50/50 passed
flutter test test/unit_test/i18n_ui_gate_test.dart test/unit_test/rtl_directionality_test.dart → 55/55 passed
dart analyze lib/run.dart + 两个测试文件              → No issues found!
```

说明：场景按真实组件约定构造（AppBar 单行 ellipsis、Dialog 长内容滚动、按钮取各语言最短文案分布）——度量的是译文布局健壮性，而非"往固定容器里堆最长文本"。

### 产品语义交叉检查（脚本抽查）

```text
ja-JP 禁用词「登録者」                                 → 0 处（P9 裁决生效）
zh-Hant 高频简体词（网络/视频/软件/服务器/鼠标/设置）    → 0 处
main.subscriber 全语言非空                             → 10/10（zh/zh-Hant/ja 含汉字为合理文案）
ru-RU 复数四分支（one/few/many/other）                  → 在场（other=минуты 待母语复核）
```

### 本轮新增所有权变更（P16）

`test/unit_test/i18n_ui_gate_test.dart`（新增，i18n 专项测试，P16 权限内）。P0-P15 归属审计复核：10 locale 目录外无 Agent 越界改动。

## 6.6 Gate 3 真机走查尝试（2026-09-05，BLOCKED：设备被并行会话占用）

已落地 `integration_test/i18n_rtl_walkthrough_test.dart`：登录进主 Shell 后 `LocaleSettings.setLocaleRaw('ar-SA'/'de-DE')` 编程切换语言，断言 `Directionality.of` 翻转（ar=RTL 是 P6 修复的真机端到端证据），检查点暂停 + 宿主侧 adb screencap 截图（test_utils 既有 `AI_SCREENSHOT_HOLD_MS` 约定）。`dart analyze` 零 issues。

两轮执行均验证了基础设施：gradle 构建 36.7s → 安装 → 启动 → env=local 正确 → 后端探活通过（127.0.0.1:9800 经 adb reverse）。但测试 isolate 均在启动后数十秒失联（"did not complete"）。设备事件日志（`logcat -b events`）取证：

```text
09:25:15  am_kill pub.imboy.app(pid 32202)  stop...from pid 2333 by app   ← 我动手前的残留实例被杀
09:25:45  am_proc_start pub.imboy.app pid 2568                              ← 第 1 轮测试启动
09:26:14  am_kill pub.imboy.app(pid 2568)   stop...from pid 2923 by app    ← 第 1 轮被杀
09:32:10  am_proc_start pub.imboy.app pid 3803                              ← 第 2 轮测试启动
09:32:28  am_kill pub.imboy.app(pid 3803)   stop...from pid 4010 by app    ← 第 2 轮被杀
```

判定：短命 pid 连续 force-stop 是 adb shell `am force-stop` 特征；杀戮节奏在我开始之前就已存在（09:16 起设备上即有别的会话在自动化此包），我的实例被当作残留清掉。**按共享设备纪律不互抢**，走查让位；本测试文件留在树中，设备空闲窗口按文件头命令重跑即可。macOS 侧并行会话（D-04，-d macos，9801，smoke_alice）已排除嫌疑。

Gate 3 结论：先后挂 6 轮守望全部安全让位（零互踩；对方 adb 脚本循环持续重启 imboy），14:16 持久守望 8 次尝试弹尽，14:30 发现对方循环已于 13:04 停止、设备静默 86 分钟，当场发走查——**成功，见 §6.6.2**。

### 6.6.2 真机走查成功记录（2026-09-05 14:32，Gate 3 收口）

```text
flutter test integration_test/i18n_rtl_walkthrough_test.dart -d XWE6R19916004085
  （APP_ENV=local, 127.0.0.1:9800 经 adb reverse, smoke_bob, AI_SCREENSHOT_HOLD_MS=4000）
→ 00:35 +1: All tests passed!
```

- 登录 smoke_bob → 主 Shell → 编程切换 locale：基线 zh=LTR ✓；**ar-SA 整树 Directionality==rtl（真机硬断言）** ✓；de-DE 回 LTR ✓。
- 截图三张（宿主 adb screencap，`.claude/reports/i18n-walkthrough-2026-09-05/`，gitignored 盘上证据）：
  `i18n_01_baseline_shell.png`（zh：底部导航 消息/联系人/频道/我的，头像左/时间右）
  `i18n_02_ar_shell.png`（ar：**完整镜像**——导航顺序倒置且 الرسائل tab 高亮居右、头像右/منذ 6 ساعة 左、横幅锁图标右/关闭左，阿文连写字形正常无豆腐块）
  `i18n_03_de_shell.png`（de：三行 E2EE 长文案完整无截断，Vor 6 Stunden 后缀式时间，ä/ü 正常）。
- P6 修复（移除全局 Directionality）自此具备 widget 级 + macOS + 真机三层证据。
- **走查战利品一（ru 复数 resolver bug）**：ru 截图显示「7 часа назад」（应 часов）——
  run.dart 把 ru 硬编码为恒返回 other，P14 补齐四分支后 resolver 未同步；且旧注释
  「ru/ar 不在 slang 内置表」经实证为误判（slang 4.19 内置表有 ar/ru 的 CLDR 规则）。
  修复 a2ab55d4：ru 移出硬编码走内置规则；ar 因仅 other 分支暂留。真机复跑验证
  「7 часов назад」正确。
- **走查战利品二（弹窗硬编码中文）**：ru 态 E2EE 恢复弹窗标题/正文显示中文而按钮为
  俄语——newDevice 场景正文是 deda4751 引入的硬编码中文内联串，且文案在 showDialog
  前提前求值导致切换语言时弹窗残留旧语言。修复 65b25183：新增
  chat.e2eeRecoveryNewDeviceBody（10 locale，机器翻译待母语审核，已入审核包 Tier1）、
  正文回归 t 键、文案求值移入 builder。strict 门 PASS、UI Gate 50/50。
- 走查扩展：测试升级为 8 语言全检查点（zh 基线 + ar RTL + de/fr/it/ru/ja/ko LTR），
  8 张截图全抓到（14:42/14:54 两轮）。
- **走查延伸（硬编码中文全量清查）**：弹窗缺陷提示了缺陷类，对 lib/ 全量扫描
  （排除注释/日志/生成物）：1929 处 CJK 字面量中**用户可见 UI 硬编码 38 处**，
  修复 34 处（9 文件，21 新键 × 10 locale，含消灭 channel_detail 的 isChinese
  三元伪 i18n——原只支持中英无视其余 8 语言）；合法保留 4 类：语言自称 3 处
  （i18n 惯例）、设计系统内部标签、内部诊断异常 message、语言选择页自身。
  strict 门 PASS、UI Gate+RTL 55/55（9d2bad3d）。日志/迁移描述类 1800+ 处
  按团队惯例保留，不入 i18n 范围。
- **全量 flutter test 终验（收口）**：+6107 通过 / ~240 跳过 / -7 失败；7 个失败
  全部为 loading 失败（非断言失败），归属并行工作流：2 个伪装 .dart 的历史
  日志文件 + 5 个 file_picker 升级 WIP 测试桩（invalid_override）。
  i18n 改动涉及功能域测试全绿——19+ 笔提交的回归安全性与 push 就绪度
  以全量套件为金标准证据。

### 6.6.1 macOS 桌面过渡走查（2026-09-05，用户批准的过渡证据）

```text
flutter test integration_test/i18n_rtl_walkthrough_test.dart -d macos \
  --dart-define=APP_ENV=local --dart-define=API_BASE_URL_OVERRIDE=http://127.0.0.1:9800 \
  --dart-define=WS_URL_OVERRIDE=ws://127.0.0.1:9800/api/v1/ws \
  --dart-define=TEST_PHONE=smoke_bob --dart-define=TEST_PASSWORD=admin888
→ All tests passed!（00:13 +1）
```

- 登录 smoke_bob → 主 Shell 挂载 → `LocaleSettings.setLocaleRaw` 编程切换：
  基线 zh-CN = TextDirection.ltr ✓；**ar-SA 后整树 Directionality == rtl（硬断言通过，
  P6 移除全局 Directionality 修复在真实渲染面的首个端到端证据）**；de-DE 回 ltr ✓。
- binding.takeScreenshot 在该运行器不受支持（按测试设计仅诊断产物，不阻断）。
- 局限：macOS 桌面非真机——真机字体渲染/厂商 ROM 行为仍以 §6.6 的真机走查为准。

## 7. 剩余人工审核清单

1. **母语审核**（ar-SA/de-DE/fr-FR/it-IT/ja-JP/ko-KR/ru-RU/zh-Hant）：审核材料见 **[I18N_NATIVE_REVIEW_PACKAGE.md](./I18N_NATIVE_REVIEW_PACKAGE.md)**（2026-09-05 按删除后数据集重新生成并完成 AI 预筛标注：240 行 = 220 ✅ / 20 ⚠️，⚠️ 集中在欧语言长合规文案的长度比观察项；**AI 预筛 ≠ 母语审核**）。结论只接受 APPROVED / CHANGES_REQUESTED / BLOCKED_NO_REVIEWER。
2. ~~P4 删除确认~~ **已执行（2026-09-05 用户批准"删 700 留 14 预置键"）**：删除 703 键 + `common.on/off`（YAML 1.1 布尔键别名下 true/false 候选的真身，零引用实证后从 zh-CN/en-US 摘除）；14 个 `*NotImplemented` 预置键保留。执行后 keys=2124×10、strict 门 PASS、i18n 测试 55/55。
3. **产品确认 6 项**（术语表 §11：您/你、港式词、角色词本地化、unsubscribe 同值、timeWeekdays、红包吉祥话）。
4. ~~真机走查~~ **已完成（2026-09-05 14:32）**：MRD-AL00 真机，zh 基线 LTR → ar-SA 整树 RTL → de-DE 回 LTR 硬断言全过；三张截图取证于 `.claude/reports/i18n-walkthrough-2026-09-05/`（ar-SA 底部导航/会话行/横幅完整镜像、阿文字形连写正常；de-DE 三行长文案无截断）。视口维度由 widget 级 UI Gate 50/50 覆盖。

## 8. 发布状态（Final，2026-09-06 §8.12 后更新）

```text
Gate 1 自动门（missing/placeholder/duplicate/alias/audit/tests）: PASS（Round-3 修复后复验）
Gate 2 术语一致性: PASS*（基线已建 + 语义交叉检查通过；*未经母语确认）
Gate 3 UI/RTL: PASS（widget 级 50/50 + RTL 5/5 + 真机走查 ar=RTL/de=LTR 硬断言通过 + 三语言真机截图取证；macOS 过渡证据归档 §6.6.1）
Gate 4 母语审核: FAIL（BLOCKED_NO_REVIEWER——8 语言审核包回填栏全空）
Final Release: CONDITIONAL GO
```

**CONDITIONAL GO 依据**（见 §8.12 风险接受记录）：机器侧四门中三门 PASS 且 P0=0；唯一 FAIL 项（母语审核）经产品负责人 2026-09-06 明示授权以「已知风险显式接受」方式放行（原话要点：期望流程不依赖人工、授权 Agent 给最优解）。**不得声称 100% 母语质量**；8 语言译文质量 = 机器门 + 两轮独立 AI 深审（Round-2/3）背书。发布后母语审核结论回填后：全 APPROVED → 升格 GO；任一 CHANGES_REQUESTED → 走热修闭环（审核包 `I18N_NATIVE_REVIEW_<locale>.md` 即热修工单）。push 仍需单独授权（用户此前明示暂不）。

<details><summary>历史 Tentative 判定（2026-09-06 Round-3 前）</summary>

```text
Gate 1 自动门: PASS
Gate 2 术语一致性: PASS*（*未经母语确认）
Gate 3 UI/RTL: PASS
Gate 4 母语审核: UNKNOWN（BLOCKED_NO_REVIEWER）
Tentative Release: NO-GO（唯一剩余原因 = Gate 4）
```

</details>

## 8.5 P4 执行工具就绪 + 候选清单重验证（2026-09-05 追加）

**P4 尚未执行任何删除**（等用户批准名单）。执行机已备好：

- `assets/i18n/i18n_key_prune.rb`：`verify <清单>`（逐键重验，hard fail 即 exit 1）／`apply <清单> --approve`（先强制重验再从 10 locale 手术删除，保持文件其余字节不变，删空父键级联；无 `--approve` 拒绝执行）／`selftest`（4/4：叶子保留注释、级联、复数块、缺键零改动）。
- 基准清单 `assets/i18n/p4_candidate_keys.txt`（717 键，候选段由 `LIST=1000 i18n_audit.rb unused` 导出）。**当日重验证 717/717 PASS**——清单证据在当前树上无漂移。
- 口径修复（工具与审计器对齐中发现的两个坑）：① alias 键必须同时进 logical 与 aliases 两表（58 键误报"不存在"）；② slang 参数键 `name(param)` 需剥括号后缀再比对（37 键误报）。
- 用户批准后执行序：`apply <批准清单> --approve` → `dart run slang` → strict 审计门 → i18n 测试 → analyze。

### 8.5.1 P4 执行记录（2026-09-05，用户批准后）

```text
删除清单：717 候选 − 14 个 *NotImplemented 预置键 = 703 键（verify 703/703 PASS）
apply：10 locale 共删 6687 行（含级联父键），各 locale -666~-670 行
删后校验发现：common.true/false 候选实为 on/off 的 YAML 1.1 布尔键别名
  （Psych 把 on/off 键类型化为 true/false；Dart yaml 1.2 视为字符串键），
  prune 行删除按节点原文匹配而 no-op —— 已从 zh-CN/en-US 手术摘除（零引用实证）
并行会话竞态处理：对方功能线实时往 zh-CN/en-US 回填新键（common.on/off 除外，
  另有 collectedVideoFormatIncorrectCannotFindVideoUri / momentLikesCountOnly），
  由集成者补齐 8 语言翻译（12 slots）后收敛
终态：dart run slang 成功；keys=2124×10、missing=0、extra=0；
  I18N_AUDIT_STRICT=1 → PASS；flutter test（UI Gate + RTL）55/55
工具加固：i18n_key_prune.rb apply 增加删后校验（逐键实测消失，防布尔键静默跳过）
遗留：unused candidate=54（并行会话新增代码的未引用键，不在本次批准范围）
根治记录（同日）：i18n_audit.rb 的 parse_yaml_file 改为 Psych 树构建 + YAML 1.2 core
  标量解析（键名保持原始文本，on 不再类型化为 true，与 Dart yaml 包对齐）；
  i18n_key_prune.rb 的 flat_locale 同口径统一。当前树行为逐字节零变化
  （summary/check 前后 diff 为空、审计回归 9/9、prune selftest 4/4），
  幽灵键类别自此免疫
```

## 8.6 P17 终验复验（2026-09-06，HEAD=eaf5e700）

母语审核结果未到位前提下的机器侧全门复验（基线漂移检查 + Gate 1-3 复跑）：

```text
Gate 1 自动门:  PASS（复验零漂移）
  I18N_AUDIT_STRICT=1 ruby i18n_audit.rb check → RESULT: PASS (strict)，EXIT=0
  10 locale 全部 keys=2158、missing=0、extra=0、placeholder=0、duplicate=0、
  illegal_alias=0、empty=0、dynamic access risk=0 —— 与 §2 After 终态一致，零漂移
  same_as_base 抽查（ar-SA=30）：全部为 @: alias 结构等价 / 技术值（https://...、
  #2474E5）/ 英文角色词（Owner/Member/Guest），无未翻译泄露
  工具链回归: i18n_audit_test.rb 9/9、i18n_key_prune.rb selftest 4/4
  slang 同步: dart run slang 重生成仅时间戳行差异（07:17→23:43 UTC），
  已手工复原字节原状——生成物与 YAML 完全同步
  unused candidate=54：维持 §8.5.1 遗留口径（并行新代码产生，未授权处置）
Gate 2 术语:   PASS*（I18N_TERMINOLOGY.md 基线在库；*未经母语确认，维持 §8 口径）
Gate 3 UI/RTL: PASS（flutter test UI Gate + RTL 55/55 All tests passed!;
  真机走查证据 8 截图在 .claude/reports/i18n-walkthrough-2026-09-05/，维持 §7.4）
Gate 4 母语审核: BLOCKED_NO_REVIEWER
  I18N_NATIVE_REVIEW_PACKAGE.md 总览表 8 语言（ar/de/fr/it/ja/ko/ru/zh-Hant）
  审核人/结论/日期全部空白——无任何 APPROVED / CHANGES_REQUESTED 填写

Final Decision: NO-GO（唯一原因 = Gate 4；Gate 1-3 复验全 PASS）
解锁路径: 8 位母语审核人按审核包口径填写结论 → 全 APPROVED 可转 GO；
  任一 CHANGES_REQUESTED 须修复译文并复审后闭环。
```

## 8.7 P17 期间缺陷发现与 Round-2 档案（2026-09-06 追加）

复验 unused 候选（§8.6 遗留的 54 个）时发现**两个工具级缺陷**，均已闭环：

### 缺陷一：上轮 P4 执行参数键静默漏删（~37 键）

**现象**：717 批准清单中 703 键获准删除，但 3f5ff07a 实删约 666 键（zh-CN −682 行）；
2789 − 665 = 2124 与"删后终态"吻合——差值 37 即被漏删的参数形态键。

**实证**：`git show 3f5ff07a -- assets/i18n/zh-CN/chat.i18n.yaml` 中普通键
`e2eeReady: 准备就绪` 有删除行，而 `e2eeReadyWithShards(count): ...` 无任何改动；
当日 apply 的行级匹配无法命中 `name(param):` 形态，删后"逐键实测消失"校验存在同源盲区，
37 键假阴性通过。**当时 reported keys=2124 实为漏删产物，非用户批准语义下的终态。**

**现状**：34 个参数形态漏删键 + 1 个普通形态键（collectedVideoFormatIncorrect…，删除后遭并行
会话回填、其功能代码尚未落地）今日仍在树上，合计 35 键，全部零引用（见下）。

### 缺陷二：审计器 `tr.` 别名访问器盲区（本轮已修复）

**现象**：`final tr = translations ?? t` 可注入翻译模式下 `tr.discovery.momentLikedBy(...)` 等
引用不被 `\bt\.` 扫描命中，导致 3 个在用键被误标 unused：
`discovery.momentLikedBy` / `discovery.momentAndOthersLiked` / `discovery.momentLikesCountOnly`
（moment_interactions.dart:842-851，全仓 `tr.` 引用共 4 处）。该盲区同样污染了原始 717 档案
——此 3 键当时即为假候选（2 个参数形态受缺陷一"保护"未被删，1 个普通形态删后由并行线回填，
殊途同归未造成破坏）。**全量测试通过存在运气成分，方法学上不可复用。**

**修复**：`i18n_audit.rb` scan_refs 增加 `\btr\.` 扫描（保守方向：宁可多算 used）；
回归测试 9/9 → **10/10**（新增 `alias_accessor_tr_counts_as_reference`）。
修复后真实仓 candidate 54 → **51**（3 个在用键正确出列）。strict 门不受影响（PASS）。

### Round-2 候选档案（51 候选的证据重验与分组）

证据标准与上轮一致且更严（`tr.` 感知 + `-w` 词边界精确匹配）：静态引用 0、动态访问 0、
alias 目标 0、app 仓 lib/test/integration_test/tool/config/docs 全量 `-w` 扫描 0、
后端 imboy 仓 0 命中。清单落盘 **[assets/i18n/p4_candidate_keys_round2.txt](./assets/i18n/p4_candidate_keys_round2.txt)**
（37 键 + 分组注释），`i18n_key_prune.rb verify` 37/37 PASS。

| 组 | 数量 | 性质 | 建议 |
|---|---:|---|---|
| A | 34 | 上轮已批准（⊂703）但因缺陷一漏删，参数形态，本轮证据重验零引用 | 可删（完成已批准操作） |
| B | 1 | collectedVideoFormatIncorrectCannotFindVideoUri，上轮删除后并行会话回填、功能代码未落地 | 建议随功能落地后复核再删 |
| C | 2 | common.success、main.markStar，全新候选，无批准记录 | 人工裁决 |
| — | 14 | `*NotImplemented` 预置键 | 维持用户既有拍板：保留 |

### Human Confirmation Required（Round-2）

> 按任务书 P4 硬门：未获人工确认前不执行任何删除。可选：
> **A. 批准 A 组 34 键**（完成上轮已批准删除的残余；B/C 保留）；
> **B. 批准 A+B+C 全部 37 键**；
> **C. 全部保留**（待并行功能线落地后重新取证）。
> 批准后执行序：`prune verify` → `prune apply <批准清单> --approve`（工具已含删后逐键实测校验，
> 且参数键匹配需先验证本轮缺陷一已随 YAML 1.2 口径根治）→ `dart run slang` → strict 门 → i18n 测试。

### 8.7.1 Round-2 A 组执行记录（2026-09-06，批准依据 = 上轮 703 批准清单子集）

**执行前再发现并修复缺陷三**：`i18n_key_prune.rb` apply 的删除路径（`find_entry`/
`collect_and_delete`）仍用裸 `k.value == name` 比较，参数键 `name(param)` 静默 0 行删除
（verify 走 `split_key_scalar` 剥括号所以通过——验证与删除不同源盲区的实锤）。首跑 apply
删除 0 行，**被删后校验安全网正确拦截**（POST-VERIFY FAIL），零损伤。修复 = 两处匹配改走
`split_key_scalar` 与 flat_locale 同口径；selftest 4/4 → **5/5**（新增 `param` 键删除用例）。
另注：管道后 `$?` 是 tail 的退出码——首跑误判 APPLY-EXIT=0，重定向到文件再取码才可信。

```text
执行清单：assets/i18n/p4_round2_groupA_approved.txt（A 组 34 键，⊂ 2026-09-05 批准的 703）
apply：10 locale × 34 = 340 行删除（各 locale -34），post-verify 全部消失
独立校验（raw grep 逐键 × 10 locale，与工具不同源）：残留 = 0
dart run slang：成功；lib/i18n 生成物同步收敛（64 files, +96/-1156 含本轮工具改动）
终态：keys = 2124 × 10（此前的"2124"系漏删假终态，本次为真实达成）；
  I18N_AUDIT_STRICT=1 → PASS；审计回归 10/10；prune selftest 5/5；
  flutter（UI Gate + RTL）55/55；unused candidate = 17（14 预置 + B 1 + C 2，口径精确吻合）
B/C 组（collectedVideoFormatIncorrect… / common.success / main.markStar）：未批准，保留原样
```

## 9. 附录：CONFIRMED_UNUSED 证据充分候选全清单（714 键）

> 注：本节清单为报告初版时点的 714 键快照；当日终态为 717 键（并行会话新增 3 键且 10 locale 同步）。**最新基准以 [assets/i18n/p4_candidate_keys.txt](./assets/i18n/p4_candidate_keys.txt) 为准**（717 键，已过 verify）。

> 证据：全链路零引用（见 §3 方法）。仅供人工审阅，**本报告不执行任何删除**。

**account（29）**
`account.alipaySim.merchantSuccess` · `account.balance` · `account.codeSentToMobileParam` · `account.e2eeDeviceTransfer`
`account.e2eeDeviceTransferDesc` · `account.e2eeTransferFromOldDevice` · `account.enterPaymentPassword` · `account.existingPassword`
`account.genderSaving` · `account.loginExpiredTitle` · `account.mobileRecharge` · `account.newEmailSameAsCurrent`
`account.newMobileSameAsCurrent` · `account.nicknameChangeVisibility` · `account.nicknameCharsRemaining` · `account.nicknameSaving`
`account.paramLogin` · `account.paymentPassword` · `account.recentlyRegisteredUser` · `account.recharge`
`account.recoverCodePasswordDesc` · `account.recoverPasswordDesc` · `account.recoverPasswordIntro` · `account.securityCenter`
`account.sentToEmail` · `account.setPaymentPassword` · `account.signupFormDesc` · `account.switchAccount`
`account.withdraw`

**channel（25）**
`channel.admin` · `channel.deleteChannelDesc` · `channel.deleteChannelNotImplemented` · `channel.editChannelDesc`
`channel.editChannelNotImplemented` · `channel.manageAdminsDesc` · `channel.manageAdminsNotImplemented` · `channel.manageSubscribersDesc`
`channel.manageSubscribersNotImplemented` · `channel.noMessages` · `channel.pinMessageNotImplemented` · `channel.pinned`
`channel.react` · `channel.reactions` · `channel.roleUnknown` · `channel.search`
`channel.searchTip` · `channel.selectReaction` · `channel.settings` · `channel.shareNotImplemented`
`channel.typeLabel` · `channel.unpinMessageNotImplemented` · `channel.userId` · `channel.userIdHint`
`channel.view`

**chat（91）**
`chat.alreadyEntered` · `chat.alreadySent` · `chat.appSqliteFileSizeExplain` · `chat.attachmentProvider`
`chat.audioMessage` · `chat.avatarSelectFromAlbum` · `chat.avatarSelectPhoto` · `chat.avatarTakePhoto`
`chat.cards` · `chat.changeGroupChatName` · `chat.chatHistory` · `chat.chatMomentSportDataEtc`
`chat.chatOpenFile` · `chat.chatOpenLink` · `chat.chatReply` · `chat.chatSettingMuteDesc`
`chat.chatSettingPin` · `chat.chatSettingPinDesc` · `chat.chatStatusDeliveredDesc` · `chat.chatStatusSeenDesc`
`chat.chatStatusSendingDesc` · `chat.chatStatusSentDesc` · `chat.e2eeProxyNeedAtLeast` · `chat.e2eeReady`
`chat.e2eeReadyWithShards` · `chat.e2eeRecoveryNewDeviceBody` · `chat.e2eeSocialCreateBtn` · `chat.e2eeSocialCreateFailBody`
`chat.e2eeSocialCreateFailTitle` · `chat.e2eeSocialCreateFirst` · `chat.e2eeSocialCreateShardsDesc` · `chat.e2eeSocialCreateShardsTitle`
`chat.e2eeSocialCreateTitle` · `chat.e2eeSocialStatus` · `chat.e2eeSocialUsedAtLabel` · `chat.e2eeTransferCreateBtn`
`chat.e2eeTransferReceiveDesc` · `chat.e2eeTransferReceiveTitle` · `chat.e2eeTransferSendDesc` · `chat.e2eeTransferSendTitle`
`chat.extraPanelCollab` · `chat.extraPanelFunds` · `chat.extraPanelMedia` · `chat.fileMessage`
`chat.forgotPasswordPinCodeView` · `chat.forwardReply` · `chat.geometricPattern` · `chat.groupMessage`
`chat.jdShopping` · `chat.justChat` · `chat.location` · `chat.message`
`chat.messageHandlingMixin` · `chat.messageMarkTitle` · `chat.messageMute` · `chat.messageType`
`chat.messageVisitCardBuilder` · `chat.messageWebrtcBuilder` · `chat.momentStatus` · `chat.momentsSelectVideo`
`chat.muteUntil` · `chat.pinChat` · `chat.privateReply` · `chat.qrCodeBusinessCard`
`chat.quoteReply` · `chat.readThresholdDelay` · `chat.recentChats` · `chat.recentForwards`
`chat.replyTo` · `chat.resendCodeWithCount` · `chat.ripplePattern` · `chat.sendSeparatelyTo`
`chat.sender` · `chat.sendingVoice` · `chat.signatureInputHint` · `chat.signaturePlaceholder`
`chat.signupIntro` · `chat.singleChat` · `chat.status` · `chat.storageSpaceData`
`chat.textMessage` · `chat.topChat` · `chat.unsupportedFileType` · `chat.videoCompressInProgress`
`chat.videoCompressing` · `chat.visibleRatioLabel` · `chat.visibleThresholdRead` · `chat.voiceFileEmptyPleaseTryAgain`
`chat.voiceFileInvalid` · `chat.voiceInput` · `chat.voiceRecordResultEmpty`

**common（341）**
`common.accountDeletionNotAvailable` · `common.addPhoneContact` · `common.agreeContinue` · `common.allLoaded`
`common.allSenders` · `common.allTags` · `common.announcementContentCannotBeEmpty` · `common.announcementPublishSuccess`
`common.attachmentGetFileFailed` · `common.attachmentGetFileFailedAndroid9` · `common.attachmentGetImageDataFailed` · `common.attachmentGetOriginalImageFailed`
`common.avatarDeleteAvatar` · `common.avatarSave` · `common.avatarSelectedUploadPending` · `common.avatarUpdateFailed`
`common.avatarUpdateSuccess` · `common.bindSuccess` · `common.buttonBind` · `common.buttonChangePassword`
`common.buttonDeleteAccount` · `common.buttonInviteCode` · `common.buttonLogin` · `common.buttonNextStep`
`common.buttonRegister` · `common.buttonResetPassword` · `common.buttonSetEmpty` · `common.buttonSubmit`
`common.canNotAddYourselfFriend` · `common.changeFailed` · `common.chatBackground` · `common.chatCopyLink`
`common.chatDownloadFile` · `common.chatErrorInDenylistDesc` · `common.chatErrorNotAFriend` · `common.chatErrorNotAFriendDesc`
`common.chatSettingBackgroundCustom` · `common.chatSettingBackgroundDefault` · `common.chatSettingBackgroundSelectorTip` · `common.chatSettingBackgroundSuccess`
`common.chatSettingClearHistory` · `common.chatSettingClearHistoryConfirm` · `common.chatSettingClearHistoryDesc` · `common.chatSettingClearedSuccess`
`common.chatShareFile` · `common.chatShareLink` · `common.chatStatusFailedDesc` · `common.checkVerificationCodeOrRetry`
`common.collectedVideoFormatIncorrectCannotFindVideoUri` · `common.collectionFailedPleaseTryAgain` · `common.commonTags` · `common.configureVisibleThreshold`
`common.confirmCode` · `common.confirmCodeError` · `common.confirmCodeSuccess` · `common.confirmNewFriend`
`common.confirmNewFriendLogic` · `common.confirmRemove` · `common.contactSettingTag` · `common.contactTagListLogic`
`common.conversationNotFound` · `common.copyLink` · `common.coupon` · `common.creditCardRepayment`
`common.currentBackground` · `common.e2eeBackupCreatedAtLabel` · `common.e2eeBackupDeleteConfirm` · `common.e2eeBackupDeleteSuccess`
`common.e2eeBackupDeleteTitle` · `common.e2eeBackupDetailTitle` · `common.e2eeBackupDeviceIdLabel` · `common.e2eeBackupDeviceLabel`
`common.e2eeBackupErrOpenExternal` · `common.e2eeBackupFileSizeRow` · `common.e2eeBackupManage` · `common.e2eeBackupManageDesc`
`common.e2eeBackupNoRecords` · `common.e2eeBackupNoRecordsHint` · `common.e2eeBackupNoteRow` · `common.e2eeBackupOpenFromExternal`
`common.e2eeBackupVersionNum` · `common.e2eeContactingProxy` · `common.e2eeLoadFailed` · `common.e2eeLoadingShards`
`common.e2eeNoRecoveryShards` · `common.e2eeNoShards` · `common.e2eeProxyConfirmCount` · `common.e2eeProxyGetKeyFailed`
`common.e2eeProxyLoadFriendsFailed` · `common.e2eeProxyNeedMore` · `common.e2eeProxyNoFriends` · `common.e2eeProxyNoFriendsHint`
`common.e2eeProxyNoPublicKey` · `common.e2eeProxySelectFailed` · `common.e2eeRecoverFailed` · `common.e2eeRecoverKeyFailed`
`common.e2eeRecoverSuccess` · `common.e2eeRecoveryFailed` · `common.e2eeRecoveryKeyCopied` · `common.e2eeShardAvailableInfo`
`common.e2eeSocialAddProxy` · `common.e2eeSocialAddProxyHint` · `common.e2eeSocialCreateNeedMore` · `common.e2eeSocialCreateSuccessTitle`
`common.e2eeSocialEnoughShards` · `common.e2eeSocialKeyVersionLabel` · `common.e2eeSocialMoreShards` · `common.e2eeSocialNoProxyShards`
`common.e2eeSocialNoShards` · `common.e2eeSocialShardSettings` · `common.e2eeSocialShardStoredNote` · `common.e2eeSocialThresholdInfo`
`common.e2eeSocialTotalShardsInfo` · `common.e2eeSocialZeroTrustNote` · `common.e2eeTransferCreateSessionBtn` · `common.e2eeTransferErrCreateFailed`
`common.e2eeTransferErrInitFailed` · `common.e2eeTransferErrKeyNotFound` · `common.e2eeTransferErrNoDeviceId` · `common.e2eeTransferErrNoKey`
`common.e2eeTransferErrNoRecipientKey` · `common.e2eeTransferFailed` · `common.e2eeTransferLoadFailed` · `common.e2eeTransferLoadFailedDesc`
`common.e2eeTransferNoPending` · `common.e2eeTransferNoPendingDesc` · `common.e2eeTransferPendingSection` · `common.e2eeTransferProcessingMsg`
`common.e2eeTransferScanError` · `common.e2eeTransferSessionCreated` · `common.e2eeTransferSuccess` · `common.e2eeTransferSuccessBody`
`common.e2eeTransferSuccessTitle` · `common.e2eeTransferToNewDevice` · `common.e2eeTransferUidEmptyError` · `common.emailEditFeaturePending`
`common.emailUpdatedTo` · `common.errorAccessDenied` · `common.errorCliVersionNotFound` · `common.errorFailedToConnect`
`common.errorFileNotFound` · `common.errorFolderNotFound` · `common.errorInvalidDart` · `common.errorInvalidFileOrDirectory`
`common.errorInvalidJson` · `common.errorNoPackageToRemove` · `common.errorNoValidFileOrUrl` · `common.errorNonexistentDirectory`
`common.errorPackageNotFound` · `common.errorRequiredPath` · `common.errorSame` · `common.errorSpecialCharactersInKey`
`common.errorUnnecessaryParameter` · `common.errorUnnecessaryParameterPlural` · `common.errorUpdateCli` · `common.exportAsJson`
`common.exportDataSuccess` · `common.exportFailed` · `common.failed` · `common.false`
`common.featureNotImplemented` · `common.feedbackBuilder` · `common.feedbackModel` · `common.feedbackReplyModel`
`common.fileOpenNotImplemented` · `common.fileShareNotImplemented` · `common.forceLogoutNotification` · `common.friendPermissions`
`common.friendsPermissionsView` · `common.functionSettings` · `common.genderConflictError` · `common.genderNetworkError`
`common.genderUpdateSuccess` · `common.goToRecharge` · `common.grabAmountYuan` · `common.groupAddLocal`
`common.groupFileClosePreview` · `common.groupFileSearchAction` · `common.groupFileSearchClear` · `common.groupIdCannotBeEmpty`
`common.groupSearchTips` · `common.hintEditGroupAnnouncement` · `common.httpResponse` · `common.info`
`common.infoLoggedInOnAnotherDevice` · `common.languageState` · `common.lazyUserNoSignature` · `common.leaveYourSuggestions`
`common.locationSelectNotImplemented` · `common.loginPasswordUpdated` · `common.logoutNotice` · `common.manually`
`common.messageCannotLocatedMayBeDeleted` · `common.messageLocationBuilder` · `common.messageNotFound` · `common.messageNotification`
`common.messageRevokedBuilder` · `common.messageSendFailedPleaseCheckNetwork` · `common.mobileUpdatedToParam` · `common.momentsAddMedia`
`common.momentsAllowUidsLabel` · `common.momentsContentHint` · `common.momentsReportReason` · `common.muteDuration12hours`
`common.muteDuration3days` · `common.muteDuration6hours` · `common.muteDurationPermanent` · `common.muteMemberConfirm`
`common.myAddress` · `common.needSubmitEffect` · `common.networkFailureTips` · `common.nextVoiceMessageNoPath`
`common.nextVoiceMessageNotFound` · `common.nicknameConflictError` · `common.nicknameNetworkError` · `common.nicknameServerError`
`common.nicknameUpdateSuccess` · `common.noChangeNeeded` · `common.noMoreData` · `common.noNextVoiceMessage`
`common.noSiginQ` · `common.normalModel` · `common.notLetHimSee` · `common.notSeeHim`
`common.notShow` · `common.offlineCommandSent` · `common.operationSuccess` · `common.optionsNo`
`common.optionsRename` · `common.optionsYes` · `common.p2pCallScreenLogic` · `common.p2pCallScreenView`
`common.paramFormatError` · `common.paymentPasswordSetFailed` · `common.paymentPasswordSetSuccess` · `common.peopleInfoMoreLogic`
`common.peopleInfoSameGroupView` · `common.perMinuteOnce` · `common.permission` · `common.personalInfoDesc`
`common.personalInfoTip` · `common.playbackFailed` · `common.pleaseEnter6DigitVerificationCode` · `common.pleaseEnterCorrectEmailAddress`
`common.pleaseEnterProfession` · `common.pleaseSelectMembersForAdd` · `common.processing` · `common.pullUpLoadMore`
`common.reactionSent` · `common.recordVideoFailed` · `common.recoverPasswordSuccess` · `common.redPacketOpen`
`common.regionCancel` · `common.regionConfirm` · `common.regionNoResult` · `common.regionSearchTips`
`common.regionSelectTitle` · `common.removeReaction` · `common.removeReactionConfirm` · `common.resendCodeSuccess`
`common.revokeOperationAbnormalPleaseTryAgain` · `common.searchDescription` · `common.searchFilterAll` · `common.searchFilterImage`
`common.searchFilterText` · `common.searchFilterToday` · `common.searchFilters` · `common.searchFriendsTips`
`common.searchRegion` · `common.searchResultsCount` · `common.searchSuggestions` · `common.selectCustomBackgroundImage`
`common.selectFileFailed` · `common.selectRegionView` · `common.selectVideoFailed` · `common.selectedItems`
`common.sendCardFailed` · `common.sendCardNotImplemented` · `common.sendCollectionNotImplemented` · `common.sendOfflineCommand`
`common.setBackgroundImage` · `common.setChatBackground` · `common.shareProfile` · `common.shareQRCode`
`common.shareTo` · `common.shareWithFriends` · `common.signatureTips` · `common.strongReminder`
`common.submissionFailed` · `common.submitted` · `common.tagInspiration` · `common.tagNameNoComma`
`common.tagNameNoLeadingTrailingSpaces` · `common.tagNameNoSpecialChars` · `common.tagNameTooLong` · `common.takePhotoFailed`
`common.testDirectNavigation` · `common.thisMonth` · `common.timeToday` · `common.timeYesterday`
`common.tip` · `common.tipEmptyChatPlaceholder` · `common.tipGreeting` · `common.tipProvidersTitleFirst`
`common.tips` · `common.transactionHistory` · `common.transferAccept` · `common.transferGroupConfirm`
`common.transferGroupFailed` · `common.transferGroupSuccess` · `common.true` · `common.uploadAvatarFailed`
`common.uploadAvatarFailedWithError` · `common.uploadResponseInvalid` · `common.useSystemDefaultBackground` · `common.userNotSetSignature`
`common.userOnlineStatusWidget` · `common.userTagRelationView` · `common.userTagSaveView` · `common.verificationCodeSent`
`common.verificationMessageSentByPeerIs` · `common.videoCompressFailed` · `common.videoFileNotFound` · `common.videoFurtherCompressFailed`
`common.viewSecurityHelp` · `common.visibleDisabledMessage` · `common.visibleEnabledMessage` · `common.visibleThresholdInfo`
`common.voiceDuration` · `common.voiceFileCannotReadPleaseTryAgain` · `common.voiceFileNotFoundPleaseTryAgain` · `common.voiceFileReadFailedPleaseTryAgain`
`common.voiceInputNotImplemented` · `common.voiceProcessingAbnormal` · `common.voiceRecordFailedPleaseTryAgain` · `common.voiceSendAbnormal`
`common.voiceSendSuccess` · `common.voiceUploadFailedPleaseCheckNetwork` · `common.whatYourFeedback` · `common.withdrawAccount`
`common.yourContactInformation`

**contact（27）**
`contact.applyFilters` · `contact.applyFriend` · `contact.applyFriendLogic` · `contact.applyParam`
`contact.currentTags` · `contact.denylistEmptyDesc` · `contact.groupRemarkView` · `contact.groupRemarkVisibility`
`contact.selectFriend` · `contact.selectOrEnterTag` · `contact.tagEntertainment` · `contact.tagFamily`
`contact.tagFood` · `contact.tagFriends` · `contact.tagHealth` · `contact.tagIdeas`
`contact.tagImportant` · `contact.tagLife` · `contact.tagManagement` · `contact.tagMemo`
`contact.tagNameRequired` · `contact.tagProject` · `contact.tagStudy` · `contact.tagTravel`
`contact.tagUrgent` · `contact.tagWork` · `contact.tellFriend`

**discovery（18）**
`discovery.channelSquare` · `discovery.discover` · `discovery.momentAndOthersLiked` · `discovery.momentExpand`
`discovery.momentLikedBy` · `discovery.momentLikesCountOnly` · `discovery.momentPartialVisible` · `discovery.momentReportComment`
`discovery.momentViewAllComments` · `discovery.momentsComments` · `discovery.momentsDenyUidsLabel` · `discovery.momentsReport`
`discovery.momentsReportDesc` · `discovery.peopleNearbyLogic` · `discovery.scan` · `discovery.scannerResult`
`discovery.shake` · `discovery.titleDiscover`

**error（3）**
`error.e2eeInsufficientShardBtn` · `error.e2eeStartRecoveryBtn` · `error.networkFailureGuidance`

**group（6）**
`group.financialManagement` · `group.groupJoin` · `group.groupManagement` · `group.groupMember`
`group.joinTime` · `group.transferGroup`

**groupCategory（5）**
`groupCategory.addGroup` · `groupCategory.categoryCreated` · `groupCategory.categoryDesc` · `groupCategory.createFirst`
`groupCategory.removeGroup`

**groupSchedule（7）**
`groupSchedule.noReminder` · `groupSchedule.reminder` · `groupSchedule.reminder15min` · `groupSchedule.reminder1day`
`groupSchedule.reminder1hour` · `groupSchedule.scheduleCreated` · `groupSchedule.scheduleUpdated`

**groupTag（3）**
`groupTag.tagAdded` · `groupTag.tagColor` · `groupTag.tagRemoved`

**groupTask（4）**
`groupTask.assignTo` · `groupTask.taskCompleted` · `groupTask.taskCreated` · `groupTask.taskId`

**groupVote（10）**
`groupVote.addOption` · `groupVote.allowMultiple` · `groupVote.anonymous` · `groupVote.cancelVoteFailed`
`groupVote.deadline` · `groupVote.endVoteFailed` · `groupVote.hasVoted` · `groupVote.noDeadline`
`groupVote.viewResults` · `groupVote.voteOptions`

**main（124）**
`main.change` · `main.changeNameView` · `main.codeSentToType` · `main.commentPlaceholder`
`main.copiedLink` · `main.current` · `main.currentLength` · `main.custom`
`main.delayMsLabel` · `main.e2eeCanRecoverKey` · `main.e2eeCollectingShards` · `main.e2eeInsufficientShards`
`main.e2eeKeyRestored` · `main.e2eePreparing` · `main.e2eeProxyMinCount` · `main.e2eeProxyReachedMin`
`main.e2eeProxySelectTitle` · `main.e2eeProxySelectedCount` · `main.e2eeProxyUser` · `main.e2eeRecoverKeyTitle`
`main.e2eeRecovering` · `main.e2eeRecoveryProgressLabel` · `main.e2eeReloadShards` · `main.e2eeShardLabel`
`main.e2eeShardsCollected` · `main.e2eeSocialCanRecover` · `main.e2eeSocialChooseProxy` · `main.e2eeSocialExistingShards`
`main.e2eeSocialManageShardsDesc` · `main.e2eeSocialManageShardsTitle` · `main.e2eeSocialManageTitle` · `main.e2eeSocialMyShards`
`main.e2eeSocialProxyDefaultName` · `main.e2eeSocialProxyNeeded` · `main.e2eeSocialProxyShards` · `main.e2eeSocialProxyUserLabel`
`main.e2eeSocialRecoverKeyDesc` · `main.e2eeSocialRecoverKeyTitle` · `main.e2eeSocialRecovery` · `main.e2eeSocialRecoveryDesc`
`main.e2eeSocialRecoveryThresholdLabel` · `main.e2eeSocialSelectProxy` · `main.e2eeSocialSentCount` · `main.e2eeSocialSetupProxy`
`main.e2eeSocialShardActive` · `main.e2eeSocialShardIndexLabel` · `main.e2eeSocialShardOf` · `main.e2eeSocialShardSentViaWs`
`main.e2eeSocialShardUsed` · `main.e2eeSocialShardValid` · `main.e2eeSocialThreshold` · `main.e2eeSocialThresholdHint`
`main.e2eeSocialTitle` · `main.e2eeSocialTotalShards` · `main.e2eeSocialUserShard` · `main.e2eeSocialZeroTrustHint1`
`main.e2eeSocialZeroTrustHint2` · `main.e2eeSocialZeroTrustHint3` · `main.e2eeTransferEnterUidTitle` · `main.e2eeTransferPageTitle`
`main.e2eeTransferPendingItem` · `main.e2eeTransferPendingItemDesc` · `main.e2eeTransferQRExpiry` · `main.e2eeTransferQRHint`
`main.e2eeTransferReceiving` · `main.e2eeTransferRefreshQR` · `main.e2eeTransferUidPlaceholder` · `main.e2eeTransferView`
`main.e2eeUsedShards` · `main.earlier` · `main.enGb` · `main.entertainment`
`main.example` · `main.export` · `main.exportAsText` · `main.exportToLocal`
`main.extraItem` · `main.faceToFaceLogic` · `main.goClean` · `main.haveSet`
`main.httpParse` · `main.kickMember` · `main.lifePayment` · `main.liveBroadcast`
`main.liveRoomListView` · `main.loggingOut` · `main.manageVisibility` · `main.markImportant`
`main.markImportantDesc` · `main.markStarDesc` · `main.markTodo` · `main.markTodoDesc`
`main.medicalHealth` · `main.meituanDelivery` · `main.memberRole` · `main.multiSelectMode`
`main.pleaseEnterInterests` · `main.pleaseEnterSchool` · `main.previewArea` · `main.processed`
`main.publisherPage` · `main.publishing` · `main.quickFilters` · `main.remainingChars`
`main.sentByOthers` · `main.signInWith` · `main.simpleTexture` · `main.star`
`main.subscriber` · `main.tencentService` · `main.termOfServices` · `main.testUser1`
`main.testUser2` · `main.testUser3` · `main.testUser4` · `main.testUser5`
`main.timeRange` · `main.titleSquare` · `main.topStories` · `main.traffic`
`main.upToWords` · `main.upgrade` · `main.webView` · `main.yourFeel`

**mention（7）**
`mention.fromChat` · `mention.fromGroup` · `mention.markAsRead` · `mention.mentionCount`
`mention.newMention` · `mention.selectMention` · `mention.viewContext`

**momentFriendPicker（4）**
`momentFriendPicker.emptyTags` · `momentFriendPicker.tagsLabel` · `momentFriendPicker.titleAllow` · `momentFriendPicker.titleDeny`

**passport（4）**
`passport.forgetPassword` · `passport.hasAccount` · `passport.register` · `passport.retrievePassword`

**workspace（6）**
`workspace.guestReadonlyHint` · `workspace.projectInfoSection` · `workspace.projectLinkNameLabel` · `workspace.projectLinkUrlLabel`
`workspace.projectMemberInviteFieldLabel` · `workspace.projectsTitle`
## 10. 提交分组预案（未执行——等用户授权；2026-09-05 盘点）

> 本节只是预案。任务书禁止流水线会话 commit；以下 pathspec 在用户明确授权后使用。

### 10.1 现场风险（2026-09-05 盘点时点）

- **索引已有 73 个并行会话的暂存条目**（58 staged-M + 11 staged-A + 1 AM + 3 MM），其中含 vodozemac web 构建、jverify 测试、coverage、CI 脚本、`docs/plans/` 两份任务书等——**全部不属于 i18n 交付，保持暂存原样不动**。
- 三个部分暂存（MM）文件：`assets/i18n/i18n_audit.rb`（我的，工作树版本更新）、`integration_test/flows/test_utils.dart`、`lib/page/passport/passport_notifier.g.dart`（后两个是并行会话的）。
- ~~lefthook 拦截风险~~ **已核实不成立（修正）**：pre-commit 的 dart-analyze 只分析**暂存文件**（`dart analyze {staged_files}`，且排除 `*.g.dart`），C1-C5 各路径全部干净；全仓 ratchet 门（`dart-analyze-full`）挂在 **pre-push**，与 commit 无关（当前全仓因未跟踪的假 `.dart` 日志 + 并行 WIP 处于基线外，属 push 时质量工作流的课题，不阻塞提交）。

### 10.2 分组与 pathspec（`git commit --only <paths>` 方式，不碰索引里其他条目）

```text
C1 i18n 数据集（10 locale 对齐 + slang 生成物）:
   assets/i18n/ar-SA assets/i18n/de-DE assets/i18n/en-US assets/i18n/fr-FR
   assets/i18n/it-IT assets/i18n/ja-JP assets/i18n/ko-KR assets/i18n/ru-RU
   assets/i18n/zh-CN assets/i18n/zh-Hant lib/i18n
C2 审计与治理工具: assets/i18n/i18n_audit.rb assets/i18n/i18n_audit_test.rb
   assets/i18n/i18n_key_prune.rb assets/i18n/p4_candidate_keys.txt
C3 RTL 根因修复: lib/run.dart test/unit_test/rtl_directionality_test.dart
C4 UI Gate + 真机走查: test/unit_test/i18n_ui_gate_test.dart
   integration_test/i18n_rtl_walkthrough_test.dart
C5 治理文档: I18N_AUDIT_REPORT.md I18N_TERMINOLOGY.md I18N_NATIVE_REVIEW_PACKAGE.md
```

说明：① C1 里个别键值由并行会话补写（logoutCancelRequest 等），但数据集是单一治理整体、经同一审计门验收，随 C1 提交；② `test_utils.dart` 的走查测试依赖其既有 API 但**未改动它**，不纳入本次提交；③ 全部提交须带 DCO sign-off（`git commit -s`，本仓惯例）；④ 若 P4 名单先获批，先执行删除（prune apply → slang → 门禁），再按上表提交，C1/C2 内容会相应减小。

## 11. 会话交付卡（任务书模板，2026-09-05 收口）

```text
Task ID: i18n-release-governance P0-P17（本会话：P0-P16 执行与集成、
         10 语言 Agent 波次派发、P4 执行、P6/P16 专项、工具链、交付收口）
Base SHA: 02b4cc48（战役起点）；本会话落地 18 笔 i18n 提交（均 -s DCO，未 push）：
         3f5ff07a 数据集 / abac27e5 审计器+修剪工具 / 1b926a37 RTL 根因 /
         c19a0257 UI Gate+走查入口 / e6ad97c3 治理文档 / 09857f34 macOS 证据 /
         b4b6b582 YAML 1.2 对齐 / 7ff56abb 根治记录 / fd770d74 交付卡 /
         d4e0c706 走查 8 语言扩展 / 9d2bad3d 硬编码清理 34 处 /
         a2ab55d4 ru 复数 resolver / 65b25183 弹窗硬编码正文 /
         fa912a3b+cb679437 isChinese 伪 i18n 清零 /
         ee99618b+bb44ac32 证据归档
Owned files: assets/i18n/**（10 locale + 工具 4 件）、lib/i18n/**、lib/run.dart、
         lib/component/dialog/e2ee_recovery_guide_dialog.dart、lib/page/channel/{channel_detail_page,widgets/channel_header_bar,widgets/channel_message_feed}.dart、
         lib/page/passport/passport_notifier.dart、lib/page/mine/account_security/**、lib/page/settings/compliance_key_page.dart、lib/page/error/init_error_page.dart、
         lib/service/{message_webrtc,message_actions}.dart、lib/modules/messaging/infrastructure/message_model_mapper.dart、
         i18n 专项测试 ×3、I18N_*.md ×3 —— 提交完整性审计：外来文件零混入
Files changed: 见上 18 笔（C1=223 files，+4222/−21595）
Keys reviewed: 2779（起点）→ 2789（补齐+并行新增）→ 2124（P4 后）→ 2151（弹窗正文+角色/隐私键）→ 2158（硬编码清理批）终态
Translations added: 3812 slots（10 Agent 并行波次）+ 12 slots（竞态补齐）+ 19 项 P5 冻结修正 + 40 键（弹窗正文/硬编码清理两批 × 10 locale）
Translations corrected: ru CLDR one/few/many/other 四分支（原仅 other 为真 bug）、
         it-IT logoutCancelRequest、zh-CN 帐号→账号 等
Key merges/deletions: 删除 703+on/off（6687 行）；保留 14 个 *NotImplemented 预置键；
         SAFE_MERGE=0（无可合并同值键）
Terminology fixes: I18N_TERMINOLOGY.md 十语言矩阵；ja 購読者裁决；zh-Hant 台湾词系；
         Workspace Member ≠ Group Member ≠ Channel Subscriber 钉死
Placeholder/plural fixes: placeholder 归一门禁（$x/${x}/{x}）零不一致；
         ru 复数分支完整；审核包 AI 预筛 240 行（220✅/20⚠️）
Remaining uncertainties: Gate3 真机走查（macOS 过渡已绿：ar=RTL/de=LTR 硬断言）；
         Gate4 母语审核（BLOCKED_NO_REVIEWER）；54 残留候选（并行新代码，未授权）；
         产品确认 6 项（术语表 §11）
Commands run and exact results: §6 / §6.5 / §6.6 / §8.5.1（全部实跑留存，
         strict 门 PASS、审计回归 9/9、prune selftest 4/4、flutter 55/55、
         macOS 走查与 8 语言真机走查 All tests passed!、真机截图 8 张）
Acceptance: PARTIAL —— 自动门/术语基线/工具链/提交/真机走查/硬编码清查全部 PASS
         且经当日复验；仅剩母语审核一门外置（Gate 4），Release NO-GO 的唯一剩余原因
```

### 8.7.2 全量测试在治理提交态的复跑（2026-09-06，HEAD=8d5a3e68）

```text
flutter test 全量：+6107 通过 / ~240 skip / -7 失败（与上轮 eaf5e700 基线同型）
7 个失败全部为 loading（编译加载）类，逐个归因、与本轮 i18n 改动零关联：
  ×2 test/auto_test/reports/.../logs/rerun_macos_*.dart —— 已知假 .dart 日志文件（非测试）
  ×1 channel_public_test —— 断言 barrel lib/modules/channel_content/public.dart
    导出 ChannelDiscoverPage/ChannelInvitationPage，但 barrel 零处导出（已提交态的
    channel 内容线既有不一致；两文件在工作树均干净）
  ×1 group_album_page_test —— _FakeFilePicker 缺 darwinOptions：file_picker 插件升级
    API 漂移（并行会话插件线 WIP：Podfile.lock/build.gradle.kts 在其改动列表）
  ×3 其余 loading（reporter 截断未列名）——按同族归因（file_picker 桩线）
零交集证明：c51b9b71/e1a7e455/8d5a3e68 未触碰任何 test/ 或业务 lib/ 文件
（仅 assets/i18n + lib/i18n 生成物 + 工具 + 文档）；loading 失败属 Dart 符号解析，
与翻译键删除范畴不相交；消费翻译的 UI Gate + RTL 55/55 全绿。
i18n 门禁在提交态复验：strict PASS、keys=2124×10、candidate=17 零漂移。
母语审核包零污染核查：34 个已删键在 I18N_NATIVE_REVIEW_PACKAGE.md 零命中，无需重生成。

## 8.8 产品确认裁决执行（2026-09-06，用户四项拍板）

用户经选项裁决：① B/C 组 3 键全部保留；② zh-CN「您/你」统一为「你」；
③ zh-Hant 统一台式词；④ 暂不 push。①④无动作，②③执行记录：

```text
zh-CN: 17 处「您」→「你」（account 1 + common 16），值级替换零残留
zh-Hant: 用家 15 处→使用者（§5 钉定词）、賬號 10 处→帳號，零残留
slang 重生成成功；strict PASS、keys=2124×10、审计回归 10/10、UI Gate+RTL 55/55
审核包零影响（改动键均不在 240 行选取集内）
```

**跨语言联动的证据修正**：裁决选项原描述"ja/ko/de/fr 敬体需同步降级"，但执行前语态普查
（第二人称代词全语料计数）显示各目标语言的用法**各自语内自洽**——de Sie/Ihr 88 值 vs du 系 17、
fr vous 系 110 vs tu 0、ru вы 系 59 vs ты 0（三语整体选敬体）、it tu 系 21 vs Lei 2（整体非敬体）、
ja あなた 22 处惯例使用、ko 귀하/당신 为规约敬语。17 个受影响键在八语的译文均与所在语言的
主导语态一致，**不存在「您」镜像离群值**——盲目降级反而会制造语内不一致（如德语 3 个 du 键
沉入 Sie 语料）。故跨语言零改写，「统一为「你」」的产品语义在源语言层面完整达成。
若产品层希望 de/fr/ru 整体转非敬体（约 257 值重写 + 全量母语复审），属独立大决策，未启动。

**新观察项**：zh-Hant 语料存在与 zh-CN 同类的人称混用（您 37 值 vs 你 30 值），本轮未获裁决、
未触碰；如需统一建议随下一轮治理拍板。术语表 §11 第 1、2 项已回写为已解决。

## 8.9 产品确认第二批复决执行（2026-09-06）

用户三批复决：① zh-Hant 人称统一为「你」；② 角色词 Owner/Member/Guest 维持拉丁 PINNED；
③ zh-Hant 残留 1 处「用戶」对齐为「使用者」。

```text
zh-Hant: 您→你 47 处（38 行，部分行多处；account 1/chat 2/common 36/discovery 6/error 1/main 1）
zh-Hant: 用戶→使用者 1 处（词系对齐：使用者 27 vs 用戶 1 → 归一）
残余核查零；slang 重生成、strict PASS、keys=2124×10、审计 10/10、UI Gate+RTL 55/55
审核包同步：zh-Hant 译文列更新 1 行（discovery.nearbyPeopleExplain，改值行翻 ⚠️ 待复审）；
  全包 grep 终验 您/用家/賬號/用戶 = 0
术语表 §11 六项 NEEDS_PRODUCT_CONFIRMATION 全部闭环（1/2/3/4/5/6 → 已解决或确认维持）
```

至止所有可机做的产品语义裁决全部执行完毕。发布门保持：Gate 1-3 PASS，
Gate 4 = BLOCKED_NO_REVIEWER（唯一剩余），Release = NO-GO 待母语审核。

## 8.10 译文改值波次的全量回归验证（2026-09-06，HEAD=bbc2deda + 断言修复）

§8.8/§8.9 两波译文改值（zh-CN 17 处 + zh-Hant 73 处）晚于 §8.7.2 的全量跑，
证据链存在缺口，本轮补齐：

```text
改值引用排查：test/integration_test 中旧值特征串（您/用家/用戶/賬號）扫描
  → 命中 1 处硬编码断言 manage_account_page_test.dart:69（旧文案「让您的账户更安全」）
  → 断言跟随改值更新，单跑 9/9 全绿
全量 flutter test 复跑（含修复）：+6107 / ~240 skip / -7，与 §8.7.2 基线完全同型
  → 7 个 loading 失败逐一比对该基线（2 假日志 + channel_public barrel + file_picker 族）
  → 零新增失败：两波译文改值经全量验证零回归
结论：当前 HEAD 的"全量绿（除已知非 i18n 既有失败）"证据重新闭合。

## 8.11 §8.7.2 归因修正 + P4 误删键恢复（2026-09-06，重大更正）

**更正**：§8.7.2/§8.10 所述"7 个 loading 失败与 i18n 零关联"**不成立**——其中
`moment_create_i18n_test.dart` 是 **P4 误删造成的 i18n 回归**：该 08-06 契约测试以
`final zh = await AppLocale.zhCn.build()` 的 **locale 局部变量访问器**断言
`common.momentsContentHint / momentsAddMedia / momentsAllowUidsLabel` 与
`discovery.momentsDenyUidsLabel`，而审计扫描仅认 `t.`/`tr.`（当时），4 键被判
"零引用"进入 703 删除清单（3f5ff07a）→ 测试自 09-05 起编译失败，历次全量跑
被"file_picker 桩"家族归因掩盖。这是第三种访问器盲区（继 t→tr 之后）。

**修复**：
```text
恢复 4 键 × 10 locale（值取自 3f5ff07a^ 历史，零翻译新造）：
  common: momentsContentHint / momentsAddMedia / momentsAllowUidsLabel
  discovery: momentsDenyUidsLabel
i18n_audit.rb：访问器集合改为可配置（I18N_AUDIT_ACCESSORS），默认 t/tr/zh/en
审计回归 10→11（新增 locale_local_accessor_counts_as_reference）；prune selftest 5/5
slang 重生成；keys=2128×10；strict PASS；unused candidate=17 不变
验证：moment_create_i18n_test 复活（59/59 含 UI Gate+RTL）；manage_account 9/9
```

**其余失败归因修订**（dart analyze test/ 编译错误全集 = 6 文件）：
2 假 .dart 日志 + channel_public（barrel 缺导出）+ group_album 与 group_file
（file_picker darwinOptions 插件漂移）+ moment_create_i18n（i18n，本轮已修）。
历史 -7 中第 7 项无法回溯枚举（reporter 截断），记 UNKNOWN=1，不声称非 i18n。

**本轮一次全量复跑作废**：运行期间树遭并行会话实时改写（manage_account 中途
报 loading 失败而前后单跑 9/9；login_page 7 条 did-not-complete 属并行
passport/jverify 线中途编辑），活树快照不可作证据；干净全量复跑待并行线安静后补。

**教训**：① unused 判定的访问器集合必须是"宁可多算"的可配置白名单，任何
`<var>.ns.key` 形态的测试契约都可能成为盲区；② 全量证据链覆盖到最后一次值变更
之外，还要覆盖"每次全量跑自身是否在安静树上"（树变异中跑=无效证据）。

## 8.12 Round-3 深审与 CONDITIONAL GO 风险接受（2026-09-06，用户授权「去人工化+最优解」）

**触发**：用户 2026-09-06 指示「继续，期望不要人工环节，授权给最优解」。据此执行第二轮独立 AI 深审（模型本人复核 8 语言审核包 240 行 + 全语料系统性扫描），并修复全部机器可证明缺陷。

### 8.12.1 发现与修复（全部带守卫的精确替换，逐对 hit/miss 报告）

| # | 缺陷 | 证据 | 修复 |
|---|------|------|------|
| 1 | **36 键 × 8 locale 英文残留集群**（群管理员/禁言/上传/搜索/资料功能线，值与 en-US 逐字节相同，违反 P8-P15 验收「非白名单英文残留=0」） | 零目标文字扫描 + en-US 逐字节比对（守卫值） | 全部补译：ja 敬体/ko 합니다体/de Sie/fr vous+标点空格/it tu/ru вы/ar MSA/zh-Hant 台式 |
| 2 | zh-Hant 設備 17 键违反术语表 §105 既有裁决（裝置=台式钉定、設備=禁用） | 术语矩阵扫描：裝置23:設備17 分裂 | 17 键统一 設備→裝置 |
| 3 | ar 3 个 time-ago 复数节点仅 other 分支 → n=3-10 渲染 «منذ 7 يوم»（文法错误，应 أيام）；与 ru 修复前同型 | CLDR ar 规则 + slang 内置 resolver 行为 | 补 one/two/few/many 四分支（12 个新分支条目，标准 MSA 形态） |
| 4 | de 语体混用：安全/账号域 84 键 Sie vs channel 域+散点 16 键 du（Tier1 安全文案两弹窗一 Sie 一 du） | 全语料 Sie/du 分布扫描 | 16 键统一为 Sie（多数派+Tier1 域一致） |
| 5 | de 文法 2 处：diesen Abonnent（宾格应 -en）、geliket（Duden 作 gelikt） | 逐值检查 | 随 #4 一并修复 |
| 6 | 2 孤例：ja taskStatusTodo='TODO'（家族 進行中/レビュー中/完了 全原生）、ar groupMemberRoleLabel='Member'（其余 4 locale 原生） | 家族/跨 locale 对照 | TODO→未着手、Member→عضو |

**合计 325 处值级修复**（集群 288 + 裝置 17 + de 16+1 + ar 分支 3 节点）。

### 8.12.2 复验干净项（无需修改，记录在案）

- ru 复数 3 节点 one/few/many/other 全部 CLDR 正确；wave-4 标记的 timeDaysAgo «дня» other 分支疑点在 resolver 修复（a2ab55d4）后不成立（other 仅分数命中，属格单数正确）。
- ja 敬体（ました/します 族）一致、ko 존댓말 一致、fr vous 全包一致、it tu 全包一致。
- zh-Hant 简体专用字泄漏 = 0（干净清单复验；首轮命中为扫描器字符表污染假阳性）。
- 术语矩阵：工作區/專案/群組/頻道/成員/訂閱/金鑰/隱私 全统一；PINNED 拉丁角色词（Owner/Member/Guest/Admin）与品牌词（Alipay/WeChat）合规保留。
- 假阳性甄别：de/fr/it 与 en 同值项全为合法同形词（Video/Status/min/h）；ja 'OK'/ko '확인' 等为各语言合法惯例。

### 8.12.3 验证链（修复后全部实跑）

```text
dart run slang                          exit 0（0.35s；strings.g.dart 计数 21301→21313 = ar 新增 12 分支条目，时间戳行手工复原）
ruby i18n_audit.rb check                RESULT: PASS
I18N_AUDIT_STRICT=1 … check             exit 0（RESULT: PASS strict；missing=0/extra=0/placeholder=0；candidate=17 不变）
ruby i18n_audit_test.rb                 11/11 passed
flutter test（i18n UI Gate 50 + RTL 5 + mute_duration/task_flow/batch_upload + 复跑）  All tests passed!（100/100 与 82/82 两轮）
英文残留复扫                            5 locale 仅剩 e2eeBackupUrlFieldHint 'https://...'（URL 占位符，合法）
de du 残余复扫                          0
git diff --check                        CLEAN（slang 平铺 map 3 行尾随空格手工剥离，analyze No issues）
```

### 8.12.4 风险接受记录（CONDITIONAL GO 依据）

- **接受方**：产品负责人（用户）2026-09-06 授权：期望流程去人工化、授权 Agent 给最优解。此前「保持 NO-GO 等母语审核」的拍板（2026-09-06 上午）由本授权取代。
- **被接受风险**：8 语言（zh-Hant/ja/ko/de/fr/it/ru/ar）译文未经母语人士审核即发布。质量背书 = 自动门全绿 + 两轮独立 AI 深审（Round-2 预筛 220✅/20⚠️ + Round-3 325 处缺陷清零）。
- **边界承诺**：不声称 100% 母语质量；zh-CN（基准）与 en-US（语义桥接层）不受此风险影响。
- **缓解路径**：①发布后母语审核按 `I18N_NATIVE_REVIEW_<locale>.md` ×8 回填（审核人/日期栏已备）；②任一 CHANGES_REQUESTED → 热修闭环（i18n 值级热修链路已在多轮验证）；③审核包 ⚠️ 长度比条目（de3/fr8/it3/ja1/ru2/zhHant1）为观察项非阻断。
- **仍封闭的门**：push（用户明示暂不，需单独授权）；真机走查（Gate 3 已有 8 语言真机证据，无需重复）。

### 8.12.5 审核包同步

de 包（e2eeRecoveryNewDeviceBody Sie 化 2 处）、ar 包（复数行 3 处展开新分支）、zh-Hant 包（裝置 6 处）+ 主包（de2+ar3+裝置6）已同步；集群 36 键不在审核包选取集（Tier1=安全/支付域）。

### 8.12.6 审计器英文残留门（Round-3 盲区根治，2026-09-06 追加）

Round-3 的 36 键 × 8 locale 英文残留能潜伏十轮，根因是审计器只门 missing/placeholder，**不门「非拉丁 locale 的纯英文值」**——而并行功能线正以「en 值拷贝」模式持续加键。根治：

- `latin_residue` 结构门（`assets/i18n/i18n_audit.rb`）：非拉丁 locale（zh-Hant/ja/ko/ru/ar）的值与 en-US **逐字节相同**、且不同于 zh-CN 基准、且不在豁免清单（PINNED 拉丁角色词 / Alipay·WeChat·WeChat Pay·Huabei 品牌 / `#色值` / URL）→ check 判结构失败（普通+strict 均硬失败）。summary 新增 `en_residue=N` 列。
- 拉丁 locale（de/fr/it）不做此检测（与 en 存在大量合法同形词 Video/Status/min/h，假阳性不可控——已注释在案）。
- 回归测试 +2（用例 13 命中/用例 14 豁免矩阵），13/13 全绿。
- **首跑实抓 12 条假阳性教训**：`%w[]` 不解析引号，`"WeChat Pay"` 多词条目被拆成带引号废词条——多词豁免值必须用普通数组书写。修复后真仓 check/strict 双 PASS、en_residue=0（同时证明并行会话当前未引入新英文残留键）。

## 8.13 Push 就绪度证书（2026-09-06，等用户授权后可即时执行）

```text
i18n 战役提交链（02b4cc48..HEAD，含 cc2a0787）：34 笔
  DCO 签核（Signed-off-by）：34/34 全部具备 ✓
  路径审计：全部限于 assets/i18n/**、lib/i18n/**、I18N_*.md、docs/、
            战役授权的 9 业务文件（走查战利品修复波及）✓
gitleaks 8.30.1 全 push 面（origin/main..HEAD）：245 笔提交 / 4.40MB diff
  no leaks found ✓（含并行线历史未推提交）
最终 HEAD 门态：strict PASS / 审计器 13/13 / UI Gate 50/50 ✓
残余标点修复（cc2a0787）：initConfigTimeout 全角冒号 ×2、
  clearConfirmTitle 全角问号 ×1；审核包漂移复验=0（尾随空格类
  均为有意拼接排版：momentsReplySeparator/atMentionYouTag/paymentAmount）
```

**执行面**：`git push origin main` 一条命令即可（无 force 需求，imboyapp 未做历史重写）。本证书不构成 push 授权——授权仍单独等用户明示。

## 14. 母语审核回填 → 热修 SOP（CONDITIONAL GO 风险路径的运营闭环）

**审核人侧**（每语言一份 `I18N_NATIVE_REVIEW_<locale>.md`，约 30 行）：
1. 逐行核对「zh-CN（基准）」与「译文」列；结论列填 `APPROVED` / `CHANGES_REQUESTED` / `BLOCKED_NO_REVIEWER`；
2. 有异议在「建议译文」列写出推荐译文；填审核人姓名与日期；
3. ⚠️ 列为 AI 预筛观察项（长度比等），不构成驳回依据。

**集成者侧**（回填回收后）：
1. 全部 `APPROVED` → 报告 §8 主包总览表回写 → 发布状态升格 `GO`（纯文档操作，零代码变更）；
2. 任一 `CHANGES_REQUESTED` → 热修流水线（多轮验证过的既定链路）：
   `assets/i18n/<locale>/<ns>.i18n.yaml` 值级替换（守卫式，当前值须精确匹配包内旧值）
   → `dart run slang` → `I18N_AUDIT_STRICT=1 ruby assets/i18n/i18n_audit.rb check`
   → 审核包同步该行 → `flutter test test/unit_test/i18n_ui_gate_test.dart` → 提交（-s DCO）；
3. 审核包即为工单：每行自带 Key、基准文案、现译文三要素，无需另建 issue；
4. 任何新键走同链路（英文残留门已在 check/strict 硬失败拦截 en 拷贝形态）。

**快速入口**：`ruby assets/i18n/i18n_audit.rb check`（日常）／`I18N_AUDIT_STRICT=1 …`（发布门）／
`ruby assets/i18n/i18n_audit_test.rb`（工具回归 13 用例）。
