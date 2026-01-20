import 'package:flutter/material.dart';
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
  final String? heroTag;

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
    this.heroTag,
    this.isBorder = false,
    this.lineWidth,
    this.padding,
  }) : assert(id != null);

  @override
  Widget build(BuildContext context) {
    TextStyle labelStyle = ThemeManager.instance.getTextStyle(
      FontSizeType.small,
      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
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
                  color: Theme.of(context).colorScheme.primary,
                  width: lineWidth ?? 1.0,
                ),
              )
            : null,
      ),
      width: MediaQuery.of(context).size.width, // 使用 MediaQuery 替代 Get.width
      padding:
          padding ??
          const EdgeInsets.only(right: 15.0, left: 15.0, bottom: 20.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          GestureDetector(
            child: Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: Avatar(
                imgUri: avatar!,
                width: 55,
                height: 55,
                heroTag: heroTag,
              ),
            ),
            onTap: () {
              if (isNetWorkImg(avatar!)) {
                zoomInPhotoView(context, avatar!);
              } else {
                // 使用 ScaffoldMessenger 替代 Get.snackbar
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text(t.noAvatar)));
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
