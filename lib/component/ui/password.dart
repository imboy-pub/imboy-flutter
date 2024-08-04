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
    return TextField(
      obscureText: obscureText,
      enableSuggestions: false,
      autocorrect: false,
      decoration: InputDecoration(
        border: InputBorder.none,
        hintText: hintText,
        hintStyle: const TextStyle(fontSize: 14.0),
        prefixIcon: const Icon(Icons.lock),
        suffixIcon: InkWell(
          onTap: onTap,
          child: obscureText
              ? const Icon(Icons.visibility)
              : const Icon(Icons.visibility_off),
        ),
      ),
      onChanged: onChanged,
    );
  }
}
