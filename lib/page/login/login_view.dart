import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:imboy/component/login/body.dart';

import 'login_logic.dart';
import 'login_state.dart';

class LoginPage extends GetWidget {
  final LoginLogic logic = Get.put(LoginLogic());
  final LoginState state = Get.find<LoginLogic>().state;

  @override
  Widget build(BuildContext context) {
    return GetBuilder<LoginLogic>(
      builder: (logic) => Scaffold(
        body: GestureDetector(
          onTap: () {
            FocusScopeNode currentFocus = FocusScope.of(context);
            if (!currentFocus.hasPrimaryFocus &&
                currentFocus.focusedChild != null) {
              FocusManager.instance.primaryFocus.unfocus();
            }
          },
          child: Body(),
        ),
      ),
    );
  }
}
