import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:imboy/component/ui/app_loading.dart';
import 'package:imboy/component/ui/ios_settings_ui.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/font_types.dart';
import 'package:imboy/theme/default/app_spacing.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/mine/change_password/change_password_provider.dart';

/// 修改密码页面 - 像素级对齐 iOS 设置风
class ChangePasswordPage extends ConsumerWidget {
  const ChangePasswordPage({super.key});

  static const int minPasswordLength = 8;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final state = ref.watch(changeLoginPasswordProvider);

    return IosPageTemplate(
      title: t.account.changeLoginPassword,
      useLargeTitle: false,
      bottomWidget: _buildSaveButton(context, ref, state, t),
      child: Column(
        children: [
          // 状态说明 Section
          ImBoySettingsSection(
            children: [
              ImBoySettingsTile(
                title: Text(t.account.loginPassword),
                subtitle: Text(t.account.loginPasswordDesc),
                leading: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: AppColors.getIosBlue(Theme.of(context).brightness),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    CupertinoIcons.lock,
                    color: AppColors.onPrimary,
                    size: 18,
                  ),
                ),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: AppSpacing.tiny,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.getIosBlue(
                      Theme.of(context).brightness,
                    ).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    t.common.enabled,
                    style: context.textStyle(
                      FontSizeType.small,
                      fontWeight: FontWeight.w600,
                      color: AppColors.getIosBlue(Theme.of(context).brightness),
                    ),
                  ),
                ),
              ),
            ],
          ),

          // 表单 Section
          ImBoySettingsSection(
            header: Text(t.account.changeLoginPassword.toUpperCase()),
            footer: Text(
              t.account.passwordMinLength(min: minPasswordLength.toString()),
            ),
            children: [
              _buildPasswordField(
                context: context,
                t: t,
                label: t.account.oldPassword,
                hint: t.account.enterOldPassword,
                obscure: state.existingObscure,
                onToggle: () => ref
                    .read(changeLoginPasswordProvider.notifier)
                    .toggleExistingObscure(),
                onChanged: (v) => ref
                    .read(changeLoginPasswordProvider.notifier)
                    .updateExistingPassword(v),
              ),
              _buildPasswordField(
                context: context,
                t: t,
                label: t.account.newPassword,
                hint: t.account.enterNewPassword,
                obscure: state.newObscure,
                onToggle: () => ref
                    .read(changeLoginPasswordProvider.notifier)
                    .toggleNewObscure(),
                onChanged: (v) => ref
                    .read(changeLoginPasswordProvider.notifier)
                    .updateNewPassword(v),
              ),
              _buildPasswordField(
                context: context,
                t: t,
                label: t.common.confirmNewPassword,
                hint: t.account.enterNewPasswordAgain,
                obscure: state.confirmObscure,
                onToggle: () => ref
                    .read(changeLoginPasswordProvider.notifier)
                    .toggleConfirmObscure(),
                onChanged: (v) => ref
                    .read(changeLoginPasswordProvider.notifier)
                    .updateConfirmPassword(v),
              ),
            ],
          ),

          // 校验提示 Section
          if (state.existingLength > 0 ||
              state.newLength > 0 ||
              state.confirmLength > 0)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xxLarge,
                AppSpacing.small,
                AppSpacing.xxLarge,
                0,
              ),
              child: Column(
                children: [
                  _ValidationRow(
                    label: t.account.oldPassword,
                    ok: state.existingLengthOk,
                    text: state.existingLengthOk
                        ? t.common.lengthOk
                        : t.main.pendingInput,
                  ),
                  _ValidationRow(
                    label: t.account.newPassword,
                    ok: state.newLengthOk,
                    text: state.newLengthOk
                        ? t.common.lengthOk
                        : t.main.pendingInput,
                  ),
                  _ValidationRow(
                    label: t.common.confirmNewPassword,
                    ok: state.confirmLengthOk && state.passwordMatchOk,
                    text: !state.confirmLengthOk
                        ? t.main.pendingInput
                        : (state.passwordMatchOk
                              ? t.common.validationPassed
                              : t.chat.passwordMismatch),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPasswordField({
    required BuildContext context,
    required Translations t,
    required String label,
    required String hint,
    required bool obscure,
    required VoidCallback onToggle,
    required ValueChanged<String> onChanged,
  }) {
    return CupertinoListTile.notched(
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: context.textStyle(
              FontSizeType.footnote,
              color: AppColors.iosGray,
            ),
          ),
          AppSpacing.verticalTiny,
          Row(
            children: [
              Expanded(
                child: CupertinoTextField(
                  placeholder: hint,
                  obscureText: obscure,
                  onChanged: onChanged,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 0,
                    vertical: AppSpacing.small,
                  ),
                  decoration: null,
                  style: context.textStyle(FontSizeType.body),
                ),
              ),
              Semantics(
                button: true,
                label: obscure ? t.common.showPassword : t.common.hidePassword,
                child: CupertinoButton(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(44, 44),
                  onPressed: onToggle,
                  child: Icon(
                    obscure ? CupertinoIcons.eye : CupertinoIcons.eye_slash,
                    size: 20,
                    color: AppColors.iosGray,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSaveButton(
    BuildContext context,
    WidgetRef ref,
    ChangeLoginPasswordState state,
    Translations t,
  ) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        8,
        16,
        MediaQuery.of(context).padding.bottom + 16,
      ),
      child: SizedBox(
        width: double.infinity,
        height: 50,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: AppColors.onPrimary,
            disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.3),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          onPressed: state.canSubmit
              ? () async {
                  FocusScope.of(context).unfocus();
                  try {
                    await ref
                        .read(changeLoginPasswordProvider.notifier)
                        .submit();
                  } on Exception catch (_) {
                    if (context.mounted) {
                      AppLoading.showError(t.common.operationFailed);
                    }
                  }
                }
              : null,
          child: state.isLoading
              ? CupertinoActivityIndicator(color: AppColors.onPrimary)
              : Text(
                  t.common.buttonSave,
                  style: context.textStyle(
                    FontSizeType.body,
                    fontWeight: FontWeight.w600,
                  ),
                ),
        ),
      ),
    );
  }
}

class _ValidationRow extends StatelessWidget {
  const _ValidationRow({
    required this.label,
    required this.ok,
    required this.text,
  });
  final String label;
  final bool ok;
  final String text;

  @override
  Widget build(BuildContext context) {
    final color = ok ? AppColors.iosGreen : AppColors.iosRed;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: context.textStyle(
                FontSizeType.small,
                color: AppColors.iosGray,
              ),
            ),
          ),
          Icon(
            ok ? CupertinoIcons.check_mark_circled : CupertinoIcons.info_circle,
            size: 14,
            color: color,
          ),
          AppSpacing.horizontalTiny,
          Text(
            text,
            style: context.textStyle(
              FontSizeType.small,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
