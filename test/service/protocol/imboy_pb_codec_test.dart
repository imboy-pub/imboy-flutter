import 'dart:convert';
import 'dart:typed_data';

import 'package:fixnum/fixnum.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/service/protocol/imboy.pb.dart';
import 'package:imboy/service/protocol/imboy_pb_codec.dart';

void main() {
  group('ImboyPbCodec', () {
    group('tryDecode', () {
      test('decodes protobuf IMBoyMessage with logged_another_device action',
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

        // Assert: should decode to Map successfully
        expect(result, isNotNull);
        expect(result!['id'], 'msg_001');
        expect(result['type'], 'S2C');
        expect(result['from'], 0);
        expect(result['to'], 1000000051);
        expect(result['action'], 'logged_another_device');
        expect(result['server_ts'], 1746300000100);

        // payload should be JSON-decoded Map
        final payloadMap = result['payload'];
        expect(payloadMap, isA<Map>());
        expect(payloadMap['did'], 'device-abc-123');
        expect(payloadMap['dname'], 'iPhone 16e');
      });

      test('returns null for non-protobuf binary (random bytes)', () {
        final randomBytes = Uint8List.fromList([0x89, 0x50, 0x4E, 0x47]);
        final result = ImboyPbCodec.tryDecode(randomBytes);
        expect(result, isNull);
      });

      test(
          'falls back gracefully for valid protobuf but missing required fields',
          () {
        // Minimal protobuf message (only id field)
        final msg = IMBoyMessage(id: 'minimal');
        final bytes = msg.writeToBuffer();

        final result = ImboyPbCodec.tryDecode(Uint8List.fromList(bytes));

        expect(result, isNotNull);
        expect(result!['id'], 'minimal');
        expect(result['action'], isEmpty);
      });
    });

    group('tryDecodeJsonFallback', () {
      test('decodes valid JSON bytes to Map', () {
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
        final inner = decoded['payload'] as Map;
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

        final decoded =
            ImboyPbCodec.tryDecode(Uint8List.fromList(msg.writeToBuffer()));

        expect(decoded, isNotNull);
        expect(decoded!['action'], 'please_refresh_token');
        final p = decoded['payload'] as Map;
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

        final decoded =
            ImboyPbCodec.tryDecode(Uint8List.fromList(msg.writeToBuffer()));

        expect(decoded, isNotNull);
        expect(decoded!['action'], 'device_force_offline');
        final p = decoded['payload'] as Map;
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

        final decoded =
            ImboyPbCodec.tryDecode(Uint8List.fromList(msg.writeToBuffer()));

        expect(decoded, isNotNull);
        expect(decoded!['action'], 'c2c_del_everyone');
        final p = decoded['payload'] as Map;
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

        final decoded =
            ImboyPbCodec.tryDecode(Uint8List.fromList(msg.writeToBuffer()));

        expect(decoded, isNotNull);
        expect(decoded!['action'], 'app_upgrade');
        final p = decoded['payload'] as Map;
        expect(p['upgrade_type'], 'soft');
        expect(p['vsn'], '2.0.0');
        expect(p['download_url'], 'https://example.com/app.apk');
      });

      test('inner payload JSON fallback when not protobuf', () {
        // Simulate backend sending JSON as inner payload bytes
        final innerJson =
            utf8.encode(jsonEncode({'expire_at': 1234567890}));
        final msg = IMBoyMessage(
          id: 'json_inner',
          type: MsgDirection.S2C,
          action: 'please_refresh_token',
          payload: innerJson,
        );

        final decoded =
            ImboyPbCodec.tryDecode(Uint8List.fromList(msg.writeToBuffer()));

        expect(decoded, isNotNull);
        final p = decoded!['payload'] as Map;
        // JSON fallback should parse the inner bytes as JSON
        expect(p['expire_at'], 1234567890);
      });
    });
  });
}
