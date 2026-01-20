import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:imboy/page/passport/passport_notifier.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:imboy/store/api/user_api.dart';

part 'bind_mobile_provider.g.dart';

/// 获取区域代码列表
List<String> getRegionCodeList(String scene) {
  // 返回常用的国家代码
  return ['CN', 'US', 'UK', 'JP', 'KR', 'TW', 'HK', 'SG'];
}

/// BindMobile 模块的状态
class BindMobileState {
  final String mobile;
  final String code;
  final int mobileLength;
  final int codeLength;
  final bool mobileOk;
  final bool codeOk;
  final int seconds;
  final bool isSendingCode;
  final bool isSubmitting;
  final bool canSendCode;
  final bool canSubmit;

  const BindMobileState({
    this.mobile = '',
    this.code = '',
    this.mobileLength = 0,
    this.codeLength = 0,
    this.mobileOk = false,
    this.codeOk = false,
    this.seconds = 0,
    this.isSendingCode = false,
    this.isSubmitting = false,
    this.canSendCode = false,
    this.canSubmit = false,
  });

  BindMobileState copyWith({
    String? mobile,
    String? code,
    int? mobileLength,
    int? codeLength,
    bool? mobileOk,
    bool? codeOk,
    int? seconds,
    bool? isSendingCode,
    bool? isSubmitting,
    bool? canSendCode,
    bool? canSubmit,
  }) {
    return BindMobileState(
      mobile: mobile ?? this.mobile,
      code: code ?? this.code,
      mobileLength: mobileLength ?? this.mobileLength,
      codeLength: codeLength ?? this.codeLength,
      mobileOk: mobileOk ?? this.mobileOk,
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
class BindMobileNotifier extends _$BindMobileNotifier {
  final TextEditingController mobileCtl = TextEditingController();
  final TextEditingController codeCtl = TextEditingController();

  @override
  BindMobileState build() {
    return const BindMobileState();
  }

  void updateMobile(String mobile) {
    final currentMobile = UserRepoLocal.to.current.mobile;
    final mobileOk = mobile.length > 8;
    final changed = mobile.isNotEmpty && mobile != currentMobile;

    final canSendCode =
        mobileOk &&
        changed &&
        state.seconds == 0 &&
        !state.isSendingCode &&
        !state.isSubmitting;

    final canSubmit =
        !state.isSubmitting &&
        !state.isSendingCode &&
        mobileOk &&
        state.codeOk &&
        changed;

    state = state.copyWith(
      mobile: mobile,
      mobileLength: mobile.length,
      mobileOk: mobileOk,
      canSendCode: canSendCode,
      canSubmit: canSubmit,
    );
  }

  void updateCode(String code) {
    final codeOk = code.length == 6;

    final currentMobile = UserRepoLocal.to.current.mobile;
    final changed = state.mobile.isNotEmpty && state.mobile != currentMobile;

    final canSubmit =
        !state.isSubmitting &&
        !state.isSendingCode &&
        state.mobileOk &&
        codeOk &&
        changed;

    state = state.copyWith(
      code: code,
      codeLength: code.length,
      codeOk: codeOk,
      canSubmit: canSubmit,
    );
  }

  void startCountdown() {
    state = state.copyWith(seconds: 60);
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (state.seconds <= 0) return false;
      final newSeconds = state.seconds - 1;
      state = state.copyWith(seconds: newSeconds);

      // 更新 canSendCode
      final currentMobile = UserRepoLocal.to.current.mobile;
      final changed = state.mobile.isNotEmpty && state.mobile != currentMobile;
      final canSendCode =
          state.mobileOk &&
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
        'mobile',
        state.mobile,
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

    final currentMobile = UserRepoLocal.to.current.mobile;
    if (currentMobile.isNotEmpty && state.mobile == currentMobile) {
      return 'New mobile is same as current';
    }

    state = state.copyWith(isSubmitting: true);
    try {
      // 使用 userApiProvider 调用 API
      final userApi = ref.read(userApiProvider);
      final ok = await userApi.changeMobile(
        mobile: state.mobile,
        code: state.code,
      );

      if (ok) {
        final user = UserRepoLocal.to.current;
        user.mobile = state.mobile;
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
    mobileCtl.dispose();
    codeCtl.dispose();
  }
}
