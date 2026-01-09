import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:imboy/component/ui/common_bar.dart';
import 'package:imboy/theme/default/app_colors.dart';

import 'change_password_logic.dart';

/// 修改密码页面
class ChangePasswordPage extends GetView<ChangeLoginPasswordController> {
  const ChangePasswordPage({super.key});

  @override
  ChangeLoginPasswordController get controller =>
      Get.put(ChangeLoginPasswordController());

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: GlassAppBar(
        automaticallyImplyLeading: true,
        title: '修改登录密码',
      ),
      backgroundColor:
          isDark ? Theme.of(context).colorScheme.surface : const Color(0xFFF5F5F5),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          children: [
            Container(
              decoration: BoxDecoration(
                color: isDark
                    ? Theme.of(context).colorScheme.surfaceContainerHighest
                    : Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: isDark
                        ? Theme.of(context)
                            .colorScheme
                            .shadow
                            .withValues(alpha: 0.05)
                        : Colors.black.withValues(alpha: 0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
                border: isDark
                    ? Border.all(
                        color: Theme.of(context)
                            .colorScheme
                            .outline
                            .withValues(alpha: 0.15),
                        width: 0.5,
                      )
                    : null,
              ),
              child: ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isDark
                        ? colorScheme.primary.withValues(alpha: 0.1)
                        : AppColors.primaryGreen.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.lock_outline,
                    color: isDark ? colorScheme.primary : AppColors.primaryGreen,
                    size: 20,
                  ),
                ),
                title: const Text(
                  '登录密码',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  '用于登录与身份验证',
                  style: TextStyle(color: colorScheme.onSurfaceVariant),
                ),
                trailing: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: isDark
                        ? colorScheme.primary.withValues(alpha: 0.12)
                        : AppColors.primaryGreen.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '已启用',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? colorScheme.primary : AppColors.primaryGreen,
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
                color: isDark
                    ? Theme.of(context).colorScheme.surfaceContainerHighest
                    : Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: isDark
                        ? Theme.of(context)
                            .colorScheme
                            .shadow
                            .withValues(alpha: 0.05)
                        : Colors.black.withValues(alpha: 0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
                border: isDark
                    ? Border.all(
                        color: Theme.of(context)
                            .colorScheme
                            .outline
                            .withValues(alpha: 0.15),
                        width: 0.5,
                      )
                    : null,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '修改登录密码',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '新密码至少 ${ChangeLoginPasswordController.minPasswordLength} 位',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(height: 20),
                  _PasswordField(
                    label: '原密码',
                    hintText: '请输入原密码',
                    controller: controller.existingCtl,
                    obscure: controller.existingObscure,
                    onToggleObscure: controller.toggleExistingObscure,
                  ),
                  const SizedBox(height: 8),
                  Obx(
                    () => _FieldStatusRow(
                      length: controller.existingLength.value,
                      minLength: ChangeLoginPasswordController.minPasswordLength,
                      ok: controller.existingLengthOk.value,
                      okText: '长度符合要求',
                      errorText:
                          '至少 ${ChangeLoginPasswordController.minPasswordLength} 位',
                    ),
                  ),
                  const SizedBox(height: 16),
                  _PasswordField(
                    label: '新密码',
                    hintText: '请输入新密码',
                    controller: controller.newCtl,
                    obscure: controller.newObscure,
                    onToggleObscure: controller.toggleNewObscure,
                  ),
                  const SizedBox(height: 8),
                  Obx(
                    () => _FieldStatusRow(
                      length: controller.newLength.value,
                      minLength: ChangeLoginPasswordController.minPasswordLength,
                      ok: controller.newLengthOk.value,
                      okText: '长度符合要求',
                      errorText:
                          '至少 ${ChangeLoginPasswordController.minPasswordLength} 位',
                    ),
                  ),
                  const SizedBox(height: 16),
                  _PasswordField(
                    label: '确认新密码',
                    hintText: '请再次输入新密码',
                    controller: controller.confirmCtl,
                    obscure: controller.confirmObscure,
                    onToggleObscure: controller.toggleConfirmObscure,
                  ),
                  const SizedBox(height: 8),
                  Obx(
                    () {
                      final ok = controller.confirmLengthOk.value &&
                          controller.passwordMatchOk.value;
                      final errorText = !controller.confirmLengthOk.value
                          ? '至少 ${ChangeLoginPasswordController.minPasswordLength} 位'
                          : (controller.passwordMatchOk.value ? '' : '两次输入不一致');
                      return _FieldStatusRow(
                        length: controller.confirmLength.value,
                        minLength: ChangeLoginPasswordController.minPasswordLength,
                        ok: ok,
                        okText: '校验通过',
                        errorText: errorText.isEmpty ? '校验通过' : errorText,
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: Obx(
                      () => ElevatedButton(
                        onPressed: controller.canSubmit.value
                            ? controller.submit
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryGreen,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(25),
                          ),
                          disabledBackgroundColor:
                              AppColors.primaryGreen.withValues(alpha: 0.3),
                          disabledForegroundColor: Colors.white.withValues(alpha: 0.7),
                        ),
                        child: controller.isLoading.value
                            ? Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                          Colors.white),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  const Text('保存中...'),
                                ],
                              )
                            : const Text(
                                '保存',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
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

class _PasswordField extends StatelessWidget {
  const _PasswordField({
    required this.label,
    required this.hintText,
    required this.controller,
    required this.obscure,
    required this.onToggleObscure,
  });

  final String label;
  final String hintText;
  final TextEditingController controller;
  final RxBool obscure;
  final VoidCallback onToggleObscure;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Obx(
      () => TextField(
        controller: controller,
        obscureText: obscure.value,
        enableSuggestions: false,
        autocorrect: false,
        textInputAction: TextInputAction.next,
        decoration: InputDecoration(
          labelText: label,
          hintText: hintText,
          filled: true,
          fillColor: isDark
              ? cs.surfaceContainerHighest.withValues(alpha: 0.5)
              : const Color(0xFFF9F9F9),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.1)
                  : Colors.black.withValues(alpha: 0.05),
              width: 1,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: isDark ? cs.primary : AppColors.primaryGreen,
              width: 1.5,
            ),
          ),
          suffixIcon: IconButton(
            onPressed: onToggleObscure,
            icon: Icon(
              obscure.value
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
              color: isDark
                  ? Colors.white.withValues(alpha: 0.5)
                  : Colors.black.withValues(alpha: 0.4),
            ),
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
    
    final successColor = isDark ? cs.primary : AppColors.primaryGreen;
    final errorColor = isDark ? cs.error : const Color(0xFFD32F2F);
    
    final color = ok ? successColor : errorColor;
    final icon = ok ? Icons.check_circle_rounded : Icons.info_outline_rounded;
    final statusText = ok ? okText : errorText;

    return Row(
      children: [
        Expanded(
          child: Text(
            '当前长度：$length / $minLength',
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
