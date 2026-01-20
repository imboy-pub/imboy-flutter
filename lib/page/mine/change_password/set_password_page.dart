import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/component/ui/button.dart';
import 'package:imboy/component/ui/password.dart';
import 'package:imboy/component/ui/common_bar.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:imboy/page/passport/manage_account_page.dart';
import 'package:imboy/page/bottom_navigation/bottom_navigation_page.dart';
import 'package:imboy/theme/default/app_radius.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/mine/change_password/set_password_provider.dart';

/// 设置密码页面
class SetPasswordPage extends ConsumerWidget {
  const SetPasswordPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final colorScheme = Theme.of(context).colorScheme;
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final state = ref.watch(setPasswordProvider);

    return Scaffold(
      appBar: GlassAppBar(
        automaticallyImplyLeading: true,
        title: t.setPassword,
      ),
      backgroundColor: colorScheme.surface,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),

            // 安全说明卡片
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: AppRadius.borderRadiusRegular,
              ),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  borderRadius: AppRadius.borderRadiusRegular,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      colorScheme.primary.withAlpha(25),
                      colorScheme.primary.withAlpha(10),
                    ],
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: colorScheme.primary.withAlpha(51),
                            borderRadius: AppRadius.borderRadiusMedium,
                          ),
                          child: Icon(
                            Icons.shield_outlined,
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
                                t.setLoginPassword,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: colorScheme.onSurface,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                t.enhanceAccountSecurity,
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
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHighest.withAlpha(
                          128,
                        ),
                        borderRadius: AppRadius.borderRadiusSmall,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            t.setPasswordSecurityTips,
                            style: TextStyle(
                              fontSize: 14,
                              color: colorScheme.onSurface.withAlpha(204),
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            t.passwordLengthRequirement,
                            style: TextStyle(
                              fontSize: 13,
                              color: colorScheme.primary,
                              fontWeight: FontWeight.w500,
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

            // 密码设置表单卡片
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: AppRadius.borderRadiusRegular,
              ),
              child: Container(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 新密码输入
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: colorScheme.surface,
                        borderRadius: AppRadius.borderRadiusMedium,
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
                                Icons.lock_open,
                                color: colorScheme.primary,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                t.newPassword,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: colorScheme.onSurface,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          PasswordTextField(
                            obscureText: state.newPwdObscure,
                            hintText: t.pleaseEnterPassword,
                            onTap: () {
                              ref
                                  .read(setPasswordProvider.notifier)
                                  .toggleNewPwdObscure();
                            },
                            onChanged: (String? val) {
                              if (strNoEmpty(val)) {
                                ref
                                    .read(setPasswordProvider.notifier)
                                    .updateNewPassword(val!.trim());
                              }
                            },
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // 确认密码输入
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: colorScheme.surface,
                        borderRadius: AppRadius.borderRadiusMedium,
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
                                t.retypePassword,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: colorScheme.onSurface,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          PasswordTextField(
                            obscureText: state.retypePwdObscure,
                            hintText: t.retypePassword,
                            onTap: () {
                              ref
                                  .read(setPasswordProvider.notifier)
                                  .toggleRetypePwdObscure();
                            },
                            onChanged: (String? val) {
                              if (strNoEmpty(val)) {
                                ref
                                    .read(setPasswordProvider.notifier)
                                    .updateRetypePassword(val!.trim());
                              }
                            },
                          ),
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
                text: t.buttonConfirm,
                onPressed: () async {
                  bool res = await ref
                      .read(setPasswordProvider.notifier)
                      .setPassword();
                  if (res && context.mounted) {
                    EasyLoading.showSuccess(t.confirmRecoverSuccess);
                    final user = UserRepoLocal.to.current;
                    final needGuide =
                        (user.email.isEmpty || user.mobile.isEmpty);
                    if (needGuide) {
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(
                          builder: (context) => const ManageAccountPage(),
                        ),
                        (route) => false,
                      );
                    } else {
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(
                          builder: (context) => const BottomNavigationPage(),
                        ),
                        (route) => false,
                      );
                    }
                  }
                },
                highlighted: true,
                size: Size(MediaQuery.of(context).size.width - 32, 58),
                borderRadius: AppRadius.borderRadiusMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
