import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:imboy/config/const.dart';

class AlreadHaveAnAccountCheck extends StatelessWidget {
  final bool? login;
  final GestureTapCallback? onTap;
  const AlreadHaveAnAccountCheck({
    Key? key,
    this.login,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          (login! ? 'tip_login_false'.tr : 'tip_login_true'.tr) + ' ',
          style: TextStyle(color: Color(AppColors.ButtonArrowColor)),
        ),
        GestureDetector(
          onTap: onTap,
          child: Text(
            login! ? 'button_sign_in'.tr : 'button_login'.tr,
            style: TextStyle(
                color: Color(AppColors.ButtonArrowColor),
                fontWeight: FontWeight.bold),
          ),
        )
      ],
    );
  }
}
