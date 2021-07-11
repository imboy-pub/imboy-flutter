import 'package:flutter/material.dart';
import 'package:imboy/component/widget/login/text_field_container.dart';

class RoundedInputField extends StatelessWidget {
  final String hintText;
  final IconData icon;
  final ValueChanged<String> onChanged;
  const RoundedInputField({
    Key key,
    this.hintText,
    this.icon,
    this.onChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return TextFieldContainer(
      child: TextField(
        onChanged: onChanged,
        decoration: InputDecoration(
          icon: Icon(icon, color: Theme.of(context).primaryColor),
          hintText: hintText,
          border: InputBorder.none,
        ),
      ),
    );
  }
}
