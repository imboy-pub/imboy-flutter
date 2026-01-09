import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:intl_phone_number_input/intl_phone_number_input.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/component/ui/common_bar.dart';
import 'package:imboy/page/mine/account_security/account_security_logic.dart';
import 'package:imboy/page/mine/language/language_logic.dart';
import 'package:imboy/page/passport/passport_logic.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/component/locales/locales.dart';

class BindMobilePage extends GetView<BindMobileController> {
  const BindMobilePage({super.key});

  @override
  BindMobileController get controller => Get.put(BindMobileController());

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final currentMobile = UserRepoLocal.to.current.mobile;
    final hasBound = currentMobile.isNotEmpty;

    // Modern styling constants
    final inputBorderRadius = BorderRadius.circular(12);
    const inputFillColor = Color(0xFFF9FAFB); // Very light grey/white

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: GlassAppBar(
        automaticallyImplyLeading: true,
        title: hasBound ? '更换手机号' : '绑定手机号',
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
          children: [
            // Current Status Card
            Container(
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
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primaryGreen.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.phone_iphone,
                    color: AppColors.primaryGreen,
                    size: 24,
                  ),
                ),
                title: const Text(
                  '当前手机号',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  hasBound ? hiddenPhone(currentMobile) : '未绑定',
                  style: TextStyle(color: cs.onSurfaceVariant),
                ),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: hasBound
                        ? AppColors.primaryGreen.withValues(alpha: 0.1)
                        : Colors.grey.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    hasBound ? '已绑定' : '未绑定',
                    style: TextStyle(
                      fontSize: 12,
                      color: hasBound
                          ? AppColors.primaryGreen
                          : Colors.grey[600],
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Form Area
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 8),
                  child: Text(
                    hasBound ? '新手机号' : '手机号',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    color: inputFillColor,
                    borderRadius: inputBorderRadius,
                    border: Border.all(
                      color: Colors.grey.withValues(alpha: 0.15),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.only(left: 12),
                    child: InternationalPhoneNumberInput(
                      locale: sysLang('intl_phone_number_input'),
                      countries: controller.langLogic.regionCodeList(
                        'intl_phone_number_input',
                      ),
                      onInputChanged: (PhoneNumber number) {
                        controller.mobile.value = number.phoneNumber ?? '';
                      },
                      onInputValidated: (bool value) {
                        // handled by controller
                      },
                      selectorConfig: const SelectorConfig(
                        selectorType: PhoneInputSelectorType.BOTTOM_SHEET,
                        useBottomSheetSafeArea: true,
                        trailingSpace: false,
                        leadingPadding: 0,
                      ),
                      ignoreBlank: false,
                      autoValidateMode: AutovalidateMode.disabled,
                      selectorTextStyle: TextStyle(
                        color: cs.onSurface,
                        fontSize: 16,
                      ),
                      textStyle: TextStyle(color: cs.onSurface, fontSize: 16),
                      initialValue: PhoneNumber(isoCode: 'CN'), // Default
                      textFieldController: controller.mobileCtl,
                      keyboardType: const TextInputType.numberWithOptions(
                        signed: true,
                        decimal: true,
                      ),
                      inputBorder: InputBorder.none,
                      inputDecoration: InputDecoration(
                        hintText: '请输入手机号',
                        hintStyle: TextStyle(color: Colors.grey[400]),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.only(
                          bottom: 12,
                        ), // Adjust alignment
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 8),
                // Simple status
                Obx(
                  () => _StatusRow(
                    label: '格式检查',
                    value: controller.mobileOk.value ? '正确' : '待输入',
                    ok: controller.mobileOk.value,
                  ),
                ),

                const SizedBox(height: 20),

                // Verification Code
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(left: 4, bottom: 8),
                      child: Text(
                        '验证码',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    Obx(
                      () => Container(
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: controller.canSendCode.value
                                ? AppColors.primaryGreen.withValues(alpha: 0.5)
                                : Colors.grey.withValues(alpha: 0.3),
                          ),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: TextButton(
                          onPressed: controller.canSendCode.value
                              ? controller.sendCode
                              : null,
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.primaryGreen,
                            disabledForegroundColor: Colors.grey[400],
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: controller.isSendingCode.value
                              ? SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.primaryGreen,
                                  ),
                                )
                              : Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.sms_outlined,
                                      size: 16,
                                      color: controller.canSendCode.value
                                          ? AppColors.primaryGreen
                                          : Colors.grey[400],
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      controller.seconds.value > 0
                                          ? '重新发送 (${controller.seconds.value}s)'
                                          : '获取验证码',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ),
                  ],
                ),

                Container(
                  decoration: BoxDecoration(
                    color: inputFillColor,
                    borderRadius: inputBorderRadius,
                    border: Border.all(
                      color: Colors.grey.withValues(alpha: 0.15),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: controller.codeCtl,
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.done,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(6),
                    ],
                    style: const TextStyle(fontSize: 16, letterSpacing: 2),
                    decoration: InputDecoration(
                      hintText: '000000',
                      hintStyle: TextStyle(
                        color: Colors.grey[400],
                        letterSpacing: 1,
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.all(16),
                    ),
                  ),
                ),

                const SizedBox(height: 8),
                // Length status
                Obx(
                  () => _StatusRow(
                    label: '长度检查',
                    value: '${controller.codeLength.value} / 6',
                    ok: controller.codeOk.value,
                  ),
                ),

                const SizedBox(height: 40),

                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: Obx(
                    () => ElevatedButton(
                      onPressed: controller.canSubmit.value
                          ? controller.submit
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryGreen,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: Colors.grey[200],
                        disabledForegroundColor: Colors.grey[400],
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(26),
                        ),
                      ),
                      child: controller.isSubmitting.value
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              hasBound ? '确认更换' : '立即绑定',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Center(
                  child: Text(
                    '验证码将发送至该手机，请在有效期内完成验证',
                    style: TextStyle(color: Colors.grey[500], fontSize: 13),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class BindMobileController extends GetxController {
  final LanguageLogic langLogic = Get.put(LanguageLogic());
  final PassportLogic passportLogic = Get.put(PassportLogic());

  final TextEditingController mobileCtl = TextEditingController();
  final TextEditingController codeCtl = TextEditingController();

  final RxString mobile = ''.obs;
  final RxString code = ''.obs;
  final RxInt mobileLength = 0.obs;
  final RxInt codeLength = 0.obs;
  final RxBool mobileOk = false.obs;
  final RxBool codeOk = false.obs;

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

    // InternationalPhoneNumberInput handles controller updates internally mostly,
    // but mobile string update comes from callback.
    // We listener to codeCtl for code.
    codeCtl.addListener(() => code.value = codeCtl.text.trim());

    everAll([
      mobile,
      code,
      seconds,
      isSendingCode,
      isSubmitting,
    ], (_) => _recompute());
    _recompute();
  }

  @override
  void onClose() {
    mobileCtl.dispose();
    codeCtl.dispose();
    super.onClose();
  }

  void _recompute() {
    // Basic validation logic
    mobileLength.value = mobile.value.length;
    codeLength.value = code.value.length;

    // Simple check: mobile > 8 chars (rough check since lib handles validation too, but we need simple gate)
    mobileOk.value = mobile.value.length > 8;
    codeOk.value = codeLength.value == 6;

    final currentMobile = UserRepoLocal.to.current.mobile;
    final changed = mobile.value.isNotEmpty && mobile.value != currentMobile;

    canSendCode.value =
        mobileOk.value &&
        changed &&
        seconds.value == 0 &&
        !isSendingCode.value &&
        !isSubmitting.value;

    canSubmit.value =
        !isSubmitting.value &&
        !isSendingCode.value &&
        mobileOk.value &&
        codeOk.value &&
        changed;
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
      final res = await passportLogic.sendCode(
        'mobile',
        mobile.value,
        'signup',
      );
      if (res == null) {
        Get.snackbar(
          '验证码已发送',
          '已发送至 ${hiddenPhone(mobile.value)}',
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
      final currentMobile = UserRepoLocal.to.current.mobile;
      if (currentMobile.isNotEmpty && mobile.value == currentMobile) {
        Get.snackbar(
          '无需修改',
          '新号码与当前绑定一致',
          snackPosition: SnackPosition.bottom,
          backgroundColor: Get.theme.colorScheme.surfaceContainerHighest,
          colorText: Get.theme.colorScheme.onSurface,
          margin: const EdgeInsets.all(12),
          duration: const Duration(seconds: 2),
        );
        return;
      }

      final ok = await _securityLogic.changeMobile(
        mobile: mobile.value,
        code: code.value,
      );

      if (ok) {
        final user = UserRepoLocal.to.current;
        user.mobile = mobile.value;
        await UserRepoLocal.to.changeInfo(user.toMap());

        Get.snackbar(
          '绑定成功',
          '手机号已更新为 ${hiddenPhone(mobile.value)}',
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
  });

  final String label;
  final String value;
  final bool ok;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          ok ? Icons.check_circle : Icons.circle_outlined,
          size: 14,
          color: ok ? AppColors.primaryGreen : Colors.grey[400],
        ),
        const SizedBox(width: 6),
        Text(
          '$label: $value',
          style: TextStyle(
            color: ok ? AppColors.primaryGreen : Colors.grey[500],
            fontSize: 12,
            fontWeight: ok ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ],
    );
  }
}
