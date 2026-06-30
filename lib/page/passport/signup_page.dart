import 'package:flutter/material.dart';
import 'package:imboy/theme/default/app_spacing.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:imboy/component/ui/debounce_button.dart';
import 'package:imboy/component/ui/phone_input.dart';
import 'package:imboy/config/routes.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/passport/passport_notifier.dart';
import 'package:imboy/page/passport/passport_state.dart';
import 'package:imboy/page/passport/widget/bezier_container.dart';
import 'package:imboy/page/passport/widget/passport_title.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/font_types.dart';

class SignupPage extends ConsumerStatefulWidget {
  const SignupPage({super.key});

  @override
  ConsumerState<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends ConsumerState<SignupPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _nicknameController = TextEditingController();

  // Mobile Input
  final TextEditingController _mobileController = TextEditingController();
  String _fullMobile = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        String type = 'email';
        if (_tabController.index == 1) type = 'mobile';
        // We can update state if needed, but for simple form switching we might not need to sync everything
        ref.read(passportProvider.notifier).setAccountType(type);
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _nicknameController.dispose();
    _mobileController.dispose();
    super.dispose();
  }

  bool get _isDark => Theme.of(context).brightness == Brightness.dark;
  Color get _inputFill =>
      _isDark ? AppColors.darkSurfaceContainer : AppColors.lightSurface;
  Color get _unselectedLabel =>
      _isDark ? AppColors.darkTextSecondary : AppColors.iosGray;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(passportProvider);
    final notifier = ref.read(passportProvider.notifier);
    final height = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: _isDark ? AppColors.darkSurface : null,
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
                      Tab(text: t.account.email),
                      Tab(text: t.account.mobile),
                    ],
                  ),
                  AppSpacing.verticalLarge,

                  SizedBox(
                    height: 340,
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        _buildEmailRegister(state, notifier),
                        _buildMobileRegister(state, notifier),
                      ],
                    ),
                  ),

                  AppSpacing.verticalLarge,
                  // Quick Login / One Click Login
                  _buildQuickLogin(notifier),

                  AppSpacing.verticalLarge,
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        t.main.siginQ,
                        style: context.textStyle(
                          FontSizeType.footnote,
                          fontWeight: FontWeight.w600,
                          color: _isDark
                              ? AppColors.darkTextPrimary
                              : AppColors.lightTextPrimary,
                        ),
                      ),
                      const SizedBox(width: 10),
                      InkWell(
                        onTap: () => context.go(AppRoutes.signIn),
                        child: Text(
                          t.account.login,
                          style: context.textStyle(
                            FontSizeType.footnote,
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            top: 20,
            left: 0,
            child: notifier.backButton(color: AppColors.primary),
          ),
        ],
      ),
    );
  }

  Widget _buildEmailRegister(PassportState state, PassportNotifier notifier) {
    return Column(
      children: [
        TextField(
          controller: _nicknameController,
          style: TextStyle(
            color: _isDark
                ? AppColors.darkTextPrimary
                : AppColors.lightTextPrimary,
          ),
          keyboardType: TextInputType.name,
          textInputAction: TextInputAction.next,
          decoration: InputDecoration(
            hintText: t.account.nicknameHint,
            prefixIcon: const Icon(
              Icons.person_outline,
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
          ),
        ),
        const SizedBox(height: 15),
        TextField(
          controller: _emailController,
          style: TextStyle(
            color: _isDark
                ? AppColors.darkTextPrimary
                : AppColors.lightTextPrimary,
          ),
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          decoration: InputDecoration(
            hintText: t.passport.hintEmail,
            prefixIcon: const Icon(Icons.email, color: AppColors.primary),
            filled: true,
            fillColor: _inputFill,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: _isDark
                  ? const BorderSide(color: AppColors.darkBorder)
                  : BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 15),
        TextField(
          controller: _passwordController,
          style: TextStyle(
            color: _isDark
                ? AppColors.darkTextPrimary
                : AppColors.lightTextPrimary,
          ),
          obscureText: state.loginPwdObscure,
          decoration: InputDecoration(
            hintText: t.passport.hintPassword,
            prefixIcon: const Icon(Icons.lock, color: AppColors.primary),
            suffixIcon: IconButton(
              icon: Icon(
                state.loginPwdObscure ? Icons.visibility : Icons.visibility_off,
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
          ),
        ),
        AppSpacing.verticalLarge,
        DebounceButton(
          text: t.common.nextStep,
          width: double.infinity,
          height: 50,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          textStyle: context.textStyle(
            FontSizeType.large,
            color: AppColors.onPrimary,
          ),
          onPressed: () async {
            FocusScope.of(context).unfocus();
            final nickname = _nicknameController.text.trim();
            final email = _emailController.text.trim();
            final pwd = _passwordController.text;
            if (nickname.isEmpty) {
              notifier.snackBar(t.common.nicknameEmptyError);
              return;
            }
            if (email.isEmpty || pwd.isEmpty) {
              notifier.snackBar(
                t.common.errorEmptyDirectory(
                  param: "${t.account.email}/${t.account.password}",
                ),
              );
              return;
            }
            final error = await notifier.sendCode('email', email, 'signup');
            if (error == null) {
              notifier.setSignupData(
                account: email,
                accountType: 'email',
                password: pwd,
                nickname: nickname,
              );
              if (mounted) {
                context.push('/sign_up/continue');
              }
            } else {
              notifier.snackBar(error);
            }
          },
        ),
      ],
    );
  }

  Widget _buildMobileRegister(PassportState state, PassportNotifier notifier) {
    return Column(
      children: [
        TextField(
          controller: _nicknameController,
          style: TextStyle(
            color: _isDark
                ? AppColors.darkTextPrimary
                : AppColors.lightTextPrimary,
          ),
          keyboardType: TextInputType.name,
          textInputAction: TextInputAction.next,
          decoration: InputDecoration(
            hintText: t.account.nicknameHint,
            prefixIcon: const Icon(
              Icons.person_outline,
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
          ),
        ),
        const SizedBox(height: 15),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: _inputFill,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: _isDark ? AppColors.darkBorder : AppColors.lightBorder,
            ),
          ),
          child: PhoneInputWidget(
            initialValue: '',
            onInputChanged: (String fullNumber) {
              _fullMobile = fullNumber;
              _mobileController.text = fullNumber.replaceFirst(
                RegExp(r'^\+\d+'),
                '',
              );
            },
            hintText: t.passport.hintMobile,
          ),
        ),
        const SizedBox(height: 15),
        TextField(
          controller: _passwordController,
          style: TextStyle(
            color: _isDark
                ? AppColors.darkTextPrimary
                : AppColors.lightTextPrimary,
          ),
          obscureText: state.loginPwdObscure,
          decoration: InputDecoration(
            hintText: t.passport.hintPassword,
            prefixIcon: const Icon(Icons.lock, color: AppColors.primary),
            suffixIcon: IconButton(
              icon: Icon(
                state.loginPwdObscure ? Icons.visibility : Icons.visibility_off,
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
          ),
        ),
        AppSpacing.verticalLarge,
        DebounceButton(
          text: t.common.nextStep,
          width: double.infinity,
          height: 50,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          textStyle: context.textStyle(
            FontSizeType.large,
            color: AppColors.onPrimary,
          ),
          onPressed: () async {
            FocusScope.of(context).unfocus();
            final nickname = _nicknameController.text.trim();
            if (nickname.isEmpty) {
              notifier.snackBar(t.common.nicknameEmptyError);
              return;
            }
            if (_fullMobile.isEmpty || _passwordController.text.isEmpty) {
              notifier.snackBar(
                t.common.errorEmptyDirectory(
                  param: "${t.account.mobile}/${t.account.password}",
                ),
              );
              return;
            }
            final error = await notifier.sendCode(
              'mobile',
              _fullMobile,
              'signup',
            );
            if (error == null) {
              notifier.setSignupData(
                account: _fullMobile,
                accountType: 'mobile',
                password: _passwordController.text,
                nickname: nickname,
              );
              if (mounted) {
                context.push('/sign_up/continue');
              }
            } else {
              notifier.snackBar(error);
            }
          },
        ),
      ],
    );
  }

  Widget _buildQuickLogin(PassportNotifier notifier) {
    // Placeholder for One-Click Login (JVerify usually)
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Divider(color: _isDark ? AppColors.darkBorder : null),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Text(
                "OR",
                style: TextStyle(
                  color: _isDark
                      ? AppColors.darkTextSecondary
                      : AppColors.iosGray,
                ),
              ),
            ),
            Expanded(
              child: Divider(color: _isDark ? AppColors.darkBorder : null),
            ),
          ],
        ),
        AppSpacing.verticalLarge,
        Semantics(
          label: t.passport.oneKeyLogin,
          button: true,
          child: InkWell(
            onTap: () {
              // Trigger JVerify or similar
              notifier.snackBar(
                "One-click login implementation pending JVerify setup",
              );
            },
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: _isDark ? AppColors.darkBorder : AppColors.lightBorder,
                ),
              ),
              child: const Icon(
                Icons.touch_app,
                color: AppColors.primary,
                size: 30,
              ),
            ),
          ),
        ),
        const SizedBox(height: 5),
        Text(
          t.passport.oneKeyLogin,
          style: context.textStyle(FontSizeType.small, color: _unselectedLabel),
        ),
      ],
    );
  }
}
