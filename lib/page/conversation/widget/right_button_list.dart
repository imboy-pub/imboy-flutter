import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:niku/namespace.dart' as n;
import 'package:popover/popover.dart';

import 'package:imboy/page/scanner/scanner_view.dart';
import 'package:imboy/page/uqrcode/uqrcode_view.dart';
import 'package:imboy/page/friend/add_friend_view.dart';

class RightButton extends StatelessWidget {
  const RightButton({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      child: const SizedBox(
        width: 46.0,
        child: Icon(
          Icons.add_circle_outline_sharp,
          color: Colors.black54,
        ),
      ),
      onTap: () {
        showPopover(
          context: context,
          bodyBuilder: (context) => const RightButtonList(),
          // onPop: () => print('Popover was popped!'),
          direction: PopoverDirection.top,
          barrierColor: Colors.black54,
          backgroundColor: Colors.black54,
          // barrierDismissible: false,
          // shadow: const [BoxShadow(color: Colors.white, blurRadius: 5)],
          width: 128,
          height: 180,
          arrowHeight: 6,
          arrowWidth: 20,
          arrowDxOffset: 0,
          arrowDyOffset: -10,
        );
      },
    );
  }
}

class ItemTitleStyle {
  static final style = n.Text('')
    ..color = Colors.white.withOpacity(0.9)
    ..fontSize = 14
    ..bold;
}

class RightButtonList extends StatelessWidget {
  const RightButtonList({Key? key}) : super(key: key);
  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black54,
      padding: EdgeInsets.symmetric(vertical: GetPlatform.isDesktop ? 24 : 8),
      child: n.ListView.children([
        InkWell(
          onTap: () {
            Get.close(1);
            /*
            Get.to(
              () => AddFriendPage(),
              transition: Transition.rightToLeft,
              popGesture: true, // 右滑，返回上一页
            );
            */
          },
          child: n.Row([
            n.Padding(
              left: 12,
              right: 8,
              child: n.Icon(Icons.chat_bubble_outlined)
                ..size = 18
                ..color = Colors.white.withOpacity(0.9),
            ),
            n.Text(
              '发起群聊'.tr,
            )..apply = ItemTitleStyle.style,
          ]),
        ),
        const SizedBox(height: 16),
        InkWell(
          onTap: () {
            Get.close(1);
            Get.to(
              () => AddFriendPage(),
              transition: Transition.rightToLeft,
              popGesture: true, // 右滑，返回上一页
            );
          },
          child: n.Row([
            n.Padding(
              left: 12,
              right: 8,
              child: n.Icon(Icons.person_add_alt_1)
                ..size = 18
                ..color = Colors.white.withOpacity(0.9),
            ),
            n.Text(
              '添加朋友'.tr,
            )..apply = ItemTitleStyle.style,
          ]),
        ),
        const SizedBox(height: 16),
        InkWell(
          onTap: () {
            Get.close(1);
            Get.to(
              () => UqrcodePage(),
              transition: Transition.rightToLeft,
              popGesture: true, // 右滑，返回上一页
            );
          },
          child: n.Row([
            n.Padding(
              left: 12,
              right: 8,
              child: n.Icon(Icons.qr_code_2)
                ..size = 18
                ..color = Colors.white.withOpacity(0.9),
            ),
            n.Text(
              '我的二维码'.tr,
            )..apply = ItemTitleStyle.style,
          ]),
        ),
        const SizedBox(height: 16),
        InkWell(
          onTap: () {
            Get.close(1);
            Get.to(
              () => const ScannerPage(),
              transition: Transition.rightToLeft,
              popGesture: true, // 右滑，返回上一页
            );
          },
          child: n.Row([
            n.Padding(
              left: 12,
              right: 8,
              child: n.Icon(Icons.qr_code_scanner_outlined)
                ..size = 18
                ..color = Colors.white.withOpacity(0.9),
            ),
            n.Text(
              '扫一扫'.tr,
            )..apply = ItemTitleStyle.style,
          ]),
        ),
      ]),
    );
  }
}
