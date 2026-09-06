# IMBoy i18n 全量翻译质量审计与发布治理计划

> 创建：2026-09-04
> 仓库：`/Users/leeyi/project/imboy.pub/imboyapp`
> 权威资源：`assets/i18n/<locale>/<namespace>.i18n.yaml`
> 当前结论：`CONDITIONAL GO`（终判，2026-09-06；依据与风险接受记录见 [I18N_AUDIT_REPORT.md §8/§8.12](../../I18N_AUDIT_REPORT.md)）
> 当前阶段：W0-W18 全部完成；W4 收敛 717→0（用户批准删 703+34，14 预置键保留）；
> W19 母语审核包就绪待回填（8 语言拆分包）；W20 终判 CONDITIONAL GO——Gate1/2/3 PASS，
> Gate4 经用户 2026-09-06 授权显式接受。push 就绪度证书见报告 §8.13，push 需单独授权。

## 1. 目标和边界

目标是在不改变产品功能和业务逻辑的前提下，把 10 个 locale 的翻译、术语、Key、占位符、复数、RTL 和移动端布局治理到可验证的发布状态。

本计划不预设最终必须 GO。最终结论只能是 `GO`、`CONDITIONAL GO`、`NO-GO` 或 `BLOCKED`，并由实际证据决定。

禁止事项：

- 不修改后端、数据库或 API。
- 不重构 Flutter 业务逻辑，不大规模调整 UI。
- 不修改 `ios/*`、`macos/*`、`plugin/r_upgrade`。
- 不新增依赖；优先复用 Ruby、Dart、Flutter 和现有 Slang。
- 不手改 `lib/i18n/*.g.dart`。
- 不删除未能确认无引用的 Key。
- 不把不同产品概念仅因中文相同而合并。
- 不整文件使用机器翻译覆盖。
- 不 reset、clean、restore 或覆盖共享工作树中的既有改动。
- 不 commit、push、发布或联系第三方，除非用户另行明确授权。

## 2. Phase 1 基线

| Locale | Files | Keys | Missing | Used Missing | Extra |
|---|---:|---:|---:|---:|---:|
| zh-CN | 28 | 2,779 | 0 | 0 | 0 |
| en-US | 27 | 2,639 | 143 | 138 | 3* |
| zh-Hant | 25 | 2,351 | 428 | 415 | 0 |
| ar-SA | 25 | 2,316 | 463 | 450 | 0 |
| de-DE | 25 | 2,319 | 463 | 450 | 3* |
| fr-FR | 25 | 2,319 | 463 | 450 | 3* |
| it-IT | 25 | 2,319 | 463 | 450 | 3* |
| ja-JP | 25 | 2,316 | 463 | 450 | 0 |
| ko-KR | 25 | 2,316 | 463 | 450 | 0 |
| ru-RU | 25 | 2,316 | 463 | 450 | 0 |

`Extra=3` 是目标语言需要的 plural `one` 分支，不是可删除 Key。

基线统计：

```text
Languages: 10
Base keys: 2779
Union keys: 2782
Missing translation slots: 3812
Statically used base keys: 2042
Used missing translation slots: 3703
Static unused candidates: 737
Exact duplicate-value groups in zh-CN: 193 (460 keys)
Empty/null translations: 0
Duplicate YAML mapping keys: 0
Shared-key placeholder mismatch: 0
RTL: BLOCKED by global TextDirection.ltr
Release: NO-GO
```

已知审计器缺陷：

- `assets/i18n/i18n_audit.rb` 会把 `.dart_tool` 当成 locale。
- 它会把指向 plural 节点的合法 alias 误报为缺失目标。
- `737` 只能称为静态未引用候选，不能直接认定为可删除。

## 3. 产品术语不变量

以下概念必须保持独立，除非术语审计证明目标语言在特定 UI 角色中可以安全复用：

```text
Workspace Member != Project Member != Group Member != Channel Subscriber
Workspace Owner != Project Owner != Group Owner != Channel Admin
Join Workspace != Join Group != Subscribe Channel
Invite != Accept Invitation != Join/Subscribe
Delete Account != Log Out
Remove Member != Leave Group/Workspace
Encryption failed != Decryption failed
Message != Chat != Channel Post != Comment
```

## 4. 执行波次

```text
Wave 0: W0 baseline
   |
Wave 1: W1 audit gate || W2 terminology
   |
Wave 2: W3 key decision -> W4 key changes -> W5 zh-CN -> W6 en-US
                                  || W7 RTL root fix
   |
Wave 3: W8-W15 locale directories in parallel
   |
Wave 4: W16 terminology review || W17 UI/RTL tests
   |
Wave 5: W18 regeneration/full validation -> W19 native review -> W20 release decision
```

建议并行度最多为 3，保留一个执行槽用于审计、冲突检查和失败处理。

## 5. 工作包台账

状态只允许：`TODO`、`IN_PROGRESS`、`PASS`、`PARTIAL`、`BLOCKED`。

