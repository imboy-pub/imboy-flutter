import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:imboy/component/ui/app_loading.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/component/ui/button.dart';
import 'package:imboy/component/ui/password.dart';
import 'package:imboy/component/ui/common_bar.dart';
import 'package:imboy/modules/identity/public.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:imboy/page/bottom_navigation/bottom_navigation_page.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/font_types.dart';
import 'package:imboy/theme/default/app_radius.dart';
import 'package:imboy/theme/default/app_spacing.dart';
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
        title: t.account.setPassword,
      ),
      backgroundColor: AppColors.getSurfaceGrouped(
        Theme.of(context).brightness,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.regular),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppSpacing.verticalSmall,

            // 安全说明卡片
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.large),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: AppRadius.borderRadiusRegular,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.medium),
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
                      AppSpacing.horizontalRegular,
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              t.account.setLoginPassword,
                              style: context.textStyle(
                                FontSizeType.medium,
                                fontWeight: FontWeight.w600,
                                color: colorScheme.onSurface,
                              ),
                            ),
                            AppSpacing.verticalTiny,
                            Text(
                              t.account.enhanceAccountSecurity,
                              style: context.textStyle(
                                FontSizeType.normal,
                                color: colorScheme.onSurface.withAlpha(179),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  AppSpacing.verticalRegular,
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.medium),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest.withAlpha(128),
                      borderRadius: AppRadius.borderRadiusSmall,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          t.common.setPasswordSecurityTips,
                          style: context
                              .textStyle(
                                FontSizeType.normal,
                                color: colorScheme.onSurface.withAlpha(204),
                              )
                              .copyWith(height: 1.4),
                        ),
                        AppSpacing.verticalSmall,
                        Text(
                          t.account.passwordLengthRequirement,
                          style: context.textStyle(
                            FontSizeType.footnote,
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

            AppSpacing.verticalXLarge,

            // 密码设置表单卡片
            Container(
              padding: const EdgeInsets.all(AppSpacing.large),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: AppRadius.borderRadiusRegular,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 新密码输入
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.regular),
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
                            AppSpacing.horizontalSmall,
                            Text(
                              t.account.newPassword,
                              style: context.textStyle(
                                FontSizeType.normal,
                                fontWeight: FontWeight.w600,
                                color: colorScheme.onSurface,
                              ),
                            ),
                          ],
                        ),
                        AppSpacing.verticalMedium,
                        PasswordTextField(
                          obscureText: state.newPwdObscure,
                          hintText: t.account.pleaseEnterPassword,
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

                  AppSpacing.verticalRegular,

                  // 确认密码输入
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.regular),
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
                            AppSpacing.horizontalSmall,
                            Text(
                              t.account.retypePassword,
                              style: context.textStyle(
                                FontSizeType.normal,
                                fontWeight: FontWeight.w600,
                                color: colorScheme.onSurface,
                              ),
                            ),
                          ],
                        ),
                        AppSpacing.verticalMedium,
                        PasswordTextField(
                          obscureText: state.retypePwdObscure,
                          hintText: t.account.retypePassword,
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

            AppSpacing.verticalXXLarge,

            // 确认按钮
            Container(
              padding: EdgeInsets.only(
                bottom: bottomPadding != 20 ? 20 : bottomPadding,
              ),
              width: double.infinity,
              child: RoundedElevatedButton(
                text: t.common.buttonConfirm,
                onPressed: () async {
                  bool res = await ref
                      .read(setPasswordProvider.notifier)
                      .setPassword();
                  if (res && context.mounted) {
                    AppLoading.showSuccess(t.common.confirmRecoverSuccess);
                    final user = UserRepoLocal.to.current;
                    final needGuide =
                        (user.email.isEmpty || user.mobile.isEmpty);
                    if (needGuide) {
                      Navigator.of(context).pushAndRemoveUntil(
                        CupertinoPageRoute<dynamic>(
                          builder: (context) => const ManageAccountPage(),
                        ),
                        (route) => false,
                      );
                    } else {
                      Navigator.of(context).pushAndRemoveUntil(
                        CupertinoPageRoute<dynamic>(
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
