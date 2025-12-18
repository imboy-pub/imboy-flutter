import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';

class PassportState {

  // 网络状态描述
  RxString connectDesc = "".obs;

  RxString error = "".obs;

  TextEditingController loginAccountCtl = TextEditingController();

  RxString nickname = ''.obs;
  RxString mobile = ''.obs;

  // accountType: 'mobile' | 'email'
  RxString accountType = 'mobile'.obs;

  // 注册使用的 email 字段（用于邮箱注册）
  RxString email = ''.obs;

  // 手机号码格式验证（也用于 email 注册时表示账号格式验证通过）
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