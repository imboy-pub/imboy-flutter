import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart' show CupertinoIcons, TextPainter;
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import 'package:imboy/component/helper/func.dart';
import 'package:imboy/component/ui/avatar_shape.dart';
import 'package:imboy/theme/default/app_colors.dart';

/// 群头像合成单图缓存（W5：每群 1 纹理替代 9 纹理，对齐微信观感）。
///
/// - key 由「URL 原序列表 + size」构成：格子顺序即布局位置（W2 后顺序 =
///   user_id 升序恒定），**不得排序**——计划定稿时的 hash(sorted urls) 是
///   W2 之前顺序不稳定时代的产物，排序会让同集合不同顺序命中同一张图，
///   布局就错了。
/// - in-flight 去重用 Completer 中转（同 [[GroupAvatarMemberCache.load]]，
///   Dart 3.13.1 下 then/whenComplete 链存 map 再回调 remove 同 key 会
///   await 永久挂起，勿改回）。
/// - 合成失败（解码超时 / 无 raster 上下文如 flutter_test）返回 null 且
///   **不缓存失败结果**，调用方常驻 legacy 逐 tile Widget 路径，零观感回退。
/// - 容量上限简单插入序淘汰：群头像合成图是小尺寸位图（≤9 格 size×size），
///   上限 64 张足够，防长会话列表场景无限增长。
class GroupAvatarComposite {
  GroupAvatarComposite._();

  /// 合成完成后的重建通知；GroupAvatar 的 legacy 路径用它包裹，
  /// 合成图就绪后自然切到同步分支。
  static final ChangeNotifier rebuildNotifier = _RebuildNotifier();

  static final _images = <String, ui.Image>{};
  static final _inflight = <String, Future<ui.Image?>>{};
  static const _maxEntries = 64;
  static const _decodeTimeout = Duration(seconds: 8);

  static String keyFor(List<String> urls, double size) {
    return '${urls.join('\u{1}')}@$size';
  }

  /// 命中返回已合成 ui.Image；纯内存查询，build 内随便调。
  static ui.Image? peek(String key) => _images[key];

  /// 未命中时触发后台合成（fire-and-forget）。重复调用同 key 只发起一次。
  static void schedule(
    List<String> urls,
    double size,
    AvatarShape shape,
    double borderRadius,
    bool isDark,
  ) {
    final key = keyFor(urls, size);
    if (_images.containsKey(key) || _inflight.containsKey(key)) {
      return;
    }
    final completer = Completer<ui.Image?>();
    _inflight[key] = completer.future;
    unawaited(() async {
      ui.Image? image;
      try {
        image = await _compose(urls, size, shape, borderRadius, isDark);
        if (image != null) {
          _images[key] = image;
          while (_images.length > _maxEntries) {
            _images.remove(_images.keys.first);
          }
        }
      } finally {
        _inflight.remove(key);
        if (image != null) {
          _notifyRebuild();
        }
      }
      if (!completer.isCompleted) {
        completer.complete(image);
      }
    }());
  }

