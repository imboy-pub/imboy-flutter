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

  Widget _buildItem(BuildContext context, PeopleModel member) {
    if (member.account == 'last') {
      return _RoundedDottedBorder(
        child: ClipRRect(
          borderRadius: const BorderRadius.all(Radius.circular(12)),
          child: SizedBox(height: height ?? 56, width: width ?? 56),
        ),
      );
    } else if (member.account == 'add') {
      return InkWell(
        onTap: onTapAdd,
        child: _RoundedDottedBorder(
          child: ClipRRect(
            borderRadius: const BorderRadius.all(Radius.circular(12)),
            child: SizedBox(
              height: (height ?? 56) - 4,
              width: (width ?? 56) - 4,
              child: const Icon(Icons.add),
            ),
          ),
        ),
      );
    } else if (member.account == 'remove') {
      return InkWell(
        onTap: onTapRemove,
        child: _RoundedDottedBorder(
          child: ClipRRect(
            borderRadius: const BorderRadius.all(Radius.circular(12)),
            child: SizedBox(
              height: (height ?? 56) - 4,
              width: (width ?? 56) - 4,
              child: const Icon(Icons.remove),
            ),
          ),
        ),
      );
    } else {
      return Avatar(
        imgUri: member.avatar,
        height: height ?? 56,
        width: width ?? 56,
        onTap: onTapAvatar == null
            ? null
            : () {
                onTapAvatar!(member);
              },
        title: Text(
          member.nickname,
          style: titleStyle,
          maxLines: titleMaxLines ?? 3,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (int i = 0; i < memberList.length; i += column)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (int j = i; j < i + column; j++)
                if (j < memberList.length)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(right: 10, bottom: 10),
                      child: _buildItem(context, memberList[j]),
                    ),
                  )
                else
                  const Expanded(child: SizedBox.shrink()),
            ],
          ),
      ],
    );
  }
}

// 圆角虚线边框，替代 dotted_border 包（radius=12, dash=4/4, stroke=1）
class _RoundedDottedBorder extends StatelessWidget {
  const _RoundedDottedBorder({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DottedBorderPainter(
        color: Theme.of(context).colorScheme.outline,
      ),
      child: child,
    );
  }
}

class _DottedBorderPainter extends CustomPainter {
  const _DottedBorderPainter({required this.color});

  final Color color;

  static const double _radius = 12.0;
  static const double _dashWidth = 4.0;
  static const double _dashGap = 4.0;
  static const double _strokeWidth = 1.0;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = _strokeWidth
      ..style = PaintingStyle.stroke;

    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        _strokeWidth / 2,
        _strokeWidth / 2,
        size.width - _strokeWidth,
        size.height - _strokeWidth,
      ),
      const Radius.circular(_radius),
    );

    final path = Path()..addRRect(rrect);
    for (final metric in path.computeMetrics()) {
      double distance = 0;
      while (distance < metric.length) {
        canvas.drawPath(
          metric.extractPath(distance, distance + _dashWidth),
          paint,
        );
        distance += _dashWidth + _dashGap;
      }
    }
  }

  @override
  bool shouldRepaint(_DottedBorderPainter old) => old.color != color;
}
