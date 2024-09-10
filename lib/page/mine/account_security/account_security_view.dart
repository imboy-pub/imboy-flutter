import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/component/ui/button.dart';
import 'package:imboy/component/web_view.dart';
import 'package:imboy/page/mine/change_password/change_password_view.dart';
import 'package:imboy/page/mine/change_password/set_password_view.dart';
import 'package:imboy/page/mine/logout_account/logout_account_view.dart';
import 'package:imboy/page/mine/user_device/user_device_view.dart';
import 'package:imboy/page/passport/welcome_view.dart';
import 'package:imboy/page/personal_info/update/update_view.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:niku/namespace.dart' as n;

import 'package:imboy/component/ui/line.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/component/ui/common_bar.dart';

import 'account_security_logic.dart';

class AccountSecurityPage extends StatelessWidget {
  AccountSecurityPage({super.key});

  final logic = Get.put(AccountSecurityLogic());

  @override
  Widget build(BuildContext context) {
    bool needSet = StorageService.to.getBool(Keys.needSetPwd) ?? false;
    return Scaffold(
      appBar: NavAppBar(
        automaticallyImplyLeading: true,
        title: 'account_security'.tr,
      ),
      body: SingleChildScrollView(
        child: n.Column([
          n.Column([
            n.ListTile(
              title: n.Row([
                Text('account'.tr),
                n.Padding(
                  right: 12,
                  child: Text(UserRepoLocal.to.current.account),
                ),
              ])
                // 两端对齐
                ..mainAxisAlignment = MainAxisAlignment.spaceBetween,
              // trailing: navigateNextIcon,
              onTap: () {
                // Get.to(
                //       () => const AccountSecurityPage(),
                //   transition: Transition.rightToLeft,
                //   popGesture: true, // 右滑，返回上一页
                // );
              },
            ),
            n.Padding(
                left: 18,
                child: HorizontalLine(
                  height: Get.isDarkMode ? 0.5 : 1.0,
                  color: Theme.of(context).colorScheme.primary,
                )),
            n.ListTile(
              title: n.Row([
                Text('email'.tr),
                Text(UserRepoLocal.to.current.email.isEmpty
                    ? 'not_bound'.tr
                    : UserRepoLocal.to.current.email.replaceRange(
                        4,
                        UserRepoLocal.to.current.email.length - 8,
                        '*' * (UserRepoLocal.to.current.email.length - 12),
                      )),
              ])
                // 两端对齐
                ..mainAxisAlignment = MainAxisAlignment.spaceBetween,
              trailing: navigateNextIcon,
              onTap: () {
                Get.to(
                  () => UpdatePage(
                      title: 'set_param'.trArgs(['email'.tr]),
                      value: UserRepoLocal.to.current.email,
                      field: 'input',
                      callback: (val) async {
                        iPrint("set_param val $val");
                        if (isEmail(val) == false) {
                          EasyLoading.showError(
                            'error_invalid'.trArgs(['email'.tr]),
                          );
                          return false;
                        }
                        bool res = await logic.changeEmail(val);
                        if (res) {
                          EasyLoading.showSuccess(
                            '一封验证邮件已发送至leevisoft@icloud.com，请登录你的邮箱查收并通过邮件验证。'
                                .tr,
                            duration: const Duration(seconds: 30),
                            dismissOnTap: true,
                          );
                          return true;
                        }
                        return false;
                      }),
                  transition: Transition.rightToLeft,
                  popGesture: true, // 右滑，返回上一页,
                );
              },
            ),
            /*
            n.Padding(
                left: 18,
                child: HorizontalLine(
                  height: Get.isDarkMode ? 0.5 : 1.0,
                  color: Theme.of(context).colorScheme.primary,
                )),
            n.ListTile(
              title: n.Row([
                Text('mobile'.tr),
                Text(UserRepoLocal.to.current.mobile.isEmpty
                    ? 'not_bound'.tr
                    : UserRepoLocal.to.current.mobile.replaceRange(
                        3,
                        7,
                        '****',
                      )),
              ])
                // 两端对齐
                ..mainAxisAlignment = MainAxisAlignment.spaceBetween,
              trailing: navigateNextIcon,
              onTap: () {
                Get.to(
                  () => UpdatePage(
                      title: 'set_param'.trArgs(['mobile'.tr]),
                      value: UserRepoLocal.to.current.mobile,
                      field: 'input',
                      callback: (val) async {
                        if (isPhone(val) == false) {
                          EasyLoading.showError('param_format_error'.trArgs(['mobile'.tr]));
                          return false;
                        }
                        iPrint("set_param val $val");
                        return false;
                      }),
                  transition: Transition.rightToLeft,
                  popGesture: true, // 右滑，返回上一页,
                );
              },
            ),
            */
            HorizontalLine(
              height: 10,
              color: Theme.of(context).colorScheme.primary,
            ),
            n.ListTile(
              title: n.Row([
                Text('password'.tr),
                if (needSet == false) Text('have_set'.tr),
              ])
                // 两端对齐
                ..mainAxisAlignment = MainAxisAlignment.spaceBetween,
              trailing: navigateNextIcon,
              onTap: () {
                Get.to(
                  () => needSet == false
                      ? ChangePasswordPage()
                      : SetPasswordPage(),
                  transition: Transition.rightToLeft,
                  popGesture: true, // 右滑，返回上一页
                );
              },
            ),
            HorizontalLine(
              height: 10,
              color: Theme.of(context).colorScheme.primary,
            ),
            n.Padding(
                left: 40,
                child: HorizontalLine(
                  height: 1.0,
                  color: Theme.of(context).colorScheme.primary,
                )),
            n.ListTile(
              // leading: const Icon(
              //   Icons.devices,
              //   color: Colors.green,
              //   size: 22,
              // ),
              // title: Transform(
              //   transform: Matrix4.translationValues(-10, 0.0, 0.0),
              //   child: Text('device_list'.tr),
              // ),
              title: Text('device_list'.tr),
              trailing: navigateNextIcon,
              onTap: () {
                Get.to(
                  () => UserDevicePage(),
                  transition: Transition.rightToLeft,
                  popGesture: true, // 右滑，返回上一页
                );
              },
            ),
          ]),
          /*
          ButtonRow(
            margin: const EdgeInsets.only(
              top: 10.0,
            ),
            text: 'switch_account'.tr,
            style: const TextStyle(
              color: AppColors.ButtonTextColor,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
            isBorder: false,
            onPressed: () async {},
          ),
          */
          n.Padding(
              left: 18,
              child: HorizontalLine(
                height: Get.isDarkMode ? 0.5 : 1.0,
                color: Theme.of(context).colorScheme.primary,
              )),
          n.ListTile(
            title: Text('security_center'.tr),
            trailing: navigateNextIcon,
            onTap: () {
              Get.to(
                () => WebViewPage(
                  "https://weixin110.qq.com/security/newreadtemplate?t=w_security_center_website/newindex",
                  'security_center'.tr,
                ),
                transition: Transition.rightToLeft,
                popGesture: true, // 右滑，返回上一页
              );
            },
          ),
          HorizontalLine(
            height: 10,
            color: Theme.of(context).colorScheme.primary,
          ),
          ButtonRow(
            text: 'log_out'.tr,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onPrimary,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
            isBorder: false,
            onPressed: () async {
              bool result = await UserRepoLocal.to.quitLogin();
              if (result) {
                Get.offAll(() => const WelcomePage());
              }
            },
          ),
          HorizontalLine(
            height: 10,
            color: Theme.of(context).colorScheme.primary,
          ),
          ButtonRow(
            text: 'logout_account'.tr,
            style: const TextStyle(
              fontSize: 16,
            ),
            isBorder: false,
            onPressed: () async {
              Get.to(
                () => LogoutAccountPage(),
                transition: Transition.rightToLeft,
                popGesture: true, // 右滑，返回上一页
              );
            },
          ),
          HorizontalLine(
            height: 10,
            color: Theme.of(context).colorScheme.primary,
          ),
        ]),
      ),
    );
  }
}
