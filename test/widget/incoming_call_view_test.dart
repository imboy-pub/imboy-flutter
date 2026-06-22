// 全屏来电界面 Widget 测试 / IncomingCallView Widget Tests
//
// 测试策略 / Test strategy:
//   - avatar 传空字符串 → avatarImageProvider 短路为 IconImageProvider，
//     不触达任何网络/DB/服务，CI 稳定。
//   - 验证：昵称渲染、视频/音频图标分流、接听/拒接回调正确接线。
//
// 运行方式 / How to run:
//   flutter test test/widget/incoming_call_view_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/page/chat/p2p_call_screen/incoming_call_view.dart';

Widget _wrap({
  required String media,
  required VoidCallback onAccept,
  required VoidCallback onDecline,
}) {
  return MaterialApp(
    home: IncomingCallView(
      avatar: '',
      nickname: '张三',
      media: media,
      onAccept: onAccept,
      onDecline: onDecline,
    ),
  );
}

void main() {
  testWidgets('视频来电：渲染昵称与接听/拒接，且回调正确接线', (tester) async {
    var accepted = false;
    var declined = false;
    await tester.pumpWidget(
      _wrap(
        media: 'video',
        onAccept: () => accepted = true,
        onDecline: () => declined = true,
      ),
    );
    // 呼吸动画无限循环，不能 pumpAndSettle。
    await tester.pump();

    expect(find.text('张三'), findsOneWidget);
    // 拒接按钮（红色 call_end）
    expect(find.byIcon(Icons.call_end), findsOneWidget);
    // 视频来电的接听按钮用 videocam 图标
    expect(find.byIcon(Icons.videocam), findsWidgets);

    await tester.tap(find.byIcon(Icons.call_end));
    expect(declined, isTrue);
    expect(accepted, isFalse);
  });

  testWidgets('音频来电：接听按钮用电话图标，点击触发 onAccept', (tester) async {
    var accepted = false;
    await tester.pumpWidget(
      _wrap(media: 'audio', onAccept: () => accepted = true, onDecline: () {}),
    );
    await tester.pump();

    expect(find.byIcon(Icons.phone), findsOneWidget);
    expect(find.byIcon(Icons.videocam), findsNothing);

    await tester.tap(find.byIcon(Icons.phone));
    expect(accepted, isTrue);
  });

  testWidgets('Reduce Motion: 关闭呼吸动画(pumpAndSettle 不挂起)', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          // disableAnimations=true → 无限呼吸动画应被停止
          data: const MediaQueryData(
            size: Size(400, 800),
            disableAnimations: true,
          ),
          child: const IncomingCallView(
            avatar: '',
            nickname: '张三',
            media: 'video',
            onAccept: _noop,
            onDecline: _noop,
          ),
        ),
      ),
    );
    // 若呼吸动画未被停止, pumpAndSettle 会因无限动画超时失败。
    await tester.pumpAndSettle();
    expect(find.text('张三'), findsOneWidget);
  });
}

void _noop() {}
