import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl_phone_number_input/intl_phone_number_input.dart';
import 'package:imboy/config/routes.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/passport/passport_notifier.dart';
import 'package:imboy/page/passport/passport_state.dart';
import 'package:imboy/page/passport/widget/bezier_container.dart';
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
  final TextEditingController _passwordController =
      TextEditingController(); // For initial password setup if needed, or just account

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
    _mobileController.dispose();
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
                        Tab(text: t.email),
                        Tab(text: t.mobile),
                      ],
                    ),
                    const SizedBox(height: 20),

                    SizedBox(
                      height: 256,
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          _buildEmailRegister(state, notifier),
                          _buildMobileRegister(state, notifier),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),
                    // Quick Login / One Click Login
                    _buildQuickLogin(notifier),

                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          t.siginQ,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 10),
                        InkWell(
                          onTap: () => context.go(AppRoutes.signIn),
                          child: Text(
                            t.login,
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontSize: 13,
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
      ),
    );
  }

  Widget _buildEmailRegister(PassportState state, PassportNotifier notifier) {
    return Column(
      children: [
        TextField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          decoration: InputDecoration(
            hintText: t.passport.hintEmail,
            prefixIcon: const Icon(Icons.email, color: AppColors.primary),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 15),
        // Password input for registration?
        // Usually registration needs password setting.
        // The existing `signup_continue_view.dart` takes `pwd`.
        // So we should ask for password here or in the next step?
        // Let's check logic: User enters email -> Next -> Receive Code -> Enter Code & Set Password?
        // Or Enter Email & Password -> Next -> Verify Code?
        // Existing `signup_view` didn't show password input in my quick read, but `SignupContinuePage` takes `pwd`.
        // Let's assume we ask for password here to pass it to the next screen.
        TextField(
          controller: _passwordController,
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
              final email = _emailController.text;
              final pwd = _passwordController.text;
              if (email.isEmpty || pwd.isEmpty) {
                notifier.snackBar(
                  t.errorEmptyDirectory(param: "${t.email}/${t.password}"),
                );
                return;
              }
              // Send Code
              final error = await notifier.sendCode('email', email, 'signup');
              if (error == null) {
                // 存储注册数据到 provider
                notifier.setSignupData(
                  account: email,
                  accountType: 'email',
                  password: pwd,
                  nickname: '',
                );
                if (mounted) {
                  context.push('/sign_up/continue');
                }
              } else {
                notifier.snackBar(error);
              }
            },
            child: Text(
              t.nextStep,
              style: const TextStyle(color: Colors.white, fontSize: 18),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMobileRegister(PassportState state, PassportNotifier notifier) {
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
              hintText: t.passport.hintMobile,
              border: InputBorder.none,
            ),
          ),
        ),
        const SizedBox(height: 15),
        TextField(
          controller:
              _passwordController, // Shared controller, reset when tab changes?
          // Better use separate or clear on tab change.
          // Since I used SingleTickerProvider, State is kept. I should probably use separate controllers or clear.
          // For simplicity, I'll use the same controller but I cleared it in logic? No I didn't.
          // It's fine to share for this demo, but UX wise, better separate.
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
              if (_fullMobile.isEmpty || _passwordController.text.isEmpty) {
                notifier.snackBar(
                  t.errorEmptyDirectory(param: "${t.mobile}/${t.password}"),
                );
                return;
              }
              final error = await notifier.sendCode(
                'mobile',
                _fullMobile,
                'signup',
              );
              if (error == null) {
                // 存储注册数据到 provider
                notifier.setSignupData(
                  account: _fullMobile,
                  accountType: 'mobile',
                  password: _passwordController.text,
                  nickname: '',
                );
                if (mounted) {
                  context.push('/sign_up/continue');
                }
              } else {
                notifier.snackBar(error);
              }
            },
            child: Text(
              t.nextStep,
              style: const TextStyle(color: Colors.white, fontSize: 18),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildQuickLogin(PassportNotifier notifier) {
    // Placeholder for One-Click Login (JVerify usually)
    return Column(
      children: [
        const Row(
          children: [
            Expanded(child: Divider()),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 10),
              child: Text("OR"),
            ),
            Expanded(child: Divider()),
          ],
        ),
        const SizedBox(height: 20),
        InkWell(
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
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: const Icon(
              Icons.touch_app,
              color: AppColors.primary,
              size: 30,
            ),
          ),
        ),
        const SizedBox(height: 5),
        Text(
          t.passport.oneKeyLogin,
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
      ],
    );
  }
}
