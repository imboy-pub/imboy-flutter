import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:imboy/component/ui/common_bar.dart';

import 'package:niku/namespace.dart' as n;

class NetworkFailureGuidancePage extends StatelessWidget {
  const NetworkFailureGuidancePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: NavAppBar(
        automaticallyImplyLeading: true,
        title: 'network_exception'.tr,
      ),
      body: Card(
        color: Theme.of(context).colorScheme.surface,
        child: n.Column(
          // mainAxisSize: MainAxisSize.min,
          [
            const ListTile(
              title: Text(
                '建议按照以下方法检查网络连接',
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 17.0,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              n.Row(
                [
                  Expanded(
                    child: n.Padding(
                      left: 16,
                      right: 6,
                      child: const Text(
                        "1.打开手机“设置”并把“Wi-Fi”开关保持开启状态。\n\n"
                        "2.打开手机“设置”-“通用”-“蜂窝移动网络”，并把“蜂窝移动数据”开关保持开启状态。\n\n"
                        "3.如果仍无法连接网络，请检查手机接入的“Wi-Fi”是否已接入互联网或者咨询网络运营商。",
                        // style: TextStyle(
                        //   color: XColors.textColor33,
                        //   fontSize: setSp(28),
                        // ),
                      ),
                    ),
                  ),
                ],
              ),
            ]),
          ],
        ),
      ),
    );
  }
}
