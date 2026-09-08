# IMBoy i18n 治理并行执行提示词

> 配套计划：`docs/plans/2026-09-04-i18n-release-governance-plan.md`
> 使用方式：每个提示词开一个独立会话。严格按依赖顺序启动；只有标注可并行的提示词可以同时执行。
> 并行 locale 会话只改自己的目录，不改台账、术语表、业务代码或 `lib/i18n` 生成物。

## 调度顺序

```text
先执行 P0
P0 完成后并行执行 P1、P2
P1/P2 完成后执行 P3
用户确认 P3 的 Key 清单后执行 P4
P4 完成后执行 P5
P5 完成后可并行执行 P6 和 P7
P7 完成后并行执行 P8-P15
全部完成后执行 P16
母语审核完成后执行 P17
```

## P0：只读基线协调会话

```text
工作目录：/Users/leeyi/project/imboy.pub/imboyapp。

读取 AGENTS.md、CLAUDE.md、slang.yaml、assets/i18n/README.md，以及 docs/plans/2026-09-04-i18n-release-governance-plan.md。执行 W0，只读，不修改任何文件，不 commit、不 push。

先确认 git rev-parse --show-toplevel 精确返回 /Users/leeyi/project/imboy.pub/imboyapp。当前是共享脏工作树，保留全部既有改动，禁止 reset/clean/restore。

记录 HEAD、git status、Flutter/Dart/Ruby 版本；复跑语言目录、文件数、Key、missing、extra、空/null、placeholder、plural、alias 和静态引用统计。验证 Phase 1 基线是否仍成立，明确当前值与计划文档的漂移。不要把 .dart_tool 算作 locale，不要把语言特有 plural one/few/many 当 extra，不要删除任何 Key。

输出：命令及准确结果、当前 Language Inventory、基线漂移、P0/P1 风险、W0 的 PASS/PARTIAL/BLOCKED。只汇报，不落盘。
```

## P1：审计器加固会话（可与 P2 并行）

```text
工作目录：/Users/leeyi/project/imboy.pub/imboyapp。读取项目指令和 docs/plans/2026-09-04-i18n-release-governance-plan.md，执行 W1。

独占所有权：assets/i18n/i18n_audit.rb 和一个最小 Ruby 审计器测试文件。禁止修改任何 locale YAML、业务 Dart、报告、术语表或 lib/i18n 生成物。共享脏工作树中保留其他会话改动，不 reset/clean/restore，不 commit、不 push。

在理解现有脚本后做最小修改：locale 只识别 10 个合法目录；正确处理 YAML 解析、重复 Key、空/null、嵌套 Key、Slang 方法参数、$name/${name}/{name}、plural 节点、跨 namespace alias、语言特有 plural 分支、静态使用位置和动态使用风险。修复 .dart_tool 假 locale 与 plural alias 假阳性。无法证明未使用的 Key必须标为 candidate/unknown，不能标 confirmed unused。

测试至少覆盖：.dart_tool 排除；合法 plural alias；丢失 placeholder；重复 YAML Key；特有 plural 分支；嵌套 Key；动态使用 unknown。不得新增 gem 或其他依赖。

验收：运行 Ruby 测试、ruby assets/i18n/i18n_audit.rb check、summary 和 git diff --check。返回修改文件、测试结果、真实项目统计、残余限制和 PASS/PARTIAL/BLOCKED。
```

## P2：术语表会话（可与 P1 并行）

```text
工作目录：/Users/leeyi/project/imboy.pub/imboyapp。读取项目指令、产品代码中 Workspace/Project/Group/Channel 的实际模型和 UI 使用位置，以及 docs/plans/2026-09-04-i18n-release-governance-plan.md，执行 W2。

独占所有权：仓库根 I18N_TERMINOLOGY.md。禁止修改 YAML、Dart、审计报告或生成物，不 commit、不 push。保留共享工作树的全部既有改动。

建立 10 语言术语表，至少覆盖 Workspace、Project、Group、Channel、各自 Member/Owner/Admin/Subscriber、Invite/Invitation/Invite Code、Join/Leave/Subscribe/Unsubscribe、User/Account/Profile/Friend/Contact、Message/Chat/Post/Comment/Reply、Privacy/Security/E2EE/Device/Session/Verification/Recovery、Delete/Remove/Block/Report/Mute。

每项包含 Concept、English、Chinese、Locale、Recommended、Forbidden/Discouraged、词性/UI角色、Reason、Review Status。结合代码上下文，不把中文当唯一真源。无法可靠确认的目标语言标记 NEEDS_NATIVE_REVIEW；产品语义不清标记 NEEDS_PRODUCT_CONFIRMATION，不猜测。

验收：明确 Workspace Member != Group Member != Channel Subscriber，Join Workspace != Join Group != Subscribe Channel，Owner/Admin/Moderator 不混用。运行 git diff --check，输出证据位置、未决项和 PASS/PARTIAL/BLOCKED。
```

