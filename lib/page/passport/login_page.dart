import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl_phone_number_input/intl_phone_number_input.dart';
import 'package:imboy/config/routes.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/passport/passport_notifier.dart';
import 'package:imboy/page/passport/passport_state.dart';
import 'package:imboy/page/passport/widget/bezier_container.dart';
import 'package:imboy/page/passport/widget/login_history_input.dart';
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

    // Initialize history
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(passportProvider.notifier).initLoginHistory();
      if (widget.account != null) {
        _accountController.text = widget.account!;
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

    return Scaffold(
      body: SizedBox(
        height: height,
        child: Stack(
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
                    notifier.title(color: AppColors.primary),
                    const SizedBox(height: 40),

                    // Tabs
                    TabBar(
                      controller: _tabController,
                      labelColor: AppColors.primary,
                      unselectedLabelColor: Colors.grey,
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
                            style: TextStyle(color: Colors.grey[600]),
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
          decoration: InputDecoration(
            hintText: t.pleaseInputParam(param: t.password),
            prefixIcon: const Icon(Icons.lock, color: AppColors.primary),
            suffixIcon: IconButton(
              icon: Icon(
                state.loginPwdObscure ? Icons.visibility : Icons.visibility_off,
              ),
              onPressed: () => notifier.toggleLoginPwdObscure(),
            ),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () async {
              debugPrint('🔘 登录按钮被点击');
              final account = _accountController.text;
              final pwd = _passwordController.text;
              debugPrint('📝 账号: $account, 密码长度: ${pwd.length}');

              if (account.isEmpty || pwd.isEmpty) {
                debugPrint('⚠️ 账号或密码为空');
                notifier.setError(
                  t.errorEmptyDirectory(param: "${t.account}/${t.password}"),
                );
                return;
              }

              debugPrint('🔄 开始登录...');
              final error = await notifier.loginUser('account', account, pwd);
              debugPrint('✅ 登录完成，错误: $error');

              if (error == null) {
                notifier.saveHistory('account', account);
                // Navigate to home is handled in loginUser success logic usually,
                // or we can do it here if loginUser returns success signal.
                // The existing logic seems to handle navigation or return error string.
                if (mounted) {
                  debugPrint('🚀 导航到底部导航页');
                  context.go('/bottom_navigation'); // Using go_router
                }
              } else {
                debugPrint('❌ 登录失败: $error');
                notifier.snackBar(error);
              }
            },
            child: Text(
              t.login,
              style: const TextStyle(color: Colors.white, fontSize: 18),
            ),
          ),
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
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: InternationalPhoneNumberInput(
            onInputChanged: (PhoneNumber number) {
              _fullMobile = number.phoneNumber ?? '';
            },
            selectorConfig: const SelectorConfig(
              selectorType: PhoneInputSelectorType.BOTTOM_SHEET,
            ),
            ignoreBlank: false,
            autoValidateMode: AutovalidateMode.disabled,
            selectorTextStyle: const TextStyle(color: Colors.black),
            initialValue: PhoneNumber(isoCode: 'CN'),
            textFieldController: _mobileController,
            formatInput: false,
            keyboardType: const TextInputType.numberWithOptions(
              signed: true,
              decimal: true,
            ),
            inputDecoration: InputDecoration(
              hintText: t.pleaseInputParam(param: t.mobile),
              border: InputBorder.none,
            ),
          ),
        ),
        const SizedBox(height: 15),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _mobileCodeController,
                decoration: InputDecoration(
                  hintText: t.pleaseInputParam(param: t.confirmCode),
                  prefixIcon: const Icon(
                    Icons.security,
                    color: AppColors.primary,
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
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
              child: Text("获取验证码", style: const TextStyle(color: Colors.white)),
            ),
          ],
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () async {
              final mobile = _fullMobile; // 使用包含区域码的完整手机号
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
            child: Text(
              t.login,
              style: const TextStyle(color: Colors.white, fontSize: 18),
            ),
          ),
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
                decoration: InputDecoration(
                  hintText: t.passport.hintVerifyCode,
                  prefixIcon: const Icon(
                    Icons.security,
                    color: AppColors.primary,
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
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
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () async {
              final email = _emailController.text;
              final code = _emailCodeController.text;
              if (email.isEmpty || code.isEmpty) return;

              final error = await notifier.loginUserByCode(
                'email',
                email,
                code,
              );
              if (error == null) {
                notifier.saveHistory('email', email);
                if (mounted) context.go('/bottom_navigation');
              } else {
                notifier.snackBar(error);
              }
            },
            child: Text(
              t.login,
              style: const TextStyle(color: Colors.white, fontSize: 18),
            ),
          ),
        ),
      ],
    );
  }
}
