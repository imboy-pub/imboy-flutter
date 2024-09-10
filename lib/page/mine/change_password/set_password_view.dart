import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';
import 'package:imboy/page/bottom_navigation/bottom_navigation_view.dart';
import 'package:niku/namespace.dart' as n;

import 'package:imboy/component/helper/func.dart';
import 'package:imboy/component/ui/button.dart';
import 'package:imboy/component/ui/password.dart';

import 'package:imboy/component/ui/common_bar.dart';

import 'change_password_logic.dart';

class SetPasswordPage extends StatelessWidget {
  final logic = Get.put(ChangePasswordLogic());
  final state = Get.find<ChangePasswordLogic>().state;

  SetPasswordPage({super.key});

  @override
  Widget build(BuildContext context) {
    double width = MediaQuery.of(context).size.width;
    double bottomPadding = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      appBar: NavAppBar(
        automaticallyImplyLeading: true,
        title: 'set_param'.trArgs(['password'.tr]),
      ),
      body: SingleChildScrollView(
        child: n.Column([
          n.Padding(
            top: 10,
            left: 16,
            right: 16,
            child: n.Row([
              Expanded(
                child: Text(
                  '为了提升账号安全，同时防止因无法获取验证码导致无法登录，请设置登录密码。'.tr,
                ),
              ),
            ]),
          ),
          n.Padding(
            top: 10,
            left: 16,
            right: 16,
            bottom: 10,
            child: n.Row([
              Expanded(
                child: Text(
                  'error_length_between'.trArgs([
                    'password'.tr,
                    '4',
                    '32',
                  ]),
                ),
              ),
            ]),
          ),
          n.Column([
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 0.0,
                vertical: 8.0,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.all(Radius.circular(5)),
              ),
              child: Obx(() => PasswordTextField(
                    obscureText: state.newPwdObscure.value,
                    hintText: 'please_input_param'.trArgs(['password'.tr]),
                    onTap: () {
                      state.newPwdObscure.value = !state.newPwdObscure.value;
                    },
                    onChanged: (String? val) {
                      if (strNoEmpty(val)) {
                        state.newPwd.value = val!.trim();
                      }
                    },
                  )),
            ),
            const SizedBox(
              height: 10,
            ),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 0.0,
                vertical: 8.0,
              ),
              decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.all(Radius.circular(5))),
              child: Obx(() => PasswordTextField(
                    obscureText: state.retypePwdObscure.value,
                    hintText: 'retype_password'.tr,
                    onTap: () {
                      state.retypePwdObscure.value =
                          !state.retypePwdObscure.value;
                    },
                    onChanged: (String? val) {
                      if (strNoEmpty(val)) {
                        state.retypePwd.value = val!.trim();
                      }
                    },
                  )),
            ),
          ])
            ..crossAxisAlignment = CrossAxisAlignment.start,
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 8.0,
                bottom: bottomPadding != 20 ? 20 : bottomPadding,
              ),
              width: width,
              child: RoundedElevatedButton(
                text: 'button_confirm'.tr,
                onPressed: () async {
                  bool res = await logic.setPassword(
                    newPwd: state.newPwd.value,
                    rePwd: state.retypePwd.value,
                  );
                  if (res) {
                    EasyLoading.showSuccess('confirm_recover_success'.tr);
                    Get.off(() => BottomNavigationPage());
                  }
                },
                highlighted: true,
                size: Size(Get.width - 20, 58),
                borderRadius: BorderRadius.circular(6.0), // 设置圆角大小
              ),
            ),
          ),
        ])
          ..mainAxisAlignment = MainAxisAlignment.spaceBetween,
      ),
    );
  }
}
