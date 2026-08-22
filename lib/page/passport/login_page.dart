import 'package:flutter/cupertino.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/theme/default/app_spacing.dart';
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
    final state = ref.watch(passportProvider);
    final notifier = ref.read(passportProvider.notifier);
    final height = MediaQuery.of(context).size.height;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
      body: Stack(
        children: [
          const Positioned(top: -120, right: -60, child: BezierContainer()),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  SizedBox(height: height * 0.04),
                  const PassportTitle(color: AppColors.primary),
                  AppSpacing.verticalXLarge,

                  // TabBar 对齐 iOS 风格
                  Container(
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppColors.darkSurfaceGrouped
                          : AppColors.lightSurfaceGrouped,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: AppSpacing.allTiny,
                    child: TabBar(
                      controller: _tabController,
                      indicator: BoxDecoration(
                        color: isDark
                            ? AppColors.darkSurfaceGroupedTertiary
                            : AppColors.lightSurface,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.darkBackground.withValues(
                              alpha: 0.05,
                            ),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      labelColor: AppColors.primary,
                      unselectedLabelColor: AppColors.iosGray,
                      dividerColor: Colors.transparent,
                      indicatorSize: TabBarIndicatorSize.tab,
                      tabs: [
                        Tab(text: t.account.account),
                        Tab(text: t.account.mobile),
                        Tab(text: t.account.email),
                      ],
                    ),
                  ),
                  AppSpacing.verticalRegular,

                  SizedBox(
                    height: 220,
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        _buildAccountLogin(state, notifier, isDark),
                        _buildMobileLogin(state, notifier, isDark),
                        _buildEmailLogin(state, notifier, isDark),
                      ],
                    ),
                  ),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton(
                        onPressed: () => context.push(AppRoutes.forgotPassword),
                        child: Text(
                          t.account.forgotPassword,
                          style: const TextStyle(color: AppColors.iosGray),
                        ),
                      ),
                      TextButton(
                        onPressed: () => context.push(AppRoutes.signUp),
                        child: Text(
                          t.account.signup,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),

                  AppSpacing.verticalLarge,
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
          Positioned(
            top: 10,
            left: 0,
            child: notifier.backButton(color: AppColors.primary),
          ),
        ],
      ),
    );
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
            autofillHints: const [AutofillHints.username, AutofillHints.email],
            onSelect: (val) {
              _accountController.text = val;
              setState(() {});
            },
            onDelete: (val) => notifier.removeHistory('account', val),
          ),
          AppSpacing.verticalRegular,
          TextField(
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
                ),
                onPressed: () => notifier.toggleLoginPwdObscure(),
              ),
            ),
          ),
          AppSpacing.verticalXXLarge,
          _buildLoginButton(() {
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
            notifier.loginUser(accountType, account, pwd).then((err) {
              if (mounted) setState(() => _isLoading = false);
              if (err == null) {
                notifier.saveHistory('account', account);
                if (mounted) context.go('/bottom_navigation');
              } else {
                notifier.snackBar(err);
              }
            });
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
              onInputChanged: (v) {
                _fullMobile = v;
                _mobileController.text = v.replaceFirst(RegExp(r'^\+\d+'), '');
                setState(() {});
              },
              hintText: t.account.mobile,
            ),
          ),
          AppSpacing.verticalRegular,
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _mobileCodeController,
                  readOnly: _isLoading,
                  autofillHints: const [AutofillHints.oneTimeCode],
                  decoration: _getInputDecoration(
                    hintText: t.passport.hintVerifyCode,
                    prefixIcon: CupertinoIcons.shield,
                    isDark: isDark,
                  ),
                ),
              ),
              AppSpacing.horizontalMedium,
              CupertinoButton(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                color: AppColors.getIosBlue(
                  isDark ? Brightness.dark : Brightness.light,
                ).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                onPressed: _isLoading
                    ? null
                    : () {
                        if (_fullMobile.isNotEmpty) {
                          notifier.sendCode('mobile', _fullMobile, 'login');
                        } else {
                          notifier.snackBar(
                            t.common.errorEmptyDirectory(
                              param: t.account.mobile,
                            ),
                          );
                        }
                      },
                child: Text(
                  t.common.getVerificationCode,
                  style: context.textStyle(
                    FontSizeType.footnote,
                    color: AppColors.getIosBlue(
                      isDark ? Brightness.dark : Brightness.light,
                    ),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          AppSpacing.verticalXXLarge,
          _buildLoginButton(() async {
            if (_fullMobile.isEmpty || _mobileCodeController.text.isEmpty) {
              return;
            }
            setState(() => _isLoading = true);
            final err = await notifier.loginUserByCode(
              'mobile',
              _fullMobile,
              _mobileCodeController.text,
            );
            if (mounted) setState(() => _isLoading = false);
            if (err == null) {
              notifier.saveHistory('mobile', _fullMobile);
              if (mounted) context.go('/bottom_navigation');
            } else {
              notifier.snackBar(err);
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
            autofillHints: const [AutofillHints.email],
            onSelect: (val) {
              _emailController.text = val;
              setState(() {});
            },
            onDelete: (val) => notifier.removeHistory('email', val),
            keyboardType: TextInputType.emailAddress,
          ),
          AppSpacing.verticalRegular,
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _emailCodeController,
                  readOnly: _isLoading,
                  autofillHints: const [AutofillHints.oneTimeCode],
                  decoration: _getInputDecoration(
                    hintText: t.passport.hintVerifyCode,
                    prefixIcon: CupertinoIcons.shield,
                    isDark: isDark,
                  ),
                ),
              ),
              AppSpacing.horizontalMedium,
              CupertinoButton(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                color: AppColors.getIosBlue(
                  isDark ? Brightness.dark : Brightness.light,
                ).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                onPressed: _isLoading
                    ? null
                    : () {
                        if (_emailController.text.isNotEmpty) {
                          notifier.sendCode(
                            'email',
                            _emailController.text,
                            'login',
                          );
                        } else {
                          notifier.snackBar(
                            t.common.errorEmptyDirectory(
                              param: t.account.email,
                            ),
                          );
                        }
                      },
                child: Text(
                  t.passport.getVerifyCode,
                  style: context.textStyle(
                    FontSizeType.footnote,
                    color: AppColors.getIosBlue(
                      isDark ? Brightness.dark : Brightness.light,
                    ),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          AppSpacing.verticalXXLarge,
          _buildLoginButton(() async {
            if (_emailController.text.isEmpty ||
                _emailCodeController.text.isEmpty) {
              return;
            }
            setState(() => _isLoading = true);
            final err = await notifier.loginUserByCode(
              'email',
              _emailController.text,
              _emailCodeController.text,
            );
            if (mounted) setState(() => _isLoading = false);
            if (err == null) {
              notifier.saveHistory('email', _emailController.text);
              if (mounted) context.go('/bottom_navigation');
            } else {
              notifier.snackBar(err);
            }
          }, isEnabled: isEnabled),
        ],
      ),
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
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        key: const Key('login_submit_button'),
        onPressed: (_isLoading || !isEnabled)
            ? null
            : () {
                FocusScope.of(context).unfocus();
                onPressed();
              },
        child: _isLoading
            ? const CupertinoActivityIndicator(color: AppColors.onPrimary)
            : Text(t.account.login),
      ),
    );
  }
}
