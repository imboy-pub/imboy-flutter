import 'package:flutter/material.dart';

class NavAppBar extends StatelessWidget implements PreferredSizeWidget {
  const NavAppBar({
    super.key,
    this.leading,
    this.leadingWidth,
    this.title = '',
    this.titleWidget,
    this.rightDMActions,
    // this.backgroundColor = AppColors.AppBarColor,
    // this.mainColor = Colors.black,
    this.automaticallyImplyLeading = false,
  });

  final Widget? leading;
  final double? leadingWidth;
  final String? title;
  final Widget? titleWidget;
  final List<Widget>? rightDMActions;

  // final Color? backgroundColor;
  // final Color? mainColor;
  // 如果有 leading 这个不会管用 ；
  // 如果没有leading ，当有侧边栏的时候， false：不会显示默认的图片，true 会显示 默认图片，并响应打开侧边栏的事件
  final bool automaticallyImplyLeading;

  @override
  Size get preferredSize => const Size(100, 50);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      leading: leading,
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
      backgroundColor: Theme.of(context).colorScheme.primary,
      // foregroundColor: mainColor,
      // backgroundColor: Theme.of(context).colorScheme.background,
      // foregroundColor: Theme.of(context).colorScheme.primary,
      elevation: 0.0,
      centerTitle: true,
      actions: rightDMActions ?? [const Center()],
    );
  }
}
