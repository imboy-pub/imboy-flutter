import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:imboy/component/ui/debounce_button.dart';
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
  String _fullMobile = ''; // 完整的手机号（包含区域码）

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

    // Initialize history and auto-fill last login account
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(passportProvider.notifier).initLoginHistory();
      // 优先使用传入的账号（如果有），否则使用上一次登录的账号
      if (widget.account != null && widget.account!.isNotEmpty) {
        _accountController.text = widget.account!;
      } else {
        // 自动填充上一次登录的账号
        final lastAccount = UserRepoLocal.to.lastLoginAccount;
        if (lastAccount.isNotEmpty) {
          _accountController.text = lastAccount;
          if (kDebugMode) {
            debugPrint('📝 自动填充上一次登录账号: $lastAccount');
          }
        }
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

  bool get _isDark => Theme.of(context).brightness == Brightness.dark;
  Color get _inputFill =>
      _isDark ? AppColors.darkSurfaceContainer : Colors.white;
  Color get _hintColor =>
      _isDark ? AppColors.darkTextDisabled : Colors.grey[400]!;
  Color get _suffixColor =>
      _isDark ? AppColors.darkTextSecondary : Colors.grey[600]!;
  Color get _unselectedLabel =>
      _isDark ? AppColors.darkTextSecondary : Colors.grey;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(passportProvider);
    final notifier = ref.read(passportProvider.notifier);
    final height = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor:
          _isDark ? AppColors.darkSurface : null,
      body: Stack(
        children: [
          Positioned(
              top: -height * .15,
              right: -MediaQuery.of(context).size.width * .18,
              child: const BezierContainer(),
            ),

            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(height: height * 0.12),
                    const PassportTitle(color: AppColors.primary),
                    const SizedBox(height: 40),

                    // Tabs
                    TabBar(
                      controller: _tabController,
                      labelColor: AppColors.primary,
                      unselectedLabelColor: _unselectedLabel,
                      indicatorColor: AppColors.primary,
                      tabs: [
                        Tab(text: t.account),
                        Tab(text: t.mobile),
                        Tab(text: t.email),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Tab Views
                    SizedBox(
                      height: 300, // Adjust height as needed
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          _buildAccountLogin(state, notifier),
                          _buildMobileLogin(state, notifier),
                          _buildEmailLogin(state, notifier),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Quick Actions / Guides
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        TextButton(
                          onPressed: () =>
                              context.push(AppRoutes.forgotPassword),
                          child: Text(
                            t.forgotPassword,
                            style: TextStyle(
                              color: _isDark
                                  ? AppColors.darkTextSecondary
                                  : Colors.grey[600],
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () => context.push(AppRoutes.signUp),
                          child: Text(
                            t.signup,
                            style: TextStyle(color: AppColors.primary),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            Positioned(
              top: 40,
              left: 0,
              child: notifier.backButton(color: AppColors.primary),
            ),
        ],
      ),
    );
  }

  Widget _buildAccountLogin(PassportState state, PassportNotifier notifier) {
    return Column(
      children: [
        LoginHistoryInput(
          controller: _accountController,
          hintText: t.hintLoginAccount,
          prefixIcon: Icons.person,
          historyList: state.accountHistory,
          onSelect: (val) => _accountController.text = val,
          onDelete: (val) => notifier.removeHistory('account', val),
        ),
        const SizedBox(height: 15),
        TextField(
          controller: _passwordController,
          obscureText: state.loginPwdObscure,
          style: TextStyle(
            color: _isDark
                ? AppColors.darkTextPrimary
                : AppColors.lightTextPrimary,
          ),
          decoration: InputDecoration(
            hintText: t.pleaseInputParam(param: t.password),
            hintStyle: TextStyle(color: _hintColor),
            prefixIcon: const Icon(Icons.lock, color: AppColors.primary),
            suffixIcon: IconButton(
              icon: Icon(
                state.loginPwdObscure ? Icons.visibility : Icons.visibility_off,
                color: _suffixColor,
              ),
              onPressed: () => notifier.toggleLoginPwdObscure(),
            ),
            filled: true,
            fillColor: _inputFill,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: _isDark
                  ? const BorderSide(color: AppColors.darkBorder)
                  : BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.primary),
            ),
          ),
        ),
        const SizedBox(height: 20),
        DebounceButton(
          text: t.login,
          width: double.infinity,
          height: 50,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          textStyle: const TextStyle(color: Colors.white, fontSize: 18),
          onPressed: () async {
            final account = _accountController.text;
            final pwd = _passwordController.text;

            if (account.isEmpty || pwd.isEmpty) {
              notifier.setError(
                t.errorEmptyDirectory(param: "${t.account}/${t.password}"),
              );
              return;
            }

            final error = await notifier.loginUser('account', account, pwd);
            if (kDebugMode) {
              debugPrint('✅ 登录完成，错误: $error');
            }

            if (error == null) {
              notifier.saveHistory('account', account);
              if (mounted) {
                context.go('/bottom_navigation');
              }
            } else {
              notifier.snackBar(error);
            }
          },
        ),
      ],
    );
  }

  Widget _buildMobileLogin(PassportState state, PassportNotifier notifier) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: _inputFill,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: _isDark ? AppColors.darkBorder : Colors.grey.shade200,
            ),
          ),
          child: PhoneInputWidget(
            initialValue: '',
            onInputChanged: (String fullNumber) {
              _fullMobile = fullNumber;
              // 同步到控制器
              _mobileController.text = fullNumber.replaceFirst(RegExp(r'^\+\d+'), '');
            },
            hintText: t.pleaseInputParam(param: t.mobile),
          ),
        ),
        const SizedBox(height: 15),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _mobileCodeController,
                style: TextStyle(
                  color: _isDark
                      ? AppColors.darkTextPrimary
                      : AppColors.lightTextPrimary,
                ),
                decoration: InputDecoration(
                  hintText: t.pleaseInputParam(param: t.confirmCode),
                  hintStyle: TextStyle(color: _hintColor),
                  prefixIcon: const Icon(
                    Icons.security,
                    color: AppColors.primary,
                  ),
                  filled: true,
                  fillColor: _inputFill,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: _isDark
                        ? const BorderSide(color: AppColors.darkBorder)
                        : BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppColors.primary),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            ElevatedButton(
              onPressed: () {
                if (_fullMobile.isNotEmpty) {
                  notifier.sendCode('mobile', _fullMobile, 'login');
                } else {
                  notifier.snackBar(t.errorEmptyDirectory(param: t.mobile));
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
              ),
              child: Text(t.getVerificationCode, style: const TextStyle(color: Colors.white)),
            ),
          ],
        ),
        const SizedBox(height: 20),
        DebounceButton(
          text: t.login,
          width: double.infinity,
          height: 50,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          textStyle: const TextStyle(color: Colors.white, fontSize: 18),
          onPressed: () async {
            final mobile = _fullMobile;
            final code = _mobileCodeController.text;
            if (mobile.isEmpty || code.isEmpty) return;

            final error = await notifier.loginUserByCode(
              'mobile',
              mobile,
              code,
            );
            if (error == null) {
              notifier.saveHistory('mobile', mobile);
              if (mounted) context.go('/bottom_navigation');
            } else {
              notifier.snackBar(error);
            }
          },
        ),
      ],
    );
  }

  Widget _buildEmailLogin(PassportState state, PassportNotifier notifier) {
    return Column(
      children: [
        LoginHistoryInput(
          controller: _emailController,
          hintText: t.passport.hintEmail,
          prefixIcon: Icons.email,
          historyList: state.emailHistory,
          onSelect: (val) => _emailController.text = val,
          onDelete: (val) => notifier.removeHistory('email', val),
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 15),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _emailCodeController,
                style: TextStyle(
                  color: _isDark
                      ? AppColors.darkTextPrimary
                      : AppColors.lightTextPrimary,
                ),
                decoration: InputDecoration(
                  hintText: t.passport.hintVerifyCode,
                  hintStyle: TextStyle(color: _hintColor),
                  prefixIcon: const Icon(
                    Icons.security,
                    color: AppColors.primary,
                  ),
                  filled: true,
                  fillColor: _inputFill,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: _isDark
                        ? const BorderSide(color: AppColors.darkBorder)
                        : BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppColors.primary),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            ElevatedButton(
              onPressed: () {
                if (_emailController.text.isNotEmpty) {
                  notifier.sendCode('email', _emailController.text, 'login');
                } else {
                  notifier.snackBar(t.errorEmptyDirectory(param: t.email));
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
              ),
              child: Text(
                t.passport.getVerifyCode,
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        DebounceButton(
          text: t.login,
          width: double.infinity,
          height: 50,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          textStyle: const TextStyle(color: Colors.white, fontSize: 18),
          onPressed: () async {
            final email = _emailController.text;
            final code = _emailCodeController.text;
            if (email.isEmpty || code.isEmpty) return;

            final error = await notifier.loginUserByCode('email', email, code);
            if (error == null) {
              notifier.saveHistory('email', email);
              if (mounted) context.go('/bottom_navigation');
            } else {
              notifier.snackBar(error);
            }
          },
        ),
      ],
    );
  }
}
