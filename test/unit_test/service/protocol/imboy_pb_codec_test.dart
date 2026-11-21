import 'dart:convert';
import 'dart:typed_data';

import 'package:fixnum/fixnum.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/service/event_bus.dart';
import 'package:imboy/service/protocol/imboy.pb.dart';
import 'package:imboy/service/protocol/imboy_pb_codec.dart';
import 'package:imboy/service/web_writer_gate.dart';
import 'package:imboy/service/websocket.dart';
import 'package:imboy/service/websocket_events.dart';
import 'package:imboy/service/websocket_message_parser.dart';

void main() {
  const encodedWire = String.fromEnvironment('FL05_ERLANG_WIRE_BASE64');
  if (encodedWire.isNotEmpty) {
    if (kIsWeb) setUpAll(prepareWebWriter);
    final fixture = jsonDecode(
      utf8.decode(base64Decode(encodedWire)),
    ) as Map<String, dynamic>;
    final vectors = (fixture['vectors'] as List).cast<Map<String, dynamic>>();
    test('Erlang wire fixture contains the entire matrix', () {
      expect(fixture['producer'], 'imboy_codec:encode_ws_msg/4');
      expect(vectors, hasLength(12));
      expect(
        vectors.map((v) => (v['direction'], v['framing'], v['expected_kind'])),
        unorderedEquals([
          for (final direction in ['C2C', 'C2G'])
            for (final framing in ['none', 'v2'])
              for (final kind in ['explicit_zero', 'missing', 'nonzero'])
                (direction, framing, kind),
        ]),
      );
    });
    for (final vector in vectors) {
      final direction = vector['direction'];
      final framing = vector['framing'];
      final kind = vector['expected_kind'];
      test(
        'Erlang wire reaches normal dispatch: $direction/$framing/$kind',
        () async {
          final isOlm = direction == 'C2C';
          final id = isOlm ? 'msg-olm-001' : 'msg-megolm-001';
          final field = isOlm ? 'message_type' : 'message_index';
          final bytes = base64Decode(vector['wire_base64'] as String);
          expect(vector['field'], field);
          expect(vector['expected_present'], kind != 'missing');
          final expectedValue = switch (kind) {
            'explicit_zero' => 0,
            'nonzero' => isOlm ? 1 : 42,
            'missing' => null,
            _ => throw StateError('Unknown wire case: $kind'),
          };
          expect(vector['expected_value'], expectedValue);

          WebSocketService.resetForTest();
          addTearDown(WebSocketService.resetForTest);
          final socket = WebSocketService.to
            ..framingForTest = framing == 'v2'
                ? FramingMode.v2
                : FramingMode.none;
          final events = <WebSocketMessageReceivedEvent>[];
          final subscription = AppEventBus.on<WebSocketMessageReceivedEvent>()
              .listen((event) {
                if (event.data['id'] == id) events.add(event);
              });
          addTearDown(subscription.cancel);
          socket.handleInboundForTest(
            vector['opcode'] == 'text' ? utf8.decode(bytes) : bytes,
          );
          await pumpEventQueue();
          expect(events, hasLength(1));
          final message = events.single.data;
          expect(events.single.type, direction);
          expect(message['from'], '111222333');
          expect(message['to'], isOlm ? '444555666' : '999888777');
          expect(
            message['payload'],
            isOlm ? 'olm-ciphertext-binary' : 'megolm-ciphertext-binary',
          );
          final e2ee = message['e2ee'] as Map;
          expect(e2ee.containsKey(field), kind != 'missing');
          expect(e2ee[field], expectedValue);
        },
      );
    }
  }

  group('ImboyPbCodec', () {
    group('tryDecode', () {
      test(
        'decodes protobuf IMBoyMessage with logged_another_device action',
        () {
          // Arrange: construct a logged_another_device protobuf message
          final payload = PayloadLoggedAnotherDevice(
            did: 'device-abc-123',
            dname: 'iPhone 16e',
          );
          final msg = IMBoyMessage(
            id: 'msg_001',
            type: MsgDirection.S2C,
            from: Int64(0),
            to: Int64(1000000051),
            msgType: ContentType.CUSTOM,
            action: 'logged_another_device',
            payload: payload.writeToBuffer(),
            createdAt: Int64(1746300000000),
            serverTs: Int64(1746300000100),
          );
          final bytes = msg.writeToBuffer();

          // Act
          final result = ImboyPbCodec.tryDecode(Uint8List.fromList(bytes));

          // Assert: should decode to Map<String, dynamic> successfully
          expect(result, isNotNull);
          expect(result!['id'], 'msg_001');
          expect(result['type'], 'S2C');
          expect(result['from'], 0);
          expect(result['to'], 1000000051);
          final dispatched = parseWebSocketMessage(jsonEncode(result));
          expect(dispatched['from'], '0');
          expect(dispatched['to'], '1000000051');
          expect(result['action'], 'logged_another_device');
          expect(result['server_ts'], 1746300000100);

          // payload should be JSON-decoded Map<String, dynamic>
          final payloadMap = result['payload'];
          expect(payloadMap, isA<Map<String, dynamic>>());
          expect(payloadMap['did'], 'device-abc-123');
          expect(payloadMap['dname'], 'iPhone 16e');
        },
      );

      test('returns null for non-protobuf binary (random bytes)', () {
        final randomBytes = Uint8List.fromList([0x89, 0x50, 0x4E, 0x47]);
        final result = ImboyPbCodec.tryDecode(randomBytes);
        expect(result, isNull);
      });

      test('leaves protobuf without an application direction unclassified', () {
        // Minimal protobuf message (only id field)
        final msg = IMBoyMessage(id: 'minimal');
        final bytes = msg.writeToBuffer();

        final result = ImboyPbCodec.tryDecode(Uint8List.fromList(bytes));

        expect(result, isNull);
      });
    });

    group('tryDecodeJsonFallback', () {
      test('decodes valid JSON bytes to Map<String, dynamic>', () {
        final json = jsonEncode({
          'id': 'msg_002',
          'type': 'S2C',
          'action': 'logged_another_device',
          'payload': {'did': 'dev-456', 'dname': 'Pixel 9'},
        });
        final bytes = Uint8List.fromList(utf8.encode(json));

        final result = ImboyPbCodec.tryDecodeJsonFallback(bytes);

        expect(result, isNotNull);
        expect(result!['id'], 'msg_002');
        expect(result['action'], 'logged_another_device');
        expect(result['payload']['did'], 'dev-456');
      });

      test('returns null for invalid UTF-8', () {
        final badBytes = Uint8List.fromList([0xFF, 0xFE, 0xFD]);
        final result = ImboyPbCodec.tryDecodeJsonFallback(badBytes);
        expect(result, isNull);
      });

      test('returns null for valid UTF-8 but invalid JSON', () {
        final bytes = Uint8List.fromList(utf8.encode('not json'));
        final result = ImboyPbCodec.tryDecodeJsonFallback(bytes);
        expect(result, isNull);
      });
    });

    group('round-trip: protobuf encode -> decode', () {
      for (final direction in [
        MsgDirection.C2C,
        MsgDirection.C2G,
        MsgDirection.S2C,
        MsgDirection.C2S,
      ]) {
        test(
          '${direction.name} preserves TSIDs and opaque payload across encodings',
          () {
            const from = '18382940179824651';
            const to = '18382940179824659';
            const payload = {
              'text': '会话🗨️ résumé',
              'reply_to': {'msg_id': 'original_001', 'from_id': from},
              'snippet': null,
            };
            final json = parseWebSocketMessage(
              '{"id":"quoted_001","type":"${direction.name}",'
              '"from":$from,"to":$to,"payload":${jsonEncode(payload)}}',
            );
            final protobuf = ImboyPbCodec.tryDecode(
              IMBoyMessage(
                id: 'quoted_001',
                type: direction,
                from: Int64.parseInt(from),
                to: Int64.parseInt(to),
                payload: utf8.encode(jsonEncode(payload)),
              ).writeToBuffer(),
            )!;
            expect(protobuf['from'], from);
            expect(protobuf['to'], to);
            final dispatched = parseWebSocketMessage(jsonEncode(protobuf));
            for (final decoded in [json, dispatched]) {
              expect(decoded['id'], 'quoted_001');
              expect(decoded['from'], from);
              expect(decoded['to'], to);
              expect(decoded['payload'], payload);
              expect(decoded['e2ee'], isNull);
            }
          },
        );
      }

      test('JSON fallback retains unsupported protobuf correlation fields', () {
        final result = parseWebSocketMessage(
          '{"type":"C2S","id":"result_1","action":"sync_resp",'
          '"in_reply_to":"request_1","payload":{"results":[]}}',
        );
        expect(result['in_reply_to'], 'request_1');
        expect(result['payload'], {'results': <Object>[]});
        expect(result.containsKey('to'), isFalse);
      });

      test('legacy encrypted payload remains the original opaque string', () {
        const ciphertext = 'bm9uY2U=.Y2lwaGVydGV4dA==';
        const suite = 'RSA-OAEP-256+AES-256-GCM';
        final result = ImboyPbCodec.tryDecode(
          IMBoyMessage(
            id: 'encrypted_1',
            type: MsgDirection.C2C,
            msgType: ContentType.E2EE,
            e2ee: E2EEMeta(ver: 1, suite: suite),
            payload: utf8.encode(ciphertext),
          ).writeToBuffer(),
        )!;
        expect(result['payload'], ciphertext);
        expect(result['e2ee'], containsPair('e2ee_ver', 1));
        expect(result['e2ee'], containsPair('e2ee_suite', suite));
      });

      test(
        'protobuf distinguishes explicit zero from absent routing fields',
        () {
          final message = IMBoyMessage(
            id: 'encrypted_2',
            type: MsgDirection.C2C,
            msgType: ContentType.E2EE,
            e2ee: E2EEMeta(protocol: 'olm', messageType: 0),
            payload: utf8.encode('Y2lwaGVydGV4dA=='),
          );
          final explicit = ImboyPbCodec.tryDecode(message.writeToBuffer())!;
          expect(explicit['e2ee'], containsPair('message_type', 0));
          message.e2ee.clearMessageType();
          final omitted = ImboyPbCodec.tryDecode(message.writeToBuffer())!;
          final metadata = omitted['e2ee'] as Map<String, dynamic>;
          expect(metadata.containsKey('message_type'), isFalse);
        },
      );

      test('logged_another_device message survives round-trip', () {
        final innerPayload = PayloadLoggedAnotherDevice(
          did: 'dev-rt-001',
          dname: 'MacBook Pro',
        );
        final original = IMBoyMessage(
          id: 'rt_msg',
          type: MsgDirection.S2C,
          from: Int64(0),
          to: Int64(999),
          action: 'logged_another_device',
          payload: innerPayload.writeToBuffer(),
          createdAt: Int64(1746300000000),
        );

        final encoded = original.writeToBuffer();
        final decoded = ImboyPbCodec.tryDecode(Uint8List.fromList(encoded));

        expect(decoded, isNotNull);
        expect(decoded!['id'], 'rt_msg');
        expect(decoded['action'], 'logged_another_device');
        final inner = decoded['payload'] as Map<String, dynamic>;
        expect(inner['did'], 'dev-rt-001');
        expect(inner['dname'], 'MacBook Pro');
      });

      test('please_refresh_token round-trip', () {
        final inner = PayloadRefreshToken(expireAt: Int64(1746303600000));
        final msg = IMBoyMessage(
          id: 'rt_token',
          type: MsgDirection.S2C,
          action: 'please_refresh_token',
          payload: inner.writeToBuffer(),
        );

        final decoded = ImboyPbCodec.tryDecode(
          Uint8List.fromList(msg.writeToBuffer()),
        );

        expect(decoded, isNotNull);
        expect(decoded!['action'], 'please_refresh_token');
        final p = decoded['payload'] as Map<String, dynamic>;
        expect(p['expire_at'], 1746303600000);
      });

      test('device_force_offline round-trip', () {
        final inner = PayloadDeviceKicked(reason: 'duplicate_login');
        final msg = IMBoyMessage(
          id: 'rt_kick',
          type: MsgDirection.S2C,
          action: 'device_force_offline',
          payload: inner.writeToBuffer(),
        );

        final decoded = ImboyPbCodec.tryDecode(
          Uint8List.fromList(msg.writeToBuffer()),
        );

        expect(decoded, isNotNull);
        expect(decoded!['action'], 'device_force_offline');
        final p = decoded['payload'] as Map<String, dynamic>;
        expect(p['reason'], 'duplicate_login');
      });

      test('c2c_del_everyone round-trip', () {
        final inner = PayloadMsgDeleted(oldMsgId: 'original_123');
        final msg = IMBoyMessage(
          id: 'rt_del',
          type: MsgDirection.S2C,
          action: 'c2c_del_everyone',
          payload: inner.writeToBuffer(),
        );

        final decoded = ImboyPbCodec.tryDecode(
          Uint8List.fromList(msg.writeToBuffer()),
        );

        expect(decoded, isNotNull);
        expect(decoded!['action'], 'c2c_del_everyone');
        final p = decoded['payload'] as Map<String, dynamic>;
        expect(p['old_msg_id'], 'original_123');
      });

      test('app_upgrade round-trip', () {
        final inner = PayloadAppUpgrade(
          upgradeType: 'soft',
          vsn: '2.0.0',
          downloadUrl: 'https://example.com/app.apk',
        );
        final msg = IMBoyMessage(
          id: 'rt_upgrade',
          type: MsgDirection.S2C,
          action: 'app_upgrade',
          payload: inner.writeToBuffer(),
        );

        final decoded = ImboyPbCodec.tryDecode(
          Uint8List.fromList(msg.writeToBuffer()),
        );

        expect(decoded, isNotNull);
        expect(decoded!['action'], 'app_upgrade');
        final p = decoded['payload'] as Map<String, dynamic>;
        expect(p['upgrade_type'], 'soft');
        expect(p['vsn'], '2.0.0');
        expect(p['download_url'], 'https://example.com/app.apk');
      });

      test('inner payload JSON fallback when not protobuf', () {
        // Simulate backend sending JSON as inner payload bytes
        final innerJson = utf8.encode(jsonEncode({'expire_at': 1234567890}));
        final msg = IMBoyMessage(
          id: 'json_inner',
          type: MsgDirection.S2C,
          action: 'please_refresh_token',
          payload: innerJson,
        );

        final decoded = ImboyPbCodec.tryDecode(
          Uint8List.fromList(msg.writeToBuffer()),
        );

        expect(decoded, isNotNull);
        final p = decoded!['payload'] as Map<String, dynamic>;
        // JSON fallback should parse the inner bytes as JSON
        expect(p['expire_at'], 1234567890);
      });
    });
  });
}
