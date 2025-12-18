import 'package:flutter/material.dart';

class ActionButton extends StatefulWidget {
  final String? title;
  final String subTitle;
  final IconData? icon;
  final bool checked;
  final bool number;
  final Color? fillColor;
  final Function()? onPressed;
  final Function()? onLongPress;

  const ActionButton(
      {super.key,
      this.title,
      this.subTitle = '',
      this.icon,
      this.onPressed,
      this.onLongPress,
      this.checked = false,
      this.number = false,
      this.fillColor});

  @override
  // ignore: library_private_types_in_public_api
  _ActionButtonState createState() => _ActionButtonState();
}

class _ActionButtonState extends State<ActionButton> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: colorScheme.surface, // 应用主题表面颜色
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: colorScheme.outline.withValues(alpha: 0.1), // 应用主题边框颜色
            spreadRadius: 2,
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onPressed,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: 60,
            height: 60,
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  widget.icon!,
                  size: 24,
                  color: colorScheme.primary, // 应用主题主颜色
                ),
                const SizedBox(height: 4),
                Text(
                  widget.title ?? '',
                  style: TextStyle(
                    color: colorScheme.onSurface, // 应用主题文本颜色
                    fontSize: 12,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
