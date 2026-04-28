/// Tests for `lib/component/chat/message_spacing.dart`
///
/// MessageSpacing 是纯常量 + 静态辅助函数：
///   - getBubbleBorderRadius(isSentByMe) → 发送/接收侧的圆角矩阵
///   - getBubbleBoxShadows(isSentByMe, bgColor) → 阴影深浅区分
///
/// 锁定关键常量值（与 DESIGN.md 第 9.1 章 + iMessage 标准对齐），
/// 防止未来误改间距/圆角破坏视觉一致性。
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/component/chat/message_spacing.dart';

void main() {
  group('MessageSpacing constants', () {
    test('基础单位为 4dp（Material 3 标准）', () {
      expect(MessageSpacing.unit, 4.0);
    });

    test('消息气泡主圆角 20pt（DESIGN.md §9.1）', () {
      expect(MessageSpacing.bubbleBorderRadius, 20.0);
    });

    test('方向指示圆角 4pt（小角，对应消息侧）', () {
      expect(MessageSpacing.bubbleDirectionRadius, 4.0);
    });

    test('图片消息圆角 14pt（统一单图/九宫格）', () {
      expect(MessageSpacing.imageBorderRadius, 14.0);
    });

    test('引用容器圆角 8pt', () {
      expect(MessageSpacing.quoteBorderRadius, 8.0);
    });

    test('外/内边距 EdgeInsets 与单值常量一致', () {
      expect(
        MessageSpacing.messageMargin,
        EdgeInsets.symmetric(
          horizontal: MessageSpacing.messageHorizontalMargin,
          vertical: MessageSpacing.messageVerticalMargin,
        ),
      );
      expect(
        MessageSpacing.bubblePaddingAll,
        EdgeInsets.all(MessageSpacing.bubblePadding),
      );
      expect(
        MessageSpacing.bubblePaddingSymmetric,
        EdgeInsets.symmetric(
          horizontal: MessageSpacing.bubblePaddingHorizontal,
          vertical: MessageSpacing.bubblePaddingVertical,
        ),
      );
    });

    test('播放按钮 = 40dp 直径，圆角 = 半径（完美圆形）', () {
      expect(MessageSpacing.playButtonSize, 40.0);
      expect(MessageSpacing.playButtonBorderRadius * 2,
          MessageSpacing.playButtonSize,
          reason: '播放按钮圆角应等于直径的一半，呈完整圆形');
    });

    test('发送 elevation > 接收 elevation（视觉层级区分）', () {
      expect(
        MessageSpacing.sentMessageElevation,
        greaterThan(MessageSpacing.receivedMessageElevation),
      );
    });
  });

  group('MessageSpacing.getBubbleBorderRadius', () {
    test('isSentByMe=true → 右下角小圆角（指向自己）', () {
      final r = MessageSpacing.getBubbleBorderRadius(true);
      // 发送：topLeft、bottomLeft、bottomRight 大；topRight 小
      expect(r.topLeft.x, MessageSpacing.bubbleBorderRadius);
      expect(r.topRight.x, MessageSpacing.bubbleDirectionRadius);
      expect(r.bottomLeft.x, MessageSpacing.bubbleBorderRadius);
      expect(r.bottomRight.x, MessageSpacing.bubbleBorderRadius);
    });

    test('isSentByMe=false → 左上角小圆角（指向对方）', () {
      final r = MessageSpacing.getBubbleBorderRadius(false);
      // 接收：topRight、bottomLeft、bottomRight 大；topLeft 小
      expect(r.topLeft.x, MessageSpacing.bubbleDirectionRadius);
      expect(r.topRight.x, MessageSpacing.bubbleBorderRadius);
      expect(r.bottomLeft.x, MessageSpacing.bubbleBorderRadius);
      expect(r.bottomRight.x, MessageSpacing.bubbleBorderRadius);
    });

    test('发送 vs 接收：恰好一个角的大小不同（小圆角位置不同）', () {
      final sent = MessageSpacing.getBubbleBorderRadius(true);
      final recv = MessageSpacing.getBubbleBorderRadius(false);
      // 4 个角中只有 topLeft / topRight 两个角不同
      // sent.topRight = small；recv.topLeft = small
      expect(sent.topLeft, recv.topRight);
      expect(sent.topRight, recv.topLeft);
      expect(sent.bottomLeft, recv.bottomLeft);
      expect(sent.bottomRight, recv.bottomRight);
    });
  });

  group('MessageSpacing.getBubbleBoxShadows', () {
    const bg = Color(0xFF2474E5); // brand blue

    test('isSentByMe=true → alpha 0.1 + blur 4', () {
      final shadows = MessageSpacing.getBubbleBoxShadows(true, bg);
      expect(shadows.length, 1);
      final s = shadows.first;
      expect(s.blurRadius, 4.0);
      expect(s.offset, const Offset(0, 1));
      // alpha = 0.1
      expect(s.color.a, closeTo(0.1, 0.001));
    });

    test('isSentByMe=false → alpha 0.05 + blur 2', () {
      final shadows = MessageSpacing.getBubbleBoxShadows(false, bg);
      expect(shadows.length, 1);
      final s = shadows.first;
      expect(s.blurRadius, 2.0);
      expect(s.offset, const Offset(0, 1));
      expect(s.color.a, closeTo(0.05, 0.001));
    });

    test('阴影颜色相对 bgColor 变 alpha（同色相 RGB 不变）', () {
      final s = MessageSpacing.getBubbleBoxShadows(true, bg).first;
      expect(s.color.r, bg.r);
      expect(s.color.g, bg.g);
      expect(s.color.b, bg.b);
    });

    test('发送侧阴影 blurRadius > 接收侧（视觉层级）', () {
      final sent = MessageSpacing.getBubbleBoxShadows(true, bg).first;
      final recv = MessageSpacing.getBubbleBoxShadows(false, bg).first;
      expect(sent.blurRadius, greaterThan(recv.blurRadius));
      expect(sent.color.a, greaterThan(recv.color.a));
    });
  });
}
