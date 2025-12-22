import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/component/ui/common_bar.dart';
import 'package:imboy/page/mine/account_security/account_security_logic.dart';
import 'package:imboy/page/passport/passport_logic.dart';
import 'package:imboy/store/repository/user_repo_local.dart';

class BindEmailPage extends GetView<BindEmailController> {
  const BindEmailPage({super.key});

  @override
  BindEmailController get controller => Get.put(BindEmailController());

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final currentEmail = UserRepoLocal.to.current.email;
    final hasBound = currentEmail.isNotEmpty;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: NavAppBar(
        automaticallyImplyLeading: true,
        title: hasBound ? '修改邮箱' : '绑定邮箱',
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          children: [
            Card(
              margin: EdgeInsets.zero,
              child: ListTile(
                leading: Icon(Icons.alternate_email, color: cs.primary),
                title: const Text('邮箱'),
                subtitle: Text(
                  hasBound ? _maskEmail(currentEmail) : '未绑定',
                  style: TextStyle(color: cs.onSurfaceVariant),
                ),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: cs.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    hasBound ? '已绑定' : '未绑定',
                    style: TextStyle(
                      fontSize: 12,
                      color: cs.primary,
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
                      hasBound ? '更换绑定邮箱' : '绑定邮箱',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '用于登录、身份验证与找回密码',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: controller.emailCtl,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      autocorrect: false,
                      enableSuggestions: false,
                      decoration: InputDecoration(
                        labelText: '邮箱',
                        hintText: '请输入邮箱地址',
                        filled: true,
                        fillColor: cs.surfaceContainerHighest,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        suffixIcon: Obx(
                          () => controller.email.value.isEmpty
                              ? const SizedBox.shrink()
                              : IconButton(
                                  onPressed: controller.clearEmail,
                                  icon: const Icon(Icons.close_rounded),
                                ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Obx(
                      () => _StatusRow(
                        label: '当前长度',
                        value: controller.emailLength.value.toString(),
                        ok: controller.emailOk.value,
                        okText: '格式正确',
                        errorText: controller.emailError.value,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: Obx(
                        () => OutlinedButton.icon(
                          onPressed: controller.canSendCode.value
                              ? controller.sendCode
                              : null,
                          icon: controller.isSendingCode.value
                              ? SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: cs.primary,
                                  ),
                                )
                              : const Icon(Icons.mark_email_read_outlined),
                          label: Text(
                            controller.seconds.value > 0
                                ? '重新发送（${controller.seconds.value}s）'
                                : '获取验证码',
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: controller.codeCtl,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.done,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(6),
                      ],
                      decoration: InputDecoration(
                        labelText: '验证码',
                        hintText: '请输入 6 位验证码',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Obx(
                      () => _StatusRow(
                        label: '当前长度',
                        value: '${controller.codeLength.value} / 6',
                        ok: controller.codeOk.value,
                        okText: '长度正确',
                        errorText: controller.codeError.value,
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: Obx(
                        () => FilledButton(
                          onPressed: controller.canSubmit.value
                              ? controller.submit
                              : null,
                          child: controller.isSubmitting.value
                              ? Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: cs.onPrimary,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    const Text('提交中...'),
                                  ],
                                )
                              : Text(hasBound ? '确认更换' : '确认绑定'),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '验证码将发送至该邮箱，请在有效期内完成验证。',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                    ),
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

class BindEmailController extends GetxController {
  final PassportLogic passportLogic = Get.put(PassportLogic());

  final TextEditingController emailCtl = TextEditingController();
  final TextEditingController codeCtl = TextEditingController();

  final RxString email = ''.obs;
  final RxString code = ''.obs;
  final RxInt emailLength = 0.obs;
  final RxInt codeLength = 0.obs;
  final RxBool emailOk = false.obs;
  final RxBool codeOk = false.obs;
  final RxString emailError = '请输入正确的邮箱地址'.obs;
  final RxString codeError = '请输入 6 位验证码'.obs;

  final RxInt seconds = 0.obs;
  final RxBool isSendingCode = false.obs;
  final RxBool isSubmitting = false.obs;
  final RxBool canSendCode = false.obs;
  final RxBool canSubmit = false.obs;

  late final AccountSecurityLogic _securityLogic;

  @override
  void onInit() {
    super.onInit();
    _securityLogic = Get.isRegistered<AccountSecurityLogic>()
        ? Get.find<AccountSecurityLogic>()
        : Get.put(AccountSecurityLogic());

    emailCtl.addListener(() => email.value = emailCtl.text.trim());
    codeCtl.addListener(() => code.value = codeCtl.text.trim());
    everAll(
      [email, code, seconds, isSendingCode, isSubmitting],
      (_) => _recompute(),
    );
    _recompute();
  }

  @override
  void onClose() {
    emailCtl.dispose();
    codeCtl.dispose();
    super.onClose();
  }

  void clearEmail() {
    emailCtl.clear();
  }

  void _recompute() {
    emailLength.value = email.value.length;
    codeLength.value = code.value.length;
    emailOk.value = email.value.isNotEmpty && isEmail(email.value);
    codeOk.value = codeLength.value == 6;

    final currentEmail = UserRepoLocal.to.current.email;
    final changed = email.value.isNotEmpty && email.value != currentEmail;

    canSendCode.value = emailOk.value &&
        changed &&
        seconds.value == 0 &&
        !isSendingCode.value &&
        !isSubmitting.value;
    canSubmit.value =
        !isSubmitting.value && !isSendingCode.value && emailOk.value && codeOk.value && changed;
  }

  void _startCountdown() {
    seconds.value = 60;
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (seconds.value <= 0) return false;
      seconds.value = seconds.value - 1;
      return seconds.value > 0;
    });
  }

  Future<void> sendCode() async {
    if (!canSendCode.value) return;
    FocusManager.instance.primaryFocus?.unfocus();

    isSendingCode.value = true;
    try {
      final res = await passportLogic.sendCode('email', email.value, 'signup');
      if (res == null) {
        Get.snackbar(
          '验证码已发送',
          '已发送至 ${_maskEmail(email.value)}',
          snackPosition: SnackPosition.bottom,
          backgroundColor: Get.theme.colorScheme.inverseSurface,
          colorText: Get.theme.colorScheme.onInverseSurface,
          margin: const EdgeInsets.all(12),
          duration: const Duration(seconds: 2),
        );
        _startCountdown();
      } else {
        Get.snackbar(
          '发送失败',
          res.tr,
          snackPosition: SnackPosition.bottom,
          backgroundColor: Get.theme.colorScheme.errorContainer,
          colorText: Get.theme.colorScheme.onErrorContainer,
          margin: const EdgeInsets.all(12),
          duration: const Duration(seconds: 2),
        );
      }
    } finally {
      isSendingCode.value = false;
    }
  }

  Future<void> submit() async {
    if (!canSubmit.value) return;
    FocusManager.instance.primaryFocus?.unfocus();

    isSubmitting.value = true;
    try {
      final currentEmail = UserRepoLocal.to.current.email;
      if (currentEmail.isNotEmpty && email.value == currentEmail) {
        Get.snackbar(
          '无需修改',
          '新邮箱与当前绑定一致',
          snackPosition: SnackPosition.bottom,
          backgroundColor: Get.theme.colorScheme.surfaceContainerHighest,
          colorText: Get.theme.colorScheme.onSurface,
          margin: const EdgeInsets.all(12),
          duration: const Duration(seconds: 2),
        );
        return;
      }

      final ok = await _securityLogic.changeEmail(email: email.value, code: code.value);
      if (ok) {
        final user = UserRepoLocal.to.current;
        user.email = email.value;
        await UserRepoLocal.to.changeInfo(user.toMap());

        Get.snackbar(
          '绑定成功',
          '邮箱已更新为 ${_maskEmail(email.value)}',
          snackPosition: SnackPosition.bottom,
          backgroundColor: Get.theme.colorScheme.inverseSurface,
          colorText: Get.theme.colorScheme.onInverseSurface,
          margin: const EdgeInsets.all(12),
          duration: const Duration(seconds: 2),
        );
        Get.back();
      } else {
        Get.snackbar(
          '提交失败',
          '请检查验证码或稍后重试',
          snackPosition: SnackPosition.bottom,
          backgroundColor: Get.theme.colorScheme.errorContainer,
          colorText: Get.theme.colorScheme.onErrorContainer,
          margin: const EdgeInsets.all(12),
          duration: const Duration(seconds: 2),
        );
      }
    } finally {
      isSubmitting.value = false;
    }
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({
    required this.label,
    required this.value,
    required this.ok,
    required this.okText,
    required this.errorText,
  });

  final String label;
  final String value;
  final bool ok;
  final String okText;
  final String errorText;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = ok ? cs.primary : cs.error;
    final icon = ok ? Icons.check_circle_outline : Icons.error_outline;
    final text = ok ? okText : errorText;

    return Row(
      children: [
        Expanded(
          child: Text(
            '$label：$value',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: cs.onSurfaceVariant),
          ),
        ),
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        Text(
          text,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w600,
              ),
        ),
      ],
    );
  }
}

String _maskEmail(String email) {
  final v = email.trim();
  final at = v.indexOf('@');
  if (at <= 1) return v;
  final name = v.substring(0, at);
  final domain = v.substring(at);
  if (name.length <= 2) return '${name[0]}*$domain';
  return '${name.substring(0, 2)}***$domain';
}