## P3：Key 治理裁决会话

```text
工作目录：/Users/leeyi/project/imboy.pub/imboyapp。前置条件：P1、P2 已完成。读取项目指令、加固后的审计器、I18N_TERMINOLOGY.md 和完整代码引用，执行 W3。

独占所有权：仓库根 I18N_AUDIT_REPORT.md。此会话只审计和制定裁决，不修改 YAML、Dart、生成物，不 commit、不 push。

把 2779 个基准 Key 分类为 USED、INDIRECTLY_USED、DYNAMIC_OR_PROTOCOL_RISK、SAFE_MERGE、UNSAFE_MERGE、CONFIRMED_UNUSED、KEEP。对每个 SAFE_MERGE 列出全部调用位置、10 语言值、UI 角色、参数/plural、目标 Key 和风险。对 CONFIRMED_UNUSED 排除 Dart、测试、配置、文档、alias、通知模板、服务端错误码和协议映射。无法确认的一律保留。

报告必须含 Executive Summary、Language Inventory、Language Quality、Key Governance、P0-P3、UI/RTL 风险、Before 统计、建议修改批次和人工审核项。明确列出待用户确认的 merge/delete 清单；没有用户确认不得执行 W4。

验收：运行审计器、rg 证据检查和 git diff --check。输出报告路径、候选数量、确认删除数量、未决风险和 PASS/PARTIAL/BLOCKED，然后停止等待用户确认。
```

## P4：Key 收敛执行会话（必须先有人工作出确认）

```text
工作目录：/Users/leeyi/project/imboy.pub/imboyapp。前置条件：用户已明确确认 I18N_AUDIT_REPORT.md 中具体的 SAFE_MERGE/CONFIRMED_UNUSED 清单；没有明确确认则停止，只报告 BLOCKED。

执行 W4，只处理用户确认的清单。先读取所有调用方和 10 语言上下文，做最小 diff。禁止顺手重命名、扩大删除、重构业务逻辑或改变产品语义。不修改 ios/*、macos/*、plugin/r_upgrade，不新增依赖，不 commit、不 push，保留共享工作树既有改动。

优先复用现有公共 Key或 Slang alias。每个旧 Key 删除前再次 rg 全仓并检查 alias、动态错误码、通知和协议入口。任何不确定项保留并写回报告。

验收：rg 旧 Key、dart run slang、相关 flutter analyze、相关 flutter test、审计器 check、git diff --check。输出每个 merge/delete 的前后映射、改动文件、命令结果、残余项和 PASS/PARTIAL/BLOCKED。
```

## P5：简体中文语义冻结会话

```text
工作目录：/Users/leeyi/project/imboy.pub/imboyapp。前置条件：W3 已完成；若有确认的 W4，必须先完成。执行 W5。

独占所有权：assets/i18n/zh-CN/**。禁止修改其他 locale、业务 Dart、术语表、报告或 lib/i18n 生成物，不 commit、不 push。保留共享工作树其他改动。

结合 Key 名、所有调用位置、Widget 角色、参数和邻近文案，修复确定性的中文错别字、歧义、工程化表达、术语冲突、标点和长度问题。遵守 I18N_TERMINOLOGY.md。不能仅为文风偏好重写大量文案；产品语义不清时保留并报告。

重点确认 Workspace/Project/Group/Channel、成员角色、邀请/加入/订阅、安全/隐私/E2EE、支付、删除账户。不得合并未获确认的 Key。

验收：审计器 check、placeholder/plural 检查、git diff --check。不要运行并提交 slang 生成物。输出修改统计、逐项理由、未决产品语义和 PASS/PARTIAL/BLOCKED。
```

