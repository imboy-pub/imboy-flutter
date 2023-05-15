import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/page/single/network_failure_guidance.dart';
import 'package:get/get.dart' as getx;
import 'package:niku/namespace.dart' as n;

// ignore: must_be_immutable
class NetworkFailureTips extends StatelessWidget {
  Color? backgroundColor;

  NetworkFailureTips({Key? key, this.backgroundColor}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      color: backgroundColor ?? const Color.fromRGBO(247, 226, 230, 1),
      child: RawMaterialButton(
        // highlightColor是点击的时候的高亮效果
        // highlightColor: const Color.fromRGBO(247, 226, 230, 1),
        // splashColor 是点击后不松手的扩散效果
        splashColor: const Color.fromRGBO(247, 226, 230, 1),
        onPressed: () {
          getx.Get.to(()=>
            const NetworkFailureGuidancePage(),
            transition: Transition.rightToLeft,
            popGesture: true, // 右滑，返回上一页
          );
        },
        child: n.Row([
          n.Padding(
              left: 10,
              child: const Icon(
                Icons.info_sharp,
                color: Colors.red,
              )),
          Expanded(
              child: Text(
            // '当前网络不可用。'.tr,
            '当前网络不可用，请检查你的网络设置。'.tr,
            // '当前网络不可用，请检查你的网络设置。当前网络不可用，请检查你的网络设置。当前网络不可用，请检查你的网络设置。'.tr,
            style: const TextStyle(color: Colors.red),
          )),
          const Icon(
            Icons.chevron_right_rounded,
            color: AppColors.LabelTextColor,
          )
        ]),
      ),
    );
  }
}
