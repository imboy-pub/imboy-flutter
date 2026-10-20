# GOLDEN 覆盖度修正（2026-10-20，第四轮 review 发现）

对 312 张封存 golden 做逐字节唯一度审计（sha256 + 五轴分组坍缩分析）后
发现：**golden 矩阵的名义轴与实际渲染差异不符**。以下数字取代此前
"3 场景 × 3 平台 × 2 视口 × 2 主题 × 2 缩放"的多样性暗示。

## 实测（方法：同其余四轴取值组内两两 sha256 对比）

| plan | 文件数 | 唯一图 | scale 轴 | 视口轴 | 主题轴 | platform 轴 | scene 轴 |
|---|---|---|---|---|---|---|---|
| P1 | 120 | **24** | 有效 | 有效 | 有效 | **字节死**（120/120 组全同） | 有效 |
| P2 | 72 | **16** | 有效 | 有效 | 有效 | **字节死**（72/72 全同） | **字节死**（24/24 全同） |
| P3 | 120 | **24** | 有效 | 有效 | 有效 | **字节死**（120/120 全同） | 有效 |

- 全计划唯一图合计 **64 / 312**。
- platform 轴：`debugDefaultTargetPlatformOverride` 注入后 ios/android/
  macos 渲染逐字节相同（Material 页面对平台差异不敏感所致）。
- P2 scene 轴：apps-only / resources-visible / conditional-login 三预置
  渲染逐字节相同——fixture 门控未改变工作台可见输出；**P2-04 辅助登录行、
  多行资源区等状态未被任何 golden 捕获**。
- 另有既有备案：CJK 在 golden 中渲染为 tofu（GOLDEN_ENV 缺视觉字体的
  既有决策）——golden 为结构基线，非文案基线。

## 影响与不受影响项

**不受影响**：零 diff 回归性质（每个配置的渲染稳定且已封存，compare 模式
幂等可继续作为回归网）；sealed_hashes 位级完整性；143 契约测试与
C-FULL 10830 行为验证；T30.a 真机证据。

**受影响**：以 golden 做视觉验收的覆盖度应按 64 张唯一图理解；P2 三个
业务预置的视觉基线实际缺失；平台差异无 golden 证据。

## 处置建议（归所有者裁决）

修正 platform/scene 两轴 = 测试基建变更（fixture 门控注入 + 平台差异
捕获路径），属封存后变更：需要新候选 K、golden 重生成与重封存。自动会话
不擅自解封；本文件即为该决策的输入。

## 修复记录（2026-10-20，所有者"继续"指示后自动会话执行）

已修复并重新封存（新候选 K=95dc3cddf，纯测试基建变更）：

| 项 | 修复前 | 修复后 |
|---|---|---|
| P2 scene 轴 | 字节死（3 预置渲染相同） | **3/3 分化**（apps-only 仅联调区 / resources-visible 多行资源区 / conditional-login 辅助登录行=P2-04 状态） |
| CJK 字形 | tofu 方块（注册字体从未被主题/回退链使用） | **真实落字形**（同字节按命中 family 名多名注册：UiuxGoldenFont/Roboto/PingFang SC/Heiti SC/Microsoft YaHei/sans-serif/Cupertino 系 + pump 主题 apply） |
| 唯一图 | 64/312 | **80/312**（P2 16→32；P1/P3 随字体修正重渲染） |

- 图标字形仍为 tofu（图标字体容错加载已实现，本机渲染仍退化）——确定性
  局限，如实记录；图标位置/尺寸已入基线。
- **残余债务（归所有者裁决）**：① platform 轴字节死（Material 页面对平台
  不敏感，不造人为差异）；② P1/P3 scene 夹具 4/5 场景注入相同状态
  （empty/initial-error/stats-disabled；closed/missing-preview/
  unknown-source 未分化）——行为断言由契约测试覆盖，视觉基线待补。
- 门禁证据：compare 模式复跑零 diff；C-TARGET-ALL 143/143；
  analyze 0 issues；封存哈希重写并复核（120+72+120）。

