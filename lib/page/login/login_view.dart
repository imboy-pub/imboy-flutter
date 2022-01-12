import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:imboy/component/widget/login/alread_have_an_account_check.dart';
import 'package:imboy/component/widget/login/or_divider.dart';
import 'package:imboy/component/widget/login/rounded_button.dart';
import 'package:imboy/component/widget/login/rounded_input_field.dart';
import 'package:imboy/component/widget/login/rounded_password_field.dart';
import 'package:imboy/config/init.dart';
import 'package:imboy/config/routes.dart';

import 'login_logic.dart';
import 'login_state.dart';

class LoginPage extends GetWidget {
  final LoginLogic logic = Get.put(LoginLogic());
  final LoginState state = Get.find<LoginLogic>().state;

  @override
  Widget build(BuildContext context) {
    init();
    return GetBuilder<LoginLogic>(
      builder: (logic) => Scaffold(
        body: GestureDetector(
          onTap: () {
            FocusScopeNode currentFocus = FocusScope.of(context);
            if (!currentFocus.hasPrimaryFocus &&
                currentFocus.focusedChild != null) {
              FocusManager.instance.primaryFocus!.unfocus();
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
            padding: EdgeInsets.fromLTRB(32.0, 32.0, 0.0, 0.0),
            child: Text(
              'tip_greeting'.tr,
              style: TextStyle(
                color: Theme.of(context).primaryColor,
                fontWeight: FontWeight.bold,
                fontSize: 32,
              ),
            ),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: EdgeInsets.fromLTRB(32.0, 10.0, 0.0, 0.0),
                child: Text('IMBoy',
                    style: Theme.of(context).textTheme.headline2!.copyWith(
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
            height: 20,
          ),
          RoundedInputField(
            hintText: 'tip_account'.tr,
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
            text: 'button_login'.tr,
            color: Theme.of(context).primaryColor,
            onPressed: controller.submit,
          ),
          SizedBox(
            height: 12,
          ),
          AlreadHaveAnAccountCheck(
            login: true,
            onTap: () => Get.toNamed(AppRoutes.SIGN_UP),
          ),
          SizedBox(
            height: 24,
          ),
          OrDivider(),
          SizedBox(
            height: 24,
          ),
          RoundedButton(
            text: 'button_sign_in'.tr,
            onPressed: () => Get.offNamed(AppRoutes.SIGN_IN),
          ),
        ],
      ),
    );
  }
}
