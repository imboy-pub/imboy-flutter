import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:imboy/component/ui/common_bar.dart';

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

    return Scaffold(
      appBar: NavAppBar(
        automaticallyImplyLeading: true,
        title: '修改登录密码',
      ),
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          children: [
            Card(
              margin: EdgeInsets.zero,
              child: ListTile(
                leading: Icon(Icons.lock, color: colorScheme.primary),
                title: const Text('登录密码'),
                subtitle: Text(
                  '用于登录与身份验证',
                  style: TextStyle(color: colorScheme.onSurfaceVariant),
                ),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '已启用',
                    style: TextStyle(
                      fontSize: 12,
                      color: colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(16),
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
                    const SizedBox(height: 16),
                    _PasswordField(
                      label: '原密码',
                      hintText: '请输入原密码',
                      controller: controller.existingCtl,
                      obscure: controller.existingObscure,
                      onToggleObscure: controller.toggleExistingObscure,
                      style: _FieldStyle.filled,
                    ),
                    const SizedBox(height: 8),
                    Obx(
                      () => _FieldStatusRow(
                        length: controller.existingLength.value,
                        minLength: ChangeLoginPasswordController.minPasswordLength,
                        ok: controller.existingLengthOk.value,
                        okText: '长度符合要求',
                        errorText: '至少 ${ChangeLoginPasswordController.minPasswordLength} 位',
                      ),
                    ),
                    const SizedBox(height: 16),
                    _PasswordField(
                      label: '新密码',
                      hintText: '请输入新密码',
                      controller: controller.newCtl,
                      obscure: controller.newObscure,
                      onToggleObscure: controller.toggleNewObscure,
                      style: _FieldStyle.filled,
                    ),
                    const SizedBox(height: 8),
                    Obx(
                      () => _FieldStatusRow(
                        length: controller.newLength.value,
                        minLength: ChangeLoginPasswordController.minPasswordLength,
                        ok: controller.newLengthOk.value,
                        okText: '长度符合要求',
                        errorText: '至少 ${ChangeLoginPasswordController.minPasswordLength} 位',
                      ),
                    ),
                    const SizedBox(height: 16),
                    _PasswordField(
                      label: '确认新密码',
                      hintText: '请再次输入新密码',
                      controller: controller.confirmCtl,
                      obscure: controller.confirmObscure,
                      onToggleObscure: controller.toggleConfirmObscure,
                      style: _FieldStyle.outlined,
                    ),
                    const SizedBox(height: 8),
                    Obx(
                      () {
                        final ok = controller.confirmLengthOk.value &&
                            controller.passwordMatchOk.value;
                        final errorText = !controller.confirmLengthOk.value
                            ? '至少 ${ChangeLoginPasswordController.minPasswordLength} 位'
                            : (controller.passwordMatchOk.value
                                ? ''
                                : '两次输入不一致');
                        return _FieldStatusRow(
                          length: controller.confirmLength.value,
                          minLength: ChangeLoginPasswordController.minPasswordLength,
                          ok: ok,
                          okText: '校验通过',
                          errorText: errorText.isEmpty ? '校验通过' : errorText,
                        );
                      },
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: Obx(
                        () => FilledButton(
                          onPressed: controller.canSubmit.value
                              ? controller.submit
                              : null,
                          child: controller.isLoading.value
                              ? Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: colorScheme.onPrimary,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    const Text('保存中...'),
                                  ],
                                )
                              : const Text('保存'),
                        ),
                      ),
                    ),
                    SizedBox(height: bottomPadding == 0 ? 12 : bottomPadding),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _FieldStyle { filled, outlined }

class _PasswordField extends StatelessWidget {
  const _PasswordField({
    required this.label,
    required this.hintText,
    required this.controller,
    required this.obscure,
    required this.onToggleObscure,
    required this.style,
  });

  final String label;
  final String hintText;
  final TextEditingController controller;
  final RxBool obscure;
  final VoidCallback onToggleObscure;
  final _FieldStyle style;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isFilled = style == _FieldStyle.filled;

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
          filled: isFilled,
          fillColor: isFilled ? cs.surfaceContainerHighest : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          suffixIcon: IconButton(
            onPressed: onToggleObscure,
            icon: Icon(
              obscure.value ? Icons.visibility_off_outlined : Icons.visibility_outlined,
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
    final color = ok ? cs.primary : cs.error;
    final icon = ok ? Icons.check_circle_outline : Icons.error_outline;
    final statusText = ok ? okText : errorText;

    return Row(
      children: [
        Expanded(
          child: Text(
            '当前长度：$length / $minLength',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: cs.onSurfaceVariant),
          ),
        ),
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
    );
  }
}
