import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:imboy/component/widget/login/alread_have_an_account_check.dart';
import 'package:imboy/component/widget/login/or_divider.dart';
import 'package:imboy/component/widget/login/rounded_button.dart';
import 'package:imboy/component/widget/login/rounded_input_field.dart';
import 'package:imboy/component/widget/login/rounded_password_field.dart';
import 'package:imboy/helper/constant.dart';

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

class Body extends GetView<LoginLogic> {
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: Get.width,
            padding: EdgeInsets.fromLTRB(15.0, 115.0, 0.0, 0.0),
            child: Text('欢迎使用',
                style: Theme.of(context).textTheme.headline2.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).primaryColor,
                    )),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: EdgeInsets.fromLTRB(15.0, 15.0, 0.0, 0.0),
                child: Text('IMBoy',
                    style: Theme.of(context).textTheme.headline2.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).primaryColor,
                        )),
              ),
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  image: new DecorationImage(
                    image: new AssetImage('assets/images/logo.png'),
                  ),
                ),
              )
            ],
          ),
          SizedBox(
            height: 60,
          ),
          RoundedInputField(
            hintText: '账号/邮箱/手机号',
            icon: Icons.person,
            onChanged: controller.onUsernameChanged,
          ),
          RoundedPasswordField(
            onChanged: controller.onPasswordChanged,
          ),
          SizedBox(
            height: 8,
          ),
          RoundedButton(
            text: '登录',
            color: Theme.of(context).primaryColor,
            onPressed: controller.submit,
          ),
          SizedBox(
            height: 12,
          ),
          AlreadHaveAnAccountCheck(
            login: true,
            onTap: () => Get.toNamed(Routes.SIGN_UP),
          ),
          SizedBox(
            height: 24,
          ),
          OrDivider(),
          SizedBox(
            height: 24,
          ),
          RoundedButton(
            text: 'SKIP SIGN',
            onPressed: () => Get.offNamed(Routes.Home),
          ),
        ],
      ),
    );
  }
}
