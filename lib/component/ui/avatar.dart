import 'package:flutter/material.dart';

import 'package:imboy/component/helper/func.dart';
import 'package:imboy/theme/default/app_radius.dart';

import 'avatar_group.dart';

// 2. 创建智能容器组件
class SmartGroupAvatar extends StatefulWidget {
  final String groupId;
  final String? avatar;
  final double size;
  final VoidCallback? onTap;
  final Future<List<String>> Function(String groupId)? avatarLoader;
  final String? heroTag;

  const SmartGroupAvatar({
    super.key,
    required this.groupId,
    this.avatar,
    this.size = 50,
    this.onTap,
    this.avatarLoader,
    this.heroTag,
  });

  @override
  State<SmartGroupAvatar> createState() => _SmartGroupAvatarState();
}

class _SmartGroupAvatarState extends State<SmartGroupAvatar> {
  late Future<List<String>> _membersFuture;
  final _avatarCache = <String, List<String>>{};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    if (widget.avatar != null && widget.avatar!.isNotEmpty) {
      return;
    }

    if (widget.groupId == "") {
      return;
    }

    // 使用缓存避免重复查询
    if (_avatarCache.containsKey(widget.groupId)) {
      return;
    }

    // 使用传入的回调函数加载头像，如果没有提供则返回空列表
    if (widget.avatarLoader != null) {
      _membersFuture = widget.avatarLoader!(widget.groupId).then((avatars) {
        _avatarCache[widget.groupId] = avatars;
        return avatars;
      });
    } else {
      _membersFuture = Future.value([]);
    }
  }

  @override
  Widget build(BuildContext context) {
    // 有自定义头像直接显示
    if (widget.avatar != null && widget.avatar!.isNotEmpty) {
      return GroupAvatar(
        avatar: widget.avatar,
        size: widget.size,
        onTap: widget.onTap,
        heroTag: widget.heroTag,
      );
    }

    // 没有groupId显示默认
    if (widget.groupId == "") {
      return GroupAvatar(
        size: widget.size,
        onTap: widget.onTap,
        heroTag: widget.heroTag,
      );
    }

    // 异步加载成员头像
    return FutureBuilder<List<String>>(
      future: _membersFuture,
      builder: (context, snapshot) {
        return GroupAvatar(
          memberAvatars: snapshot.data ?? [],
          size: widget.size,
          onTap: widget.onTap,
          heroTag: widget.heroTag,
        );
      },
    );
  }
}

class Avatar extends StatelessWidget {
  const Avatar({
    super.key,
    required this.imgUri,
    this.onTap,
    this.width,
    this.height,
    this.title,
    this.heroTag,
  });

  final String imgUri;
  final void Function()? onTap;
  final double? width;
  final double? height;
  final Widget? title;
  final String? heroTag;

  @override
  Widget build(BuildContext context) {
    Widget avatarContent = Container(
      width: width ?? 50,
      height: height ?? 50,
      decoration: BoxDecoration(
        shape: BoxShape.rectangle,
        borderRadius: AppRadius.borderRadiusTiny,
        border: Border.all(
          width: 0.5,
          style: BorderStyle.solid,
          color: Colors.grey.withValues(alpha: 0.5),
        ),
        color: Colors.grey.withValues(alpha: 0.5),
        image: dynamicAvatar(imgUri),
      ),
    );

    if (heroTag != null) {
      avatarContent = Hero(tag: heroTag!, child: avatarContent);
    }

    return InkWell(
      onTap: onTap,
      child: Wrap(
        verticalDirection: VerticalDirection.down,
        children: [
          avatarContent,
          if (title != null) SizedBox(width: width ?? 50, child: title!),
        ],
      ),
    );
  }
}
