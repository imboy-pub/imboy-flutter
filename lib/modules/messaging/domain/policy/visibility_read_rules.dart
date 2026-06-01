/// 可视阈值已读参数归一化 —— 纯函数（零外部依赖）
///
/// slice-C-5: `build` 方法内 L2110-2119 的 IIFE 把 `UserSetting` 字段
/// `visibilityReadFraction` / `visibilityReadDelayMs` 归一化为安全值，
/// 内含三类边界（NaN / 超范围 / 零负数）和四个魔法常数。
/// 提取后注入原始字段值，可独立单测钉死所有边界契约。
library;

/// 将 `UserSetting.visibilityReadFraction` 归一化到 `[0.1, 1.0]`。
///
/// - NaN（未初始化 / 损坏配置）→ 0.6（默认 60% 可视即触发）
/// - < 0.1 / 负数 / 负无穷    → 0.1（最小有意义阈值）
/// - > 1.0 / 正无穷           → 1.0（完全可见才触发）
/// - [0.1, 1.0]               → 原值（用户自定义范围内直接使用）
double normalizeVisibilityFraction(double v) {
  if (v.isNaN) return 0.6;
  if (v < 0.1) return 0.1;
  if (v > 1.0) return 1.0;
  return v;
}

/// 将 `UserSetting.visibilityReadDelayMs` 归一化为正整数延迟毫秒数。
///
/// - <= 0（零 / 负数 / 未配置）→ 400ms（经验默认：避免快速滑动误触发）
/// - > 0                       → 原值
int normalizeVisibilityDelayMs(int raw) => raw <= 0 ? 400 : raw;
