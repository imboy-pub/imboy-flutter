import 'package:flutter/material.dart';
import 'package:imboy/service/encrypter.dart';
import 'package:imboy/service/rsa.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/store/provider/user_provider.dart';

import 'change_password_state.dart';

class ChangePasswordLogic extends GetxController {
  final ChangePasswordState state = ChangePasswordState();

  /// 密码格式验证
  String? passwordValidator(String? val) {
    if (strEmpty(val)) {
      return 'errorEmptyDirectory'.trArgs(['password'.tr]);
    }
    if (val!.length < 4 || val.length > 32) {
      return 'errorLengthBetween'.trArgs([
        'password'.tr,
        '4',
        '32',
      ]);
    }
    return null;
  }

  Future<bool> changePassword(
      {required String newPwd,
      required String rePwd,
      required String existingPwd}) async {
    if (strEmpty(existingPwd)) {
      EasyLoading.showError('errorRequired'.trArgs(['existingPassword'.tr]));
      return false;
    }
    String? error = passwordValidator(newPwd);
    if (error != null) {
      EasyLoading.showError(error);
      return false;
    }
    if (strEmpty(newPwd)) {
      EasyLoading.showError('errorRequired'.trArgs(['newPassword'.tr]));
      return false;
    }
    if (rePwd != newPwd) {
      EasyLoading.showError('errorRetypePassword'.tr);
      return false;
    }
    if (newPwd == existingPwd) {
      EasyLoading.showError(
          'errorSame'.trArgs(['existingPassword'.tr, 'newPassword'.tr]));
      return false;
    }

    String? pubKey = StorageService.to.getString(Keys.apiPublicKey);
    // iPrint("pubKey $pubKey; ");
    bool res = await UserProvider().changePassword(
      newPwd: await _encryptPassword(pubKey!, newPwd),
      existingPwd: await _encryptPassword(pubKey, existingPwd),
    );
    return res;
  }

  Future<String> _encryptPassword(String pubKey, String password) async {
    password = EncrypterService.md5(password);
    // debugPrint("login_pwd_rsa_encrypt ${payload.toString()}");
    final encrypted = RSAService.rsaEncryptWithPointyCastle(password, pubKey);
    return encrypted;
  }

  Future<bool> setPassword(
      {required String newPwd, required String rePwd}) async {
    String? error = passwordValidator(newPwd);
    if (error != null) {
      EasyLoading.showError(error);
      return false;
    }
    if (strEmpty(newPwd)) {
      EasyLoading.showError('errorRequired'.trArgs(['newPassword'.tr]));
      return false;
    }
    if (rePwd != newPwd) {
      EasyLoading.showError('errorRetypePassword'.tr);
      return false;
    }

    String? pubKey = StorageService.to.getString(Keys.apiPublicKey);
    // iPrint("pubKey $pubKey; ");
    bool res = await UserProvider().setPassword(
      newPwd: await _encryptPassword(pubKey!, newPwd),
    );

    return res;
  }
}

class ChangeLoginPasswordController extends GetxController {
  static const int minPasswordLength = 8;

  final RxString existingPassword = ''.obs;
  final RxString newPassword = ''.obs;
  final RxString confirmPassword = ''.obs;

  // 关键逻辑：输入框控制器放在 Controller 里，便于统一清空/复位，UI 不持有业务状态
  final TextEditingController existingCtl = TextEditingController();
  final TextEditingController newCtl = TextEditingController();
  final TextEditingController confirmCtl = TextEditingController();

  final RxInt existingLength = 0.obs;
  final RxInt newLength = 0.obs;
  final RxInt confirmLength = 0.obs;

  final RxBool existingLengthOk = false.obs;
  final RxBool newLengthOk = false.obs;
  final RxBool confirmLengthOk = false.obs;
  final RxBool passwordMatchOk = false.obs;

  final RxBool canSubmit = false.obs;
  final RxBool isLoading = false.obs;

  final RxBool existingObscure = true.obs;
  final RxBool newObscure = true.obs;
  final RxBool confirmObscure = true.obs;

  @override
  void onInit() {
    super.onInit();
    existingCtl.addListener(() => existingPassword.value = existingCtl.text);
    newCtl.addListener(() => newPassword.value = newCtl.text);
    confirmCtl.addListener(() => confirmPassword.value = confirmCtl.text);
    everAll(
      [existingPassword, newPassword, confirmPassword, isLoading],
      (_) => _recompute(),
    );
    _recompute();
  }

  @override
  void onClose() {
    existingCtl.dispose();
    newCtl.dispose();
    confirmCtl.dispose();
    super.onClose();
  }

  void toggleExistingObscure() {
    existingObscure.value = !existingObscure.value;
  }

  void toggleNewObscure() {
    newObscure.value = !newObscure.value;
  }

  void toggleConfirmObscure() {
    confirmObscure.value = !confirmObscure.value;
  }

  // 关键逻辑：表单状态统一在 Controller 内部实时计算，UI 仅负责渲染
  void _recompute() {
    existingLength.value = existingPassword.value.length;
    newLength.value = newPassword.value.length;
    confirmLength.value = confirmPassword.value.length;

    existingLengthOk.value = existingLength.value >= minPasswordLength;
    newLengthOk.value = newLength.value >= minPasswordLength;
    confirmLengthOk.value = confirmLength.value >= minPasswordLength;
    passwordMatchOk.value =
        confirmPassword.value.isNotEmpty && confirmPassword.value == newPassword.value;

    canSubmit.value = !isLoading.value &&
        existingLengthOk.value &&
        newLengthOk.value &&
        confirmLengthOk.value &&
        passwordMatchOk.value;
  }

  // 关键逻辑：模拟接口请求（Future.delayed），并通过 Get.snackbar 反馈结果
  Future<void> submit() async {
    if (!canSubmit.value) return;
    FocusManager.instance.primaryFocus?.unfocus();

    isLoading.value = true;
    try {
      await Future.delayed(const Duration(milliseconds: 1200));

      final ok = DateTime.now().millisecondsSinceEpoch % 5 != 0;
      if (ok) {
        Get.snackbar(
          '修改成功',
          '登录密码已更新',
          snackPosition: SnackPosition.bottom,
          backgroundColor: Get.theme.colorScheme.inverseSurface,
          colorText: Get.theme.colorScheme.onInverseSurface,
          margin: const EdgeInsets.all(12),
          duration: const Duration(seconds: 2),
        );
        existingCtl.clear();
        newCtl.clear();
        confirmCtl.clear();
      } else {
        Get.snackbar(
          '修改失败',
          '请稍后重试',
          snackPosition: SnackPosition.bottom,
          backgroundColor: Get.theme.colorScheme.errorContainer,
          colorText: Get.theme.colorScheme.onErrorContainer,
          margin: const EdgeInsets.all(12),
          duration: const Duration(seconds: 2),
        );
      }
    } finally {
      isLoading.value = false;
    }
  }
}
