# STRUCTURE_ENV.md — 结构测试环境（T05）

> plan: imboy-enterprise-uiux-v1 | batch B1 | 卡片 T05
> 本文定义**结构/交互测试**的冻结环境与判定边界。视觉（金图）环境见
> GOLDEN_ENV.md（T05.a），两者严格分离，不共享字体承诺。

## 1. 环境绑定（env bindings）

| 维度 | 绑定值 | 实现位置 |
|---|---|---|
| 视口（基准） | 360×800 逻辑像素，DPR=1 | `UiuxViewport.phone` |
| 视口（宽窗） | 1280×800 逻辑像素，DPR=1 | `UiuxViewport.wide` |
| 亮度 | light / dark（双主题真实构建） | `AppTheme.getLight/DarkThemeFromOption` |
| 平台 | iOS（默认）/ Android 等按用例覆盖 | `debugDefaultTargetPlatformOverride`（挂载期生效，pumpUiux 返回前同步复位） |
| locale | zh-CN（默认）/ en-US 等按用例覆盖 | `TranslationProvider` + `MaterialApp.locale` |
| 文字缩放 | `TextScaler.linear(scale)`，1=基准 / 2=大字 | MaterialApp.builder 包裹 MediaQuery |
| 主题字号档 | `FontSizeOption.normal`（结构测试固定档） | AppTheme 静态构建器 |
| i18n | 真实 `strings.g.dart`，10 locale 资产 | slang 生成物 |

同步复位约束：flutter_test 的 foundation invariant 检查发生在测试体结束
瞬间、早于 dart test 的 addTearDown 回调，因此平台/视口覆盖必须在
`pumpUiux` 返回前以 try/finally 同步还原；挂载期证据一律取自已构建树
（`Theme.of` / `MediaQuery.*Of`），不依赖挂载后的全局状态。

## 2. 用例清单（manifest，全部不得 skip）

C-T05-1 = `flutter test test/uiux/contract/harness_test.dart
--reporter json`，期望 6/6 执行、0 skip、退出码 0：

1. `harness_real_shell_mounts` — 真实应用主题构建器 + 真实组件（NoDataView）
2. `harness_restores_platform_locale_clock` — 平台/locale/scale/DPR 挂载期生效
3. `harness_env_restored_after_teardown` — 跨用例全局复位（顺序敏感）
4. `harness_fails_render_exceptions` — 渲染异常不被夹具吞掉
5. `harness_font_missing_does_not_disable_nonvisual_tests` — 默认测试字体下
   中文文本仍可查找/测量
6. `harness_env_switches` — 宽窗/暗色/scale2 参数化切换（STRUCTURE_ONLY）

## 3. STRUCTURE_ONLY 判定规则

- 结构测试只做**结构/交互/几何关系**断言：组件挂载、文本可查找、
  自然高度随文字缩放单调变化、主题产物一致性等。
- 缺确定性 CJK 字体时：不产生任何视觉图像结论；截图/金图类断言一律
  标注 STRUCTURE_ONLY 或直接不运行（VISUAL_BLOCKED，见 GOLDEN_ENV.md）。
- 禁止用结构测试冒充：中文可读性、字形正确性、精确文本几何（基线/
  字宽）验收。此类断言只能由 T05.a 冻结字体后的视觉环境给出。

## 4. 时钟限制

`uiuxFrozenClock()`（2026-01-15 10:00:00）仅作为**断言输入**（日期分隔、
等待时长格式化等的期望值来源）。不拦截应用内 `DateTime.now()`：
被测组件内部调用真实时钟的路径不在结构测试的冻结范围内；若某卡片
需要对内部时钟取伪，须在该卡片以依赖注入方式实现，不得在本框架
全局打补丁。

## 5. 与 GOLDEN_ENV 的分离

| | STRUCTURE_ENV（本文） | GOLDEN_ENV（T05.a） |
|---|---|---|
| 字体 | 无要求：缺字体不阻塞任何结构/交互/i18n/回归测试 | 冻结 CJK/图标/emoji fallback 字体，登记 hash 与许可 |
| 图像比较 | 无 | pixels 对比，仅同环境 hash 下有效 |
| 结论效力 | 结构、文案、缩放行为、主题一致性 | 中文可读性与精确文本几何 |
| 失败语义 | 断言失败=结构缺陷 | 缺字体=VISUAL_BLOCKED；比较失败=视觉缺陷 |

## 6. 首次验证证据

- 命令：`flutter test test/uiux/contract/harness_test.dart --reporter json`
- 结果：executed=7（6 用例 + loading），success=7，failed=0，skipped=0，exit=0
- 证据文件：运行时 `evidence/T05/1/`（JSON 报告 + 运行说明）
