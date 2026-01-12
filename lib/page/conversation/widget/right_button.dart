import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:imboy/page/contact/new_friend/add_friend_view.dart';
import 'package:imboy/page/group/launch_chat/launch_chat_view.dart';
import 'package:imboy/page/contact/recently_registered_user/recently_registered_user_view.dart';
import 'package:imboy/page/scanner/scanner_view.dart';
import 'package:imboy/page/qrcode/qrcode_view.dart';

import 'package:popover/popover.dart';
import 'package:imboy/i18n/strings.g.dart';

class RightButton extends StatelessWidget {
  const RightButton({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: () {
        showPopover(
          context: context,
          bodyBuilder: (context) => const RightButtonList(),
          direction: PopoverDirection.bottom,
          width: 160,
          // 移除固定高度，让内容决定高度
          arrowHeight: 8,
          arrowWidth: 16,
          arrowDxOffset: 0,
          contentDxOffset: 0,
          arrowDyOffset: -4,
          backgroundColor: Theme.of(context).colorScheme.surface,
          shadow: [
            BoxShadow(
              color: Theme.of(context).colorScheme.shadow.withValues(alpha: 0.15),
              blurRadius: 12,
              offset: const Offset(0, 4),
            )
          ],
        );
      },
      icon: Icon(
        Icons.add_circle_outline,
        color: Theme.of(context).colorScheme.onSurface,
      ),
    );
  }
}

class RightButtonList extends StatelessWidget {
  const RightButtonList({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildMenuItem(
          context,
          icon: Icons.chat_bubble_outline,
          title: t.initiateChat,
          onTap: () {
            Navigator.of(context).pop();
            Get.to(
              () => LaunchChatPage(),
              transition: Transition.rightToLeft,
              popGesture: true,
            );
          },
        ),
        _buildDivider(),
        _buildMenuItem(
          context,
          icon: Icons.person_add_alt_1,
          title: t.addFriend,
          onTap: () {
            Navigator.of(context).pop();
            Get.to(
              () => AddFriendPage(),
              transition: Transition.rightToLeft,
              popGesture: true,
            );
          },
        ),
        _buildDivider(),
        _buildMenuItem(
          context,
          icon: Icons.person,
          title: t.newlyRegisteredPeople,
          onTap: () {
            Navigator.of(context).pop();
            Get.to(
              () => RecentlyRegisteredUserPage(),
              transition: Transition.rightToLeft,
              popGesture: true,
            );
          },
        ),
        _buildDivider(),
        _buildMenuItem(
          context,
          icon: Icons.qr_code_2,
          title: t.myQrcode,
          onTap: () {
            Navigator.of(context).pop();
            Get.to(
              () => UserQrCodePage(),
              transition: Transition.rightToLeft,
              popGesture: true,
            );
          },
        ),
        _buildDivider(),
        _buildMenuItem(
          context,
          icon: Icons.qr_code_scanner_outlined,
          title: t.scanQrCode,
          onTap: () {
            Navigator.of(context).pop();
            Get.to(
              () => const ScannerPage(),
              transition: Transition.rightToLeft,
              popGesture: true,
            );
          },
        ),
      ],
    );
  }

  Widget _buildMenuItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 24,
              height: 24,
              alignment: Alignment.center,
              child: Icon(
                icon,
                color: Theme.of(context).colorScheme.onSurface,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.normal,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Container(
      height: 1,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      color: const Color(0xFFE5E5E5),
    );
  }
}
