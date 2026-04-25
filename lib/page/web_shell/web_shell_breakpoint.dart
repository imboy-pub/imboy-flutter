/// Web 端响应式布局断点决策（纯函数）
///
/// - `<900px` → `mobile`：直接渲染 BottomNavigationPage（移动端入口复用）
/// - `900-1200px` → `twoColumn`：左 NavigationRail + 中右合并的列表→详情导航
/// - `>=1200px` → `threeColumn`：完整三栏壳（nav rail + 中间列表 + 右侧主内容）
///
/// 设计原则：
/// - 显式枚举三档，断点固定（900 / 1200），不引入连续插值
/// - 入参为 BuildContext 派生的 width 值，由调用方负责取值（保持纯函数无副作用）
/// - 边界值采用左闭右开分段：900.0 走 twoColumn，1200.0 走 threeColumn
library;

/// Web Shell 布局类型枚举。
///
/// 顺序按宽度递增排列，便于 UI 层做条件渲染。
enum WebShellLayout {
  /// 移动端布局：直接复用 BottomNavigationPage（< 900px）
  mobile,

  /// 双栏布局：左 NavigationRail + 列表/详情合并面板（900-1200px）
  twoColumn,

  /// 三栏布局：左 nav rail + 中间列表 + 右侧主内容（>= 1200px）
  threeColumn,
}

/// 根据可用宽度解析当前应使用的 Web Shell 布局
///
/// 使用左闭右开分段：
/// - `width < 900` → mobile
/// - `900 <= width < 1200` → twoColumn
/// - `width >= 1200` → threeColumn
///
/// 调用方负责传入合法宽度（>= 0）；负数会被归入 mobile 分支（安全默认）。
WebShellLayout resolveShellLayout(double width) {
  if (width < 900) return WebShellLayout.mobile;
  if (width < 1200) return WebShellLayout.twoColumn;
  return WebShellLayout.threeColumn;
}
