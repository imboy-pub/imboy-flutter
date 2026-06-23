import 'package:flutter/cupertino.dart';
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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        String type = 'account';
        if (_tabController.index == 1) type = 'mobile';
        if (_tabController.index == 2) type = 'email';
        ref.read(passportProvider.notifier).setAccountType(type);
      }
    });

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
                  SizedBox(height: height * 0.08),
                  const PassportTitle(color: AppColors.primary),
                  const SizedBox(height: 40),

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
                  AppSpacing.verticalXXLarge,

                  SizedBox(
                    height: 320,
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
    return Column(
      children: [
        LoginHistoryInput(
          key: const Key('login_phone_input'),
          controller: _accountController,
          hintText: t.account.hintLoginAccount,
          prefixIcon: CupertinoIcons.person,
          historyList: state.accountHistory,
          onSelect: (val) => _accountController.text = val,
          onDelete: (val) => notifier.removeHistory('account', val),
        ),
        AppSpacing.verticalRegular,
        TextField(
          key: const Key('login_password_input'),
          controller: _passwordController,
          obscureText: state.loginPwdObscure,
          decoration: InputDecoration(
            hintText: t.account.password,
            prefixIcon: const Icon(CupertinoIcons.lock, size: 20),
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
          notifier.loginUser('account', account, pwd).then((err) {
            if (err == null) {
              notifier.saveHistory('account', account);
              if (mounted) context.go('/bottom_navigation');
            } else {
              notifier.snackBar(err);
            }
          });
        }),
      ],
    );
  }

  Widget _buildMobileLogin(
    PassportState state,
    PassportNotifier notifier,
    bool isDark,
  ) {
    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            color: isDark
                ? AppColors.darkSurfaceGroupedTertiary
                : AppColors.lightSurfaceGrouped,
            borderRadius: BorderRadius.circular(10),
          ),
          child: PhoneInputWidget(
            initialValue: '',
            onInputChanged: (v) {
              _fullMobile = v;
              _mobileController.text = v.replaceFirst(RegExp(r'^\+\d+'), '');
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
                decoration: const InputDecoration(
                  hintText: 'Code',
                  prefixIcon: Icon(CupertinoIcons.shield, size: 20),
                ),
              ),
            ),
            AppSpacing.horizontalMedium,
            CupertinoButton(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
              child: Text(
                t.common.getVerificationCode,
                style: TextStyle(
                  fontSize: FontSizeType.footnote.size,
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
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
          ],
        ),
        AppSpacing.verticalXXLarge,
        _buildLoginButton(() async {
          if (_fullMobile.isEmpty || _mobileCodeController.text.isEmpty) return;
          final err = await notifier.loginUserByCode(
            'mobile',
            _fullMobile,
            _mobileCodeController.text,
          );
          if (err == null) {
            notifier.saveHistory('mobile', _fullMobile);
            if (mounted) context.go('/bottom_navigation');
          } else {
            notifier.snackBar(err);
          }
        }),
      ],
    );
  }

  Widget _buildEmailLogin(
    PassportState state,
    PassportNotifier notifier,
    bool isDark,
  ) {
    return Column(
      children: [
        LoginHistoryInput(
          controller: _emailController,
          hintText: t.passport.hintEmail,
          prefixIcon: CupertinoIcons.mail,
          historyList: state.emailHistory,
          onSelect: (val) => _emailController.text = val,
          onDelete: (val) => notifier.removeHistory('email', val),
          keyboardType: TextInputType.emailAddress,
        ),
        AppSpacing.verticalRegular,
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _emailCodeController,
                decoration: const InputDecoration(
                  hintText: 'Code',
                  prefixIcon: Icon(CupertinoIcons.shield, size: 20),
                ),
              ),
            ),
            AppSpacing.horizontalMedium,
            CupertinoButton(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
              child: Text(
                t.passport.getVerifyCode,
                style: TextStyle(
                  fontSize: FontSizeType.footnote.size,
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
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
          ],
        ),
        AppSpacing.verticalXXLarge,
        _buildLoginButton(() async {
          if (_emailController.text.isEmpty ||
              _emailCodeController.text.isEmpty) {
            return;
          }
          final err = await notifier.loginUserByCode(
            'email',
            _emailController.text,
            _emailCodeController.text,
          );
          if (err == null) {
            notifier.saveHistory('email', _emailController.text);
            if (mounted) context.go('/bottom_navigation');
          } else {
            notifier.snackBar(err);
          }
        }),
      ],
    );
  }

  Widget _buildLoginButton(VoidCallback onPressed) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        key: const Key('login_submit_button'),
        onPressed: onPressed,
        child: Text(t.account.login),
      ),
    );
  }
}
