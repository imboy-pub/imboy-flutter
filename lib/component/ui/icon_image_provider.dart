import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:imboy/theme/default/app_colors.dart';

/// from https://stackoverflow.com/questions/63779906/how-to-convert-icon-widget-to-imageprovider
class IconImageProvider extends ImageProvider<IconImageProvider> {
  final IconData icon;
  final double scale;
  final int size;
  final Color color;
  final Color? bgColor;

  IconImageProvider(
    this.icon, {
    this.scale = 1.0,
    this.size = 48,
    this.color = AppColors.iosGray,
    this.bgColor,
  });

  @override
  Future<IconImageProvider> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture<IconImageProvider>(this);

  @override
  ImageStreamCompleter loadImage(
    IconImageProvider key,
    ImageDecoderCallback decode,
  ) => OneFrameImageStreamCompleter(_loadAsync(key));

  Future<ImageInfo> _loadAsync(IconImageProvider key) async {
    assert(key == this);

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.scale(scale, scale);
    if (bgColor != null) {
      // 绘制背景
      final paint = Paint()..color = bgColor!;
      final rect = Offset.zero & Size(size.toDouble(), size.toDouble()); // 画布大小
      canvas.drawOval(rect, paint); // 绘制圆形背景
    }
    final textPainter = TextPainter(textDirection: TextDirection.rtl);
    textPainter.text = TextSpan(
      text: String.fromCharCode(icon.codePoint),
      style: TextStyle(
        fontSize: size.toDouble(),
        fontFamily: icon.fontFamily,
        // package 不传就渲染成缺字形方框：CupertinoIcons / 各类图标包的字体
        // 打在 package 里，Flutter 要 `packages/<pkg>/<family>` 才找得到，
        // 只给 fontFamily 是解析不到的。
        // 这条路径正是**无头像用户**的兜底（dynamicAvatar 空值分支），
        // 于是所有没设头像的人在列表里都顶着一个 ⊠ 方框，看着像加载失败。
        package: icon.fontPackage,
        fontFamilyFallback: icon.fontFamilyFallback,
        color: color,
      ),
    );
    textPainter.layout();
    final double xOffset = (size.toDouble() - textPainter.width) / 2;
    final double yOffset = (size.toDouble() - textPainter.height) / 2;
    textPainter.paint(canvas, Offset(xOffset, yOffset));
    final image = await recorder.endRecording().toImage(size, size);
    return ImageInfo(image: image, scale: key.scale);
  }

  @override
  bool operator ==(Object other) {
    if (other.runtimeType != runtimeType) return false;
    if (other is IconImageProvider) {
      final IconImageProvider typedOther = other;
      return icon == typedOther.icon &&
          scale == typedOther.scale &&
          size == typedOther.size &&
          color == typedOther.color;
    } else {
      return false;
    }
  }

  @override
  int get hashCode => Object.hash(icon.hashCode, scale, size, color);

  @override
  String toString() =>
      '$runtimeType(${describeIdentity(icon)}, scale: $scale, size: $size, color: $color)';
}
