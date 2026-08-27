import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';

import 'package:imboy/page/chat/rtc_room/rtc_room_page.dart';
import 'package:imboy/page/chat/rtc_room/rtc_room_provider.dart';

/// 假 Notifier：不触碰 LiveKit Room，仅驱动 UI 状态
class _FakeRtcRoomNotifier extends RtcRoomNotifier {
  @override
  Future<bool> connect({required String wsUrl, required String token}) async {
    state = state.copyWith(status: RtcRoomStatus.connected);
    return true;
  }

  @override
  Future<void> toggleMic() async {
    state = state.copyWith(micOn: !state.micOn);
  }

  @override
  Future<void> toggleCamera() async {
    state = state.copyWith(cameraOn: !state.cameraOn);
  }

  @override
  Future<void> toggleSpeaker() async {
    state = state.copyWith(speakerOn: !state.speakerOn);
  }

  @override
  Future<void> switchCamera() async {}

  @override
  Future<void> hangup() async {
    state = state.copyWith(status: RtcRoomStatus.disconnected);
  }
}

class _FailedRtcRoomNotifier extends RtcRoomNotifier {
  @override
  Future<bool> connect({required String wsUrl, required String token}) async {
    state = state.copyWith(status: RtcRoomStatus.failed);
    return false;
  }
}

Widget _buildPage() {
  return ProviderScope(
    overrides: [rtcRoomProvider.overrideWith(_FakeRtcRoomNotifier.new)],
    child: MaterialApp(
      home: const RtcRoomPage(
        wsUrl: 'wss://rtc.example.com',
        token: 'jwt-token',
        roomName: 'rtc_group_123',
        title: '测试群',
      ),
      builder: EasyLoading.init(),
    ),
  );
}

Widget _buildFailedPage() {
  return ProviderScope(
    overrides: [rtcRoomProvider.overrideWith(_FailedRtcRoomNotifier.new)],
    child: MaterialApp(
      home: const RtcRoomPage(
        wsUrl: 'wss://rtc.example.com',
        token: 'jwt-token',
        roomName: 'rtc_group_123',
        title: '测试群',
      ),
      builder: EasyLoading.init(),
    ),
  );
}

void main() {
  test('群通话状态支持重连标记且不影响媒体开关', () {
    const state = RtcRoomState();
    final reconnecting = state.copyWith(reconnecting: true);

    expect(reconnecting.reconnecting, isTrue);
    expect(reconnecting.status, RtcRoomStatus.idle);
    expect(reconnecting.micOn, isTrue);
    expect(reconnecting.cameraOn, isTrue);
  });

  test('群通话副画面上下滑动超过阈值才交换', () {
    expect(shouldSwapRtcVideoLayout(null), isFalse);
    expect(shouldSwapRtcVideoLayout(280), isFalse);
    expect(shouldSwapRtcVideoLayout(-281), isTrue);
  });

  test('群通话副画面松手吸附到左右边缘', () {
    expect(
      snapRtcThumbnailLeft(
        currentLeft: 20,
        thumbnailWidth: 120,
        stageWidth: 400,
      ),
      12,
    );
    expect(
      snapRtcThumbnailLeft(
        currentLeft: 280,
        thumbnailWidth: 120,
        stageWidth: 400,
      ),
      268,
    );
  });

  // 2026-08-27 跟随 7c0f755e Material→Cupertino 迁移：
  // 控制栏图标为 CupertinoIcons（mic_fill/videocam_fill/arrow_2_circlepath/
  // phone_down_fill），连接失败图标为 exclamationmark_circle。
  testWidgets('renders title and full control bar', (tester) async {
    await tester.pumpWidget(_buildPage());
    await tester.pump(); // post-frame connect

    expect(find.text('测试群'), findsOneWidget);
    expect(find.byIcon(CupertinoIcons.mic_fill), findsOneWidget);
    expect(find.byIcon(CupertinoIcons.videocam_fill), findsOneWidget);
    expect(find.byIcon(CupertinoIcons.arrow_2_circlepath), findsOneWidget);
    expect(find.byIcon(CupertinoIcons.phone_down_fill), findsOneWidget);
  });

  testWidgets('群通话初次连接失败时保留页面并提供重试', (tester) async {
    await tester.pumpWidget(_buildFailedPage());
    await tester.pump();

    expect(find.text('重试'), findsOneWidget);
    expect(find.byIcon(CupertinoIcons.exclamationmark_circle), findsOneWidget);
  });

  testWidgets('mic button toggles icon between mic and mic_off', (
    tester,
  ) async {
    await tester.pumpWidget(_buildPage());
    await tester.pump();

    await tester.tap(find.byIcon(CupertinoIcons.mic_fill));
    await tester.pump();
    expect(find.byIcon(CupertinoIcons.mic_slash), findsOneWidget);
    expect(find.byIcon(CupertinoIcons.mic_fill), findsNothing);

    await tester.tap(find.byIcon(CupertinoIcons.mic_slash));
    await tester.pump();
    expect(find.byIcon(CupertinoIcons.mic_fill), findsOneWidget);
  });

  testWidgets('camera button toggles icon', (tester) async {
    await tester.pumpWidget(_buildPage());
    await tester.pump();

    await tester.tap(find.byIcon(CupertinoIcons.videocam_fill));
    await tester.pump();
    expect(find.byIcon(CupertinoIcons.video_camera), findsOneWidget);
  });

  testWidgets('speaker button toggles icon', (tester) async {
    await tester.pumpWidget(_buildPage());
    await tester.pump();

    await tester.tap(find.byIcon(CupertinoIcons.volume_up));
    await tester.pump();
    expect(find.byIcon(CupertinoIcons.volume_off), findsOneWidget);
  });
}
