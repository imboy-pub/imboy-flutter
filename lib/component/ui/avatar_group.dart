import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/component/ui/group_avatar_composite.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:octo_image/octo_image.dart';

import 'avatar_shape.dart';

class GroupAvatar extends StatelessWidget {
  const GroupAvatar({
    super.key,
    this.avatar,
    this.memberAvatars = const [],
    this.onTap,
    this.size = 50,
    this.maxDisplayCount = 9,
    this.backgroundColor,
    this.errorWidget,
    this.shape = AvatarShape.roundedSquare, // 默认圆形
    this.borderRadius = 4.0, // 圆角半径，仅在shape为roundedSquare时有效
    this.heroTag,
  });

  final String? avatar;
  final List<String> memberAvatars;
  final VoidCallback? onTap;
  final double size;
  final int maxDisplayCount;
  final Color? backgroundColor;
  final Widget? errorWidget;
  final AvatarShape shape;
  final double borderRadius;
  final String? heroTag;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    Widget content = _buildAvatarContent(context, isDark);

    if (heroTag != null) {
      content = Hero(tag: heroTag!, child: content);
    }

    return GestureDetector(onTap: onTap, child: content);
  }

  BorderRadius _getBorderRadius() {
    switch (shape) {
      case AvatarShape.circle:
        return BorderRadius.circular(size / 2);
      case AvatarShape.square:
        return BorderRadius.zero;
      case AvatarShape.roundedSquare:
        return BorderRadius.circular(borderRadius);
    }
  }

  Widget _buildAvatarContent(BuildContext context, bool isDark) {
    if (avatar != null && avatar!.isNotEmpty) {
      return _buildSingleAvatar(avatar!, isDark);
    }

    if (kDebugMode) iPrint("memberAvatars count: ${memberAvatars.length}");
    if (memberAvatars.isEmpty) {
      return _buildDefaultGroupAvatar(isDark);
    }
    if (memberAvatars.length == 1) {
      return _buildSingleAvatar(memberAvatars.first, isDark);
    }

    return _buildCombinedAvatar(isDark);
  }

  Widget _buildSingleAvatar(String url, bool isDark) {
    // url = dynamicAvatar(url);
    return SizedBox(
      width: size,
      height: size,
      child: ClipRRect(
        borderRadius: _getBorderRadius(),
        child: OctoImage(
          image: ResizeImage(
            avatarImageProvider(url),
            width: size.toInt(),
            height: size.toInt(),
          ),
          fit: BoxFit.cover,
          errorBuilder: (context, error, stacktrace) =>
              _buildDefaultGroupAvatar(isDark),
        ),
      ),
    );
  }

  Widget _buildDefaultGroupAvatar(bool isDark) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color:
            backgroundColor ?? (isDark ? Colors.grey[800] : Colors.grey[200]),
        borderRadius: _getBorderRadius(),
        shape: shape == AvatarShape.circle
            ? BoxShape.circle
            : BoxShape.rectangle,
      ),
      child:
          errorWidget ??
          Icon(
            CupertinoIcons.person_2,
            size: size * 0.6,
            color: isDark ? Colors.grey[400] : Colors.grey[600],
          ),
    );
  }

  Widget _buildCombinedAvatar(bool isDark) {
    final displayAvatars = memberAvatars.take(maxDisplayCount).toList();

    // W5 合成单图优先：命中直接一纹理直出（每群 1 纹理替代 9 纹理，
    // 格子同帧出现对齐微信观感）。key 含原序列表+size（顺序即布局位置，
    // 不得排序），见 GroupAvatarComposite.keyFor 注释。
    final composite = GroupAvatarComposite.peek(
      GroupAvatarComposite.keyFor(displayAvatars, size),
    );
    if (composite != null) {
      return _compositeWidget(composite);
    }

    // 未命中：触发后台合成（in-flight 去重；失败不缓存、无 raster 上下文
    // 如测试环境安全降级 null），本帧起 legacy 逐 tile 路径兜底。
    GroupAvatarComposite.schedule(
      displayAvatars,
      size,
      shape,
      borderRadius,
      isDark,
    );
    // 通知重建时必须**重新 peek**（合成图就绪 → 切直出），而不是只重跑
    // legacy——曾把 builder 直接指向 _buildLegacyCombined，通知永远切不过去。
    return ListenableBuilder(
      listenable: GroupAvatarComposite.rebuildNotifier,
      builder: (context, _) {
        final again = GroupAvatarComposite.peek(
          GroupAvatarComposite.keyFor(displayAvatars, size),
        );
        return again != null
            ? _compositeWidget(again)
            : _buildLegacyCombined(displayAvatars, isDark);
      },
    );
  }

  /// 合成单图直出 widget。
  Widget _compositeWidget(ui.Image image) {
    return ClipRRect(
      borderRadius: _getBorderRadius(),
      child: SizedBox(
        width: size,
        height: size,
        child: RawImage(
          image: image,
          width: size,
          height: size,
          fit: BoxFit.fill,
        ),
      ),
    );
  }

  /// legacy 逐 tile Widget 路径（合成未就绪/失败时的兜底渲染）。
  /// 视觉参数与 GroupAvatarComposite._paint 一一对应，改任一侧必须同步另一侧。
  Widget _buildLegacyCombined(List<String> avatars, bool isDark) {
    final avatarCount = avatars.length;

    if (avatarCount >= 2 && avatarCount <= 4) {
      return ClipRRect(
        borderRadius: _getBorderRadius(),
        child: _buildSmallGroupLayout(avatars, isDark),
      );
    }

    return ClipRRect(
      borderRadius: _getBorderRadius(),
      child: SizedBox(
        width: size,
        height: size,
        child: _buildGridLayout(avatars, isDark),
      ),
    );
  }

  Widget _buildSmallGroupLayout(List<String> avatars, bool isDark) {
    final cornerRadius = shape == AvatarShape.circle ? 8.0 : 0.0;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        children: [
          // 第一个头像占左半边
          Positioned(
            left: 0,
            width: size / 2,
            height: size,
            child: _buildAvatarTile(
              avatars[0],
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(cornerRadius),
                bottomLeft: Radius.circular(cornerRadius),
              ),
              isDark: isDark,
            ),
          ),
          // 第二个头像占右半边
          Positioned(
            right: 0,
            width: size / 2,
            height: avatars.length == 2 ? size : size / 2,
            child: _buildAvatarTile(
              avatars[1],
              borderRadius: BorderRadius.only(
                topRight: Radius.circular(cornerRadius),
                bottomRight: avatars.length == 2
                    ? Radius.circular(cornerRadius)
                    : Radius.zero,
              ),
              isDark: isDark,
            ),
          ),
          // 第三、四个头像在下半部分
          if (avatars.length >= 3)
            Positioned(
              right: 0,
              bottom: 0,
              width: size / 2,
              height: size / 2,
              child: avatars.length == 3
                  ? _buildAvatarTile(
                      avatars[2],
                      borderRadius: BorderRadius.only(
                        bottomRight: Radius.circular(cornerRadius),
                      ),
                      isDark: isDark,
                    )
                  : Row(
                      children: [
                        Expanded(
                          child: _buildAvatarTile(avatars[2], isDark: isDark),
                        ),
                        Expanded(
                          child: _buildAvatarTile(avatars[3], isDark: isDark),
                        ),
                      ],
                    ),
            ),
        ],
      ),
    );
  }

  Widget _buildGridLayout(List<String> avatars, bool isDark) {
    return GridView.builder(
      padding: EdgeInsets.zero,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: _calculateGridCrossAxisCount(avatars.length),
        mainAxisSpacing: 1,
        crossAxisSpacing: 1,
      ),
      itemCount: avatars.length,
      itemBuilder: (context, index) =>
          _buildAvatarTile(avatars[index], isDark: isDark),
    );
  }

  Widget _buildAvatarTile(
    String url, {
    BorderRadius? borderRadius,
    required bool isDark,
  }) {
    // 空头像占位：保留格子位置（拼图顺序由 user_id 决定，不因缺头像
    // 漂移），不走 OctoImage 的网络/解码报错路径。
    if (url.isEmpty) {
      return Container(
        color: isDark
            ? AppColors.placeholderSurfaceDark
            : AppColors.placeholderSurfaceLight,
      );
    }
    return ClipRRect(
      borderRadius: borderRadius ?? _getTileBorderRadius(),
      child: OctoImage(
        image: ResizeImage(
          avatarImageProvider(url),
          width: (size / 2).toInt(),
          height: (size / 2).toInt(),
        ),
        fit: BoxFit.cover,
        errorBuilder: (context, error, stacktrace) =>
            Container(color: isDark ? Colors.grey[800] : Colors.grey[300]),
      ),
    );
  }

  BorderRadius _getTileBorderRadius() {
    switch (shape) {
      case AvatarShape.circle:
        return BorderRadius.circular(size / 4); // 小圆角
      case AvatarShape.square:
        return BorderRadius.zero;
      case AvatarShape.roundedSquare:
        return BorderRadius.circular(borderRadius / 2);
    }
  }

  int _calculateGridCrossAxisCount(int itemCount) {
    if (itemCount <= 4) return 2;
    if (itemCount <= 9) return 3;
    return 3;
  }
}
