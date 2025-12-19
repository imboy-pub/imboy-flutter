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

/// 修改密码页面
class ChangePasswordPage extends StatelessWidget {
  final logic = Get.put(ChangePasswordLogic());
  final state = Get.find<ChangePasswordLogic>().state;

  ChangePasswordPage({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    double bottomPadding = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      appBar: NavAppBar(
        automaticallyImplyLeading: true,
        title: 'changeParam'.trArgs(['password'.tr]),
      ),
      backgroundColor: colorScheme.surface,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            
            // 安全提示卡片
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      colorScheme.primary.withAlpha(25),
                      colorScheme.primary.withAlpha(10),
                    ],
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: colorScheme.primary.withAlpha(51),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.security,
                        color: colorScheme.primary,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '密码安全提示',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '为了您的账户安全，请设置复杂密码',
                            style: TextStyle(
                              fontSize: 14,
                              color: colorScheme.onSurface.withAlpha(179),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // 密码修改表单卡片
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Container(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 原密码输入
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: colorScheme.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: colorScheme.outline.withAlpha(51),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.lock_outline,
                                color: colorScheme.primary,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'existingPassword'.tr,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: colorScheme.onSurface,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Obx(() => PasswordTextField(
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
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // 新密码输入
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: colorScheme.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: colorScheme.outline.withAlpha(51),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.lock_reset,
                                color: colorScheme.primary,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'newPassword'.tr,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: colorScheme.onSurface,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Obx(() => PasswordTextField(
                            obscureText: state.newPwdObscure.value,
                            hintText: 'pleaseInputParam'.trArgs(['password'.tr]),
                            onTap: () {
                              state.newPwdObscure.value = !state.newPwdObscure.value;
                            },
                            onChanged: (String? val) {
                              if (strNoEmpty(val)) {
                                state.newPwd.value = val!.trim();
                              }
                            },
                          )),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // 确认密码输入
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: colorScheme.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: colorScheme.outline.withAlpha(51),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.lock_clock,
                                color: colorScheme.primary,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'retypePassword'.tr,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: colorScheme.onSurface,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Obx(() => PasswordTextField(
                            obscureText: state.retypePwdObscure.value,
                            hintText: 'retypePassword'.tr,
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
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 32),
            
            // 确认按钮
            Container(
              padding: EdgeInsets.only(
                bottom: bottomPadding != 20 ? 20 : bottomPadding,
              ),
              width: double.infinity,
              child: RoundedElevatedButton(
                text: 'buttonConfirm'.tr,
                onPressed: () async {
                  bool res = await logic.changePassword(
                    newPwd: state.newPwd.value,
                    rePwd: state.retypePwd.value,
                    existingPwd: state.existingPwd.value,
                  );
                  if (res) {
                    EasyLoading.showSuccess('confirmRecoverSuccess'.tr);
                    UserRepoLocal.to.quitLogin();
                    Get.offAll(() => const LoginPage());
                  }
                },
                highlighted: true,
                size: Size(Get.width - 32, 58),
                borderRadius: BorderRadius.circular(12.0),
              ),
            ),
          ],
        ),
      ),
    );
  }
}