import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:niku/namespace.dart' as n;

import 'package:imboy/component/helper/func.dart';
import 'package:imboy/component/image_gallery/image_gallery.dart';
import 'package:imboy/component/ui/avatar.dart';
import 'package:imboy/component/ui/common.dart';
import 'package:imboy/config/const.dart';

// ignore: must_be_immutable
class ContactCard extends StatelessWidget {
  final String? id;
  String? nickname;
  final String? avatar;
  final String? account;
  int gender;
  final String region;
  final String? remark;

  final bool? isBorder;
  final double? lineWidth;
  final EdgeInsets? padding;

  ContactCard({
    super.key,
    required this.id,
    this.nickname,
    required this.avatar, // 头像
    required this.account,
    required this.gender,
    this.region = '', //
    this.remark = '',
    this.isBorder = false,
    this.lineWidth = mainLineWidth,
    this.padding,
  }) : assert(id != null);

  @override
  Widget build(BuildContext context) {
    TextStyle labelStyle = const TextStyle(
      fontSize: 14,
      color: AppColors.MainTextColor,
    );

    String? title = (remark == null || remark == 'null') ? '' : remark;
    if (strEmpty(title)) {
      title = nickname!;
      nickname = '';
    }
    List<Widget> items = <Widget>[
      n.Row([
        Expanded(
            child: Text(
          title ?? '',
          style: const TextStyle(
            color: Colors.black,
            fontSize: 18.0,
            fontWeight: FontWeight.w600,
          ),
          maxLines: 6,
          overflow: TextOverflow.ellipsis,
        )),
        const Space(width: mainSpace / 3),
        genderIcon(gender),
      ]),
    ];
    if (strNoEmpty(nickname)) {
      items.add(Padding(
        padding: const EdgeInsets.only(top: 3.0),
        child: Text("昵称：".tr + nickname!, style: labelStyle),
      ));
    }
    if (strNoEmpty(account)) {
      items.add(Padding(
        padding: const EdgeInsets.only(top: 3.0),
        child: Text("账号：".tr + account!, style: labelStyle),
      ));
    }
    if (strNoEmpty(region) && region != 'null') {
      items.add(
        Text("地区：".tr + region, style: labelStyle),
      );
    }
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: isBorder!
            ? Border(
                bottom: BorderSide(
                  color: AppColors.LineColor,
                  width: lineWidth!,
                ),
              )
            : null,
      ),
      width: Get.width,
      padding: padding ??
          const EdgeInsets.only(
            right: 15.0,
            left: 15.0,
            bottom: 20.0,
          ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          GestureDetector(
            child: Padding(
              padding: const EdgeInsets.only(
                top: 4.0,
              ),
              child: Avatar(
                imgUri: avatar!,
                width: 55,
                height: 55,
              ),
            ),
            onTap: () {
              if (isNetWorkImg(avatar!)) {
                zoomInPhotoView(avatar!);
              } else {
                Get.snackbar('', '无头像'.tr);
              }
            },
          ),
          const Space(width: mainSpace * 2),
          Expanded(
              child: n.Column(items)
                ..crossAxisAlignment = CrossAxisAlignment.start),
        ],
      ),
    );
  }
}
