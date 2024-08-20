import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_login/flutter_login.dart';
import 'package:get/get.dart';
import 'package:imboy/component/ui/icon_image_provider.dart';
import 'package:imboy/component/ui/imboy_icon.dart';
import 'package:jiffy/jiffy.dart';
import 'package:niku/namespace.dart' as n;

import 'package:imboy/component/helper/datetime.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/component/ui/network_failure_tips.dart';
import 'package:imboy/config/init.dart';
import 'package:imboy/config/theme.dart';
import 'package:imboy/page/bottom_navigation/bottom_navigation_view.dart';
import 'package:imboy/store/repository/user_repo_local.dart';

import 'passport_logic.dart';

class PassportPage extends StatelessWidget {
  final PassportLogic logic = Get.put(PassportLogic());

  PassportPage({super.key});

  @override
  Widget build(BuildContext context) {
    iPrint("BottomNavigationPage passport");
    // 检查网络状态
    Connectivity().checkConnectivity().then((r) {
      if (r.contains(ConnectivityResult.none)) {
        // ignore: prefer_interpolation_to_compose_strings
        logic.connectDesc.value = 'tip_connect_desc'.tr;
      } else {
        logic.connectDesc.value = '';
      }
    });
    // 监听网络状态
    Connectivity().onConnectivityChanged.listen((List<ConnectivityResult> r) {
      if (r.contains(ConnectivityResult.none)) {
        // ignore: prefer_interpolation_to_compose_strings
        logic.connectDesc.value = 'tip_connect_desc'.tr;
      } else {
        logic.connectDesc.value = '';
      }
    });
    LoginUserType userType = LoginUserType.email;
    String userHint = 'email'.tr;
    if (userType == LoginUserType.phone) {
      userHint = 'mobile'.tr;
    } else if (userType == LoginUserType.name) {
      userHint = 'hint_login_account'.tr;
    }
    var args = Get.arguments;
    String msgType = "";
    if (args is Map<String, dynamic>) {
      msgType = args["msg_type"] ?? "";
    }
    if (msgType == "logged_another_device" && args is Map<String, dynamic>) {
      String deviceName = args['dname'] ?? '';
      if (deviceName == "") {
        deviceName = "其他".tr;
      } else {
        deviceName = "[$deviceName]";
      }
      int mts = args['server_ts'] ?? DateTimeHelper.utc();
      String hm = Jiffy.parseFromMillisecondsSinceEpoch(
              mts + DateTime.now().timeZoneOffset.inMilliseconds)
          .format(pattern: "H:m");
      // "logged_in_on_another_device":"你的账号于%s在%s设备上登录了",
      Future.delayed(const Duration(milliseconds: 500), () {
        n.showDialog(
          context: Get.context!,
          builder: (context) => n.Alert()
            // ..title = Text("Session Expired")
            ..content = SizedBox(
              height: 40,
              child: Center(
                child: Text(
                  'info_logged_in_on_another_device'.trArgs([hm, deviceName]),
                ),
              ),
            )
            ..actions = [
              n.Button('button_confirm'.tr.n)
                ..style = n.NikuButtonStyle(
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                )
                ..onPressed = () {
                  Navigator.of(context).pop();
                },
            ],
          barrierDismissible: false,
        );
      });
    }
    return Scaffold(
        body: n.Column([
      // const SizedBox(height: 40),
      Obx(() {
        return logic.connectDesc.isEmpty
            ? const SizedBox.shrink()
            : n.Padding(
                top: 0,
                child: NetworkFailureTips(backgroundColor: Colors.green),
              );
      }),
      Expanded(
        child: FlutterLogin(
          title: appName,
          logo: IconImageProvider(
            IMBoyIcon.imboyLogo,
            size: 80,
            color: Colors.white,
          ),
          userType: userType,
          messages: LoginMessages(
            // button
            loginButton: 'button_login'.tr,
            signupButton: 'button_signup'.tr,
            goBackButton: 'button_back'.tr,
            confirmSignupButton: 'button_confirm'.tr,
            resendCodeButton: 'button_resend_code'.tr,
            forgotPasswordButton: 'forgot_password'.tr,
            recoverPasswordButton: 'recover_password'.tr,
            additionalSignUpSubmitButton: 'button_submit'.tr,
            setPasswordButton: 'set_param'.trArgs(['password'.tr]),
            // hint
            userHint: userHint,
            passwordHint: 'password'.tr,
            confirmPasswordHint: 'retype_password'.tr,
            confirmationCodeHint: 'confirm_code'.tr,
            recoveryCodeHint: 'confirm_code'.tr,
            // tip
            confirmSignupIntro: 'signup_intro'.tr,
            confirmationCodeValidationError: 'confirm_code_error'.tr,
            confirmSignupSuccess: 'confirm_code_success'.tr,
            resendCodeSuccess: 'resend_code_success'.tr,
            providersTitleFirst: 'tip_providers_title_first'.tr,
            confirmRecoverIntro: 'confirm_recover_intro'.tr,
            confirmPasswordError: 'error_retype_password'.tr,
            recoverPasswordDescription: 'recover_password_desc'.tr,
            recoverPasswordSuccess: 'recover_password_success'.tr,
            recoverCodePasswordDescription: 'recover_code_password_desc'.tr,
            additionalSignUpFormDescription: 'signup_form_desc'.tr,
            flushbarTitleError: 'tip_title'.tr,
            flushbarTitleSuccess: 'tip_success'.tr,
            recoverPasswordIntro: 'recover_password_intro'.tr,
            recoveryCodeValidationError:
                'error_empty_directory'.trArgs(['confirm_code'.tr]),
            confirmRecoverSuccess: 'confirm_recover_success'.tr,
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
            // debugPrint("> on login onSubmitAnimationCompleted");
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
            /*
            LoginProvider(
              // button: Buttons.microsoft,
              icon: Icons.phone_iphone,
              label: 'sign_in_with'.trArgs(['mobile'.tr]),
              callback: () async {
                return null;
              },
              providerNeedsSignUpCallback: () {
                // put here your logic to conditionally show the additional fields
                return Future.value(true);
              },
            ),
            LoginProvider(
              button: Buttons.email,
              label: 'sign_in_with'.trArgs(['email'.tr]),
              callback: () async {
                return null;
              },
              providerNeedsSignUpCallback: () {
                // put here your logic to conditionally show the additional fields
                return Future.value(true);
              },
            ),
            LoginProvider(
              icon: IMBoyIcon.huawei,
              label: 'sign_in_with'.trArgs(['Huawei'.tr]),
              callback: () async {
                return null;
              },
              providerNeedsSignUpCallback: () {
                // put here your logic to conditionally show the additional fields
                return Future.value(true);
              },
            ),
            */
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
              text: 'term_of_services'.tr,
              validationErrorMessage:
                  'error_required'.trArgs(['term_of_services'.tr]),
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
      ),
    ]));
  }
}
