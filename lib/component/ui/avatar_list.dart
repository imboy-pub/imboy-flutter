import 'package:dotted_border/dotted_border.dart';
import 'package:flutter/material.dart';
import 'package:niku/namespace.dart' as n;

import 'package:imboy/store/model/people_model.dart';

import 'avatar.dart';

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
                options: RoundedRectDottedBorderOptions(
                  // borderType: BorderType.RRect,
                  radius: const Radius.circular(12),
                  // padding: EdgeInsets.all(6),  // Uncomment if needed
                  // strokeWidth: 2,             // Add if you want custom stroke width
                  // color: Colors.black,        // Add if you want custom color
                ),
                child: ClipRRect(
                  borderRadius: const BorderRadius.all(Radius.circular(12)),
                  child: SizedBox(
                    height: height ?? 56,
                    width: width ?? 56,
                    // color: darkBgColor,       // Uncomment if needed
                  ),
                ),
              )
            else if (memberList[j].id == 'add')
              InkWell(
                onTap: onTapAdd,
                child: n.Padding(
                  right: 10,
                  child: DottedBorder(
                    options: RoundedRectDottedBorderOptions(
                      // borderType: BorderType.RRect,
                      radius: const Radius.circular(12),
                      // padding: EdgeInsets.all(6),  // Uncomment if needed
                      // strokeWidth: 2,             // Add if you want custom stroke width
                      // color: Colors.black,        // Add if you want custom color
                    ),
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
                      options: RoundedRectDottedBorderOptions(
                        // borderType: BorderType.RRect,
                        radius: const Radius.circular(12),
                        // padding: EdgeInsets.all(6),  // Uncomment if needed
                        // strokeWidth: 2,             // Add if you want custom stroke width
                        // color: Colors.black,        // Add if you want custom color
                      ),
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
                      onTap: onTapAvatar == null
                          ? null
                          : () {
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
                  ),
                ),
        ])..crossAxisAlignment = CrossAxisAlignment.start,
    ]);
  }
}
