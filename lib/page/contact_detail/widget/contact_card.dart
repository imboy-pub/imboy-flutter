import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/component/ui/common.dart';
import 'package:imboy/component/view/image_view.dart';
import 'package:imboy/config/const.dart';
import 'package:photo_view/photo_view.dart';

class ContactCard extends StatelessWidget {
  final String? id;
  final String? nickname;
  final String? avatar;
  final String? account;
  int gender;
  final String region;

  final bool? isBorder;
  final double? lineWidth;

  ContactCard({
    required this.id,
    this.nickname,
    required this.avatar, // 头像
    required this.account,
    required this.gender,
    this.region = '', //
    this.isBorder = false,
    this.lineWidth = mainLineWidth,
  }) : assert(id != null);

  @override
  Widget build(BuildContext context) {
    TextStyle labelStyle = TextStyle(
      fontSize: 14,
      color: AppColors.MainTextColor,
    );

    List<Widget> items = <Widget>[
      Row(
        children: <Widget>[
          Text(
            nickname ?? '未知',
            style: TextStyle(
              color: Colors.black,
              fontSize: 18.0,
              fontWeight: FontWeight.w600,
            ),
          ),
          Space(width: mainSpace / 3),
          genderIcon(gender),
        ],
      ),
    ];
    if (strNoEmpty(this.account)) {
      items.add(Padding(
        padding: EdgeInsets.only(top: 3.0),
        child: Text("账号：" + this.account!, style: labelStyle),
      ));
    }
    items.add(
      Text("地区：" + region, style: labelStyle),
    );
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: isBorder!
            ? Border(
                bottom:
                    BorderSide(color: AppColors.LineColor, width: lineWidth!),
              )
            : null,
      ),
      width: Get.width,
      padding: EdgeInsets.only(right: 15.0, left: 15.0, bottom: 20.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          GestureDetector(
            child: ImageView(
                img: avatar!, width: 55, height: 55, fit: BoxFit.cover),
            onTap: () {
              if (isNetWorkImg(avatar!)) {
                Get.to(
                  PhotoView(
                    imageProvider: NetworkImage(avatar!),
                    onTapUp: (c, f, s) => Navigator.of(context).pop(),
                    maxScale: 3.0,
                    minScale: 1.0,
                  ),
                );
              } else {
                Get.snackbar('', '无头像'.tr);
              }
            },
          ),
          Space(width: mainSpace * 2),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: items,
          )
        ],
      ),
    );
  }
}
