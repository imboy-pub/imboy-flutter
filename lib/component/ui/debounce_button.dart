import 'package:flutter/cupertino.dart';

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
      child: CupertinoButton.filled(
        onPressed: isDisabled ? null : _handlePress,
        child: _isSubmitting
            ? SizedBox(
                width: 20,
                height: 20,
                child: CupertinoActivityIndicator(
                  color: widget.loadingColor ?? CupertinoColors.white,
                ),
              )
            : Text(widget.text, style: widget.textStyle),
      ),
    );
  }
}
