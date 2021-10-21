import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:imboy/component/ui/common.dart';
import 'package:imboy/component/view/image_view.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/helper/func.dart';
import 'package:imboy/helper/win_media.dart';
import 'package:photo_view/photo_view.dart';

class ContactCard extends StatelessWidget {
  final String? id;
  final String? nickname;
  final String? avatar;
  final String? account;
  final String? area;

  final bool? isBorder;
  final double? lineWidth;

  ContactCard({
    required this.id,
    this.nickname,
    required this.avatar, // 头像
    required this.account,
    this.area, //
    this.isBorder = false,
    this.lineWidth = mainLineWidth,
  }) : assert(id != null);

  @override
  Widget build(BuildContext context) {
    TextStyle labelStyle = TextStyle(fontSize: 14, color: AppColors.MainTextColor);
    String accountTitle = "账号：";
    if (this.account != null) {
      accountTitle += this.account.toString();
    }
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: isBorder!
            ? Border(
                bottom: BorderSide(color: AppColors.LineColor, width: lineWidth!),
              )
            : null,
      ),
      width: winWidth(context),
      padding: EdgeInsets.only(right: 15.0, left: 15.0, bottom: 20.0),
      child: new Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          new GestureDetector(
            child: new ImageView(
                img: avatar!, width: 55, height: 55, fit: BoxFit.cover),
            onTap: () {
              if (isNetWorkImg(avatar!)) {
                Get.to(
                  new PhotoView(
                    imageProvider: NetworkImage(avatar!),
                    onTapUp: (c, f, s) => Navigator.of(context).pop(),
                    maxScale: 3.0,
                    minScale: 1.0,
                  ),
                );
              } else {
                Get.snackbar('', '无头像');
              }
            },
          ),
          new Space(width: mainSpace * 2),
          new Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              new Row(
                children: <Widget>[
                  new Text(
                    nickname ?? '未知',
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 18.0,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  new Space(width: mainSpace / 3),
                  new Image(
                    image: AssetImage('assets/images/Contact_Female.webp'),
                    width: 20.0,
                    fit: BoxFit.fill,
                  ),
                ],
              ),
              new Padding(
                padding: EdgeInsets.only(top: 3.0),
                child: new Text(accountTitle, style: labelStyle),
              ),
              new Text("地区：" + area!, style: labelStyle),
            ],
          )
        ],
      ),
    );
  }
}
