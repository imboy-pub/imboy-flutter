# P2 结构矩阵 — imboy-enterprise-uiux-v1（T23）

> 结构/语义/尺寸/对比度断言的配置计数。golden 在 T23.a/b。

## 配置空间

2 视口 × 2 亮度 × 2 缩放 × 2 平台 = **16 配置**（场景面：resources-visible / apps-only / conditional-login，见 T23 专项用例）

## 执行计数（C-T23-1 实测）

| 配置 | 状态 |
|---|---|
| p2_360x800_dark_scale1_ios | executed |
| p2_360x800_dark_scale1_android | executed |
| p2_360x800_dark_scale2_ios | executed |
| p2_360x800_dark_scale2_android | executed |
| p2_360x800_light_scale1_ios | executed |
| p2_360x800_light_scale1_android | executed |
| p2_360x800_light_scale2_ios | executed |
| p2_360x800_light_scale2_android | executed |
| p2_1280x800_dark_scale1_ios | executed |
| p2_1280x800_dark_scale1_android | executed |
| p2_1280x800_dark_scale2_ios | executed |
| p2_1280x800_dark_scale2_android | executed |
| p2_1280x800_light_scale1_ios | executed |
| p2_1280x800_light_scale1_android | executed |
| p2_1280x800_light_scale2_ios | executed |
| p2_1280x800_light_scale2_android | executed |

**expected=16，executed=16，skipped=0**（每配置断言：应用入口常驻、无渲染异常）

## 专项断言

| 断言 | 覆盖 |
|---|---|
| p2_semantics_labels_and_targets_valid | 应用入口命中 ≥48×48 |
| p2_text_and_enabled_icon_contrast_valid | 亮/暗 × 2 视口：入口文字对分组背景 ≥3:1 |
| resources-visible 场景 | seat-contexts 出站记录（CS gate 基线） |
| conditional-login 场景 | Android inbound + 应用入口共存 |
