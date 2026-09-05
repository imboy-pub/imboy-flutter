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

## 8. 发布状态（Tentative）

```text
Gate 1 自动门（missing/placeholder/duplicate/alias/audit/tests）: PASS
Gate 2 术语一致性: PASS*（基线已建 + 语义交叉检查通过；*未经母语确认）
Gate 3 UI/RTL: PASS（widget 级 50/50 + RTL 5/5 + 真机走查 ar=RTL/de=LTR 硬断言通过 + 三语言真机截图取证；macOS 过渡证据归档 §6.6.1）
Gate 4 母语审核: UNKNOWN（BLOCKED_NO_REVIEWER）
Tentative Release: NO-GO（唯一剩余原因 = Gate 4；Gate 3 已 PASS）
```

判定依据：Gate 4 无审核不得声称母语质量；Gate 3 真机证据未收（widget 门已覆盖布局溢出，未覆盖真机字体/系统行为）。自动门从"缺 3812 slots"提升到全绿；GO 需完成 §7 第 1、4 项。

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
