import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:imboy/page/contact/new_friend/add_friend_view.dart';
import 'package:imboy/page/group/launch_chat/launch_chat_view.dart';
import 'package:imboy/page/contact/recently_registered_user/recently_registered_user_view.dart';
import 'package:imboy/page/scanner/scanner_view.dart';
import 'package:imboy/page/qrcode/qrcode_view.dart';

import 'package:popover/popover.dart';

class RightButton extends StatelessWidget {
  const RightButton({super.key});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      child: Padding(
        padding: const EdgeInsets.only(top: 10, bottom: 10),
        child: SizedBox(
          width: 46.0,
          child: Icon(
            Icons.add_circle_outline_sharp,
            color: Theme.of(context).colorScheme.onPrimary,
          ),
        ),
      ),
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
  static final style = TextStyle(
    color: Colors.white.withValues(alpha: 0.9),
    fontSize: 14,
    fontWeight: FontWeight.bold,
  );
}

class RightButtonList extends StatelessWidget {
  const RightButtonList({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
            Get.to(
              () => LaunchChatPage(),
              transition: Transition.rightToLeft,
              popGesture: true, // 右滑，返回上一页
            );
          },
          child: Row(
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Icon(
                  Icons.chat_bubble_outlined,
                  size: 18,
                  color: Colors.white.withValues(alpha: 0.9),
                ),
              ),
              Expanded(
                child: Text(
                  'initiate_chat'.tr,
                  style: ItemTitleStyle.style,
                ),
              ),
            ],
          ),
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
          child: Row(
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Icon(
                  Icons.person_add_alt_1,
                  size: 18,
                  color: Colors.white.withValues(alpha: 0.9),
                ),
              ),
              Expanded(
                child: Text(
                  'add_friend'.tr,
                  style: ItemTitleStyle.style,
                ),
              ),
            ],
          ),
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
          child: Row(
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Icon(
                  Icons.person,
                  size: 18,
                  color: Colors.white.withValues(alpha: 0.9),
                ),
              ),
              Expanded(
                child: Text(
                  'newly_registered_people'.tr,
                  style: ItemTitleStyle.style,
                ),
              ),
            ],
          ),
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
          child: Row(
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Icon(
                  Icons.qr_code_2,
                  size: 18,
                  color: Colors.white.withValues(alpha: 0.9),
                ),
              ),
              Expanded(
                child: Text(
                  'my_qrcode'.tr,
                  style: ItemTitleStyle.style,
                ),
              ),
            ],
          ),
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
          child: Row(
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Icon(
                  Icons.qr_code_scanner_outlined,
                  size: 18,
                  color: Colors.white.withValues(alpha: 0.9),
                ),
              ),
              Expanded(
                child: Text(
                  'scan_qr_code'.tr,
                  style: ItemTitleStyle.style,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
