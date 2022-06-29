import 'package:flutter/material.dart';
import 'package:flutter_login/flutter_login.dart';
import 'package:get/get.dart';
import 'package:imboy/component/helper/datetime.dart';
import 'package:imboy/config/theme.dart';
import 'package:imboy/page/bottom_navigation/bottom_navigation_view.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:jiffy/jiffy.dart';

import 'passport_logic.dart';

class PassportPage extends StatelessWidget {
  final PassportLogic logic = Get.put(PassportLogic());

  PassportPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    LoginUserType userType = LoginUserType.email;
    String userHint = 'hint_login_email'.tr;
    if (userType == LoginUserType.phone) {
      userHint = 'hint_login_phone'.tr;
    } else if (userType == LoginUserType.name) {
      userHint = 'hint_login_account'.tr;
    }
    var args = Get.arguments;
    String msgtype = "";
    if (args is Map<String, dynamic>) {
      msgtype = args["msgtype"] ?? "";
    }
    if (msgtype == "786" && args is Map<String, dynamic>) {
      String dname = args['dname'] ?? '';
      if (dname == "") {
        dname = "其他";
      } else {
        dname = "[$dname]";
      }
      int mts = args['server_ts'] ?? DateTimeHelper.currentTimeMillis;
      String hm = Jiffy.unixFromMillisecondsSinceEpoch(mts).format("H:m");
      // "logged_in_on_another_device":"你的账号于%s在%s设备上登录了",
      Future.delayed(const Duration(milliseconds: 500), () {
        Get.defaultDialog(
          title: '',
          content: Text('info_logged_in_on_another_device'.trArgs([hm, dname])),
          barrierDismissible: false,
          confirm: TextButton(
            onPressed: () {
              Get.back();
            },
            child: Text('button_confirm'.tr),
            style: ButtonStyle(
              backgroundColor: MaterialStateProperty.all<Color>(Colors.white70),
            ),
          ),
        );
      });
    }
    return Container(
      decoration: const BoxDecoration(
        //背景Colors.transparent 透明
        color: Colors.transparent,
        image: DecorationImage(
          image: AssetImage("assets/images/splash_bg.png"),
          fit: BoxFit.cover,
        ),
      ),
      child: FlutterLogin(
        title: 'IMBoy',
        logo: const AssetImage('assets/images/logo.png'),
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
          setPasswordButton: 'button_setpassword'.tr,
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
          confirmRecoverIntro: 'tip_confirmrecover_intro'.tr,
          confirmPasswordError: 'error_confirmpassword'.tr,
          recoverPasswordDescription: 'tip_recoverpassword_desc'.tr,
          recoverPasswordSuccess: 'tip_recoverpassword_success'.tr,
          recoverCodePasswordDescription: 'tip_recovercodepassword_desc'.tr,
          additionalSignUpFormDescription: 'tip_sigup_form_desc'.tr,
          flushbarTitleError: 'tip_title'.tr,
          flushbarTitleSuccess: 'tip_success'.tr,
          recoverPasswordIntro: 'tip_recoverpassword_intro'.tr,
          recoveryCodeValidationError:
              'error_empty_directory'.trArgs(['hint_login_recoverycode'.tr]),
          confirmRecoverSuccess: 'tip_confirmrecover_success'.tr,
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
          // debugPrint(">>> on login onSubmitAnimationCompleted");
          Get.off(() => BottomNavigationPage());
        },
        onRecoverPassword: logic.onRecoverPassword,
        hideForgotPasswordButton: false,
        theme: loginTheme,
        scrollable: true,
        loginAfterSignUp: false,
        navigateBackAfterRecovery: true,
        // showDebugButtons: true,
        loginProviders: const [
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
      ),
    );
  }
}