| ID | 工作包 | 依赖 | 并行 | 独占文件/目录 | 状态 |
|---|---|---|---|---|---|
| W0 | 冻结基线与工作树证据 | 无 | 否 | 只读 | TODO |
| W1 | 加固审计器和最小测试 | W0 | 可与 W2 | `assets/i18n/i18n_audit.rb`、审计器测试 | TODO |
| W2 | 建立 10 语言术语表 | W0 | 可与 W1 | `I18N_TERMINOLOGY.md` | TODO |
| W3 | Key 使用、合并、保留和删除裁决 | W1/W2 | 否 | `I18N_AUDIT_REPORT.md` | TODO |
| W4 | 执行人工确认后的安全 Key 收敛 | W3/人工确认 | 否 | 确认清单涉及的 YAML/Dart | TODO |
| W5 | 修正并冻结 zh-CN 产品语义 | W3/W4 | 否 | `assets/i18n/zh-CN/**` | TODO |
| W6 | 补齐和治理 en-US | W5 | 否 | `assets/i18n/en-US/**` | TODO |
| W7 | 修复全局 LTR 和增加 RTL 测试 | W1 | 可与 W6 | `lib/run.dart`、RTL 专项测试 | TODO |
| W8 | 治理 zh-Hant | W6 | 是 | `assets/i18n/zh-Hant/**` | TODO |
| W9 | 治理 ja-JP | W6 | 是 | `assets/i18n/ja-JP/**` | TODO |
| W10 | 治理 ko-KR | W6 | 是 | `assets/i18n/ko-KR/**` | TODO |
| W11 | 治理 de-DE | W6 | 是 | `assets/i18n/de-DE/**` | TODO |
| W12 | 治理 fr-FR | W6 | 是 | `assets/i18n/fr-FR/**` | TODO |
| W13 | 治理 it-IT | W6 | 是 | `assets/i18n/it-IT/**` | TODO |
| W14 | 治理 ru-RU | W6 | 是 | `assets/i18n/ru-RU/**` | TODO |
| W15 | 治理 ar-SA 和 RTL 文案 | W6/W7 | 是 | `assets/i18n/ar-SA/**` | TODO |
| W16 | 跨语言产品术语复核 | W8-W15 | 否 | 报告；问题回派 locale | TODO |
| W17 | 移动端长度、复数和 RTL Widget 验证 | W7-W16 | 可部分并行 | i18n 专项测试 | TODO |
| W18 | 统一生成、全量验证和第二轮审计 | W16/W17 | 否 | `lib/i18n/*.g.dart`、报告 | TODO |
| W19 | 母语人工审核 | W18 | 按语言并行 | 审核记录 | TODO |
| W20 | 最终发布门判断 | W18/W19 | 否 | `I18N_AUDIT_REPORT.md` | TODO |

## 6. 工作包验收

### W0 基线

```bash
git rev-parse --show-toplevel
git rev-parse HEAD
git status --short
flutter --version
dart --version
ruby assets/i18n/i18n_audit.rb summary
git diff -- assets/i18n slang.yaml lib/i18n
```

验收：记录命令和原始结果，没有产生新 diff。

### W1 审计门禁

必须检查 locale 白名单、YAML 解析、重复 Key、空/null、嵌套 Key、参数、plural、alias、静态引用及动态引用风险。

最小回归用例：

- `.dart_tool` 不计入语言。
- plural alias 不误报。
- 丢失 `$count` 或 `${name}` 必须失败。
- 重复 YAML Key 必须失败。
- locale 特有 plural 分支不算 extra。
- 无法排除动态使用的 Key 标为 unknown，不标 unused。

验收：

```bash
ruby assets/i18n/i18n_audit_test.rb
ruby assets/i18n/i18n_audit.rb check
```

### W2 术语表

`I18N_TERMINOLOGY.md` 至少包含 Concept、English、Chinese、Locale、Recommended、Forbidden/Discouraged、Reason、Review Status。不能确定的条目标记 `NEEDS_PRODUCT_CONFIRMATION` 或 `NEEDS_NATIVE_REVIEW`。

### W3/W4 Key 治理

所有基准 Key 必须分到：

```text
USED
INDIRECTLY_USED
DYNAMIC_OR_PROTOCOL_RISK
SAFE_MERGE
UNSAFE_MERGE
CONFIRMED_UNUSED
KEEP
```

删除必须同时排除 Dart、测试、配置、文档、alias、动态错误码、通知模板和协议映射引用，并经用户人工确认。无法判断时保留并记录。

每批 Key 变更验收：

```bash
rg -n '旧Key名称' lib test integration_test assets/i18n
dart run slang
flutter analyze <受影响Dart文件>
flutter test <受影响测试>
git diff --check
```

### W5/W6 zh-CN 和 en-US

先冻结产品语义，再补英文。优先级：安全/隐私/E2EE/账号删除/支付、Workspace/Project/Group/Channel、认证/聊天、其余 UI。

验收：

```text
en-US missing = 0
en-US used_missing = 0
placeholder mismatch = 0
英语核心 UI 不回退显示中文
P0(en-US) = 0
```

