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
