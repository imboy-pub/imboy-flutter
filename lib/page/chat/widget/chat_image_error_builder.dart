// lib/page/chat/widget/chat_image_error_builder.dart
//
// 聊天图片气泡破图显式容错（DEV-01 / RUN_ID=chat-multi-20261111）。
//
// 背景：IMBoyCachedImageProvider（object_key → viewUrl 授权 → 下载/解码）
// 重试耗尽后 rethrow（如 DioException）；FlyerChatImageMessage 内部 Image
// 未传 errorBuilder 时，Flutter Image widget 走 reportError 路径
// （image.dart: `reportErrors: widget.errorBuilder == null`）：
// - integration_test（LiveTestWidgetsFlutterBinding）下异常进入
//   _pendingExceptionDetails → 用例挂起至 10/12min 超时
//   （dev01-pass1-r4-chat_multi_select.log:196679 失败签名）；
// - 生产上则是控制台噪音 + 气泡无占位反馈。
//
// 修复：chat_page imageMessageBuilder 给 FlyerChatImageMessage 传本
// errorBuilder —— 破图渲染显式占位（token 与 history_bundle_detail_page
// 同款），异常不再进入 FlutterError 管道。

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'package:imboy/theme/default/app_colors.dart';

/// 聊天图片气泡的破图占位（FlyerChatImageMessage.errorBuilder）。
Widget chatImageErrorBuilder(
  BuildContext context,
  Object error,
  StackTrace? stackTrace,
) {
  final bool isDark = Theme.of(context).brightness == Brightness.dark;
  return Container(
    color: isDark
        ? AppColors.placeholderSurfaceDark
        : AppColors.placeholderSurfaceLight,
    alignment: Alignment.center,
    child: Icon(
      CupertinoIcons.photo,
      size: 24,
      color: isDark
          ? AppColors.mediaScrimWhite.withValues(alpha: 0.5)
          : AppColors.mediaScrimBlack.withValues(alpha: 0.4),
    ),
  );
}
