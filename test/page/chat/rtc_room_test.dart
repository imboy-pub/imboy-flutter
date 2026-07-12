import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

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
  Future<void> switchCamera() async {}

  @override
  Future<void> hangup() async {
    state = state.copyWith(status: RtcRoomStatus.disconnected);
  }
}

Widget _buildPage() {
  return ProviderScope(
    overrides: [rtcRoomProvider.overrideWith(_FakeRtcRoomNotifier.new)],
    child: const MaterialApp(
      home: RtcRoomPage(
        wsUrl: 'wss://rtc.example.com',
        token: 'jwt-token',
        roomName: 'rtc_group_123',
        title: '测试群',
      ),
    ),
  );
}

void main() {
  testWidgets('renders title and full control bar', (tester) async {
    await tester.pumpWidget(_buildPage());
    await tester.pump(); // post-frame connect

    expect(find.text('测试群'), findsOneWidget);
    expect(find.byIcon(Icons.mic), findsOneWidget);
    expect(find.byIcon(Icons.videocam), findsOneWidget);
    expect(find.byIcon(Icons.cameraswitch), findsOneWidget);
    expect(find.byIcon(Icons.call_end), findsOneWidget);
  });

  testWidgets('mic button toggles icon between mic and mic_off', (
    tester,
  ) async {
    await tester.pumpWidget(_buildPage());
    await tester.pump();

    await tester.tap(find.byIcon(Icons.mic));
    await tester.pump();
    expect(find.byIcon(Icons.mic_off), findsOneWidget);
    expect(find.byIcon(Icons.mic), findsNothing);

    await tester.tap(find.byIcon(Icons.mic_off));
    await tester.pump();
    expect(find.byIcon(Icons.mic), findsOneWidget);
  });

  testWidgets('camera button toggles icon', (tester) async {
    await tester.pumpWidget(_buildPage());
    await tester.pump();

    await tester.tap(find.byIcon(Icons.videocam));
    await tester.pump();
    expect(find.byIcon(Icons.videocam_off), findsOneWidget);
  });
}
