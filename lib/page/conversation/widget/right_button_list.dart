import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:imboy/page/chat/launch_chat/launch_chat_view.dart';
import 'package:imboy/page/contact/add_friend/add_friend_view.dart';
import 'package:imboy/page/contact/recently_registered_user/recently_registered_user_view.dart';
import 'package:imboy/page/scanner/scanner_view.dart';
import 'package:imboy/page/uqrcode/uqrcode_view.dart';
import 'package:niku/namespace.dart' as n;
import 'package:popover/popover.dart';

class RightButton extends StatelessWidget {
  const RightButton({super.key});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      child: n.Padding(
          top: 10,
          bottom: 10,
          child: const SizedBox(
            width: 46.0,
            child: Icon(
              Icons.add_circle_outline_sharp,
              color: Colors.black54,
            ),
          )),
      onTap: () {
        showPopover(
          context: context,
          bodyBuilder: (context) => const RightButtonList(),
          direction: PopoverDirection.left,
          barrierColor: Colors.black54,
          backgroundColor: Colors.black54,
          // barrierDismissible: false,
          // shadow: const [BoxShadow(color: Colors.white, blurRadius: 5)],
          width: 132,
          height: 230,
          arrowHeight: 6,
          arrowWidth: 20,
          arrowDxOffset: 0,
          contentDxOffset: 0,
          arrowDyOffset: 0,
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
  const RightButtonList({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black54,
      padding: EdgeInsets.symmetric(vertical: GetPlatform.isDesktop ? 24 : 8),
      child: n.ListView.children([
        InkWell(
          onTap: () {
            Navigator.of(context).pop();
            Get.to(
              () => LaunchChatPage(),
              transition: Transition.rightToLeft,
              popGesture: true, // 右滑，返回上一页
            );
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
              'initiate_chat'.tr,
            )..apply = ItemTitleStyle.style,
          ]),
        ),
        const SizedBox(height: 20),
        InkWell(
          onTap: () {
            Navigator.of(context).pop();
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
              'add_friend'.tr,
            )..apply = ItemTitleStyle.style,
          ]),
        ),
        const SizedBox(height: 20),
        InkWell(
          onTap: () {
            Navigator.of(context).pop();
            Get.to(
              () => RecentlyRegisteredUserPage(),
              transition: Transition.rightToLeft,
              popGesture: true, // 右滑，返回上一页
            );
          },
          child: n.Row([
            n.Padding(
              left: 12,
              right: 8,
              child: n.Icon(Icons.person)
                ..size = 18
                ..color = Colors.white.withOpacity(0.9),
            ),
            n.Text(
              'newly_registered_people'.tr,
            )..apply = ItemTitleStyle.style,
          ]),
        ),
        const SizedBox(height: 20),
        InkWell(
          onTap: () {
            Navigator.of(context).pop();
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
              'my_qrcode'.tr,
            )..apply = ItemTitleStyle.style,
          ]),
        ),
        const SizedBox(height: 20),
        InkWell(
          onTap: () {
            Navigator.of(context).pop();
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
              'scan_qr_code'.tr,
            )..apply = ItemTitleStyle.style,
          ]),
        ),
      ]),
    );
  }
}
