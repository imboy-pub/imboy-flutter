import 'package:dotted_border/dotted_border.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:octo_image/octo_image.dart';
import 'package:niku/namespace.dart' as n;
import 'package:nine_grid_view/nine_grid_view.dart';

import 'package:imboy/store/model/people_model.dart';
import 'package:imboy/component/helper/func.dart';

class Avatar extends StatelessWidget {
  const Avatar({
    super.key,
    required this.imgUri,
    this.onTap,
    this.width,
    this.height,
    this.title,
  });

  final String imgUri;
  final void Function()? onTap;
  final double? width;
  final double? height;
  final Widget? title;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: n.Column([
        Container(
          width: width ?? 49,
          height: height ?? 49,
          decoration: BoxDecoration(
            shape: BoxShape.rectangle,
            borderRadius: BorderRadius.circular(4.0),
            border: Border.all(
              width: 0.5,
              style: BorderStyle.solid,
              color: Colors.grey.withOpacity(0.25),
            ),
            color: Colors.grey.withOpacity(0.25),
            image: dynamicAvatar(imgUri),
          ),
        ),
        if (title != null)
          SizedBox(
            width: width ?? 49,
            child: n.Row([Expanded(child: title!)]),
          )
      ]),
    );
  }
}

class ComputeAvatar extends StatelessWidget {
  const ComputeAvatar({
    super.key,
    required this.imgUri,
    this.computeAvatar,
    this.onTap,
    this.width,
    this.height,
  });

  final String imgUri;
  final List<String>? computeAvatar;
  final void Function()? onTap;
  final double? width;
  final double? height;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: computeAvatar != null && computeAvatar!.length < 2
          ? Avatar(imgUri: imgUri, width: width, height: height)
          : NineGridView(
              width: width ?? 56,
              height: height ?? 56,
              padding: const EdgeInsets.all(0),
              space: 1,
              type: NineGridType.weChatGp,
              //NineGridType.weChatGp, NineGridType.dingTalkGp
              itemCount: computeAvatar!.length,
              itemBuilder: (BuildContext context, int index) {
                String i = computeAvatar![index];
                // iPrint("computeAvatar i $i");
                // return Avatar(imgUri: i);
                return OctoImage(
                  width: 56,
                  fit: BoxFit.cover,
                  image: cachedImageProvider(
                    i,
                    w: Get.width,
                  ),
                  errorBuilder: (context, error, stacktrace) =>
                      const Icon(Icons.error),
                );
              },
            ),
    );
  }
}

class AvatarList extends StatelessWidget {
  const AvatarList({
    super.key,
    required this.memberList,
    this.onTapAdd,
    this.onTapRemove,
    this.onTapAvatar,
    this.width,
    this.height,
    this.titleMaxLines,
    this.titleStyle,
    this.column = 5,
  });

  // [{"nickname": "", "avatar":"", "id":""}]
  final List<PeopleModel> memberList;

  // memberList.add(PeopleModel(id: 'add', account: ''));
  // memberList.add(PeopleModel(id: 'remove', account: ''));
  final void Function()? onTapAdd;
  final void Function()? onTapRemove;
  final void Function(PeopleModel m)? onTapAvatar;

  // 头像宽度
  final double? width;

  // 头像高度
  final double? height;

  final TextStyle? titleStyle;

  // 用户昵称最大显示多少行
  final int? titleMaxLines;
  final int column;

  @override
  Widget build(BuildContext context) {
    return n.Column([
      // _buildMemberList(),
      // 使用 List.generate 来创建多行，每行5个成员
      for (int i = 0; i < memberList.length; i += column)
        n.Row([
          // 确保每行不超过数组的长度
          for (int j = i; j < i + column && j < memberList.length; j++)
            if (memberList[j].id == 'last')
              DottedBorder(
                borderType: BorderType.RRect,
                radius: const Radius.circular(12),
                // padding: const EdgeInsets.all(6),
                child: ClipRRect(
                  borderRadius: const BorderRadius.all(Radius.circular(12)),
                  child: SizedBox(
                    height: height ?? 56,
                    width: width ?? 56,
                    // color: darkBgColor,
                  ),
                ),
              )
            else if (memberList[j].id == 'add')
              InkWell(
                onTap: onTapAdd,
                child: n.Padding(
                  right: 10,
                  child: DottedBorder(
                    borderType: BorderType.RRect,
                    radius: const Radius.circular(12),
                    child: ClipRRect(
                      borderRadius: const BorderRadius.all(Radius.circular(12)),
                      child: SizedBox(
                        height: (height ?? 56) - 4,
                        width: (width ?? 56) - 4,
                        child: const Icon(Icons.add),
                        // color: darkBgColor,
                      ),
                    ),
                  ),
                ),
              )
            else if (memberList[j].id == 'remove')
              InkWell(
                onTap: onTapRemove,
                child: n.Padding(
                  right: 10,
                  child: DottedBorder(
                    borderType: BorderType.RRect,
                    radius: const Radius.circular(12),
                    // padding: const EdgeInsets.all(6),
                    child: ClipRRect(
                      borderRadius: const BorderRadius.all(Radius.circular(12)),
                      child: SizedBox(
                        height: (height ?? 56) - 4,
                        width: (width ?? 56) - 4,
                        child: const Icon(Icons.remove),
                        // color: darkBgColor,
                      ),
                    ),
                  ),
                ),
              )
            else
              Flexible(
                  child: n.Padding(
                right: 10,
                bottom: 10,
                child: Avatar(
                  imgUri: memberList[j].avatar,
                  height: height ?? 56,
                  width: width ?? 56,
                  onTap: onTapAvatar == null ? null : () {
                    onTapAvatar!(memberList[j]);
                  },
                  title: Text(
                    memberList[j].nickname,
                    style: titleStyle,
                    // style: ,
                    maxLines: titleMaxLines ?? 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              )),
        ])
          ..crossAxisAlignment = CrossAxisAlignment.start,
    ]);
  }
}
