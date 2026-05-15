import 'package:flutter/material.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:go_router/go_router.dart';

// ignore: must_be_immutable
class NetworkFailureTips extends StatelessWidget {
  Color? backgroundColor;

  NetworkFailureTips({super.key, this.backgroundColor});

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
          // 使用 go_router 替代 Get.to()
          context.push('/network-failure-guidance');
        },
        child: Row(
          // 直接使用 Flutter 的 Row
          children: [
            const Padding(
              padding: EdgeInsets.only(left: 10),
              child: Icon(Icons.info_sharp, color: Colors.red),
            ),
            Expanded(
              child: Text(
                // '当前网络不可用，请检查你的网络设置。',
                "${t.common.networkNotAvailable}${t.error.pleaseCheckNetwork}",
                // '当前网络不可用，请检查你的网络设置。当前网络不可用，请检查你的网络设置。当前网络不可用，请检查你的网络设置。',
                style: const TextStyle(color: Colors.red),
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              // color: AppColors.LabelTextColor,
            ),
          ],
        ),
      ),
    );
  }
}
