import 'package:flutter/material.dart';

import 'package:imboy/component/helper/func.dart';
import 'package:imboy/component/image_gallery/image_gallery.dart'
    show zoomInPhotoView;
import 'package:imboy/page/group/group_avatar_cache.dart';

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
  Future<List<String>>? _membersFuture;

  // _membersFuture 对应的 groupId；widget 复用（groupId 变化）时重建 future，
  // 其余 build 复用同一 future，避免 FutureBuilder 每帧重跑。
  String? _futureGid;

  @override
  Widget build(BuildContext context) {
    // 有自定义头像直接显示（产品规则：不加载成员、不查缓存、不预热）
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

    // 同步嗅探：会话列表预热后这里命中，直接渲染真图，无 FutureBuilder
    // 首帧闪变。peek 是纯内存查询；invalidate/TTL 失效后返回 null，
    // 下一次 build 自动回落到下面的异步加载路径。
    final cached = GroupAvatarMemberCache.instance.peek(widget.groupId);
    if (cached != null) {
      return GroupAvatar(
        memberAvatars: cached,
        size: widget.size,
        onTap: widget.onTap,
        heroTag: widget.heroTag,
      );
    }

    // 缓存未命中：全局缓存异步兜底（in-flight 去重，滚动重挂载不放大
    // 查询次数），仅冷加载首帧会出现一次占位→真图。
    if (_membersFuture == null || _futureGid != widget.groupId) {
      _futureGid = widget.groupId;
      _membersFuture = GroupAvatarMemberCache.instance.load(
        widget.groupId,
        widget.avatarLoader ?? defaultGroupAvatarLoader,
      );
    }
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
      alignment: Alignment.center,
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

    return GestureDetector(
      // 默认行为：点击头像放大预览（双指缩放）。传了自定义 onTap 则优先用调用方的。
      onTap:
          onTap ??
          (imgUri.isNotEmpty ? () => zoomInPhotoView(context, imgUri) : null),
      // ponytail: 用 Wrap 而非 Column —— Wrap 空间不足时静默换行/裁剪，
      // 不会像 RenderFlex 那样在紧/松有界高度下抛 "RenderFlex OVERFLOWING"
      // 条纹。Avatar 会被塞进各种约束（含横向已选条、窄窗成员网格），
      // 必须容忍高度不足；此处不能用 Flexible（AvatarList 处于
      // SingleChildScrollView 无界高度中，Flex 子级会触发断言）。
      // 上限：空间不足时 title 会被静默换行/裁剪，没有溢出警示——出问题时是
      // "名字看不全"而不是报错，调用方得自己给够高度。
      // 无升级路径（设计约束，非延期）：Avatar 是被任意父级复用的叶子组件，
      // 无法预知传入约束；Column/Flexible 任一选择都会在"无界高度"和"紧约束"
      // 两端中的一端断言或抛溢出条纹，Wrap 是两端都安全的唯一容器。
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
