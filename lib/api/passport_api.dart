import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

Future<void> init(BuildContext context) async {
  try {
    // var result = await im.init();
    // debugPrint('初始化结果 ======> ${result}  ${result.toString()}');
  } on PlatformException {
    Get.snackbar('', '初始化失败');
  }
}

Future<void> login(BuildContext context, String account, String pwd) async {
  debugPrint(">>>>>>>>>>>>>>>>>>> on context {context}");
  // UserModel currentUser = UserRepository.currentUser();
  // try {
  //   Map resp1 = await DioUtil().get(API.init);
  //   String pub_key = resp1['payload']['login_rsa_pub_key'];
  //   final rsa_encrypt = resp1['payload']['login_pwd_rsa_encrypt'];
  //   if (rsa_encrypt == "1") {
  //     final parser = RSAKeyParser();
  //     final publicKey = parser.parse(pub_key);
  //     final encrypter = Encrypter(RSA(publicKey: publicKey));
  //     final encrypted = encrypter.encrypt(pwd);
  //
  //     pwd = encrypted.base64.toString();
  //   }
  //   Map resp2 = await DioUtil().post(API.login,
  //       data: {"account": account, "pwd": pwd, "rsa_encrypt": rsa_encrypt});
  //   if (resp2['code'] == 0) {
  //     debugPrint(">>>>>>>>>>>>>>>>>>> on logoin success ${resp2.toString()}");
  //
  //     currentUser.uid = resp2['payload']['uid']; // 进过hashids 计算的字符串
  //     currentUser.nickname = resp2['payload']['nickname'];
  //     currentUser.avatar = resp2['payload']['avatar'];
  //     currentUser.account = resp2['payload']['account'];
  //     currentUser.gender = resp2['payload']['gender'];
  //
  //     String token = resp2['payload']['token'];
  //     String refreshtoken = resp2['payload']['refreshtoken'];
  //
  //     await SharedUtil.instance.saveString(Keys.uid, resp2['payload']['uid']);
  //     await SharedUtil.instance
  //         .saveString(Keys.nickname, resp2['payload']['nickname']);
  //     await SharedUtil.instance
  //         .saveString(Keys.avatar, resp2['payload']['avatar']);
  //     await SharedUtil.instance
  //         .saveString(Keys.account, resp2['payload']['account']);
  //     await SharedUtil.instance
  //         .saveInt(Keys.gender, resp2['payload']['gender']);
  //     await SharedUtil.instance.saveString(Keys.token, token);
  //     await SharedUtil.instance.saveString(Keys.refreshtoken, refreshtoken);
  //     currentUser.refresh();
  //     await routePushAndRemove(new RootPage());
  //   } else {
  //     print('error::' + resp2.toString());
  //     showToast(context, resp2['msg']);
  //   }
  // } on PlatformException {
  //   showToast(context, '你已登录或者其他错误');
  // }
}

// 仅需刷新token
Future<void> refreshtoken() async {
  try {
//     String refreshtoken =
//     await SharedUtil.instance.getString(Keys.refreshtoken);
//     Map<String, dynamic> headers = {Keys.refreshtokenKey: refreshtoken};
//     Map resp1 = await DioUtil().get(API.refreshtoken, headers: headers);
//     debugPrint(">>>>>>>>>>>>>>>>>>> on refreshtoken >>>> ${resp1}");
//     if (resp1 != null && resp1['code'] == 0) {
//       String token = resp1['payload']['token'];
//       await SharedUtil.instance.saveString(Keys.token, token);
//     } else {
// //      showToast(context, resp1['msg']);
//     }
  } on PlatformException {
//    showToast(context, '刷新token失败');
  } on Exception catch (e) {
    // 任意一个异常
    print('Unknown exception: $e');
  } catch (e) {
    // 非具体类型
    print('Something really unknown: $e');
  }
}