### W7 RTL

移除 `lib/run.dart` 对整棵应用的强制 LTR，让 Flutter 根据 locale 决定方向。URL、ID、哈希、安全码等技术字段只在局部固定 LTR。

测试必须断言：

```text
en-US -> ltr
zh-CN -> ltr
ar-SA -> rtl
运行时切换 locale 后方向更新
技术字段仍按 ltr 可读
```

### W8-W15 locale 治理

每个会话只修改一个 locale 目录，不修改中文、英文、业务代码、报告或生成物。源语义不清时停止该 Key 并报告，不猜测。

单语言验收：

```text
missing = 0
used_missing = 0
placeholder mismatch = 0
非白名单源语言残留 = 0
核心术语符合 I18N_TERMINOLOGY.md
P0 = 0
P1 = 0，或逐条列出待母语审核项
```

### W16/W17 跨语言和 UI

最低视口：`360x640`、`375x812`、`412x915`。至少覆盖 BottomNavigation、TabBar、AppBar、Dialog、BottomSheet、设置 ListTile、认证按钮、Workspace/Project、Channel 管理和 E2EE 警告。

验收：无 RenderFlex overflow、裁切或遮挡；ar-SA 方向和方向性图标正确；数字、价格、URL、ID、验证码及 placeholder 顺序正确。

### W18 第二轮全量审计

```bash
ruby assets/i18n/i18n_audit.rb check
dart run slang
git diff --check
dart format --output=none --set-exit-if-changed <本任务Dart文件>
flutter analyze
flutter test
```

历史失败不能当成本任务失败，也不能伪装成 PASS。记录首个错误、涉及文件、与本任务关系，并继续执行可独立完成的定向门。

### W19 母语审核

`ar-SA`、`de-DE`、`fr-FR`、`it-IT`、`ja-JP`、`ko-KR`、`ru-RU` 必须由母语人士审核所有 P0/P1、安全/隐私/支付/删除文案、核心产品术语，以及高频 UI 和参数化文案样本。

审核结果只允许：`APPROVED`、`CHANGES_REQUESTED`、`BLOCKED_NO_REVIEWER`。

## 7. 并行所有权和交付格式

- W1 不得修改任何 locale。
- W2/W3 不得修改翻译或业务代码。
- W7 只修改 `lib/run.dart` 和 RTL 专项测试。
- W8-W15 每个会话独占一个 locale；不得运行并提交统一生成物。
- 只有 W18 统一运行生成器并处理 `lib/i18n/*.g.dart`。
- 并行会话发现不属于自己所有权的改动时保留，不 restore、不覆盖。

每个会话必须返回：

```text
Task ID:
Base SHA:
Owned files:
Files changed:
Keys reviewed:
Translations added/corrected:
Terminology fixes:
Placeholder fixes:
Remaining uncertainties:
Commands and exact results:
Acceptance: PASS / PARTIAL / BLOCKED
```

## 8. 停止条件

遇到下列任一情况，停止相关修改并报告：

1. 产品语义或 Key 合并无法确定。
2. 需要修改业务逻辑、后端、数据库或 API。
3. 动态 Key、协议错误码或通知模板用途无法排除。
4. 需要大规模 UI 或 i18n 架构重构。
5. 目标语言需要母语人士才能确认。
6. 自动测试出现与本任务无关的历史问题。
7. 所有权文件与其他会话发生冲突。

## 9. 集成顺序

```text
W1 -> W2 -> W3 -> 人工确认 -> W4 -> W5 -> W6
W7 可在 W6 同期独立完成
W8-W15 在 W6 后并行
W16 -> W17 -> W18 -> W19 -> W20
```

并行 locale 会话不得修改生成代码。W18 在所有 locale 合入后只生成一次，避免冲突。

## 10. 发布门

### GO

- Missing、used missing、empty/null、重复 YAML、非法 alias、placeholder mismatch 均为 0。
- P0=0、P1=0，核心术语统一。
- Slang、format、analyze、相关测试和全量可执行测试通过。
- 核心移动端布局无溢出，ar-SA RTL 通过。
- 要求的母语审核全部 APPROVED。

### CONDITIONAL GO

- 自动门全部通过且 P0=0。
- 仅剩边界明确、不影响核心流程的少量 P2/P3 或非核心母语复核。

### NO-GO

- 存在 P0、placeholder、中文 fallback、RTL 阻断、安全/隐私/支付错译、核心术语混乱或大量 P1。

### BLOCKED

- 历史基础设施问题阻止验证，且定向检查无法排除本任务回归。

## 11. Before/After 记录模板

```text
Before
Languages: 10
Keys: 2779 base / 2782 union
Missing: 3812 slots
Used missing: 3703 slots
Unused candidates: 737
Duplicate-value groups: 193
Placeholder errors: 0
P0: 10 issue families
Release: NO-GO

After
Languages:
Keys:
Missing:
Used missing:
Confirmed unused:
Safe merges:
Deleted keys:
Placeholder errors:
P0:
P1:
Native review:
Release:
```
