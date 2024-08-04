import 'package:get/get.dart';

class ChangePasswordState {
  ChangePasswordState() {
    ///Initialize variables
  }

  RxString existingPwd = ''.obs;
  RxString newPwd = ''.obs;
  RxString retypePwd = ''.obs;

  RxBool existingPwdObscure = true.obs;
  RxBool newPwdObscure = true.obs;
  RxBool retypePwdObscure = true.obs;
}
