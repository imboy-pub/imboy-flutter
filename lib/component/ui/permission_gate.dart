import 'package:flutter/widgets.dart';

/// 权限不足时对动作入口的降级策略（ENT-FND-02）。
enum PermissionGateBehavior {
  /// 直接不渲染（默认）：治理类危险动作（删除/归档/移除成员等）入口
  /// 对无权者隐藏，避免"点了才 403"的挫败路径。
  hide,

  /// 渲染但禁用：入口需可见以传达功能存在（如邀请、部门管理），
  /// 仅阻断交互。视觉降为半透明，不改动子树颜色 token。
  disable,
}

/// 权限门渲染组件：按页面注入的判定回调决定动作入口的可见/可用性。
///
/// 定位与边界（ENT-FND-02）：
/// - 只做**渲染降级**（隐藏/禁用），不是授权机制——服务端 403 仍是
///   唯一裁决（与 `Organization.governanceActionsAvailable` 的既定口径
///   一致：客户端预隐藏入口只是体验优化）；
/// - 判定回调 [check] 由页面注入（如读 member_role / 上一响应携带的
///   权限投影），本组件不感知任何业务模型、不解析错误字符串；
/// - denied 时若需提示文案，通过 [deniedReplacement] 注入页面侧
///   组装好的占位（文案请走 i18n / FontSizeType token）。
class PermissionGate extends StatelessWidget {
  const PermissionGate({
    super.key,
    required this.check,
    required this.child,
    this.behavior = PermissionGateBehavior.hide,
    this.deniedReplacement,
    this.disabledOpacity = 0.4,
  });

  /// 权限判定回调，build 时求值一次。返回 true 放行 [child]。
  final bool Function() check;

  /// 权限通过或 [PermissionGateBehavior.disable] 时渲染的内容。
  final Widget child;

  /// 降级策略，见 [PermissionGateBehavior]。
  final PermissionGateBehavior behavior;

  /// hide 策略下权限不足时的占位。null = `SizedBox.shrink()`（纯隐藏）。
  final Widget? deniedReplacement;

  /// disable 策略的降透明度。只影响可读性层级，不引入新颜色 token。
  final double disabledOpacity;

  @override
  Widget build(BuildContext context) {
    final allowed = check();
    if (allowed) {
      return child;
    }
    switch (behavior) {
      case PermissionGateBehavior.hide:
        return deniedReplacement ?? const SizedBox.shrink();
      case PermissionGateBehavior.disable:
        // IgnorePointer 阻断命中测试；Semantics(enabled:false) 同步告知
        // 无障碍层该入口不可用，避免读屏用户听到可点却无响应。
        return Semantics(
          enabled: false,
          button: false,
          child: IgnorePointer(
            child: Opacity(opacity: disabledOpacity, child: child),
          ),
        );
    }
  }
}
