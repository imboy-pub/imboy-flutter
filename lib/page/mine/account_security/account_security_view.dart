import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/component/web_view.dart';
import 'package:imboy/page/mine/change_password/change_password_view.dart';
import 'package:imboy/page/mine/change_password/set_password_view.dart';
import 'package:imboy/page/mine/logout_account/logout_account_view.dart';
import 'package:imboy/page/passport/welcome_view.dart';
import 'package:imboy/page/personal_info/update/update_view.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:imboy/component/ui/line.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/font_types.dart';

import 'package:imboy/config/const.dart';
import 'package:imboy/component/ui/common_bar.dart';

import 'account_security_logic.dart';
import 'package:imboy/page/mine/account_security/bind_mobile_view.dart';

/// 账户安全页面
class AccountSecurityPage extends StatelessWidget {
  AccountSecurityPage({super.key});

  final logic = Get.put(AccountSecurityLogic());

  @override
  Widget build(BuildContext context) {
    bool needSet = StorageService.to.getBool(Keys.needSetPwd) ?? false;
    
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: NavAppBar(
        automaticallyImplyLeading: true,
        title: 'accountSecurity'.tr,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // 账户信息分组
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                boxShadow: [
                  BoxShadow(
                    color: Theme.of(context).shadowColor.withValues(alpha: 0.02),
                    blurRadius: 1,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // 账户号码
                  _buildSettingItem(
                    context,
                    title: 'account'.tr,
                    value: UserRepoLocal.to.current.account,
                    leadingIcon: Icons.badge,
                    leadingIconColor: AppColors.info,
                  ),
                  
                  // 分割线
                  Padding(
                    padding: const EdgeInsets.only(left: 56),
                    child: HorizontalLine(
                      height: 0.5,
                    ),
                  ),

                  // 手机号（新增：在邮箱项之前）
                  _buildSettingItem(
                    context,
                    title: 'mobile'.tr,
                    value: UserRepoLocal.to.current.mobile.isEmpty
                        ? 'notBound'.tr
                        : hiddenPhone(UserRepoLocal.to.current.mobile),
                    leadingIcon: Icons.phone_iphone,
                    leadingIconColor: AppColors.info,
                    onTap: () {
                      Get.to(
                        () => const BindMobilePage(),
                        transition: Transition.rightToLeft,
                        popGesture: true,
                      );
                    },
                  ),

                  // 分割线
                  Padding(
                    padding: const EdgeInsets.only(left: 56),
                    child: HorizontalLine(
                      height: 0.5,
                    ),
                  ),
                  
                  // 邮箱
                  _buildSettingItem(
                    context,
                    title: 'email'.tr,
                    value: UserRepoLocal.to.current.email.isEmpty
                        ? 'notBound'.tr
                        : UserRepoLocal.to.current.email.replaceRange(
                            4,
                            UserRepoLocal.to.current.email.length - 8,
                            '*' * (UserRepoLocal.to.current.email.length - 12),
                          ),
                    leadingIcon: Icons.email,
                    leadingIconColor: AppColors.warning,
                    onTap: () {
                      Get.to(
                        () => UpdatePage(
                            title: 'setParam'.trArgs(['email'.tr]),
                            value: UserRepoLocal.to.current.email,
                            field: 'input',
                            callback: (val) async {
                              iPrint("set_param val $val");
                              if (isEmail(val) == false) {
                                EasyLoading.showError(
                                  'errorInvalid'.trArgs(['email'.tr]),
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
                        popGesture: true,
                      );
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // 安全设置分组
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                boxShadow: [
                  BoxShadow(
                    color: Theme.of(context).shadowColor.withValues(alpha: 0.02),
                    blurRadius: 1,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // 密码设置
                  _buildSettingItem(
                    context,
                    title: 'password'.tr,
                    value: needSet == false ? 'haveSet'.tr : '未设置',
                    leadingIcon: Icons.lock,
                    leadingIconColor: AppColors.success,
                    onTap: () {
                      Get.to(
                        () => needSet == false
                            ? ChangePasswordPage()
                            : SetPasswordPage(),
                        transition: Transition.rightToLeft,
                        popGesture: true,
                      );
                    },
                  ),
                  
                  // 分割线
                  Padding(
                    padding: const EdgeInsets.only(left: 56),
                    child: HorizontalLine(
                      height: 0.5,
                      color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
                    ),
                  ),
                  
                  // 安全中心
                  _buildSettingItem(
                    context,
                    title: 'securityCenter'.tr,
                    subtitle: '查看安全帮助',
                    leadingIcon: Icons.shield,
                    leadingIconColor: AppColors.warning,
                    onTap: () {
                      Get.to(
                        () => WebViewPage(
                          "https://weixin110.qq.com/security/newreadtemplate?t=w_security_center_website/newindex",
                          'securityCenter'.tr,
                        ),
                        transition: Transition.rightToLeft,
                        popGesture: true,
                      );
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // 账户操作分组
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                boxShadow: [
                  BoxShadow(
                    color: Theme.of(context).shadowColor.withValues(alpha: 0.02),
                    blurRadius: 1,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // 退出登录
                  _buildSettingItem(
                    context,
                    title: 'logOut'.tr,
                    leadingIcon: Icons.logout,
                    leadingIconColor: AppColors.lightError,
                    isDestructive: true,
                    onTap: () async {
                      bool result = await UserRepoLocal.to.quitLogin();
                      if (result) {
                        Get.offAll(() => const WelcomePage());
                      }
                    },
                  ),
                  
                  // 分割线
                  Padding(
                    padding: const EdgeInsets.only(left: 56),
                    child: HorizontalLine(
                      height: 0.5,
                      color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
                    ),
                  ),
                  
                  // 注销账户
                  _buildSettingItem(
                    context,
                    title: 'logoutAccount'.tr,
                    leadingIcon: Icons.delete_forever,
                    leadingIconColor: AppColors.lightError,
                    isDestructive: true,
                    onTap: () async {
                      Get.to(
                        () => LogoutAccountPage(),
                        transition: Transition.rightToLeft,
                        popGesture: true,
                      );
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  /// 构建设置项 - 参考设置页面风格
  Widget _buildSettingItem(
    BuildContext context, {
    required String title,
    String? subtitle,
    String? value,
    IconData? leadingIcon,
    Color? leadingIconColor,
    VoidCallback? onTap,
    bool isDestructive = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Row(
            children: [
              // 前导图标
              if (leadingIcon != null) ...[
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: (leadingIconColor ?? AppColors.primaryGreen).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    leadingIcon,
                    color: isDestructive ? AppColors.lightError : (leadingIconColor ?? AppColors.primaryGreen),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
              ],
              
              // 主要内容
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: ThemeManager.instance.getTextStyle(
                        FontSizeType.normal,
                        color: isDestructive ? AppColors.lightError : Theme.of(context).colorScheme.onSurface,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: ThemeManager.instance.getTextStyle(
                          FontSizeType.small,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              
              // 值显示
              if (value != null) ...[
                const SizedBox(width: 8),
                Text(
                  value,
                  style: ThemeManager.instance.getTextStyle(
                    FontSizeType.normal,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
              
              // 箭头图标
              if (onTap != null && !isDestructive) ...[
                const SizedBox(width: 8),
                Icon(
                  Icons.navigate_next,
                  color: AppColors.textSecondary,
                  size: 20,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}