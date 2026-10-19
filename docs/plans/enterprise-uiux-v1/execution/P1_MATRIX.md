# P1 结构矩阵 — imboy-enterprise-uiux-v1（T22）

> 结构/语义/尺寸/对比度与键盘边界断言的配置计数。
> golden 生成与视觉审查在 T22.a/T22.b（本矩阵不含视觉结论）。

## 配置空间

2 视口（360×800 / 1280×800）× 2 亮度 × 2 缩放（1/2）× 2 平台（iOS/Android）= **16 配置**

## 执行计数（C-T22-1 实测）

| 配置 | 状态 |
|---|---|
| p1_360x800_dark_scale1_ios | executed |
| p1_360x800_dark_scale1_android | executed |
| p1_360x800_dark_scale2_ios | executed |
| p1_360x800_dark_scale2_android | executed |
| p1_360x800_light_scale1_ios | executed |
| p1_360x800_light_scale1_android | executed |
| p1_360x800_light_scale2_ios | executed |
| p1_360x800_light_scale2_android | executed |
| p1_1280x800_dark_scale1_ios | executed |
| p1_1280x800_dark_scale1_android | executed |
| p1_1280x800_dark_scale2_ios | executed |
| p1_1280x800_dark_scale2_android | executed |
| p1_1280x800_light_scale1_ios | executed |
| p1_1280x800_light_scale1_android | executed |
| p1_1280x800_light_scale2_ios | executed |
| p1_1280x800_light_scale2_android | executed |

**expected=16，executed=16，skipped=0**（每配置断言：身份标题唯一、HeaderBar 在位、首条内容渲染、无渲染异常）

## 专项断言

| 断言 | 覆盖 |
|---|---|
| p1_semantics_labels_and_targets_valid | 管理动作语义存在（AppBar 菜单 + HeaderBar 圈钮）、命中区有效 |
| p1_text_and_enabled_icon_contrast_valid | 亮/暗 × 2 视口：可用动作图标对 surface 对比度 ≥3:1 |
| p1_short_viewport_keyboard_focus_reachable | 360×480 矮视口 ensureVisible 后动作中心在视口内 |

## 局限登记

- 无确定性 CJK 字体下的矩阵为结构级（STRUCTURE_ONLY）；精确文字几何由 T22.a/b 的 golden（GOLDEN_ENV 冻结字体）承担。
- 键盘真实弹出为设备依赖（manual_steps），自动化以矮视口几何可达为界。
