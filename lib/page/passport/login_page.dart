import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform, kIsWeb;

import 'package:imboy/modules/enterprise_oa/enterprise_oa_runtime_config.dart';
import 'package:flutter/cupertino.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/service/login_account_history_service.dart';
import 'package:imboy/component/ui/app_back_scope.dart';
import 'package:imboy/theme/default/app_spacing.dart';
import 'package:imboy/theme/default/app_sizes.dart';
import 'package:imboy/theme/default/app_radius.dart';
import 'package:imboy/theme/default/font_types.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:imboy/component/ui/phone_input.dart';
import 'package:imboy/config/routes.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/passport/passport_notifier.dart';
import 'package:imboy/page/passport/passport_state.dart';
import 'package:imboy/page/passport/widget/passport_title.dart';
import 'package:imboy/page/passport/widget/bezier_container.dart';
import 'package:imboy/page/passport/widget/login_history_input.dart';
import 'package:imboy/page/passport/widget/login_form_tabs.dart';
import 'package:imboy/page/passport/widget/other_login_section.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:imboy/theme/default/app_colors.dart';

/// 登录页面 - 系统级 UI 修复 (Harmony & Robustness)
class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key, this.account, this.refUid});

  final String? account;
  final String? refUid;

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _accountController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _mobileController = TextEditingController();
  final TextEditingController _mobileCodeController = TextEditingController();
  String _fullMobile = '';
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _emailCodeController = TextEditingController();
  bool _isLoading = false;
  bool _isClearingHistory = false;

  @override
  void initState() {
    super.initState();
    // 支付宝登录流程被系统杀死中断的恢复提示：loginByAlipay 唤起 SDK 前置位
    // 标记、正常结束清除；进程被杀时残留至此，提示用户重试而非静默停在登录页。
    if (StorageService.to.getBool(Keys.alipayLoginInProgress) == true) {
      StorageService.to.remove(Keys.alipayLoginInProgress);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ref
              .read(passportProvider.notifier)
              .snackBar(t.chat.alipayLoginInterrupted);
        }
      });
    }
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        String type = 'account';
        if (_tabController.index == 1) type = 'mobile';
        if (_tabController.index == 2) type = 'email';
        ref.read(passportProvider.notifier).setAccountType(type);
      }
    });

    _accountController.addListener(() => setState(() {}));
    _passwordController.addListener(() => setState(() {}));
    _mobileController.addListener(() => setState(() {}));
    _mobileCodeController.addListener(() => setState(() {}));
    _emailController.addListener(() => setState(() {}));
    _emailCodeController.addListener(() => setState(() {}));

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(passportProvider.notifier).initLoginHistory();
      if (widget.account?.isNotEmpty ?? false) {
        _accountController.text = widget.account!;
      } else {
        final lastAccount = UserRepoLocal.to.lastLoginAccount;
        if (lastAccount.isNotEmpty) _accountController.text = lastAccount;
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _accountController.dispose();
    _passwordController.dispose();
    _mobileController.dispose();
    _mobileCodeController.dispose();
    _emailController.dispose();
    _emailCodeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = Translations.of(context);
    final state = ref.watch(passportProvider);
    final notifier = ref.read(passportProvider.notifier);
    final height = MediaQuery.of(context).size.height;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final page = CupertinoPageScaffold(
      child: Material(
        type: MaterialType.transparency,
        child: Stack(
          children: [
            const Positioned(top: -120, right: -60, child: BezierContainer()),
            SafeArea(
              child: Column(
                children: [
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: notifier.backButton(
                      color: AppColors.primary,
                      isRtl: Directionality.of(context) == TextDirection.rtl,
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        children: [
                          SizedBox(height: height * 0.04),
                          const PassportTitle(color: AppColors.primary),
                          AppSpacing.verticalXLarge,

                          LoginFormTabs(
                            controller: _tabController,
                            labels: [
                              t.account.account,
                              t.account.mobile,
                              t.account.email,
                            ],
                            children: [
                              _buildAccountLogin(state, notifier, isDark),
                              _buildMobileLogin(state, notifier, isDark),
                              _buildEmailLogin(state, notifier, isDark),
                            ],
                          ),

                          SizedBox(
                            width: double.infinity,
                            child: Wrap(
                              alignment: WrapAlignment.spaceBetween,
                              children: [
                                CupertinoButton(
                                  onPressed: () =>
                                      context.push(AppRoutes.forgotPassword),
                                  child: Text(
                                    t.account.forgotPassword,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: isDark
                                          ? AppColors.darkTextSecondary
                                          : AppColors.lightTextSecondary,
                                    ),
                                  ),
                                ),
                                CupertinoButton(
                                  onPressed: () =>
                                      context.push(AppRoutes.signUp),
                                  child: Text(
                                    t.account.signup,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          AppSpacing.verticalLarge,
                          if ((!kIsWeb &&
                                  defaultTargetPlatform ==
                                      TargetPlatform.android) &&
                              resolveEnterpriseOaRuntimeConfig()
                                  .inboundLoginEnabled)
                            CupertinoButton(
                              onPressed: () => context.push('/oa/login'),
                              child: Text(t.enterpriseOa.startInbound),
                            ),
                          OtherLoginSection(
                            notifier: notifier,
                            isDark: isDark,
                            showAlipay: true,
                            showOneKey: true,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
    return AppBackScope<void>(
      canPop: !_isClearingHistory,
      onPopInvokedWithResult: (_, _) {},
      child: AbsorbPointer(
        absorbing: _isClearingHistory || _isLoading,
        child: page,
      ),
    );
  }

  void _historyBusyChanged(bool busy) {
    if (mounted) setState(() => _isClearingHistory = busy);
  }

  String _historyClearErrorMessage(Object error) {
    if (error is LoginAccountIdentityUnavailableException) {
      return t.account.loginHistoryIdentityUnavailable;
    }
    if (error is LoginAccountCleanupBusyException) {
      return t.account.loginHistoryCleanupBusy;
    }
    if (error is LoginAccountSharedDataException) {
      return t.account.loginHistorySharedData;
    }
    if (error is AccountLocalDataOwnershipException) {
      return t.account.loginHistoryOwnershipUnavailable;
    }
    return t.common.operationFailedAgainLater;
  }

  Future<void> _clearHistoryAccountData(String type, String value) async {
    final before = ref.read(passportProvider);
    await ref
        .read(passportProvider.notifier)
        .clearHistoryAccountData(type, value);
    if (!mounted) return;
    final after = ref.read(passportProvider);
    if (before.accountHistory.contains(_accountController.text) &&
        !after.accountHistory.contains(_accountController.text)) {
      _accountController.clear();
    }
    if (before.emailHistory.contains(_emailController.text) &&
        !after.emailHistory.contains(_emailController.text)) {
      _emailController.clear();
    }
    _passwordController.clear();
    _emailCodeController.clear();
  }

  Future<void> _finishLogin(
    PassportNotifier notifier,
    String type,
    String value,
  ) async {
    try {
      await notifier.saveHistory(type, value);
    } catch (_) {
      if (mounted) notifier.snackBar(t.common.operationFailedAgainLater);
    }
    // Authentication and account ownership are already persisted. A history
    // display preference failure must not strand a signed-in user here.
    if (mounted) context.go('/bottom_navigation');
  }

  Widget _buildAccountLogin(
    PassportState state,
    PassportNotifier notifier,
    bool isDark,
  ) {
    final bool isEnabled =
        _accountController.text.trim().isNotEmpty &&
        _passwordController.text.isNotEmpty;

    return AutofillGroup(
      child: Column(
        children: [
          LoginHistoryInput(
            key: const Key('login_phone_input'),
            controller: _accountController,
            hintText: t.account.hintLoginAccount,
            prefixIcon: CupertinoIcons.person,
            historyList: state.accountHistory,
            enabled: !_isLoading && !_isClearingHistory,
            autofillHints: const [AutofillHints.username, AutofillHints.email],
            onSelect: (val) {
              _accountController.text = val;
              setState(() {});
            },
            onClear: (val) => _clearHistoryAccountData('account', val),
            onBusyChanged: _historyBusyChanged,
            clearErrorMessage: _historyClearErrorMessage,
          ),
          AppSpacing.verticalRegular,
          TextField(
            enableSuggestions: false,
            autocorrect: false,
            key: const Key('login_password_input'),
            controller: _passwordController,
            obscureText: state.loginPwdObscure,
            readOnly: _isLoading,
            autofillHints: const [AutofillHints.password],
            decoration: _getInputDecoration(
              hintText: t.account.password,
              prefixIcon: CupertinoIcons.lock,
              isDark: isDark,
              suffixIcon: CupertinoButton(
                padding: EdgeInsets.zero,
                child: Icon(
                  state.loginPwdObscure
                      ? CupertinoIcons.eye
                      : CupertinoIcons.eye_slash,
                  size: 20,
                  color: AppColors.iosGray,
                  semanticLabel: state.loginPwdObscure
                      ? t.common.showPassword
                      : t.common.hidePassword,
                ),
                onPressed: () => notifier.toggleLoginPwdObscure(),
              ),
            ),
          ),
          AppSpacing.verticalXXLarge,
          _buildLoginButton(() async {
            final account = _accountController.text;
            final pwd = _passwordController.text;
            if (account.isEmpty || pwd.isEmpty) {
              notifier.setError(
                t.common.errorEmptyDirectory(
                  param: "${t.account.account}/${t.account.password}",
                ),
              );
              return;
            }
            final accountType = account.contains('@') ? 'email' : 'account';
            setState(() => _isLoading = true);
            try {
              final err = await notifier.loginUser(accountType, account, pwd);
              if (err == null) {
                await _finishLogin(notifier, 'account', account);
              } else {
                notifier.snackBar(err);
              }
            } catch (_) {
              if (mounted) {
                notifier.snackBar(t.common.operationFailedAgainLater);
              }
            } finally {
              if (mounted) setState(() => _isLoading = false);
            }
          }, isEnabled: isEnabled),
        ],
      ),
    );
  }

  Widget _buildMobileLogin(
    PassportState state,
    PassportNotifier notifier,
    bool isDark,
  ) {
    final bool isEnabled =
        _mobileController.text.trim().isNotEmpty &&
        _mobileCodeController.text.trim().isNotEmpty;

    return AutofillGroup(
      child: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              color: isDark
                  ? AppColors.darkSurfaceContainer
                  : AppColors.lightSurface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isDark ? AppColors.darkBorder : AppColors.iosGray5,
              ),
            ),
            child: PhoneInputWidget(
              initialValue: '',
              onInputChanged: (v, local) {
                _fullMobile = v;
                // localNumber 由组件精确剥掉国家码，勿用正则二次剥离
                // （^\+\d+ 贪婪吞整串，历史 P0：手机登录表单永久禁用）
                _mobileController.text = local;
                setState(() {});
              },
              hintText: t.account.mobile,
            ),
          ),
          AppSpacing.verticalRegular,
          _buildVerificationCodeInput(
            controller: _mobileCodeController,
            buttonText: t.common.getVerificationCode,
            isDark: isDark,
            onPressed: () {
              if (_fullMobile.isNotEmpty) {
                notifier.sendCode('mobile', _fullMobile, 'login');
              } else {
                notifier.snackBar(
                  t.common.errorEmptyDirectory(param: t.account.mobile),
                );
              }
            },
          ),
          AppSpacing.verticalXXLarge,
          _buildLoginButton(() async {
            if (_fullMobile.isEmpty || _mobileCodeController.text.isEmpty) {
              return;
            }
            setState(() => _isLoading = true);
            try {
              final mobile = _fullMobile;
              final err = await notifier.loginUserByCode(
                'mobile',
                mobile,
                _mobileCodeController.text,
              );
              if (err == null) {
                await _finishLogin(notifier, 'mobile', mobile);
              } else {
                notifier.snackBar(err);
              }
            } catch (_) {
              if (mounted) {
                notifier.snackBar(t.common.operationFailedAgainLater);
              }
            } finally {
              if (mounted) setState(() => _isLoading = false);
            }
          }, isEnabled: isEnabled),
        ],
      ),
    );
  }

  Widget _buildEmailLogin(
    PassportState state,
    PassportNotifier notifier,
    bool isDark,
  ) {
    final bool isEnabled =
        _emailController.text.trim().isNotEmpty &&
        _emailCodeController.text.trim().isNotEmpty;

    return AutofillGroup(
      child: Column(
        children: [
          LoginHistoryInput(
            controller: _emailController,
            hintText: t.passport.hintEmail,
            prefixIcon: CupertinoIcons.mail,
            historyList: state.emailHistory,
            enabled: !_isLoading && !_isClearingHistory,
            autofillHints: const [AutofillHints.email],
            onSelect: (val) {
              _emailController.text = val;
              setState(() {});
            },
            onClear: (val) => _clearHistoryAccountData('email', val),
            onBusyChanged: _historyBusyChanged,
            clearErrorMessage: _historyClearErrorMessage,
            keyboardType: TextInputType.emailAddress,
          ),
          AppSpacing.verticalRegular,
          _buildVerificationCodeInput(
            controller: _emailCodeController,
            buttonText: t.passport.getVerifyCode,
            isDark: isDark,
            onPressed: () {
              if (_emailController.text.isNotEmpty) {
                notifier.sendCode('email', _emailController.text, 'login');
              } else {
                notifier.snackBar(
                  t.common.errorEmptyDirectory(param: t.account.email),
                );
              }
            },
          ),
          AppSpacing.verticalXXLarge,
          _buildLoginButton(() async {
            if (_emailController.text.isEmpty ||
                _emailCodeController.text.isEmpty) {
              return;
            }
            setState(() => _isLoading = true);
            try {
              final email = _emailController.text;
              final err = await notifier.loginUserByCode(
                'email',
                email,
                _emailCodeController.text,
              );
              if (err == null) {
                await _finishLogin(notifier, 'email', email);
              } else {
                notifier.snackBar(err);
              }
            } catch (_) {
              if (mounted) {
                notifier.snackBar(t.common.operationFailedAgainLater);
              }
            } finally {
              if (mounted) setState(() => _isLoading = false);
            }
          }, isEnabled: isEnabled),
        ],
      ),
    );
  }

  Widget _buildVerificationCodeInput({
    required TextEditingController controller,
    required String buttonText,
    required VoidCallback onPressed,
    required bool isDark,
  }) {
    final brightness = isDark ? Brightness.dark : Brightness.light;
    final color = AppColors.getIosBlue(brightness);
    final style = context.textStyle(
      FontSizeType.footnote,
      color: _isLoading
          ? (isDark ? AppColors.darkTextDisabled : AppColors.lightTextDisabled)
          : color,
      fontWeight: FontWeight.w600,
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final scaler = MediaQuery.textScalerOf(context);
        final painter = TextPainter(
          text: TextSpan(text: buttonText, style: style),
          textDirection: Directionality.of(context),
          textScaler: scaler,
        )..layout();
        final buttonWidth = painter.width + AppSpacing.xxLarge;
        painter.dispose();
        // Reserve room for six digits, the input icon and its padding.
        final inputWidth =
            scaler.scale(
                  Theme.of(context).textTheme.bodyLarge?.fontSize ??
                      FontSizeType.medium.size,
                ) *
                6 +
            AppSizes.touchTarget +
            AppSpacing.xxLarge;
        final stacked =
            inputWidth + AppSpacing.medium + buttonWidth > constraints.maxWidth;
        final input = TextField(
          enableSuggestions: false,
          autocorrect: false,
          controller: controller,
          readOnly: _isLoading,
          autofillHints: const [AutofillHints.oneTimeCode],
          decoration: _getInputDecoration(
            hintText: t.passport.hintVerifyCode,
            prefixIcon: CupertinoIcons.shield,
            isDark: isDark,
          ),
        );
        final button = CupertinoButton(
          padding: AppSpacing.symmetricRegular,
          minimumSize: const Size(0, AppSizes.touchTarget),
          color: color.withValues(alpha: 0.1),
          borderRadius: AppRadius.borderRadiusCell,
          onPressed: _isLoading ? null : onPressed,
          child: Text(buttonText, style: style, textAlign: TextAlign.center),
        );
        if (stacked) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [input, AppSpacing.verticalMedium, button],
          );
        }
        return Row(
          children: [
            Expanded(child: input),
            AppSpacing.horizontalMedium,
            button,
          ],
        );
      },
    );
  }

  Color _getInputFill(bool isDark) =>
      isDark ? AppColors.darkSurfaceContainer : AppColors.lightSurface;

  Color _getBorderDefault(bool isDark) =>
      isDark ? AppColors.darkBorder : AppColors.iosGray5;

  InputDecoration _getInputDecoration({
    required String hintText,
    required IconData prefixIcon,
    Widget? suffixIcon,
    required bool isDark,
  }) {
    final borderDefault = _getBorderDefault(isDark);
    return InputDecoration(
      hintText: hintText,
      prefixIcon: Icon(prefixIcon, color: AppColors.primary, size: 20),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: _getInputFill(isDark),
      contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: borderDefault),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: AppColors.primary),
      ),
    );
  }

  Widget _buildLoginButton(VoidCallback onPressed, {bool isEnabled = true}) {
    final brightness = Theme.of(context).brightness;
    final disabled = _isLoading || _isClearingHistory || !isEnabled;
    final foreground = disabled
        ? AppColors.getTextColor(brightness, isSecondary: true)
        : AppColors.onPrimary;
    return SizedBox(
      width: double.infinity,
      child: CupertinoButton.filled(
        minimumSize: const Size(0, 50),
        key: const Key('login_submit_button'),
        padding: EdgeInsets.zero,
        onPressed: disabled
            ? null
            : () {
                FocusScope.of(context).unfocus();
                onPressed();
              },
        child: _isLoading
            ? CupertinoActivityIndicator(color: foreground)
            : Text(t.account.login, style: TextStyle(color: foreground)),
      ),
    );
  }
}
