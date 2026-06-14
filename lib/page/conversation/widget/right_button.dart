import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:go_router/go_router.dart';
import 'package:imboy/page/scanner/scanner_page.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_radius.dart';

class RightButton extends StatefulWidget {
  const RightButton({super.key});

  @override
  State<RightButton> createState() => _RightButtonState();
}

class _RightButtonState extends State<RightButton> {
  final _addKey = GlobalKey();

  Future<void> _showAddMenu() async {
    final renderBox =
        _addKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;
    final overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox;
    final position = RelativeRect.fromRect(
      renderBox.localToGlobal(Offset.zero, ancestor: overlay) &
          renderBox.size,
      Offset.zero & overlay.size,
    );
    await showMenu<void>(
      context: context,
      position: position,
      color: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      shadowColor:
          Theme.of(context).colorScheme.shadow.withValues(alpha: 0.15),
      elevation: 4,
      constraints: const BoxConstraints(maxWidth: 160),
      items: const [
        PopupMenuItem<void>(
          padding: EdgeInsets.zero,
          child: SizedBox(width: 160, child: RightButtonList()),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          onPressed: () => context.push('/message_search'),
          icon: Icon(
            Icons.search,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        IconButton(
          key: _addKey,
          onPressed: _showAddMenu,
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
          title: t.chat.initiateChat,
          onTap: () {
            Navigator.of(context).pop();
            context.push('/launch_chat');
          },
        ),
        _buildDivider(),
        _buildMenuItem(
          context,
          icon: Icons.person_add_alt_1,
          title: t.common.addFriend,
          onTap: () {
            Navigator.of(context).pop();
            context.push('/contact/add_friend');
          },
        ),
        _buildDivider(),
        _buildMenuItem(
          context,
          icon: Icons.person,
          title: t.account.newlyRegisteredPeople,
          onTap: () {
            Navigator.of(context).pop();
            context.push('/contact/recently_registered_user');
          },
        ),
        _buildDivider(),
        _buildMenuItem(
          context,
          icon: Icons.qr_code_2,
          title: t.account.myQrcode,
          onTap: () {
            Navigator.of(context).pop();
            context.push('/qrcode');
          },
        ),
        _buildDivider(),
        _buildMenuItem(
          context,
          icon: Icons.qr_code_scanner_outlined,
          title: t.account.scanQrCode,
          onTap: () {
            Navigator.of(context).pop();
            Navigator.of(context).push(
              CupertinoPageRoute<dynamic>(
                builder: (context) => const ScannerPage(),
              ),
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
