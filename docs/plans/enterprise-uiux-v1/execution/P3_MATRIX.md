# P3 结构矩阵 — imboy-enterprise-uiux-v1（T24）

## 配置空间

5 场景（queued / active / closed / missing-preview / unknown-source）× 2 视口 × 2 亮度 × 2 缩放 × 2 平台 = **120 渲染**

## 执行计数（C-T24-1 实测，逐场景逐配置）

| 场景 / 配置 | 状态 |
|---|---|
| queued / p3_360x800_dark_scale1_ios | executed |
| queued / p3_360x800_dark_scale1_android | executed |
| queued / p3_360x800_dark_scale2_ios | executed |
| queued / p3_360x800_dark_scale2_android | executed |
| queued / p3_360x800_light_scale1_ios | executed |
| …（共 80 行） | executed |

**expected=120，executed=120，skipped=0**（每渲染断言：行掩码名渲染、widget 源显示本地化名、无渲染异常）

## 专项断言

| 断言 | 覆盖 |
|---|---|
| p3_semantics_labels_and_targets_valid | 接单按钮（外层 FilledButton）命中 ≥48 |
| p3_contrast_valid | 行文本 maxLines=1、无异常 |
