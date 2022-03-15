import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'text_field_container.dart';

class RoundedInputField extends StatelessWidget {
  final String? hintText;
  final IconData? icon;
  final ValueChanged<String>? onChanged;
  const RoundedInputField({
    Key? key,
    this.hintText,
    this.icon,
    this.onChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return TextFieldContainer(
      child: TextField(
        onChanged: onChanged,
        keyboardType: TextInputType.numberWithOptions(),
        decoration: InputDecoration(
          icon: Icon(icon, color: Theme.of(context).primaryColor),
          hintText: hintText,
          border: InputBorder.none,
        ),
      ),
    );
  }
}
