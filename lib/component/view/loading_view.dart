import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:imboy/component/ui/common.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/page/user/user_view.dart';

class LoadingView extends StatelessWidget {
  final bool isStr;

  const LoadingView({Key? key, this.isStr = true}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    var body = Center(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          InkWell(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                const Text(
                  '加载中',
                  style: TextStyle(color: AppColors.MainTextColor),
                ),
                isStr
                    ? const Text(
                        '第一次进点我',
                        style: TextStyle(
                            color: AppColors.MainTextColor, fontSize: 9),
                      )
                    : Container(),
              ],
            ),
            onTap: () {
              if (isStr) {
                Get.to(UserPage());
              }
            },
          ),
          const Space(),
          const SizedBox(
            width: 20.0,
            height: 20.0,
            child: CircularProgressIndicator(
              strokeWidth: 1.0,
              backgroundColor: Colors.transparent,
              // value: 0.2,
              valueColor:
                  AlwaysStoppedAnimation<Color>(AppColors.MainTextColor),
            ),
          )
        ],
      ),
    );

    return Scaffold(body: body);
  }
}
