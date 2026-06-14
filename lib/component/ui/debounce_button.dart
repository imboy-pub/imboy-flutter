import 'package:flutter/material.dart';
import 'package:imboy/theme/default/app_spacing.dart';

/// 防抖按钮组件
///
/// 自动处理按钮点击防抖，防止重复提交
///
/// 使用示例：
/// ```dart
/// DebounceButton(
///   text: '登录',
///   onPressed: () async {
///     await login();
///   },
/// )
/// ```
class DebounceButton extends StatefulWidget {
  /// 按钮文本
  final String text;

  /// 点击回调
  final Future<void> Function() onPressed;

  /// 按钮样式
  final ButtonStyle? style;

  /// 是否禁用（外部控制）
  final bool disabled;

  /// 加载指示器颜色
  final Color? loadingColor;

  /// 按钮宽度
  final double? width;

  /// 按钮高度
  final double? height;

  /// 文本样式
  final TextStyle? textStyle;

  const DebounceButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.style,
    this.disabled = false,
    this.loadingColor,
    this.width,
    this.height,
    this.textStyle,
  });

  @override
  State<DebounceButton> createState() => _DebounceButtonState();
}

class _DebounceButtonState extends State<DebounceButton> {
  bool _isSubmitting = false;

  Future<void> _handlePress() async {
    if (_isSubmitting) return;

    setState(() => _isSubmitting = true);

    try {
      await widget.onPressed();
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDisabled = widget.disabled || _isSubmitting;

    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: ElevatedButton(
        style: widget.style,
        onPressed: isDisabled ? null : _handlePress,
        child: _isSubmitting
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    widget.loadingColor ?? Colors.white,
                  ),
                ),
              )
            : Text(widget.text, style: widget.textStyle),
      ),
    );
  }
}

/// 防抖文本按钮组件
class DebounceTextButton extends StatelessWidget {
  /// 按钮文本
  final String text;

  /// 点击回调
  final Future<void> Function() onPressed;

  /// 按钮样式
  final TextStyle? style;

  /// 是否禁用（外部控制）
  final bool disabled;

  const DebounceTextButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.style,
    this.disabled = false,
  });

  @override
  Widget build(BuildContext context) {
    return DebounceButton(
      text: text,
      onPressed: onPressed,
      disabled: disabled,
      width: null,
      height: null,
      textStyle: style,
    );
  }
}

/// 防抖图标按钮组件
class DebounceIconButton extends StatefulWidget {
  /// 图标
  final IconData icon;

  /// 图标大小
  final double? iconSize;

  /// 点击回调
  final Future<void> Function() onPressed;

  /// 按钮样式
  final ButtonStyle? style;

  /// 是否禁用（外部控制）
  final bool disabled;

  /// 加载指示器大小
  final double? loadingSize;

  const DebounceIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.iconSize,
    this.style,
    this.disabled = false,
    this.loadingSize,
  });

  @override
  State<DebounceIconButton> createState() => _DebounceIconButtonState();
}

class _DebounceIconButtonState extends State<DebounceIconButton> {
  bool _isSubmitting = false;

  Future<void> _handlePress() async {
    if (_isSubmitting) return;

    setState(() => _isSubmitting = true);

    try {
      await widget.onPressed();
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDisabled = widget.disabled || _isSubmitting;

    return IconButton(
      icon: _isSubmitting
          ? SizedBox(
              width: widget.loadingSize ?? widget.iconSize ?? 24,
              height: widget.loadingSize ?? widget.iconSize ?? 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(
                  widget.style?.foregroundColor?.resolve({}) ?? Colors.white,
                ),
              ),
            )
          : Icon(widget.icon, size: widget.iconSize),
      style: widget.style,
      onPressed: isDisabled ? null : _handlePress,
    );
  }
}

/// 防抖浮动操作按钮组件
class DebounceFloatingActionButton extends StatefulWidget {
  /// 子组件
  final Widget child;

  /// 点击回调
  final Future<void> Function() onPressed;

  /// 其他 FAB 参数
  final Object? heroTag;
  final ShapeBorder? shape;
  final Clip clipBehavior;
  final bool isExtended;
  final MaterialTapTargetSize? materialTapTargetSize;
  final bool? enableFeedback;

  const DebounceFloatingActionButton({
    super.key,
    required this.child,
    required this.onPressed,
    this.heroTag,
    this.shape,
    this.clipBehavior = Clip.none,
    this.isExtended = false,
    this.materialTapTargetSize,
    this.enableFeedback,
  });

  @override
  State<DebounceFloatingActionButton> createState() =>
      _DebounceFloatingActionButtonState();
}

class _DebounceFloatingActionButtonState
    extends State<DebounceFloatingActionButton> {
  bool _isSubmitting = false;

  Future<void> _handlePress() async {
    if (_isSubmitting) return;

    setState(() => _isSubmitting = true);

    try {
      await widget.onPressed();
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      heroTag: widget.heroTag,
      onPressed: _isSubmitting ? null : _handlePress,
      shape: widget.shape,
      clipBehavior: widget.clipBehavior,
      isExtended: widget.isExtended,
      materialTapTargetSize: widget.materialTapTargetSize,
      enableFeedback: widget.enableFeedback,
      child: _isSubmitting
          ? Padding(
              padding: const EdgeInsets.all(AppSpacing.regular),
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(
                  Theme.of(context).colorScheme.onPrimary,
                ),
              ),
            )
          : widget.child,
    );
  }
}
