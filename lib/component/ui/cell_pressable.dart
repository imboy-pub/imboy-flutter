import 'package:flutter/material.dart';
import 'package:imboy/theme/default/app_colors.dart';

/// iOS 风格 Cell 按下反馈 widget
///
/// 替代 [Material] + [InkWell] 组合（DESIGN.md §6.4 Cell 禁用 Material Ripple）。
/// 按下瞬间 Cell 整行变 4-6% 灰色高亮，松开/取消立即恢复，
/// 与 iOS 系统 Cell 反馈节奏一致（无延迟动画）。
///
/// [onTap] / [onLongPress] 至少一个非 null 才响应触摸；
/// 两者皆为 null 时整行透明、不响应（用于只读 Cell）。
///
/// 使用示例：
/// ```dart
/// CellPressable(
///   onTap: () => Navigator.push(...),
///   onLongPress: () => _showActionSheet(...),
///   child: Container(
///     padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
///     child: Row(children: [...]),
///   ),
/// )
/// ```
///
/// 与 [Material]+[InkWell] 的核心差异：
///   - 无 ripple 扩散动画（iOS 是即时切换 surface 色，Material 是水波纹）
///   - 不需要 [Material] 包裹（不引入 Material 主题级联）
///   - 高亮色随系统亮度自适应（亮 4% black / 暗 6% white）
///   - 支持 [onLongPress]（GestureDetector 原生支持，[InkWell] 需要 onLongPress 单独传）
class CellPressable extends StatefulWidget {
  const CellPressable({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
  });

  final Widget child;
  final VoidCallback? onTap;

  /// 长按回调；触发时同样会展示按下高亮（与 [onTap] 共享 _pressed 状态）。
  /// 长按由 [GestureDetector] 经过 ~500ms 阈值后触发。
  final VoidCallback? onLongPress;

  @override
  State<CellPressable> createState() => _CellPressableState();
}

class _CellPressableState extends State<CellPressable> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final highlightColor = isDark
        ? Colors.white.withValues(alpha: 0.06)
        : Colors.black.withValues(alpha: 0.04);

    // GestureDetector 设计：onTapDown 只在 tap 类识别器注册（onTap/onTapUp/onTapCancel
    // 任意一个非 null）时生效；onLongPressDown 同理只在 long-press 类识别器注册
    // （onLongPress/onLongPressUp 等任意一个非 null）时生效。
    //
    // 因此本组件分两路触发按下高亮：
    //   - tap 路径：onTap 非 null → 通过 onTapDown/Up/Cancel 三件套
    //   - long-press 路径：onLongPress 非 null → 通过 onLongPressDown/Up/Cancel
    //
    // 两路在 GestureDetector arena 中各自独立工作；同时注册时按下立即由 onTapDown 高亮，
    // 松开后短按走 onTap，长按超阈值走 onLongPress。
    final hasTap = widget.onTap != null;
    final hasLongPress = widget.onLongPress != null;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      onTapDown: hasTap ? (_) => _setPressed(true) : null,
      onTapCancel: hasTap ? () => _setPressed(false) : null,
      onTapUp: hasTap ? (_) => _setPressed(false) : null,
      onLongPress: widget.onLongPress,
      onLongPressDown: hasLongPress ? (_) => _setPressed(true) : null,
      onLongPressCancel: hasLongPress ? () => _setPressed(false) : null,
      onLongPressUp: hasLongPress ? () => _setPressed(false) : null,
      child: ColoredBox(
        color: _pressed ? highlightColor : AppColors.transparent,
        child: widget.child,
      ),
    );
  }
}
