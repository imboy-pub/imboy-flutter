import 'package:flutter/material.dart';

// https://stackoverflow.com/questions/52111853/how-to-add-a-password-input-type-in-flutter-makes-the-password-user-input-is-not
// ignore: must_be_immutable
class PasswordTextField extends StatelessWidget {
  /// {@macro flutter.widgets.editableText.obscureText}
  final bool obscureText;
  final String? hintText;
  final TextStyle? style;
  final TextStyle? hintStyle;
  final Color? cursorColor;
  final Color? iconColor;

  final GestureTapCallback? onTap;
  final ValueChanged<String>? onChanged;

  const PasswordTextField({
    super.key,
    this.onTap,
    this.onChanged,
    this.hintText,
    this.obscureText = false,
    this.style,
    this.hintStyle,
    this.cursorColor,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    // Default colors if not provided
    final effectiveIconColor = iconColor ?? Colors.grey.shade600;

    return ClipRRect(
      borderRadius: BorderRadius.circular(11), // 与外层容器圆角匹配
      child: TextField(
        obscureText: obscureText,
        enableSuggestions: false,
        autocorrect: false,
        // TextField 垂直居中光标
        textAlignVertical: TextAlignVertical.center,
        style: style,
        cursorColor: cursorColor,
        decoration: InputDecoration(
          border: InputBorder.none,
          focusedBorder: InputBorder.none,
          enabledBorder: InputBorder.none,
          hintText: hintText,
          hintStyle:
              hintStyle ?? TextStyle(color: Colors.grey.shade600, fontSize: 16),
          prefixIcon: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Icon(
              Icons.lock_rounded, // Rounded icon
              color: effectiveIconColor,
              size: 22,
            ),
          ),
          prefixIconConstraints: const BoxConstraints(
            minWidth: 44,
            minHeight: 44,
          ),
          suffixIcon: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(20),
              child: Icon(
                obscureText
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
                color: effectiveIconColor,
                size: 22,
              ),
            ),
          ),
          suffixIconConstraints: const BoxConstraints(
            minWidth: 44,
            minHeight: 44,
          ),
          contentPadding: const EdgeInsets.symmetric(
            vertical: 16,
            horizontal: 16,
          ),
        ),
        onChanged: onChanged,
      ),
    );
  }
}