## 合并后收口（2026-10-20，main 分支多 agent 收口 + 所有者验收反馈）

合并 main（32dd2e919）后残余债务清偿与一项用户验收回归修复。golden 基线已
随合并迁至主工作树 `test/uiux/golden/goldens/{p1,p2,p3}/`（含 sealed_hashes
清单；原 runtime truth 封存库随之退役）。

### ① P1/P3 scene 轴修复（此前残余债务②，已清偿）

根因取证推翻「夹具注入相同状态」的单层解释，实为两层叠加：

1. **Element/State 复用**（隐蔽主因）：循环 `pumpWidget` 同类型无 key 根
   widget 时 Flutter 复用 Element/State，`initState` 不重跑、加载闭包与
   首拉数据停留在首个场景——后续场景全部消费第 1 个场景的泄漏状态。
2. 夹具同态（表层）：closed/missing-preview/unknown-source 等场景视图映射
   与注入数据本就趋同。

修复：P1 `_pumpGolden` 前置 `SizedBox.shrink()` 卸载旧树强制全新 mount，
并注入各场景语义状态（stats-disabled 走 `autoLoadStats:false` 兜底 12 订阅
者，其余接口统计 88；initial-error/empty/filters-expanded 各自真实分化，
filters-expanded 显式 `loadChannel` 注入）；P3 视图按 `ValueKey(cfg.id)`
强制重建，closed/missing-preview/unknown-source 三态分别以「source 空→渠
道行隐藏 / preview=null→摘要区不渲染 / source 未映射→未知兜底标签」分化。

实测唯一图：**P1 24→64/120（scene 5/5 分化），P3 24→48/120（跨场景重复
哈希组 0）**。

### ② 图标 tofu 根因修复（此前「确定性局限」结论作废，已清偿）

多轮对照实验（golden 管线内逐像素取证）推翻既有「机器局限」判断，真因：

- **family 名改写**：`TextStyle(package:)` 构造器把 family 改写为
  `packages/<pkg>/<family>`，`Icon(CupertinoIcons.*)` 实际按前缀名查找，
  FontLoader 裸名注册永不命中。
- **Directionality 依赖**：Icon 组件路径还需 Directionality 祖先才正常
  布局（MaterialApp golden 环境天然具备；裸 pump 探针缺它时全渲染同一
  方框，导致早期探针误报「修复无效」）。

修复：`golden_font_loader.dart` 对 cupertino 字体同字节按
`packages/cupertino_icons/CupertinoIcons` + 裸名双注册；MaterialIcons 保持
裸名（fontPackage=null 不改写，加前缀反而失效）。管线内实证：
home/gear/material_add 三图标渲染出互异真实字形（119/154/8 色 vs 方框
37 色同哈希）。含图标的全部金图随之预期性重渲染。

### ③ 用户验收回归修复：工作台行左右对齐（P2-04/D02 副作用）

用户真机验收发现工作台 item 列表左右对齐不一致：客服行（Material
ListTile）默认 contentPadding 16/16，与相邻 CupertinoListTile 行（
`_kPadding` start20/end14 + leadingToTitle 16）在图标起点（16 vs 20）、
文字起点（56 vs 60）、chevron 内缩（16 vs 14）三处错位。修复：客服行显式
`contentPadding = EdgeInsetsDirectional.only(start: 20, end: 14)`，与
Cupertino 行度量逐项对齐（P2 金图随之重生成）。

### 收口后矩阵实测（最终态）

| plan | 张数 | 唯一图 |
|---|---|---|
| P1 | 120 | 64 |
| P2 | 72 | 32 |
| P3 | 120 | 48 |
| 合计 | 312 | **144** |

### 残余债务（最终态，归所有者）

- platform 轴 ios/android 字节死（Material 页面对平台不敏感，不造人为
  差异）；macos 在 P1 部分 GlassAppBar 场景存在自然差异（非注入）。
- golden 基线为本机钉住（EXTERNAL_PINNED）：字体/图标资产路径是本机
  SDK/pub 缓存，其他机器需按 GOLDEN_ENV.md 自行满足环境。