## P6：RTL 根因修复会话（可与 P7 并行）

```text
工作目录：/Users/leeyi/project/imboy.pub/imboyapp。执行 W7。

独占所有权：lib/run.dart 和新建/现有 RTL 专项测试文件。禁止修改任何 locale YAML、报告、术语表、其他业务文件或 lib/i18n 生成物，不 commit、不 push。保留共享工作树既有改动。

根因是 MaterialApp.router 外层全局 Directionality(textDirection: TextDirection.ltr)。做最小修复，让 Flutter 根据当前 locale 提供 ltr/rtl。URL、ID、哈希、安全码等确需 LTR 的技术字段不在本任务大范围改造；只记录发现的局部风险。审计方向性图标，但超出独占文件的修复只登记，不修改。

测试必须覆盖 en-US/zh-CN 为 ltr、ar-SA 为 rtl、运行时 locale 更新后方向更新。先复用现有 TranslationProvider 测试范式，不新增依赖。

验收：相关 flutter test、flutter analyze lib/run.dart 和测试文件、dart format check、git diff --check。输出改动、测试结果、未覆盖方向性控件和 PASS/PARTIAL/BLOCKED。
```

## P7：英语完整翻译会话（可与 P6 并行）

```text
工作目录：/Users/leeyi/project/imboy.pub/imboyapp。前置条件：P5 已完成。执行 W6。

独占所有权：assets/i18n/en-US/**。禁止修改 zh-CN、其他 locale、Dart、报告、术语表或 lib/i18n 生成物，不 commit、不 push。保留共享工作树既有改动。

以实际 UI 语境和 I18N_TERMINOLOGY.md 为准，补齐全部缺失英文并治理明显错误、机械直译、大小写、标点、placeholder、plural 和长度。英文是跨语言语义桥接，不是机械复制中文。重点处理安全/隐私/E2EE/账号删除/支付、Workspace/Project/Group/Channel、Agent Task、认证和聊天。

不确定产品语义时保留并报告，不自行修改中文或业务代码。不得用 fallback 掩盖缺失。

验收：en-US missing=0、used_missing=0、placeholder mismatch=0、非法 alias=0；审计器 check 和 git diff --check 通过。不要运行并提交 slang 生成物。输出新增/修正统计、核心术语检查、待人工确认项和 PASS/PARTIAL/BLOCKED。
```

## P8：繁体中文会话

```text
工作目录：/Users/leeyi/project/imboy.pub/imboyapp。前置条件：P7 已完成。执行 W8，只拥有 assets/i18n/zh-Hant/**。

读取 zh-CN、en-US、全部调用上下文和 I18N_TERMINOLOGY.md，补齐 missing 并修复英文残留、简繁地区用语、术语、标点、placeholder、plural 和长度。使用真实繁体中文产品表达，不做字符级简繁转换。特别区分 Workspace/Project/Group/Channel 及各自成员关系。

禁止修改其他目录、业务代码、报告、术语表和 lib/i18n 生成物；不 commit、不 push。源语义不清或台湾/香港用语无法统一时保留并标记 NEEDS_NATIVE_REVIEW。

验收：missing=0、used_missing=0、placeholder mismatch=0、非白名单英文残留=0；审计器 check、git diff --check。返回完整交付模板和 PASS/PARTIAL/BLOCKED。
```

## P9：日语会话

```text
工作目录：/Users/leeyi/project/imboy.pub/imboyapp。前置条件：P7 已完成。执行 W9，只拥有 assets/i18n/ja-JP/**。

读取 zh-CN、en-US、调用上下文和 I18N_TERMINOLOGY.md，补齐 missing，修复英文残留、不自然日语、敬体一致性、标点、placeholder、plural 和移动端长度。重点统一 Channel Subscriber，审计当前 購読者/登録者 冲突；区分 Workspace/Project/Group/Channel 及各类成员、所有者和管理员。

禁止修改其他目录、业务代码、报告、术语表和生成物；不 commit、不 push。不确定母语表达时保留并标记 NEEDS_NATIVE_REVIEW。

验收：missing=0、used_missing=0、placeholder mismatch=0、非白名单英文残留=0；审计器 check、git diff --check。返回完整交付模板和 PASS/PARTIAL/BLOCKED。
```

