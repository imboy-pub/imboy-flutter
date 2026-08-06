import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_player/video_player.dart';

import 'package:imboy/component/video/video_controller.dart';

/// BUG#68 回归：`VideoControllerOverlay` 必须撑满父级。
///
/// 它在 `video_viewer_page` 里是 Stack 的**非定位**子节点，拿到的是 loose 约束。
/// 而它内部 Stack 唯一的非定位子节点（手势反馈）空闲时是 `SizedBox.shrink()`，
/// 一旦不显式 expand，整层就坍缩成 0×0：控制栏 3 秒自动隐藏后再也点不出来，
/// 播放/暂停、进度条、全屏全部不可达 —— 真机实测就是这个症状。
///
/// 反向验证过：把 `SizedBox.expand` 去掉，本用例立刻红（尺寸变 0×0）。
void main() {
  testWidgets('overlay 在 Stack 的 loose 约束下仍撑满父级（不坍缩成 0×0）', (
    WidgetTester tester,
  ) async {
    // 不调用 initialize()，不触碰平台通道；overlay 只读 controller.value。
    final controller = VideoPlayerController.file(File('unused.mp4'));
    addTearDown(controller.dispose);

    const parentSize = Size(400, 300);

    await tester.pumpWidget(
      MaterialApp(
        // 与真实用法一致：video_viewer_page 用 Material 包裹播放器
        home: Material(
          child: Center(
            child: SizedBox(
              width: parentSize.width,
              height: parentSize.height,
              child: Stack(
                children: [
                  // 模拟真实用法：视频本体 + 非定位的 overlay
                  const Positioned.fill(
                    child: ColoredBox(color: Color(0xFF000000)),
                  ),
                  VideoControllerOverlay(
                    controller: controller,
                    onFullScreenPressed: () {},
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    final size = tester.getSize(find.byType(VideoControllerOverlay));
    expect(
      size,
      parentSize,
      reason: 'overlay 坍缩后 GestureDetector 没有命中区域，控制栏将永久不可点',
    );
  });
}
