import 'package:flutter/material.dart';
import 'package:imboy/helper/constant.dart';

class AlreadHaveAnAccountCheck extends StatelessWidget {
  final bool login;
  final GestureTapCallback onTap;
  const AlreadHaveAnAccountCheck({
    Key key,
    this.login,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          login ? "Don't have a Accont？" : "Already have a Accont ? ",
          style: TextStyle(color: Color(AppColors.ButtonArrowColor)),
        ),
        GestureDetector(
          onTap: onTap,
          child: Text(
            login ? 'Sign up' : "Sign in",
            style: TextStyle(
                color: Color(AppColors.ButtonArrowColor),
                fontWeight: FontWeight.bold),
          ),
        )
      ],
    );
  }
}