  /// 解码各 tile 为 ui.Image 后按现有布局画到一张 size×size 画布。
  /// 任何一步失败/超时 → null（不缓存，调用方 legacy 路径兜底）。
  static Future<ui.Image?> _compose(
    List<String> urls,
    double size,
    AvatarShape shape,
    double borderRadius,
    bool isDark,
  ) async {
    try {
      if (urls.isEmpty || urls.length == 1 || size <= 0) {
        return null; // 单图/空列表走 GroupAvatar 现有分支，不属于合成职责
      }
      final tiles = <ui.Image?>[];
      for (final url in urls) {
        tiles.add(
          url.isEmpty ? null : await _decodeTile(url).timeout(_decodeTimeout),
        );
      }
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);
      _paint(canvas, tiles, size, shape, borderRadius, isDark);
      final picture = recorder.endRecording();
      final px = size.toInt();
      // toImageSync 需要 raster 上下文；flutter_test 等无引擎环境会抛，
      // 由外层 try/catch 统一降级为 null。
      final image = picture.toImageSync(px, px);
      picture.dispose();
      return image;
    } catch (_) {
      return null;
    }
  }

  /// 单 tile 解码：provider（含 IconImageProvider 默认头像，它本身是
  /// PictureRecorder 产物）→ 首帧 ui.Image。失败返回 null → 画灰底，
  /// 对齐 legacy 路径 errorBuilder 的视觉。
  static Future<ui.Image?> _decodeTile(String url) {
    final completer = Completer<ui.Image?>();
    final stream = avatarImageProvider(url).resolve(const ImageConfiguration());
    late ImageStreamListener listener;
    listener = ImageStreamListener(
      (info, _) {
        if (!completer.isCompleted) {
          completer.complete(info.image);
        }
        stream.removeListener(listener);
      },
      onError: (Object error, StackTrace? stackTrace) {
        if (!completer.isCompleted) {
          completer.complete(null);
        }
        stream.removeListener(listener);
      },
    );
    stream.addListener(listener);
    return completer.future;
  }

  // ── 布局绘制：逐条复刻 avatar_group.dart 的 legacy Widget 布局 ──
  // 视觉参数（分栏比例/间距 1/圆角规则/灰底色）与 Widget 路径一一对应，
  // 改任一侧必须同步另一侧，观感差异以真机走查为准。

  static void _paint(
    ui.Canvas canvas,
    List<ui.Image?> tiles,
    double size,
    AvatarShape shape,
    double borderRadius,
    bool isDark,
  ) {
    final outerRadius = switch (shape) {
      AvatarShape.circle => size / 2,
      AvatarShape.square => 0.0,
      AvatarShape.roundedSquare => borderRadius,
    };
    canvas.clipRRect(
      ui.RRect.fromRectAndRadius(
        ui.Offset.zero & ui.Size(size, size),
        ui.Radius.circular(outerRadius),
      ),
    );
    if (tiles.length <= 4) {
      _paintSmallGroup(canvas, tiles, size, shape, isDark);
    } else {
      _paintGrid(canvas, tiles, size, shape, isDark);
    }
  }

  /// 2-4 人：左半 1 格 + 右上 1 格 + 右下 1~2 格，复刻 _buildSmallGroupLayout。
  static void _paintSmallGroup(
    ui.Canvas canvas,
    List<ui.Image?> tiles,
    double size,
    AvatarShape shape,
    bool isDark,
  ) {
    final cornerRadius = shape == AvatarShape.circle ? 8.0 : 0.0;
    final half = size / 2;

    // 第一个头像占左半边（topLeft+bottomLeft 圆角）
    _paintTileCorners(
      canvas,
      tiles[0],
      ui.Offset.zero & ui.Size(half, size),
      tl: cornerRadius,
      bl: cornerRadius,
      isDark: isDark,
    );
    // 第二个头像占右半（2 人时全高，否则上半），topRight+bottomRight 圆角
    _paintTileCorners(
      canvas,
      tiles[1],
      ui.Offset(half, 0) & ui.Size(half, tiles.length == 2 ? size : half),
      tr: cornerRadius,
      br: tiles.length == 2 ? cornerRadius : 0,
      isDark: isDark,
    );
    if (tiles.length == 3) {
      // 右下单格，bottomRight 圆角
      _paintTileCorners(
        canvas,
        tiles[2],
        ui.Offset(half, half) & ui.Size(half, half),
        br: cornerRadius,
        isDark: isDark,
      );
    } else if (tiles.length == 4) {
      // 右下两格并排（无边角），复刻 legacy 的 Row
      _paintTileCorners(
        canvas,
        tiles[2],
        ui.Offset(half, half) & ui.Size(half / 2, half),
        isDark: isDark,
      );
      _paintTileCorners(
        canvas,
        tiles[3],
        ui.Offset(half + half / 2, half) & ui.Size(half / 2, half),
        isDark: isDark,
      );
    }
  }

  /// 5-9 人：3 列网格、间距 1，复刻 _buildGridLayout + SliverGridDelegate。
  static void _paintGrid(
    ui.Canvas canvas,
    List<ui.Image?> tiles,
    double size,
    AvatarShape shape,
    bool isDark,
  ) {
    const gap = 1.0;
    final cell = (size - 2 * gap) / 3;
    for (int i = 0; i < tiles.length; i++) {
      final col = i % 3;
      final row = i ~/ 3;
      final offset = ui.Offset(
        gap + col * (cell + gap),
        gap + row * (cell + gap),
      );
      _paintTile(
        canvas,
        tiles[i],
        offset & ui.Size(cell, cell),
        shape: shape,
        isDark: isDark,
      );
    }
  }

  /// 单格（网格布局用）：四角同 tileRadius，复刻 _buildAvatarTile 的
  /// `_getTileBorderRadius()`（circle: size/4、square: 0、roundedSquare:
  /// borderRadius/2——格子是 size/2，对应减半）。
  static void _paintTile(
    ui.Canvas canvas,
    ui.Image? tile,
    ui.Rect rect, {
    required AvatarShape shape,
    required bool isDark,
  }) {
    final tileRadius = switch (shape) {
      AvatarShape.circle => rect.shortestSide / 4,
      AvatarShape.square => 0.0,
      AvatarShape.roundedSquare => rect.shortestSide / 4,
    };
    _paintTileWithCorners(
      canvas,
      tile,
      rect,
      tl: tileRadius,
      tr: tileRadius,
      br: tileRadius,
      bl: tileRadius,
      isDark: isDark,
    );
  }

  /// 单格（2-4 布局用）：四角显式指定，0 就是直角——复刻 legacy 把
  /// BorderRadius.only(...) 传进 _buildAvatarTile 的行为，缺角不回退默认圆角。
  static void _paintTileCorners(
    ui.Canvas canvas,
    ui.Image? tile,
    ui.Rect rect, {
    double tl = 0,
    double tr = 0,
    double br = 0,
    double bl = 0,
    required bool isDark,
  }) {
    _paintTileWithCorners(
      canvas,
      tile,
      rect,
      tl: tl,
      tr: tr,
      br: br,
      bl: bl,
      isDark: isDark,
    );
  }

  static void _paintTileWithCorners(
    ui.Canvas canvas,
    ui.Image? tile,
    ui.Rect rect, {
    double tl = 0,
    double tr = 0,
    double br = 0,
    double bl = 0,
    required bool isDark,
  }) {
    final maxRadius = rect.shortestSide / 2;
    canvas.clipRRect(
      ui.RRect.fromRectAndCorners(
        rect,
        topLeft: ui.Radius.circular(tl.clamp(0, maxRadius)),
        topRight: ui.Radius.circular(tr.clamp(0, maxRadius)),
        bottomRight: ui.Radius.circular(br.clamp(0, maxRadius)),
        bottomLeft: ui.Radius.circular(bl.clamp(0, maxRadius)),
      ),
    );
    if (tile == null) {
      // 空头像：灰底 + 人形剪影，对齐 legacy _buildAvatarTile 空串分支
      // （微信同款观感；纯色块真机验收被批"半张脸+白块"）。
      canvas.drawRect(
        rect,
        ui.Paint()
          ..color = isDark
              ? AppColors.placeholderSurfaceDark
              : AppColors.placeholderSurfaceLight,
      );
      _paintPersonGlyph(canvas, rect);
      return;
    }
    canvas.drawImageRect(
      tile,
      // BoxFit.cover 语义：按目标宽高比居中裁剪，非方形格（2 人格
      // half×size）不得整图拉伸变形。
      _coverSrcRect(tile, rect),
      rect,
      ui.Paint()..filterQuality = ui.FilterQuality.medium,
    );
  }

  /// 测试与登出清理用。
  @visibleForTesting
  static void clear() {
    _images.clear();
    _inflight.clear();
  }

  static void _notifyRebuild() {
    (rebuildNotifier as _RebuildNotifier).notify();
  }

  /// BoxFit.cover 的 src 裁剪：图片宽高比与目标不一致时按比例居中裁，
  /// 对齐 legacy OctoImage(fit: cover) 不拉伸。
  static ui.Rect _coverSrcRect(ui.Image tile, ui.Rect dst) {
    final iw = tile.width.toDouble();
    final ih = tile.height.toDouble();
    final dstRatio = dst.width / dst.height;
    final srcRatio = iw / ih;
    if ((srcRatio - dstRatio).abs() < 0.001) {
      return ui.Rect.fromLTWH(0, 0, iw, ih);
    }
    if (srcRatio > dstRatio) {
      // 图更宽：裁左右
      final w = ih * dstRatio;
      return ui.Rect.fromLTWH((iw - w) / 2, 0, w, ih);
    }
    // 图更高：裁上下
    final h = iw / dstRatio;
    return ui.Rect.fromLTWH(0, (ih - h) / 2, iw, h);
  }

  /// 空头像格的人形剪影：TextPainter 画 CupertinoIcons 字形，
  /// 手法与 IconImageProvider 相同（fontFamily+package 缺一不可，
  /// 否则渲染成缺字形方框）；观感对齐 legacy 的
  /// Icon(CupertinoIcons.person_2, size: size*0.3, color: iosGray)。
  static void _paintPersonGlyph(ui.Canvas canvas, ui.Rect rect) {
    final icon = CupertinoIcons.person_2;
    final iconSize = rect.shortestSide * 0.6;
    final tp = TextPainter(textDirection: TextDirection.ltr)
      ..text = TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(
          fontSize: iconSize,
          fontFamily: icon.fontFamily,
          package: icon.fontPackage,
          color: AppColors.iosGray,
        ),
      )
      ..layout();
    tp.paint(canvas, rect.center - ui.Offset(tp.width / 2, tp.height / 2));
  }
}

/// 暴露安全的 notify 入口（notifyListeners 是 ChangeNotifier 保护成员）。
class _RebuildNotifier extends ChangeNotifier {
  void notify() => notifyListeners();
}
