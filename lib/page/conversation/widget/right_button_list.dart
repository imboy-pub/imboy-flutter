import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:imboy/page/contact/new_friend/add_friend_view.dart';
import 'package:imboy/page/group/launch_chat/launch_chat_view.dart';
import 'package:imboy/page/contact/recently_registered_user/recently_registered_user_view.dart';
import 'package:imboy/page/scanner/scanner_view.dart';
import 'package:imboy/page/qrcode/qrcode_view.dart';
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
          child: SizedBox(
            width: 46.0,
            child: Icon(
              Icons.add_circle_outline_sharp,
              color: Theme.of(context).colorScheme.onPrimary,
            ),
          )),
      onTap: () {
        showPopover(
          context: context,
          bodyBuilder: (context) => const RightButtonList(),
          barrierColor: Theme.of(context).colorScheme.onSurface,
          backgroundColor: Theme.of(context).colorScheme.onSurface,
          // barrierDismissible: false,
          // shadow: const [BoxShadow(color: Colors.white, blurRadius: 5)],
          direction: PopoverDirection.bottom,
          width: 128,
          height: 288,
          arrowHeight: 6,
          arrowWidth: 12,
          arrowDxOffset: 0,
          contentDxOffset: 0,
          arrowDyOffset: -4,
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
    return n.ListView.children([
      TextButton(
        onPressed: () {
          Navigator.of(context).pop();
          Get.to(
            () => LaunchChatPage(),
            transition: Transition.rightToLeft,
            popGesture: true, // 右滑，返回上一页
          );
        },
        child: n.Row([
          n.Padding(
            right: 8,
            child: n.Icon(Icons.chat_bubble_outlined)
              ..size = 18
              ..color = Colors.white.withOpacity(0.9),
          ),
          Expanded(
            child: n.Text(
              'initiate_chat'.tr,
            )..apply = ItemTitleStyle.style,
          ),
        ]),
      ),
      TextButton(
        onPressed: () {
          Navigator.of(context).pop();
          Get.to(
            () => AddFriendPage(),
            transition: Transition.rightToLeft,
            popGesture: true, // 右滑，返回上一页
          );
        },
        child: n.Row([
          n.Padding(
            right: 8,
            child: n.Icon(Icons.person_add_alt_1)
              ..size = 18
              ..color = Colors.white.withOpacity(0.9),
          ),
          Expanded(
            child: n.Text(
              'add_friend'.tr,
            )..apply = ItemTitleStyle.style,
          ),
        ]),
      ),
      TextButton(
        onPressed: () {
          Navigator.of(context).pop();
          Get.to(
            () => RecentlyRegisteredUserPage(),
            transition: Transition.rightToLeft,
            popGesture: true, // 右滑，返回上一页
          );
        },
        child: n.Row([
          n.Padding(
            right: 8,
            child: n.Icon(Icons.person)
              ..size = 18
              ..color = Colors.white.withOpacity(0.9),
          ),
          Expanded(
              child: n.Text(
            'newly_registered_people'.tr,
          )..apply = ItemTitleStyle.style),
        ]),
      ),
      TextButton(
        onPressed: () {
          Navigator.of(context).pop();
          Get.to(
            () => UserQrCodePage(),
            transition: Transition.rightToLeft,
            popGesture: true, // 右滑，返回上一页
          );
        },
        child: n.Row([
          n.Padding(
            right: 8,
            child: n.Icon(Icons.qr_code_2)
              ..size = 18
              ..color = Colors.white.withOpacity(0.9),
          ),
          Expanded(
              child: n.Text(
            'my_qrcode'.tr,
          )..apply = ItemTitleStyle.style),
        ]),
      ),
      TextButton(
        onPressed: () {
          Navigator.of(context).pop();
          Get.to(
            () => const ScannerPage(),
            transition: Transition.rightToLeft,
            popGesture: true, // 右滑，返回上一页
          );
        },
        child: n.Row([
          n.Padding(
            right: 8,
            child: n.Icon(Icons.qr_code_scanner_outlined)
              ..size = 18
              ..color = Colors.white.withOpacity(0.9),
          ),
          Expanded(
              child: n.Text(
            'scan_qr_code'.tr,
          )..apply = ItemTitleStyle.style),
        ]),
      ),
    ]);
  }
}
