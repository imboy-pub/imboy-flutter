import 'package:flutter/material.dart';

import 'package:get/get.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/component/web_view.dart';
import 'package:imboy/page/mine/change_password/change_password_view.dart';
import 'package:imboy/page/mine/change_password/set_password_view.dart';
import 'package:imboy/page/mine/logout_account/logout_account_view.dart';
import 'package:imboy/page/passport/welcome_view.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:imboy/component/ui/line.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/font_types.dart';

import 'package:imboy/config/const.dart';
import 'package:imboy/component/ui/common_bar.dart';

import 'account_security_logic.dart';
import 'package:imboy/page/mine/account_security/bind_email_view.dart';
import 'package:imboy/page/mine/account_security/bind_mobile_view.dart';
import 'package:imboy/i18n/strings.g.dart';

/// 账户安全页面
class AccountSecurityPage extends StatelessWidget {
  AccountSecurityPage({super.key});

  final logic = Get.put(AccountSecurityLogic());

  @override
  Widget build(BuildContext context) {
    bool needSet = StorageService.to.getBool(Keys.needSetPwd) ?? false;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: GlassAppBar(
        automaticallyImplyLeading: true,
        title: t.accountSecurity,
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          children: [
            const SizedBox(height: 16),
            // 账户信息分组
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Theme.of(
                      context,
                    ).shadowColor.withValues(alpha: 0.04),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  // 账户号码
                  _buildSettingItem(
                    context,
                    title: t.account,
                    value: UserRepoLocal.to.current.account,
                    leadingIcon: Icons.badge,
                    leadingIconColor: AppColors.info,
                  ),

                  _buildDivider(context),

                  // 手机号
                  _buildSettingItem(
                    context,
                    title: t.mobile,
                    value: UserRepoLocal.to.current.mobile.isEmpty
                        ? t.notBound
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

                  _buildDivider(context),

                  // 邮箱
                  _buildSettingItem(
                    context,
                    title: t.email,
                    value: UserRepoLocal.to.current.email.isEmpty
                        ? t.notBound
                        : UserRepoLocal.to.current.email.replaceRange(
                            4,
                            UserRepoLocal.to.current.email.length - 8,
                            '*' * (UserRepoLocal.to.current.email.length - 12),
                          ),
                    leadingIcon: Icons.alternate_email,
                    leadingIconColor: AppColors.warning,
                    onTap: () {
                      Get.to(
                        () => const BindEmailPage(),
                        transition: Transition.rightToLeft,
                        popGesture: true,
                      );
                    },
                  ),
                ],
              ),
            ),

            // 安全设置分组
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Theme.of(
                      context,
                    ).shadowColor.withValues(alpha: 0.04),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  // 密码设置
                  _buildSettingItem(
                    context,
                    title: t.password,
                    value: needSet == false ? t.haveSet : '未设置',
                    leadingIcon: Icons.lock_outline,
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

                  _buildDivider(context),

                  // 安全中心
                  _buildSettingItem(
                    context,
                    title: t.securityCenter,
                    subtitle: '查看安全帮助',
                    leadingIcon: Icons.shield_outlined,
                    leadingIconColor: AppColors.warning,
                    onTap: () {
                      Get.to(
                        () => WebViewPage(
                          "https://weixin110.qq.com/security/newreadtemplate?t=w_security_center_website/newindex",
                          t.securityCenter,
                        ),
                        transition: Transition.rightToLeft,
                        popGesture: true,
                      );
                    },
                  ),
                ],
              ),
            ),

            // 账户操作分组
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Theme.of(
                      context,
                    ).shadowColor.withValues(alpha: 0.04),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  // 退出登录
                  _buildSettingItem(
                    context,
                    title: t.logOut,
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

                  _buildDivider(context),

                  // 注销账户
                  _buildSettingItem(
                    context,
                    title: t.logoutAccount,
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

            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildDivider(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 56),
      child: HorizontalLine(
        height: 0.5,
        color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
      ),
    );
  }

  /// 构建设置项 - 优化后的主题样式
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
                    color: (leadingIconColor ?? AppColors.primaryGreen)
                        .withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10), // Rounded bg
                  ),
                  child: Icon(
                    leadingIcon,
                    color: isDestructive
                        ? AppColors.lightError
                        : (leadingIconColor ?? AppColors.primaryGreen),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 14),
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
                        color: isDestructive
                            ? AppColors.lightError
                            : Theme.of(context).colorScheme.onSurface,
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
                  Icons.arrow_forward_ios_rounded,
                  color: AppColors.textSecondary.withValues(alpha: 0.5),
                  size: 16,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
