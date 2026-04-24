import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:go_router/go_router.dart';
import 'package:imboy/page/scanner/scanner_page.dart';
import 'package:popover/popover.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_radius.dart';

class RightButton extends StatelessWidget {
  const RightButton({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 搜索按钮
        IconButton(
          onPressed: () {
            context.push('/message_search');
          },
          icon: Icon(
            Icons.search,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        // 添加按钮（弹出菜单）
        IconButton(
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
                  color: Theme.of(
                    context,
                  ).colorScheme.shadow.withValues(alpha: 0.15),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            );
          },
          icon: Icon(
            Icons.add_circle_outline,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ],
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
            context.push('/launch_chat');
          },
        ),
        _buildDivider(),
        _buildMenuItem(
          context,
          icon: Icons.person_add_alt_1,
          title: t.addFriend,
          onTap: () {
            Navigator.of(context).pop();
            context.push('/contact/add_friend');
          },
        ),
        _buildDivider(),
        _buildMenuItem(
          context,
          icon: Icons.person,
          title: t.newlyRegisteredPeople,
          onTap: () {
            Navigator.of(context).pop();
            context.push('/contact/recently_registered_user');
          },
        ),
        _buildDivider(),
        _buildMenuItem(
          context,
          icon: Icons.qr_code_2,
          title: t.myQrcode,
          onTap: () {
            Navigator.of(context).pop();
            context.push('/qrcode');
          },
        ),
        _buildDivider(),
        _buildMenuItem(
          context,
          icon: Icons.qr_code_scanner_outlined,
          title: t.scanQrCode,
          onTap: () {
            Navigator.of(context).pop();
            Navigator.of(context).push(
              CupertinoPageRoute(builder: (context) => const ScannerPage()),
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
      borderRadius: AppRadius.borderRadiusTiny,
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
      color: AppColors.lightDivider,
    );
  }
}