## P10：韩语会话

```text
工作目录：/Users/leeyi/project/imboy.pub/imboyapp。前置条件：P7 已完成。执行 W10，只拥有 assets/i18n/ko-KR/**。

读取 zh-CN、en-US、调用上下文和 I18N_TERMINOLOGY.md，补齐 missing，修复英文残留、不自然韩语、敬语层级、助词、标点、placeholder、plural 和移动端长度。重点检查群管理确认/成功/失败文案以及 Workspace/Project/Group/Channel 的成员关系。

禁止修改其他目录、业务代码、报告、术语表和生成物；不 commit、不 push。不确定母语表达时保留并标记 NEEDS_NATIVE_REVIEW。

验收：missing=0、used_missing=0、placeholder mismatch=0、非白名单英文残留=0；审计器 check、git diff --check。返回完整交付模板和 PASS/PARTIAL/BLOCKED。
```

## P11：德语会话

```text
工作目录：/Users/leeyi/project/imboy.pub/imboyapp。前置条件：P7 已完成。执行 W11，只拥有 assets/i18n/de-DE/**。

读取 zh-CN、en-US、调用上下文和 I18N_TERMINOLOGY.md，补齐 missing，修复英文残留、格/性/数、正式程度、复合词、标点、placeholder、plural 和移动端长度。优先复核 Phase 1 的 36 个长度风险，以及安全/隐私/E2EE、支付和删除账户文案。

禁止修改其他目录、业务代码、报告、术语表和生成物；不 commit、不 push。不确定母语表达时保留并标记 NEEDS_NATIVE_REVIEW。

验收：missing=0、used_missing=0、placeholder mismatch=0、非白名单英文残留=0；审计器 check、git diff --check。返回完整交付模板和 PASS/PARTIAL/BLOCKED。
```

## P12：法语会话

```text
工作目录：/Users/leeyi/project/imboy.pub/imboyapp。前置条件：P7 已完成。执行 W12，只拥有 assets/i18n/fr-FR/**。

读取 zh-CN、en-US、调用上下文和 I18N_TERMINOLOGY.md，补齐 missing，修复英文残留、性/数、冠词、祈使语气、空格和标点规范、placeholder、plural 和移动端长度。优先复核 Phase 1 的 77 个长度风险，以及安全/隐私/E2EE、支付和删除账户文案。

禁止修改其他目录、业务代码、报告、术语表和生成物；不 commit、不 push。不确定母语表达时保留并标记 NEEDS_NATIVE_REVIEW。

验收：missing=0、used_missing=0、placeholder mismatch=0、非白名单英文残留=0；审计器 check、git diff --check。返回完整交付模板和 PASS/PARTIAL/BLOCKED。
```

## P13：意大利语会话

```text
工作目录：/Users/leeyi/project/imboy.pub/imboyapp。前置条件：P7 已完成。执行 W13，只拥有 assets/i18n/it-IT/**。

读取 zh-CN、en-US、调用上下文和 I18N_TERMINOLOGY.md，补齐 missing，修复英文残留、性/数、冠词、语气、标点、placeholder、plural 和移动端长度。优先复核 Phase 1 的 30 个长度风险及核心产品术语。

禁止修改其他目录、业务代码、报告、术语表和生成物；不 commit、不 push。不确定母语表达时保留并标记 NEEDS_NATIVE_REVIEW。

验收：missing=0、used_missing=0、placeholder mismatch=0、非白名单英文残留=0；审计器 check、git diff --check。返回完整交付模板和 PASS/PARTIAL/BLOCKED。
```

## P14：俄语会话

```text
工作目录：/Users/leeyi/project/imboy.pub/imboyapp。前置条件：P7 已完成。执行 W14，只拥有 assets/i18n/ru-RU/**。

读取 zh-CN、en-US、调用上下文和 I18N_TERMINOLOGY.md，补齐 missing，修复英文残留、格变化、性/数、命令语气、标点、placeholder、one/few/many/other 和移动端长度。优先复核 Phase 1 的 42 个长度风险及所有数量文案。

禁止修改其他目录、业务代码、报告、术语表和生成物；不 commit、不 push。不确定母语表达时保留并标记 NEEDS_NATIVE_REVIEW。

验收：missing=0、used_missing=0、placeholder mismatch=0、plural 类别正确、非白名单英文残留=0；审计器 check、git diff --check。返回完整交付模板和 PASS/PARTIAL/BLOCKED。
```

