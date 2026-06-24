import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:imboy/component/ui/app_loading.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/store/api/user_api.dart';

part 'change_password_provider.g.dart';

/// 修改登录密码状态
class ChangeLoginPasswordState {
  final String existingPassword;
  final String newPassword;
  final String confirmPassword;

  final int existingLength;
  final int newLength;
  final int confirmLength;

  final bool existingLengthOk;
  final bool newLengthOk;
  final bool confirmLengthOk;
  final bool passwordMatchOk;

  final bool canSubmit;
  final bool isLoading;

  final bool existingObscure;
  final bool newObscure;
  final bool confirmObscure;

  const ChangeLoginPasswordState({
    this.existingPassword = '',
    this.newPassword = '',
    this.confirmPassword = '',
    this.existingLength = 0,
    this.newLength = 0,
    this.confirmLength = 0,
    this.existingLengthOk = false,
    this.newLengthOk = false,
    this.confirmLengthOk = false,
    this.passwordMatchOk = false,
    this.canSubmit = false,
    this.isLoading = false,
    this.existingObscure = true,
    this.newObscure = true,
    this.confirmObscure = true,
  });

  ChangeLoginPasswordState copyWith({
    String? existingPassword,
    String? newPassword,
    String? confirmPassword,
    int? existingLength,
    int? newLength,
    int? confirmLength,
    bool? existingLengthOk,
    bool? newLengthOk,
    bool? confirmLengthOk,
    bool? passwordMatchOk,
    bool? canSubmit,
    bool? isLoading,
    bool? existingObscure,
    bool? newObscure,
    bool? confirmObscure,
  }) {
    return ChangeLoginPasswordState(
      existingPassword: existingPassword ?? this.existingPassword,
      newPassword: newPassword ?? this.newPassword,
      confirmPassword: confirmPassword ?? this.confirmPassword,
      existingLength: existingLength ?? this.existingLength,
      newLength: newLength ?? this.newLength,
      confirmLength: confirmLength ?? this.confirmLength,
      existingLengthOk: existingLengthOk ?? this.existingLengthOk,
      newLengthOk: newLengthOk ?? this.newLengthOk,
      confirmLengthOk: confirmLengthOk ?? this.confirmLengthOk,
      passwordMatchOk: passwordMatchOk ?? this.passwordMatchOk,
      canSubmit: canSubmit ?? this.canSubmit,
      isLoading: isLoading ?? this.isLoading,
      existingObscure: existingObscure ?? this.existingObscure,
      newObscure: newObscure ?? this.newObscure,
      confirmObscure: confirmObscure ?? this.confirmObscure,
    );
  }
}

/// 修改登录密码页面状态管理
@riverpod
class ChangeLoginPassword extends _$ChangeLoginPassword {
  static const int minPasswordLength = 8;

  @override
  ChangeLoginPasswordState build() {
    return ChangeLoginPasswordState();
  }

  void updateExistingPassword(String value) {
    state = state.copyWith(existingPassword: value);
    _recompute();
  }

  void updateNewPassword(String value) {
    state = state.copyWith(newPassword: value);
    _recompute();
  }

  void updateConfirmPassword(String value) {
    state = state.copyWith(confirmPassword: value);
    _recompute();
  }

  void toggleExistingObscure() {
    state = state.copyWith(existingObscure: !state.existingObscure);
  }

  void toggleNewObscure() {
    state = state.copyWith(newObscure: !state.newObscure);
  }

  void toggleConfirmObscure() {
    state = state.copyWith(confirmObscure: !state.confirmObscure);
  }

  void _recompute() {
    final existingLength = state.existingPassword.length;
    final newLength = state.newPassword.length;
    final confirmLength = state.confirmPassword.length;

    final existingLengthOk = existingLength >= minPasswordLength;
    final newLengthOk = newLength >= minPasswordLength;
    final confirmLengthOk = confirmLength >= minPasswordLength;
    final passwordMatchOk =
        state.confirmPassword.isNotEmpty &&
        state.confirmPassword == state.newPassword;

    final canSubmit =
        !state.isLoading &&
        existingLengthOk &&
        newLengthOk &&
        confirmLengthOk &&
        passwordMatchOk;

    state = state.copyWith(
      existingLength: existingLength,
      newLength: newLength,
      confirmLength: confirmLength,
      existingLengthOk: existingLengthOk,
      newLengthOk: newLengthOk,
      confirmLengthOk: confirmLengthOk,
      passwordMatchOk: passwordMatchOk,
      canSubmit: canSubmit,
    );
  }

  Future<void> submit() async {
    if (!state.canSubmit) return;

    state = state.copyWith(isLoading: true);
    try {
      final ok = await UserApi.to.changePassword(
        newPwd: state.newPassword,
        existingPwd: state.existingPassword,
      );
      if (ok) {
        AppLoading.showSuccess(t.common.changeSuccess);
        // 清空表单
        state = ChangeLoginPasswordState();
      }
      // 失败时 UserApi.changePassword 已调用 AppLoading.showError
    } finally {
      state = state.copyWith(isLoading: false);
    }
  }
}
