import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:imboy/theme/default/app_spacing.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:imboy/component/ui/phone_input.dart';
import 'package:imboy/config/routes.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/passport/passport_notifier.dart';
import 'package:imboy/page/passport/passport_state.dart';
import 'package:imboy/page/passport/widget/bezier_container.dart';
import 'package:imboy/page/passport/widget/passport_title.dart';
import 'package:imboy/page/passport/widget/other_login_section.dart';
import 'package:imboy/theme/default/app_colors.dart';

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
  bool _isLoading = false;

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

    _nicknameController.addListener(() => setState(() {}));
    _emailController.addListener(() => setState(() {}));
    _passwordController.addListener(() => setState(() {}));
    _mobileController.addListener(() => setState(() {}));
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
                  SizedBox(height: height * 0.05),
                  const PassportTitle(color: AppColors.primary),
                  AppSpacing.verticalXLarge,

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
                  AppSpacing.verticalRegular,

                  SizedBox(
                    height: 290,
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        _buildEmailRegister(state, notifier),
                        _buildMobileRegister(state, notifier),
                      ],
                    ),
                  ),

                  AppSpacing.verticalRegular,
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton(
                        onPressed: () => context.go(AppRoutes.signIn),
                        child: Text(
                          t.main.siginQ,
                          style: const TextStyle(color: AppColors.iosGray),
                        ),
                      ),
                      TextButton(
                        onPressed: () => context.go(AppRoutes.signIn),
                        child: Text(
                          t.account.login,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),

                  AppSpacing.verticalLarge,
                  OtherLoginSection(
                    notifier: notifier,
                    isDark: _isDark,
                    showAlipay: true,
                    showOneKey: true,
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

  InputDecoration _getInputDecoration({
    required String hintText,
    required IconData prefixIcon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hintText,
      prefixIcon: Icon(prefixIcon, color: AppColors.primary, size: 20),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: _inputFill,
      contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(
          color: _isDark ? AppColors.darkBorder : AppColors.iosGray5,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.primary),
      ),
    );
  }

  Widget _buildEmailRegister(PassportState state, PassportNotifier notifier) {
    final bool isEnabled =
        _nicknameController.text.trim().isNotEmpty &&
        _emailController.text.trim().isNotEmpty &&
        _passwordController.text.isNotEmpty;

    return AutofillGroup(
      child: Column(
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
            readOnly: _isLoading,
            autofillHints: const [AutofillHints.nickname],
            decoration: _getInputDecoration(
              hintText: t.account.nicknameHint,
              prefixIcon: Icons.person_outline,
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
            readOnly: _isLoading,
            autofillHints: const [AutofillHints.email],
            decoration: _getInputDecoration(
              hintText: t.passport.hintEmail,
              prefixIcon: Icons.email,
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
            readOnly: _isLoading,
            autofillHints: const [AutofillHints.newPassword],
            decoration: _getInputDecoration(
              hintText: t.passport.hintPassword,
              prefixIcon: Icons.lock,
              suffixIcon: IconButton(
                tooltip: state.loginPwdObscure
                    ? t.common.showPassword
                    : t.common.hidePassword,
                icon: Icon(
                  state.loginPwdObscure
                      ? Icons.visibility
                      : Icons.visibility_off,
                ),
                onPressed: () => notifier.toggleLoginPwdObscure(),
              ),
            ),
          ),
          AppSpacing.verticalLarge,
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: (_isLoading || !isEnabled)
                  ? null
                  : () async {
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
                      setState(() => _isLoading = true);
                      final error = await notifier.sendCode(
                        'email',
                        email,
                        'signup',
                      );
                      if (mounted) setState(() => _isLoading = false);
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
              child: _isLoading
                  ? const CupertinoActivityIndicator(color: AppColors.onPrimary)
                  : Text(t.common.nextStep),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileRegister(PassportState state, PassportNotifier notifier) {
    final bool isEnabled =
        _nicknameController.text.trim().isNotEmpty &&
        _mobileController.text.trim().isNotEmpty &&
        _passwordController.text.isNotEmpty;

    return AutofillGroup(
      child: Column(
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
            readOnly: _isLoading,
            autofillHints: const [AutofillHints.nickname],
            decoration: _getInputDecoration(
              hintText: t.account.nicknameHint,
              prefixIcon: Icons.person_outline,
            ),
          ),
          const SizedBox(height: 15),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: _inputFill,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: _isDark ? AppColors.darkBorder : AppColors.iosGray5,
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
                setState(() {});
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
            readOnly: _isLoading,
            autofillHints: const [AutofillHints.newPassword],
            decoration: _getInputDecoration(
              hintText: t.passport.hintPassword,
              prefixIcon: Icons.lock,
              suffixIcon: IconButton(
                tooltip: state.loginPwdObscure
                    ? t.common.showPassword
                    : t.common.hidePassword,
                icon: Icon(
                  state.loginPwdObscure
                      ? Icons.visibility
                      : Icons.visibility_off,
                ),
                onPressed: () => notifier.toggleLoginPwdObscure(),
              ),
            ),
          ),
          AppSpacing.verticalLarge,
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: (_isLoading || !isEnabled)
                  ? null
                  : () async {
                      FocusScope.of(context).unfocus();
                      final nickname = _nicknameController.text.trim();
                      if (nickname.isEmpty) {
                        notifier.snackBar(t.common.nicknameEmptyError);
                        return;
                      }
                      if (_fullMobile.isEmpty ||
                          _passwordController.text.isEmpty) {
                        notifier.snackBar(
                          t.common.errorEmptyDirectory(
                            param: "${t.account.mobile}/${t.account.password}",
                          ),
                        );
                        return;
                      }
                      setState(() => _isLoading = true);
                      final error = await notifier.sendCode(
                        'mobile',
                        _fullMobile,
                        'signup',
                      );
                      if (mounted) setState(() => _isLoading = false);
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
              child: _isLoading
                  ? const CupertinoActivityIndicator(color: AppColors.onPrimary)
                  : Text(t.common.nextStep),
            ),
          ),
        ],
      ),
    );
  }
}
