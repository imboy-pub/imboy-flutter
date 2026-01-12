import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:imboy/theme/default/font_types.dart';

import 'package:imboy/component/helper/func.dart';
import 'package:imboy/component/image_gallery/image_gallery.dart';
import 'package:imboy/component/ui/avatar.dart';
import 'package:imboy/i18n/strings.g.dart';

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
    this.lineWidth,
    this.padding,
  }) : assert(id != null);

  @override
  Widget build(BuildContext context) {
    TextStyle labelStyle = ThemeManager.instance.getTextStyle(
      FontSizeType.small,
      color: ThemeManager.instance.getThemeColor('textSecondary'),
    );

    String? title = (remark == null || remark == 'null') ? '' : remark;
    if (strEmpty(title)) {
      title = nickname!;
      nickname = '';
    }
    List<Widget> items = <Widget>[
      Row(
        children: [
          Expanded(
            child: Text(
              title ?? '',

              maxLines: 6,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 3.33),
          genderIcon(gender),
        ],
      ),
    ];
    if (strNoEmpty(nickname)) {
      items.add(
        Padding(
          padding: const EdgeInsets.only(top: 3.0),
          child: Text("${t.nickname}：$nickname", style: labelStyle),
        ),
      );
    }
    if (strNoEmpty(account)) {
      items.add(
        Padding(
          padding: const EdgeInsets.only(top: 3.0),
          child: Text("${t.account}：$account", style: labelStyle),
        ),
      );
    }
    if (strNoEmpty(region) && region != 'null') {
      items.add(Text("${t.region}：$region", style: labelStyle));
    }
    return Container(
      decoration: BoxDecoration(
        // color: Colors.white,
        border: isBorder!
            ? Border(
                bottom: BorderSide(
                  color: ThemeManager.instance.getThemeColor('primary'),
                  width: lineWidth ?? ThemeManager.instance.mainLineWidth,
                ),
              )
            : null,
      ),
      width: Get.width,
      padding:
          padding ??
          const EdgeInsets.only(right: 15.0, left: 15.0, bottom: 20.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          GestureDetector(
            child: Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: Avatar(imgUri: avatar!, width: 55, height: 55),
            ),
            onTap: () {
              if (isNetWorkImg(avatar!)) {
                zoomInPhotoView(avatar!);
              } else {
                Get.snackbar('', t.noAvatar);
              }
            },
          ),
          const SizedBox(width: 20.0),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: items,
            ),
          ),
        ],
      ),
    );
  }
}
