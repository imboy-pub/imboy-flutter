import 'package:flutter/material.dart';
import 'package:flutter_login/flutter_login.dart';
import 'package:get/get.dart';
import 'package:imboy/config/theme.dart';
import 'package:imboy/page/bottom_navigation/bottom_navigation_view.dart';
import 'package:imboy/store/repository/user_repo_local.dart';

import 'passport_logic.dart';

class PassportPage extends StatelessWidget {
  final PassportLogic logic = Get.put(PassportLogic());

  @override
  Widget build(BuildContext context) {
    debugPrint(
        ">>> on passport view build ${UserRepoLocal.to.lastLoginAccount}");
    LoginUserType userType = LoginUserType.email;
    String userHint = 'hint_login_email'.tr;
    if (userType == LoginUserType.phone) {
      userHint = 'hint_login_phone'.tr;
    } else if (userType == LoginUserType.name) {
      userHint = 'hint_login_account'.tr;
    }
    return FlutterLogin(
      title: 'IMBoy',
      logo: AssetImage('assets/images/logo.png'),
      userType: userType,
      messages: LoginMessages(
        // button
        loginButton: 'button_login'.tr,
        signupButton: 'button_signup'.tr,
        goBackButton: 'button_back'.tr,
        confirmSignupButton: 'button_confirm'.tr,
        resendCodeButton: 'button_resend_code'.tr,
        forgotPasswordButton: 'button_forgotpassword'.tr,
        recoverPasswordButton: 'button_recoverpassword'.tr,
        additionalSignUpSubmitButton: 'button_submit'.tr,
        // hint
        userHint: userHint,
        passwordHint: 'hint_login_password'.tr,
        confirmPasswordHint: 'hint_login_confirmpassword'.tr,
        confirmationCodeHint: 'hint_login_confirmationcode'.tr,
        recoveryCodeHint: 'hint_login_recoverycode'.tr,
        // tip
        confirmSignupIntro: 'tip_sigup_intro'.tr,
        confirmationCodeValidationError: 'tip_confirmationcode_error'.tr,
        confirmSignupSuccess: 'tip_confirmationcode_success'.tr,
        resendCodeSuccess: 'tip_resendcode_success'.tr,
        providersTitleFirst: 'tip_providers_title_first'.tr,
        confirmPasswordError: 'error_confirmpassword'.tr,
        recoverPasswordIntro: 'tip_recoverpassword_intro'.tr,
        recoverPasswordDescription: 'tip_recoverpassword_desc'.tr,
        recoverPasswordSuccess: 'tip_recoverpassword_success'.tr,
        recoverCodePasswordDescription: 'tip_recovercodepassword_desc'.tr,
        additionalSignUpFormDescription: 'tip_sigup_form_desc'.tr,
        flushbarTitleError: 'tip_title'.tr,
        flushbarTitleSuccess: 'tip_success'.tr,
      ),
      userValidator: (value) {
        return logic.userValidator(userType, value ?? '');
      },
      savedEmail: UserRepoLocal.to.lastLoginAccount,
      savedPassword: "",
      passwordValidator: logic.passwordValidator,
      onLogin: logic.loginUser,
      onSignup: logic.signupUser,
      // 注册确认码
      onConfirmSignup: logic.onConfirmSignup,
      // 重新发送确认码
      onResendCode: logic.onResendCode,
      // 确认找回密码
      onConfirmRecover: logic.onConfirmRecover,
      onSubmitAnimationCompleted: () {
        debugPrint(">>> on login onSubmitAnimationCompleted");
        Get.off(() => BottomNavigationPage());
      },
      onRecoverPassword: logic.onRecoverPassword,
      hideForgotPasswordButton: true,
      theme: loginTheme,
      scrollable: true,
      loginAfterSignUp: false,
      navigateBackAfterRecovery: true,
      // showDebugButtons: true,
      loginProviders: [
        // LoginProvider(
        //   button: Buttons.LinkedIn,
        //   label: 'Sign in with LinkedIn',
        //   callback: () async {
        //     return null;
        //   },
        //   providerNeedsSignUpCallback: () {
        //     // put here your logic to conditionally show the additional fields
        //     return Future.value(true);
        //   },
        // ),
        // LoginProvider(
        //   icon: FontAwesomeIcons.google,
        //   label: 'Google',
        //   callback: () async {
        //     return null;
        //   },
        // ),
        // LoginProvider(
        //   icon: FontAwesomeIcons.githubAlt,
        //   label: 'Github',
        //   callback: () async {
        //     debugPrint('start github sign in');
        //     await Future.delayed(loginTime);
        //     debugPrint('stop github sign in');
        //     return null;
        //   },
        // ),
      ],
      termsOfService: [
        // TermOfService(
        //   id: 'newsletter',
        //   mandatory: false,
        //   text: 'Newsletter subscription',
        // ),
        TermOfService(
          id: 'general-term',
          mandatory: true,
          text: 'title_termofservices'.tr,
          validationErrorMessage:
              'error_required'.trArgs(['title_termofservices'.tr]),
          linkUrl: 'http://www.imboy.pub/',
        ),
      ],
      // additionalSignupFields: [
      //   UserFormField(
      //     keyName: 'invite_code',
      //     displayName: 'button_invite_code'.tr,
      //   ),
      // ],
    );
  }
}
