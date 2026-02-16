import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:imboy/service/encrypter.dart';
import 'package:imboy/service/rsa.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/store/api/user_api.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/i18n/strings.g.dart';

part 'set_password_provider.g.dart';

/// 设置密码状态
class SetPasswordState {
  final String newPwd;
  final String retypePwd;
  final bool newPwdObscure;
  final bool retypePwdObscure;

  const SetPasswordState({
    this.newPwd = '',
    this.retypePwd = '',
    this.newPwdObscure = true,
    this.retypePwdObscure = true,
  });

  SetPasswordState copyWith({
    String? newPwd,
    String? retypePwd,
    bool? newPwdObscure,
    bool? retypePwdObscure,
  }) {
    return SetPasswordState(
      newPwd: newPwd ?? this.newPwd,
      retypePwd: retypePwd ?? this.retypePwd,
      newPwdObscure: newPwdObscure ?? this.newPwdObscure,
      retypePwdObscure: retypePwdObscure ?? this.retypePwdObscure,
    );
  }
}

/// 设置密码页面状态管理
@riverpod
class SetPassword extends _$SetPassword {
  /// 密码格式验证
  String? passwordValidator(String? val) {
    if (strEmpty(val)) {
      return t.errorEmptyDirectory(param: t.password);
    }
    if (val!.length < 4 || val.length > 32) {
      return t.errorLengthBetween(param: t.password, min: '4', max: '32');
    }
    return null;
  }

  @override
  SetPasswordState build() {
    return SetPasswordState();
  }

  void updateNewPassword(String value) {
    state = state.copyWith(newPwd: value);
  }

  void updateRetypePassword(String value) {
    state = state.copyWith(retypePwd: value);
  }

  void toggleNewPwdObscure() {
    state = state.copyWith(newPwdObscure: !state.newPwdObscure);
  }

  void toggleRetypePwdObscure() {
    state = state.copyWith(retypePwdObscure: !state.retypePwdObscure);
  }

  Future<bool> setPassword() async {
    String? error = passwordValidator(state.newPwd);
    if (error != null) {
      EasyLoading.showError(error);
      return false;
    }
    if (strEmpty(state.newPwd)) {
      EasyLoading.showError(t.errorRequired(param: t.newPassword));
      return false;
    }
    if (state.retypePwd != state.newPwd) {
      EasyLoading.showError(t.errorRetypePassword);
      return false;
    }

    String? pubKey = StorageService.to.getString(Keys.apiPublicKey);
    // 使用 userApiProvider 调用 API
    final userApi = ref.read(userApiProvider);
    bool res = await userApi.setPassword(
      newPwd: await _encryptPassword(pubKey, state.newPwd),
    );

    return res;
  }

  Future<String> _encryptPassword(String pubKey, String password) async {
    password = EncrypterService.md5(password);
    // 🔒 统一使用 RSA-OAEP-SHA256 加密（支持 Web 和移动端）
    final encrypted = await RSAService.rsaEncryptWithPointyCastleAsync(password, pubKey);
    return encrypted;
  }
}
