import 'package:flutter/material.dart';

// https://stackoverflow.com/questions/52111853/how-to-add-a-password-input-type-in-flutter-makes-the-password-user-input-is-not
// ignore: must_be_immutable
class PasswordTextField extends StatelessWidget {
  /// {@macro flutter.widgets.editableText.obscureText}
  final bool obscureText;
  final String? hintText;

  final GestureTapCallback? onTap;
  final ValueChanged<String>? onChanged;

  const PasswordTextField({
    super.key,
    this.onTap,
    this.onChanged,
    this.hintText,
    this.obscureText = false,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(11), // 与外层容器圆角匹配
      child: TextField(
        obscureText: obscureText,
        enableSuggestions: false,
        autocorrect: false,
        // TextField 垂直居中光标
        textAlignVertical: TextAlignVertical.center,
        decoration: InputDecoration(
          border: InputBorder.none,
          focusedBorder: InputBorder.none,
          enabledBorder: InputBorder.none,
          hintText: hintText,
          hintStyle: TextStyle(
            color: Colors.grey.shade600,
            fontSize: 16,
          ),
          prefixIcon: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Icon(
              Icons.lock,
              color: Colors.grey.shade600,
              size: 20,
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
                obscureText ? Icons.visibility : Icons.visibility_off,
                color: Colors.grey.shade600,
                size: 20,
              ),
            ),
          ),
          suffixIconConstraints: const BoxConstraints(
            minWidth: 44,
            minHeight: 44,
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        ),
        onChanged: onChanged,
      ),
    );
  }
}