## P15：阿拉伯语和 RTL 文案会话

```text
工作目录：/Users/leeyi/project/imboy.pub/imboyapp。前置条件：P6、P7 已完成。执行 W15，只拥有 assets/i18n/ar-SA/**。

读取 zh-CN、en-US、调用上下文和 I18N_TERMINOLOGY.md，补齐 missing，修复英文残留、自然阿拉伯语、性/数、双数和复数、标点、placeholder、数字/价格/验证码顺序及移动端长度。审计 Phase 1 的 18 个长度风险。技术词、品牌名、URL、ID 可按明确白名单保留拉丁字符。

禁止修改其他目录、lib/run.dart、业务代码、报告、术语表和生成物；不 commit、不 push。不确定母语或地区表达时保留并标记 NEEDS_NATIVE_REVIEW，不猜测。

验收：missing=0、used_missing=0、placeholder mismatch=0、plural 类别正确、非白名单英文残留=0；审计器 check、git diff --check。返回完整交付模板和 PASS/PARTIAL/BLOCKED。
```

## P16：最终集成、第二轮审计与 UI 验证会话

```text
工作目录：/Users/leeyi/project/imboy.pub/imboyapp。前置条件：P6-P15 全部完成且改动已存在于当前工作树。执行 W16-W18；不执行母语审核，不预设 GO，不 commit、不 push。

你是唯一允许统一修改 lib/i18n/*.g.dart、I18N_AUDIT_REPORT.md 和 i18n 专项测试的集成会话。先核实所有 locale 所有权范围，没有会话越界覆盖。跨语言复核 Workspace/Project/Group/Channel、Member/Subscriber、Owner/Admin/Moderator、Invite/Join/Subscribe、Delete/Remove/Leave、Encryption/Decryption。

运行 dart run slang；重新建立 10 语言全量矩阵。验证 missing、used missing、empty/null、重复 YAML、非法 alias、placeholder mismatch。对 360x640、375x812、412x915 建立或运行最小 Widget 检查，覆盖导航、Tab、AppBar、Dialog、BottomSheet、设置、认证、Workspace/Project、Channel 和 E2EE；重点验证 de/fr/it/ru 长度和 ar-SA RTL。禁止为了测试通过大规模重构 UI。

实际运行：审计器测试/check、dart run slang、git diff --check、相关 dart format、相关 flutter analyze、相关 flutter test；条件允许再跑全量 flutter analyze 和 flutter test。历史无关失败只记录，不擅自修复，也不能记 PASS。

更新 I18N_AUDIT_REPORT.md 的 Before/After、P0-P3、Top 20、剩余人工审核项、完整命令结果和暂定 GO/CONDITIONAL GO/NO-GO/BLOCKED。输出完整交付模板。
```

## P17：母语审核结果收口与发布判断会话

```text
工作目录：/Users/leeyi/project/imboy.pub/imboyapp。前置条件：P16 完成，且用户已提供各语言母语审核结果。执行 W19-W20，只更新 I18N_AUDIT_REPORT.md；除非用户明确提供逐条修改决定，否则不改翻译，不 commit、不 push。

核对 ar-SA、de-DE、fr-FR、it-IT、ja-JP、ko-KR、ru-RU 的审核状态，只接受 APPROVED、CHANGES_REQUESTED、BLOCKED_NO_REVIEWER。CHANGES_REQUESTED 未闭环不能给 GO；无人审核时不得声称 100% 母语发布质量。

根据自动门、产品术语门、UI/RTL 门和人工门给出最终 GO、CONDITIONAL GO、NO-GO 或 BLOCKED。报告必须包含 10 语言质量排名、修改统计、Top 20、剩余人工项、实际命令结果、阻断原因和最终发布判断。不得用计划、fallback、生成成功或局部测试代替发布证据。
```

## 会话交付模板

```text
Task ID:
Base SHA:
Owned files:
Files changed:
Keys reviewed:
Translations added:
Translations corrected:
Key merges/deletions:
Terminology fixes:
Placeholder/plural fixes:
Remaining uncertainties:
Commands run and exact results:
Acceptance: PASS / PARTIAL / BLOCKED
```
