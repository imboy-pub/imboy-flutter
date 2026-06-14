import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:imboy/component/ui/phone_input.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/passport/passport_notifier.dart';
import 'package:imboy/page/passport/passport_state.dart';
import 'package:imboy/page/passport/widget/bezier_container.dart';
import 'package:imboy/page/passport/widget/passport_title.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/page/passport/forgot_password_pin_code_page.dart';

class ForgotPasswordPage extends ConsumerStatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  ConsumerState<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends ConsumerState<ForgotPasswordPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _mobileController = TextEditingController();
  String _fullMobile = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _emailController.dispose();
    _mobileController.dispose();
    super.dispose();
  }

  bool get _isDark => Theme.of(context).brightness == Brightness.dark;
  Color get _inputFill =>
      _isDark ? AppColors.darkSurfaceContainer : Colors.white;
  Color get _unselectedLabel =>
      _isDark ? AppColors.darkTextSecondary : AppColors.iosGray;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(passportProvider);
    final notifier = ref.read(passportProvider.notifier);
    final height = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: _isDark ? AppColors.darkSurface : null,
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
                    const PassportTitle(color: AppColors.primary),
                    const SizedBox(height: 40),

                    Text(
                      t.account.recoverPassword,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: _isDark
                            ? AppColors.darkTextPrimary
                            : AppColors.lightTextPrimary,
                      ),
                    ),
                    const SizedBox(height: 30),

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
                    const SizedBox(height: 20),

                    SizedBox(
                      height: 200,
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          _buildEmailInput(state, notifier),
                          _buildMobileInput(state, notifier),
                        ],
                      ),
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

  Widget _buildEmailInput(PassportState state, PassportNotifier notifier) {
    return Column(
      children: [
        TextField(
          controller: _emailController,
          style: TextStyle(
            color: _isDark
                ? AppColors.darkTextPrimary
                : AppColors.lightTextPrimary,
          ),
          keyboardType: TextInputType.emailAddress,
          decoration: InputDecoration(
            hintText: t.main.pleaseInputParam(param: t.account.email),
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
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () async {
              final email = _emailController.text;
              if (email.isEmpty) {
                notifier.snackBar(
                  t.common.errorEmptyDirectory(param: t.account.email),
                );
                return;
              }
              final error = await notifier.sendCode(
                'email',
                email,
                'reset_pwd',
              );
              if (error == null) {
                if (mounted) {
                  Navigator.push(
                    context,
                    CupertinoPageRoute<dynamic>(
                      builder: (context) => PinCodeVerificationPage(
                        account: email,
                        accountType: 'email',
                      ),
                    ),
                  );
                }
              } else {
                notifier.snackBar(error);
              }
            },
            child: Text(
              t.common.nextStep,
              style: const TextStyle(color: Colors.white, fontSize: 18),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMobileInput(PassportState state, PassportNotifier notifier) {
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
              _mobileController.text = fullNumber.replaceFirst(
                RegExp(r'^\+\d+'),
                '',
              );
            },
            hintText: t.main.pleaseInputParam(param: t.account.mobile),
          ),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () async {
              if (_fullMobile.isEmpty) {
                notifier.snackBar(
                  t.common.errorEmptyDirectory(param: t.account.mobile),
                );
                return;
              }
              final error = await notifier.sendCode(
                'mobile',
                _fullMobile,
                'reset_pwd',
              );
              if (error == null) {
                if (mounted) {
                  Navigator.push(
                    context,
                    CupertinoPageRoute<dynamic>(
                      builder: (context) => PinCodeVerificationPage(
                        account: _fullMobile,
                        accountType: 'mobile',
                      ),
                    ),
                  );
                }
              } else {
                notifier.snackBar(error);
              }
            },
            child: Text(
              t.common.nextStep,
              style: const TextStyle(color: Colors.white, fontSize: 18),
            ),
          ),
        ),
      ],
    );
  }
}
