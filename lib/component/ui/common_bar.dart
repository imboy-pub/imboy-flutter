import 'package:flutter/material.dart';

class NavAppBar extends StatelessWidget implements PreferredSizeWidget {
  const NavAppBar({
    super.key,
    this.leading,
    this.leadingWidth,
    this.title = '',
    this.titleWidget,
    this.rightDMActions,
    this.backgroundColor,
    // this.mainColor = Colors.black,
    this.automaticallyImplyLeading = false,
    this.popTime = 1,
  });

  final Widget? leading;
  final double? leadingWidth;
  final String? title;
  final Widget? titleWidget;
  final List<Widget>? rightDMActions;

  final Color? backgroundColor;
  // final Color? mainColor;
  // 如果有 leading 这个不会管用 ；
  // 如果没有leading ，当有侧边栏的时候， false：不会显示默认的图片，true 会显示 默认图片，并响应打开侧边栏的事件
  final bool automaticallyImplyLeading;
  final int popTime;

  @override
  Size get preferredSize => const Size(100, 50);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      leading: leading ??
          BackButton(
            style: ButtonStyle(
              iconSize: WidgetStateProperty.all(18),
            ),
            onPressed: () {
              NavigatorState nav = Navigator.of(context);
              // iPrint("popTime $popTime;");
              for (int i = 0; i < popTime; i++) {
                nav.pop();
              }
            },
          ),
      leadingWidth: leadingWidth,
      title: titleWidget ??
          Text(
            title!,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onPrimary,
              fontSize: 16.0,
              fontWeight: FontWeight.w600,
            ),
          ),
      automaticallyImplyLeading: automaticallyImplyLeading,
      backgroundColor: backgroundColor ?? Theme.of(context).colorScheme.primary,
      // foregroundColor: mainColor,
      // backgroundColor: Theme.of(context).colorScheme.surface,
      // foregroundColor: Theme.of(context).colorScheme.primary,
      elevation: 0.0,
      centerTitle: true,
      actions: rightDMActions ?? [const Center()],
    );
  }
}
