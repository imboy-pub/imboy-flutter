import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:imboy/component/ui/common.dart';
import 'package:imboy/component/ui/image_view.dart';
import 'package:imboy/config/const.dart';

class ListTileView extends StatelessWidget {
  final BoxBorder? border;
  final VoidCallback? onPressed;
  final String? title;
  final String? label;
  final String icon;
  final double width;
  final double horizontal;
  final TextStyle titleStyle;
  final bool isLabel;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final BoxFit? fit;
  final double cWidth;
  final bool needRightArrow;

  const ListTileView({
    Key? key,
    this.border,
    this.onPressed,
    this.title,
    this.label,
    this.padding = const EdgeInsets.symmetric(vertical: 15.0),
    this.isLabel = true,
    this.needRightArrow = true,
    this.icon = '',
    this.titleStyle =
        const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
    this.margin,
    this.fit,
    this.width = 45.0,
    this.horizontal = 10.0,
    this.cWidth = 0.0,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    var text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(title ?? '', style: titleStyle),
        Text(
          label ?? '',
          style: const TextStyle(color: AppColors.MainTextColor, fontSize: 12),
        ),
      ],
    );

    var view = [
      isLabel ? text : Text(title!, style: titleStyle),
      const Spacer(),
      needRightArrow
          ? SizedBox(
              width: 7.0,
              child: Image(
                image:
                    const AssetImage('assets/images/ic_right_arrow_grey.webp'),
                color: AppColors.MainTextColor.withOpacity(0.5),
                fit: BoxFit.cover,
              ),
            )
          : const Space(),
      const Space(),
    ];

    var row = icon == ''
        ? Row(
            children: <Widget>[
              Container(
                width: Get.width,
                // padding: EdgeInsets.all(12.0),
                padding: padding,
                decoration: BoxDecoration(border: border),
                child: Row(children: view),
              ),
            ],
          )
        : Row(
            children: <Widget>[
              Container(
                width: width,
                margin: EdgeInsets.symmetric(horizontal: horizontal),
                child: ImageView(img: icon, width: width, fit: fit),
              ),
              Container(
                width: cWidth > 0 ? cWidth : Get.width - 60,
                padding: padding,
                decoration: BoxDecoration(border: border),
                child: Row(children: view),
              ),
            ],
          );

    return Container(
      margin: margin,
      // child: FlatButton(
      //   color: Colors.white,
      //   padding: EdgeInsets.all(0),
      //   onPressed: onPressed ?? () {},
      //   child: row,
      // ),
      child: TextButton(
        style: TextButton.styleFrom(
          minimumSize: Size.zero,
          padding: EdgeInsets.zero,
          backgroundColor: Colors.white,
        ),
        autofocus: true,
        onPressed: onPressed ?? () {},
        child: row,
      ),
    );
  }
}
