import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/modules/identity/public.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:imboy/store/api/user_api.dart';

part 'bind_email_provider.g.dart';

/// BindEmail 模块的状态
class BindEmailState {
  final String email;
  final String code;
  final int emailLength;
  final int codeLength;
  final bool emailOk;
  final bool codeOk;
  final int seconds;
  final bool isSendingCode;
  final bool isSubmitting;
  final bool canSendCode;
  final bool canSubmit;

  const BindEmailState({
    this.email = '',
    this.code = '',
    this.emailLength = 0,
    this.codeLength = 0,
    this.emailOk = false,
    this.codeOk = false,
    this.seconds = 0,
    this.isSendingCode = false,
    this.isSubmitting = false,
    this.canSendCode = false,
    this.canSubmit = false,
  });

  BindEmailState copyWith({
    String? email,
    String? code,
    int? emailLength,
    int? codeLength,
    bool? emailOk,
    bool? codeOk,
    int? seconds,
    bool? isSendingCode,
    bool? isSubmitting,
    bool? canSendCode,
    bool? canSubmit,
  }) {
    return BindEmailState(
      email: email ?? this.email,
      code: code ?? this.code,
      emailLength: emailLength ?? this.emailLength,
      codeLength: codeLength ?? this.codeLength,
      emailOk: emailOk ?? this.emailOk,
      codeOk: codeOk ?? this.codeOk,
      seconds: seconds ?? this.seconds,
      isSendingCode: isSendingCode ?? this.isSendingCode,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      canSendCode: canSendCode ?? this.canSendCode,
      canSubmit: canSubmit ?? this.canSubmit,
    );
  }
}

@riverpod
class BindEmailNotifier extends _$BindEmailNotifier {
  final TextEditingController emailCtl = TextEditingController();
  final TextEditingController codeCtl = TextEditingController();

  @override
  BindEmailState build() {
    return const BindEmailState();
  }

  void updateEmail(String email) {
    final currentEmail = UserRepoLocal.to.current.email;
    final emailOk = email.isNotEmpty && isEmail(email);
    final changed = email.isNotEmpty && email != currentEmail;

    final canSendCode =
        emailOk &&
        changed &&
        state.seconds == 0 &&
        !state.isSendingCode &&
        !state.isSubmitting;

    final canSubmit =
        !state.isSubmitting &&
        !state.isSendingCode &&
        emailOk &&
        state.codeOk &&
        changed;

    state = state.copyWith(
      email: email,
      emailLength: email.length,
      emailOk: emailOk,
      canSendCode: canSendCode,
      canSubmit: canSubmit,
    );
  }

  void updateCode(String code) {
    final codeOk = code.length == 6;

    final currentEmail = UserRepoLocal.to.current.email;
    final changed = state.email.isNotEmpty && state.email != currentEmail;

    final canSubmit =
        !state.isSubmitting &&
        !state.isSendingCode &&
        state.emailOk &&
        codeOk &&
        changed;

    state = state.copyWith(
      code: code,
      codeLength: code.length,
      codeOk: codeOk,
      canSubmit: canSubmit,
    );
  }

  void clearEmail() {
    emailCtl.clear();
  }

  void startCountdown() {
    state = state.copyWith(seconds: 60);
    Future.doWhile(() async {
      await Future<dynamic>.delayed(const Duration(seconds: 1));
      if (state.seconds <= 0) return false;
      final newSeconds = state.seconds - 1;
      state = state.copyWith(seconds: newSeconds);

      // 更新 canSendCode
      final currentEmail = UserRepoLocal.to.current.email;
      final changed = state.email.isNotEmpty && state.email != currentEmail;
      final canSendCode =
          state.emailOk &&
          changed &&
          newSeconds == 0 &&
          !state.isSendingCode &&
          !state.isSubmitting;
      state = state.copyWith(canSendCode: canSendCode);

      return state.seconds > 0;
    });
  }

  Future<String?> sendCode() async {
    if (!state.canSendCode) return 'Cannot send code';
    FocusManager.instance.primaryFocus?.unfocus();

    state = state.copyWith(isSendingCode: true);
    try {
      final passportNotifier = ref.read(passportProvider.notifier);
      final res = await passportNotifier.sendCode(
        'email',
        state.email,
        'signup',
      );
      if (res == null) {
        startCountdown();
        return null;
      } else {
        return res;
      }
    } finally {
      state = state.copyWith(isSendingCode: false);
    }
  }

  Future<String?> submit() async {
    if (!state.canSubmit) return 'Cannot submit';
    FocusManager.instance.primaryFocus?.unfocus();

    final currentEmail = UserRepoLocal.to.current.email;
    if (currentEmail.isNotEmpty && state.email == currentEmail) {
      return 'New email is same as current';
    }

    state = state.copyWith(isSubmitting: true);
    try {
      // 使用 userApiProvider 调用 API
      final userApi = ref.read(userApiProvider);
      final ok = await userApi.changeEmail(
        email: state.email,
        code: state.code,
      );

      if (ok) {
        final user = UserRepoLocal.to.current;
        user.email = state.email;
        await UserRepoLocal.to.changeInfo(user.toMap());
        return null;
      } else {
        return 'Verification failed';
      }
    } finally {
      state = state.copyWith(isSubmitting: false);
    }
  }

  void dispose() {
    emailCtl.dispose();
    codeCtl.dispose();
  }
}
