import 'package:flutter/material.dart';
import 'package:imboy/config/const.dart';

class NavAppBar extends StatelessWidget implements PreferredSizeWidget {
  const NavAppBar({
    Key? key,
    this.title = '',
    this.titleWidget,
    this.rightDMActions,
    this.backgroundColor = AppColors.AppBarColor,
    this.mainColor = Colors.black,
  }) : super(key: key);

  final String? title;
  final Widget? titleWidget;
  final List<Widget>? rightDMActions;
  final Color? backgroundColor;
  final Color? mainColor;

  @override
  Size get preferredSize => const Size(100, 50);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: titleWidget ??
          Text(
            title!,
            style: TextStyle(
              color: mainColor,
              fontSize: 16.0,
              fontWeight: FontWeight.w600,
            ),
          ),
      automaticallyImplyLeading: false,
      backgroundColor: backgroundColor,
      foregroundColor: mainColor,
      elevation: 0.0,
      centerTitle: true,
      actions: rightDMActions ?? [const Center()],
    );
  }
}

class PageAppBar extends StatelessWidget implements PreferredSizeWidget {
  const PageAppBar({
    Key? key,
    this.title = '',
    this.titleWidget,
    this.rightDMActions,
    this.backgroundColor = AppColors.AppBarColor,
    this.mainColor = Colors.black,
  }) : super(key: key);

  final String? title;
  final Widget? titleWidget;
  final List<Widget>? rightDMActions;
  final Color? backgroundColor;
  final Color? mainColor;

  @override
  Size get preferredSize => const Size(100, 50);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: titleWidget ??
          Text(
            title!,
            style: TextStyle(
              color: mainColor,
              fontSize: 16.0,
              fontWeight: FontWeight.w600,
            ),
          ),
      // 如果有 leading 这个不会管用 ；
      // 如果没有leading ，当有侧边栏的时候， false：不会显示默认的图片，true 会显示 默认图片，并响应打开侧边栏的事件
      automaticallyImplyLeading: true,
      backgroundColor: backgroundColor,
      foregroundColor: mainColor,
      elevation: 0.0,
      centerTitle: true,
      actions: rightDMActions ?? [const Center()],
    );
  }
}
