import 'package:encrypt/encrypt.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/service/encrypter.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/store/provider/user_provider.dart';

import 'change_password_state.dart';

class ChangePasswordLogic extends GetxController {
  final ChangePasswordState state = ChangePasswordState();

  /// 密码格式验证
  String? passwordValidator(String? val) {
    if (strEmpty(val)) {
      return 'error_empty_directory'.trArgs(['password'.tr]);
    }
    if (val!.length < 4 || val.length > 32) {
      return 'error_length_between'.trArgs([
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
      EasyLoading.showError('error_required'.trArgs(['existing_password'.tr]));
      return false;
    }
    String? error = passwordValidator(newPwd);
    if (error != null) {
      EasyLoading.showError(error);
      return false;
    }
    if (strEmpty(newPwd)) {
      EasyLoading.showError('error_required'.trArgs(['new_password'.tr]));
      return false;
    }
    if (rePwd != newPwd) {
      EasyLoading.showError('error_retype_password'.tr);
      return false;
    }
    if (newPwd == existingPwd) {
      EasyLoading.showError(
          'error_same'.trArgs(['existing_password'.tr, 'new_password'.tr]));
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
    dynamic publicKey = RSAKeyParser().parse(pubKey);
    final encryptor = Encrypter(RSA(publicKey: publicKey));
    final encrypted = encryptor.encrypt(password);
    return encrypted.base64.toString();
  }

  Future<bool> setPassword(
      {required String newPwd, required String rePwd}) async {
    String? error = passwordValidator(newPwd);
    if (error != null) {
      EasyLoading.showError(error);
      return false;
    }
    if (strEmpty(newPwd)) {
      EasyLoading.showError('error_required'.trArgs(['new_password'.tr]));
      return false;
    }
    if (rePwd != newPwd) {
      EasyLoading.showError('error_retype_password'.tr);
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
