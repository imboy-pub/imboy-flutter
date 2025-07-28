import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';
import 'package:imboy/page/passport/login_view.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/component/ui/button.dart';
import 'package:imboy/component/ui/password.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:imboy/component/ui/common_bar.dart';
import 'change_password_logic.dart';

class ChangePasswordPage extends StatelessWidget {
  final logic = Get.put(ChangePasswordLogic());
  final state = Get.find<ChangePasswordLogic>().state;

  ChangePasswordPage({super.key});

  @override
  Widget build(BuildContext context) {
    double width = MediaQuery.of(context).size.width;
    double bottomPadding = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      appBar: NavAppBar(
        automaticallyImplyLeading: true,
        title: 'change_param'.trArgs(['password'.tr]),
      ),
      body: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const SizedBox(
              height: 20,
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(
                    left: 24,
                    bottom: 12.0,
                  ),
                  child: Text(
                    'existing_password'.tr,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
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
                    obscureText: state.existingPwdObscure.value,
                    hintText: 'Existing Password'.tr,
                    onTap: () {
                      state.existingPwdObscure.value =
                      !state.existingPwdObscure.value;
                    },
                    onChanged: (String? val) {
                      if (strNoEmpty(val)) {
                        state.existingPwd.value = val!.trim();
                      }
                    },
                  )),
                ),
                Padding(
                  padding: const EdgeInsets.only(
                    left: 24,
                    top: 24,
                    bottom: 12.0,
                  ),
                  child: Text(
                    'new_password'.tr,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
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
                Padding(
                  padding: const EdgeInsets.only(
                    left: 24,
                    top: 24,
                    bottom: 12.0,
                  ),
                  child: Text(
                    'retype_password'.tr,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
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
              ],
            ),
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
                    bool res = await logic.changePassword(
                      newPwd: state.newPwd.value,
                      rePwd: state.retypePwd.value,
                      existingPwd: state.existingPwd.value,
                    );
                    if (res) {
                      EasyLoading.showSuccess('confirm_recover_success'.tr);
                      UserRepoLocal.to.quitLogin();
                      Get.offAll(() => const LoginPage());
                    }
                  },
                  highlighted: true,
                  size: Size(Get.width - 20, 58),
                  borderRadius: BorderRadius.circular(6.0), // 设置圆角大小
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}