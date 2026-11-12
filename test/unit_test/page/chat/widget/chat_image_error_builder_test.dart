// test/unit_test/page/chat/widget/chat_image_error_builder_test.dart
//
// DEV-01 修复锚（RUN_ID=chat-multi-20261111）：
// chatImageErrorBuilder 是 FlyerChatImageMessage.errorBuilder 的生产注入
// （chat_page imageMessageBuilder）。断言两件事：
// 1. 加载失败的 Image 经 errorBuilder 渲染占位（CupertinoIcons.photo），
//    异常**不**进入 FlutterError 管道（Flutter image.dart：
//    `reportErrors: widget.errorBuilder == null`）—— 即 integration_test 的
//    _pendingExceptionDetails 挂死签名不再可达；
// 2. 占位底色用 AppColors.placeholderSurface token（浅/深主题各断言一次）。

import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:imboy/page/chat/widget/chat_image_error_builder.dart';
import 'package:imboy/theme/default/app_colors.dart';

/// 恒失败的 ImageProvider（模拟 IMBoyCachedImageProvider 重试耗尽 rethrow，
/// 例如 object_key → viewUrl 签发后的 DioException）。
class _AlwaysFailImageProvider extends ImageProvider<Object> {
  const _AlwaysFailImageProvider(this.error);

  final Object error;

  @override
  Future<Object> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture<Object>(this);

  @override
  ImageStreamCompleter loadImage(Object key, ImageDecoderCallback decode) {
    return MultiFrameImageStreamCompleter(
      codec: Future<ui.Codec>.error(error),
      scale: 1.0,
    );
  }
}

Future<void> pumpBrokenImage(WidgetTester tester, bool dark) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: dark ? ThemeData.dark() : ThemeData.light(),
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 96,
            height: 96,
            child: Image(
              image: _AlwaysFailImageProvider(
                StateError('simulated provider retry exhausted'),
              ),
              errorBuilder: chatImageErrorBuilder,
            ),
          ),
        ),
      ),
    ),
  );
  // 排帧：让 ImageStream 错误回调与 errorBuilder 的 setState 落地。
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  testWidgets('破图走 errorBuilder 占位，异常不进入 FlutterError 管道', (tester) async {
    await pumpBrokenImage(tester, false);

    expect(
      tester.takeException(),
      isNull,
      reason:
          'errorBuilder 注入后加载异常不得进入测试异常通道'
          '（DEV-01 _pendingExceptionDetails 挂死签名）',
    );
    expect(
      find.byIcon(CupertinoIcons.photo),
      findsOneWidget,
      reason: '破图应渲染占位图标（chatImageErrorBuilder）',
    );
  });

  testWidgets('浅色主题占位底色 = placeholderSurfaceLight', (tester) async {
    await pumpBrokenImage(tester, false);

    final color = placeholderBgColor(tester);
    expect(color, AppColors.placeholderSurfaceLight);
  });

  testWidgets('深色主题占位底色 = placeholderSurfaceDark', (tester) async {
    await pumpBrokenImage(tester, true);

    final color = placeholderBgColor(tester);
    expect(color, AppColors.placeholderSurfaceDark);
  });
}

/// 从占位图标向上找底色（Container.decoration 或 ColoredBox，随 Flutter
/// 版本 Container(color:) 会编译为二者之一）。
Color? placeholderBgColor(WidgetTester tester) {
  final containers = tester.widgetList<Container>(
    find.ancestor(
      of: find.byIcon(CupertinoIcons.photo),
      matching: find.byType(Container),
    ),
  );
  for (final container in containers) {
    final decoration = container.decoration;
    if (decoration is BoxDecoration && decoration.color != null) {
      return decoration.color;
    }
  }
  final coloredBoxes = tester.widgetList<ColoredBox>(
    find.ancestor(
      of: find.byIcon(CupertinoIcons.photo),
      matching: find.byType(ColoredBox),
    ),
  );
  for (final box in coloredBoxes) {
    return box.color;
  }
  return null;
}
