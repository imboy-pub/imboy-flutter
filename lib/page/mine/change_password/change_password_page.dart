import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:imboy/component/ui/common_bar.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_radius.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/mine/change_password/change_password_provider.dart';

/// 修改密码页面
class ChangePasswordPage extends ConsumerWidget {
  const ChangePasswordPage({super.key});

  static const int minPasswordLength = 8;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final colorScheme = Theme.of(context).colorScheme;
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final state = ref.watch(changeLoginPasswordProvider);

    return Scaffold(
      appBar: GlassAppBar(
        automaticallyImplyLeading: true,
        title: t.changeLoginPassword,
      ),
      backgroundColor: AppColors.getSurfaceGrouped(Theme.of(context).brightness),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          children: [
            Container(
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: AppRadius.borderRadiusMedium,
              ),
              child: ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isDark
                        ? colorScheme.primary.withValues(alpha: 0.1)
                        : AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: AppRadius.borderRadiusSmall,
                  ),
                  child: Icon(
                    Icons.lock_outline,
                    color: isDark ? colorScheme.primary : AppColors.primary,
                    size: 20,
                  ),
                ),
                title: Text(
                  t.loginPassword,
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  t.loginPasswordDesc,
                  style: TextStyle(color: colorScheme.onSurfaceVariant),
                ),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: isDark
                        ? colorScheme.primary.withValues(alpha: 0.12)
                        : AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppRadius.circle),
                  ),
                  child: Text(
                    t.enabled,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? colorScheme.primary : AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: AppRadius.borderRadiusRegular,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t.changeLoginPassword,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    t.passwordMinLength(min: minPasswordLength.toString()),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 20),
                  _PasswordField(
                    label: t.oldPassword,
                    hintText: t.enterOldPassword,
                    obscure: state.existingObscure,
                    onToggleObscure: () {
                      ref
                          .read(changeLoginPasswordProvider.notifier)
                          .toggleExistingObscure();
                    },
                    onChanged: (value) {
                      ref
                          .read(changeLoginPasswordProvider.notifier)
                          .updateExistingPassword(value);
                    },
                  ),
                  const SizedBox(height: 8),
                  _FieldStatusRow(
                    length: state.existingLength,
                    minLength: minPasswordLength,
                    ok: state.existingLengthOk,
                    okText: t.lengthOk,
                    errorText: t.passwordMinLength(
                      min: minPasswordLength.toString(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _PasswordField(
                    label: t.newPassword,
                    hintText: t.enterNewPassword,
                    obscure: state.newObscure,
                    onToggleObscure: () {
                      ref
                          .read(changeLoginPasswordProvider.notifier)
                          .toggleNewObscure();
                    },
                    onChanged: (value) {
                      ref
                          .read(changeLoginPasswordProvider.notifier)
                          .updateNewPassword(value);
                    },
                  ),
                  const SizedBox(height: 8),
                  _FieldStatusRow(
                    length: state.newLength,
                    minLength: minPasswordLength,
                    ok: state.newLengthOk,
                    okText: t.lengthOk,
                    errorText: t.passwordMinLength(
                      min: minPasswordLength.toString(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _PasswordField(
                    label: t.confirmNewPassword,
                    hintText: t.enterNewPasswordAgain,
                    obscure: state.confirmObscure,
                    onToggleObscure: () {
                      ref
                          .read(changeLoginPasswordProvider.notifier)
                          .toggleConfirmObscure();
                    },
                    onChanged: (value) {
                      ref
                          .read(changeLoginPasswordProvider.notifier)
                          .updateConfirmPassword(value);
                    },
                  ),
                  const SizedBox(height: 8),
                  _FieldStatusRow(
                    length: state.confirmLength,
                    minLength: minPasswordLength,
                    ok: state.confirmLengthOk && state.passwordMatchOk,
                    okText: t.validationPassed,
                    errorText: !state.confirmLengthOk
                        ? t.passwordMinLength(min: minPasswordLength.toString())
                        : (state.passwordMatchOk ? '' : t.passwordMismatch),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: state.canSubmit
                          ? () {
                              ref
                                  .read(changeLoginPasswordProvider.notifier)
                                  .submit();
                            }
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: AppRadius.borderRadiusXLarge,
                        ),
                        disabledBackgroundColor: AppColors.primary.withValues(
                          alpha: 0.3,
                        ),
                        disabledForegroundColor: Colors.white.withValues(
                          alpha: 0.7,
                        ),
                      ),
                      child: state.isLoading
                          ? Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(t.loading),
                              ],
                            )
                          : Text(
                              t.buttonSave,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ),
                  SizedBox(height: bottomPadding == 0 ? 12 : bottomPadding),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PasswordField extends StatefulWidget {
  const _PasswordField({
    required this.label,
    required this.hintText,
    required this.obscure,
    required this.onToggleObscure,
    required this.onChanged,
  });

  final String label;
  final String hintText;
  final bool obscure;
  final VoidCallback onToggleObscure;
  final ValueChanged<String> onChanged;

  @override
  State<_PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<_PasswordField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _controller.addListener(() {
      widget.onChanged(_controller.text);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return TextField(
      controller: _controller,
      obscureText: widget.obscure,
      enableSuggestions: false,
      autocorrect: false,
      textInputAction: TextInputAction.next,
      decoration: InputDecoration(
        labelText: widget.label,
        hintText: widget.hintText,
        filled: true,
        fillColor: isDark
            ? cs.surfaceContainerHighest.withValues(alpha: 0.5)
            : const Color(0xFFF9F9F9),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: AppRadius.borderRadiusMedium,
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadius.borderRadiusMedium,
          borderSide: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.1)
                : Colors.black.withValues(alpha: 0.05),
            width: 1,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadius.borderRadiusMedium,
          borderSide: BorderSide(
            color: isDark ? cs.primary : AppColors.primary,
            width: 1.5,
          ),
        ),
        suffixIcon: IconButton(
          onPressed: widget.onToggleObscure,
          icon: Icon(
            widget.obscure
                ? Icons.visibility_off_outlined
                : Icons.visibility_outlined,
            color: isDark
                ? Colors.white.withValues(alpha: 0.5)
                : Colors.black.withValues(alpha: 0.4),
          ),
        ),
      ),
    );
  }
}

class _FieldStatusRow extends StatelessWidget {
  const _FieldStatusRow({
    required this.length,
    required this.minLength,
    required this.ok,
    required this.okText,
    required this.errorText,
  });

  final int length;
  final int minLength;
  final bool ok;
  final String okText;
  final String errorText;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final successColor = isDark ? cs.primary : AppColors.primary;
    final errorColor = cs.error;

    final color = ok ? successColor : errorColor;
    final icon = ok ? Icons.check_circle_rounded : Icons.info_outline_rounded;
    final statusText = ok ? okText : errorText;

    return Row(
      children: [
        Expanded(
          child: Text(
            t.currentLength(
              param1: length.toString(),
              param2: minLength.toString(),
            ),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: cs.onSurfaceVariant.withValues(alpha: 0.7),
            ),
          ),
        ),
        if (length > 0) ...[
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            statusText,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ],
    );
  }
}
