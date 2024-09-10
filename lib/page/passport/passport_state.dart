import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';

class PassportState {

  // 网络状态描述
  RxString connectDesc = "".obs;

  RxString error = "".obs;

  TextEditingController loginAccountCtl = TextEditingController();

  RxString nickname = ''.obs;
  RxString mobile = ''.obs;

  // 手机号码格式验证
  RxBool mobileValidated = false.obs;

  // 注册页面“同意并继续”按钮是否高亮
  RxBool showSignupContinue = false.obs;
  RxString loginAccount = ''.obs;
  RxString loginPwd = ''.obs;
  RxBool loginPwdObscure = true.obs;
  RxList<String> loginHistory = <String>[].obs;

  //
  RxString existingPwd = ''.obs;
  RxString newPwd = ''.obs;
  RxString retypePwd = ''.obs;

  RxBool existingPwdObscure = true.obs;
  RxBool newPwdObscure = true.obs;
  RxBool retypePwdObscure = true.obs;

  RxString selectedAgreement = ''.obs;


  // late AccountAuthService authServiceHW;

  PassportState() {
    ///Initialize variables
  }
}
