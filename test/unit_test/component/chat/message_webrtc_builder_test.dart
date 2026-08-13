import 'package:flutter/material.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:imboy/component/chat/message_webrtc_builder.dart';
import 'package:imboy/service/message_type_constants.dart';

CustomMessage _msg({Map<String, dynamic>? metadata}) {
  return CustomMessage(
    id: 'm_test',
    authorId: 'u_author',
    createdAt: DateTime.fromMillisecondsSinceEpoch(0),
    metadata: metadata,
  );
}

const _user = User(id: 'u_author');

Future<void> _pump(
  WidgetTester tester, {
  required CustomMessage message,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: WebRTCMessageBuilder(message: message, user: _user),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  group('WebRTCMessageBuilder layout & parsing', () {
    testWidgets(
      'peer_id is an int, state is an int, does not throw and renders',
      (tester) async {
        final message = _msg(
          metadata: {
            'peer_id': 12345,
            'state': 0,
            'msg_type': MessageType.webrtcVideo,
          },
        );
        await _pump(tester, message: message);
        expect(find.byType(WebRTCMessageBuilder), findsOneWidget);
      },
    );

    testWidgets(
      'peer_id is a String, state is a String, does not throw and renders',
      (tester) async {
        final message = _msg(
          metadata: {
            'peer_id': '12345',
            'state': '3',
            'msg_type': MessageType.webrtcAudio,
          },
        );
        await _pump(tester, message: message);
        expect(find.byType(WebRTCMessageBuilder), findsOneWidget);
      },
    );

    testWidgets(
      'start_at and end_at as string representations of ints, does not throw',
      (tester) async {
        final message = _msg(
          metadata: {
            'peer_id': '12345',
            'state': 1,
            'msg_type': MessageType.webrtcAudio,
            'start_at': '10000',
            'end_at': '25000',
          },
        );
        await _pump(tester, message: message);
        expect(find.byType(WebRTCMessageBuilder), findsOneWidget);
      },
    );

    testWidgets('fully missing or null metadata, handles gracefully', (
      tester,
    ) async {
      final message = _msg(metadata: null);
      await _pump(tester, message: message);
      expect(find.byType(WebRTCMessageBuilder), findsOneWidget);
    });
  });
}
