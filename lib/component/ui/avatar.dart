import 'package:flutter/material.dart';

import 'package:imboy/component/helper/func.dart';
import 'package:imboy/component/image_gallery/image_gallery.dart'
    show zoomInPhotoView;

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
    final double w = width ?? 50;
    final double h = height ?? 50;
    // iOS 风格约 22-25% 的圆角
    final double radius = w * 0.25;

    Widget avatarContent = Container(
      width: w,
      height: h,
      decoration: BoxDecoration(
        shape: BoxShape.rectangle,
        borderRadius: BorderRadius.circular(radius),
        color: Colors.grey.withValues(alpha: 0.1),
        image: dynamicAvatar(imgUri),
      ),
    );

    if (heroTag != null) {
      avatarContent = Hero(tag: heroTag!, child: avatarContent);
    }

    return InkWell(
      // 默认行为：点击头像放大预览（双指缩放）。传了自定义 onTap 则优先用调用方的。
      onTap:
          onTap ??
          (imgUri.isNotEmpty ? () => zoomInPhotoView(context, imgUri) : null),
      borderRadius: BorderRadius.circular(radius),
      // ponytail: 用 Wrap 而非 Column —— Wrap 空间不足时静默换行/裁剪，
      // 不会像 RenderFlex 那样在紧/松有界高度下抛 "RenderFlex OVERFLOWING"
      // 条纹。Avatar 会被塞进各种约束（含横向已选条、窄窗成员网格），
      // 必须容忍高度不足；此处不能用 Flexible（AvatarList 处于
      // SingleChildScrollView 无界高度中，Flex 子级会触发断言）。
      child: Wrap(
        alignment: WrapAlignment.center,
        runAlignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        runSpacing: 4,
        children: [
          avatarContent,
          if (title != null) SizedBox(width: w, child: title!),
        ],
      ),
    );
  }
}
