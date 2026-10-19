# GOLDEN_ENV.md — 视觉（金图）字体与栅格环境（T05.a）

> plan: imboy-enterprise-uiux-v1 | batch B1 | 卡片 T05.a
> 金图只在本文登记的环境完全一致时比较；环境 hash 任一字段不同即视为
> 不同环境，禁止跨环境比较（也禁止用扩大容差吸收环境差异）。
> 结构测试环境见 STRUCTURE_ENV.md，两者严格分离。

## 1. 字体资产登记（只登记，不分发）

| 字段 | 值 |
|---|---|
| 路径 | `/Library/Fonts/Arial Unicode.ttf`（macOS 附带；`/System/Library/Fonts/` 下为链接占位，探测走 `/Library/Fonts`） |
| sha256 | `876af2cd4854644e7f3e7feb2f688997fdb3343c6df6693611209c9dfb47ccec` |
| 格式 | TrueType（sfnt 0x10000），cmap 单子表 (3,1) format 4，全 BMP CJK 覆盖 |
| 家族 | Arial Unicode MS |
| 来源许可 | macOS system-bundled font；**仅本地测试使用，不随仓库分发**（本文件与 loader 只登记路径+hash） |
| 登记时间 | 2026-10-19（本工作区探测） |

接受判据 = 路径存在 + sha256 逐字节一致 + cmap 覆盖
`kRequiredCjkCodepoints`（28 个常用汉字/中文标点样本）。三步任一失败 →
`visualBlocked`。hash 不匹配视为字体被替换或损坏（含 Ahem 假字体场景），
一律拒绝，绝不静默降级到测试默认字体继续图像比较。

## 2. 栅格环境清单（goldenEnvironmentManifest）

| 字段 | 值 / 来源 |
|---|---|
| fontSha256 | 登记值（上表）或 `none`（缺字体） |
| fontFamily | `UiuxGoldenFont`（FontLoader 注册名）/ `unavailable` |
| flutterVersion | 钉 `3.47.7`（`kFlutterVersionPin` 常量；Dart 版本运行时读取） |
| dartVersion | `Platform.version`（运行时） |
| os | `Platform.operatingSystem + operatingSystemVersion` |
| locale | `zh-CN` |
| devicePixelRatio | `1.0` |
| animations | disabled |
| clock | static-frame |
| emojiPolicy | 见第 3 节 |

`goldenEnvironmentHash()` = sha256(canonical JSON(manifest))。
**升级 Flutter SDK 时必须同步更新 `kFlutterVersionPin` 与计划内
`flutter-sdk:${SDK_REALPATH_HASH}` resource key** —— hash 会随
flutterVersion/dartVersion/os 自动变化，旧金图自动失效。

## 3. emoji 显式策略

`forbidden-in-golden-fixtures`：Arial Unicode 无彩色 emoji 字形，emoji
由系统 fallback（Apple Color Emoji）渲染，跨机器不可复现 —— 金图
fixture **禁止**包含任何 emoji 码点。确需 emoji 样张时必须先登记
确定性 emoji 字体并修订本策略，不得直接入图。
（`kKnownEmojiSampleCodepoints` 仅为策略自检样例，不是 fixture。）

## 4. VISUAL_BLOCKED 语义

缺字体/hash 不匹配时：`resolveGoldenFont()` 返回
`visualBlocked`（不抛异常、不产生字体字节）：

- 金图类测试前置 `goldenVisualAllowed()` 判断，false → 整卡视觉验收
  记 **VISUAL_BLOCKED**（跳过图像比较），不得伪造、不得降容差；
- 结构/交互/i18n/实现回归测试**不受影响**（STRUCTURE_ENV.md 承诺）；
- `loadGoldenFont()` 收到非 ok resolution 抛 StateError（调用方契约
  错误），防止误用。

## 5. 与 STRUCTURE_ENV 的分离

结构环境（`test/uiux/support/uiux_harness.dart`）不导入本文件、不做
图像比较、不依赖字体资产；视觉环境（本文件 +
`golden_font_loader.dart`）不参与结构挂载。两环境的判定边界在
STRUCTURE_ENV.md §5。

## 6. 首次验证证据

- 命令：`flutter test test/uiux/contract/font_contract_test.dart --reporter json`
- 结果：executed=6（5 用例 + loading），success=6，failed=0，skipped=0，exit=0
- 用例：golden_font_has_required_cjk_glyphs /
  golden_rejects_ahem_or_missing_font /
  golden_environment_hash_changes_on_font_sdk_change /
  fixture_emojis_have_explicit_policy /
  golden_missing_font_is_visual_blocked_only
- 证据文件：运行时 `evidence/T05.a/1/`
