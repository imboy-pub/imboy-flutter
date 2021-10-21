import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:imboy/component/ui/common.dart';
import 'package:imboy/component/view/image_view.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/helper/win_media.dart';

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

  ListTileView({
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
  });

  @override
  Widget build(BuildContext context) {
    var text = new Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        new Text(title ?? '', style: titleStyle),
        new Text(
          label ?? '',
          style: TextStyle(color: AppColors.MainTextColor, fontSize: 12),
        ),
      ],
    );

    var view = [
      isLabel ? text : new Text(title!, style: titleStyle),
      new Spacer(),
      needRightArrow
          ? new Container(
              width: 7.0,
              child: new Image(
                image: AssetImage('assets/images/ic_right_arrow_grey.webp'),
                color: AppColors.MainTextColor.withOpacity(0.5),
                fit: BoxFit.cover,
              ),
            )
          : new Space(),
      new Space(),
    ];

    var row = icon == ''
        ? new Row(
            children: <Widget>[
              new Container(
                width: winWidth(context),
                // padding: new EdgeInsets.all(12.0),
                padding: padding,
                decoration: BoxDecoration(border: border),
                child: new Row(children: view),
              ),
            ],
          )
        : new Row(
            children: <Widget>[
              new Container(
                width: width,
                margin: EdgeInsets.symmetric(horizontal: horizontal),
                child: new ImageView(img: icon, width: width, fit: fit),
              ),
              new Container(
                width: cWidth > 0 ? cWidth : winWidth(context) - 60,
                padding: padding,
                decoration: BoxDecoration(border: border),
                child: new Row(children: view),
              ),
            ],
          );

    return new Container(
      margin: margin,
      // child: new FlatButton(
      //   color: Colors.white,
      //   padding: EdgeInsets.all(0),
      //   onPressed: onPressed ?? () {},
      //   child: row,
      // ),
      child: new TextButton(
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
