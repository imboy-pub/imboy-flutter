import 'package:dotted_border/dotted_border.dart';
import 'package:flutter/material.dart';

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
    return Column(
      children: [
        for (int i = 0; i < memberList.length; i += column)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (int j = i; j < i + column && j < memberList.length; j++)
                if (memberList[j].account == 'last')
                  DottedBorder(
                    options: RoundedRectDottedBorderOptions(
                      radius: const Radius.circular(12),
                    ),
                    child: ClipRRect(
                      borderRadius: const BorderRadius.all(Radius.circular(12)),
                      child: SizedBox(height: height ?? 56, width: width ?? 56),
                    ),
                  )
                else if (memberList[j].account == 'add')
                  InkWell(
                    onTap: onTapAdd,
                    child: Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: DottedBorder(
                        options: RoundedRectDottedBorderOptions(
                          radius: const Radius.circular(12),
                        ),
                        child: ClipRRect(
                          borderRadius: const BorderRadius.all(
                            Radius.circular(12),
                          ),
                          child: SizedBox(
                            height: (height ?? 56) - 4,
                            width: (width ?? 56) - 4,
                            child: const Icon(Icons.add),
                          ),
                        ),
                      ),
                    ),
                  )
                else if (memberList[j].account == 'remove')
                  InkWell(
                    onTap: onTapRemove,
                    child: Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: DottedBorder(
                        options: RoundedRectDottedBorderOptions(
                          radius: const Radius.circular(12),
                        ),
                        child: ClipRRect(
                          borderRadius: const BorderRadius.all(
                            Radius.circular(12),
                          ),
                          child: SizedBox(
                            height: (height ?? 56) - 4,
                            width: (width ?? 56) - 4,
                            child: const Icon(Icons.remove),
                          ),
                        ),
                      ),
                    ),
                  )
                else
                  Flexible(
                    child: Padding(
                      padding: const EdgeInsets.only(right: 10, bottom: 10),
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
                          maxLines: titleMaxLines ?? 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ),
            ],
          ),
      ],
    );
  }
}
