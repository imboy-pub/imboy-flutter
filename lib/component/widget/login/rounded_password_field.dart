import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:imboy/component/widget/login/text_field_container.dart';
import 'package:imboy/page/login/login_logic.dart';

class RoundedPasswordField extends StatelessWidget {
  final ValueChanged<String> onChanged;
  const RoundedPasswordField({
    Key? key,
    required this.onChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final LoginLogic logic = Get.find();

    return TextFieldContainer(
      child: TextField(
        // controller: new TextEditingController(text: 'admin888'),
        onChanged: onChanged,
        obscureText: !logic.passwordVisible,
        decoration: InputDecoration(
          hintText: '密码',
          icon: Icon(
            Icons.lock,
            color: Theme.of(context).primaryColor,
          ),
          suffixIcon: IconButton(
            icon: Icon(
              logic.passwordVisible ? Icons.visibility : Icons.visibility_off,
              color: Theme.of(context).primaryColor,
            ),
            onPressed: () {
              print(logic.passwordVisible.toString());
              logic.visibilityOnOff();
            },
          ),
          border: InputBorder.none,
        ),
      ),
    );
  }
}
