import 'dart:convert';

import 'package:fixnum/fixnum.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/component/http/channel_id_response_decoder.dart';
import 'package:imboy/service/e2ee/trust_event_canonical.dart';
import 'package:imboy/service/e2ee/trust_event_client.dart';
import 'package:imboy/service/event_bus.dart';
import 'package:imboy/service/events/message_events.dart';
import 'package:imboy/service/message_s2c.dart';
import 'package:imboy/config/const.dart' show Keys;
import 'package:imboy/service/storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:imboy/service/protocol/imboy.pb.dart';
import 'package:imboy/service/protocol/imboy_frame.dart';
import 'package:imboy/service/protocol/imboy_pb_codec.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const actor = '9007199254740993';
  const target = '9007199254740995';
  const rawPayload =
      '{"actor_uid":9007199254740993,"target_uid":9007199254740995,"target_device_id":"d","to_state":"revoked","method":"revoke","event_id":"abc","issued_at":123}';

  test('canonical bytes and request preserve adjacent IDs', () {
    const fields = TrustEventCanonicalFields(
      actorDeviceGeneration: 1,
      actorUid: actor,
      eventId: 'abc',
      expiresAt: 200,
      fromState: 'verified',
      issuedAt: 100,
      targetDeviceId: 'd',
      targetEd25519: 'key',
      targetIdentityVersion: 1,
      targetUid: target,
      toState: 'revoked',
    );
    final text = utf8.decode(fields.canonicalBytes());
    expect(text, contains('actor_uid=$actor\n'));
    expect(text, contains('target_uid=$target\n'));
    final body = buildTrustRecordRequest(
      fields: fields,
      actorDeviceId: 'a',
      method: 'revoke',
      actorSignatureB64: 'sig',
    );
    expect(body['target_uid'], kIsWeb ? target : int.parse(target));
    expect(body.containsKey('actor_uid'), isFalse);
    expect(() => trustUid('9223372036854775808'), throwsFormatException);
    expect(() => trustUid('-1'), throwsFormatException);
    expect(() => trustUid('01'), throwsFormatException);
  });

  test('JSON and offline trust event preserve raw IDs and other values', () {
    final socket = jsonDecode(
      rewriteChannelIds(
        '{"action":"e2ee_trust_changed","payload":$rawPayload}',
        ChannelResponseShape.trustSocket,
      ),
    ) as Map;
    final event = TrustChangedEvent.fromBroadcast(
      Map<String, dynamic>.from(socket['payload'] as Map),
    );
    expect(event.actorUid, actor);
    expect(event.targetUid, target);
    expect(event.issuedAt, 123);
    final offline = jsonDecode(
      rewriteChannelIds(
        '{"payload":{"s2c":{"list":[{"action":"e2ee_trust_changed","payload":$rawPayload}]}}}',
        ChannelResponseShape.offline,
      ),
    ) as Map;
    final payload =
        (((offline['payload'] as Map)['s2c'] as Map)['list'] as List)
                .single['payload']
            as Map;
    expect(payload['actor_uid'], actor);
    expect(payload['target_uid'], target);
    expect(payload['issued_at'], 123);
  });

  test('protobuf binary trust payload preserves adjacent IDs', () {
    final message = IMBoyMessage(
      id: 'synthetic',
      type: MsgDirection.S2C,
      action: 'e2ee_trust_changed',
      from: Int64.ONE,
      to: Int64.ONE,
      payload: utf8.encode(rawPayload),
    );
    final frame = ImboyFrame.encode(
      type: FrameType.msgS2C,
      flags: 0,
      payload: Uint8List.fromList(message.writeToBuffer()),
    );
    final (frames, _) = ImboyFrame.decodeStream(frame);
    final decoded = ImboyPbCodec.tryDecode(frames.single.payload)!;
    final event = TrustChangedEvent.fromBroadcast(
      Map<String, dynamic>.from(decoded['payload'] as Map),
    );
    expect(event.actorUid, actor);
    expect(event.targetUid, target);
  });

  test('device key change preserves UID in JSON, offline and protobuf', () {
    const devicePayload =
        '{"uid":9007199254740993,"device_id":"d","device_type":"ios","key_id":"key"}';
    final online = jsonDecode(
      rewriteChannelIds(
        '{"action":"e2ee_device_key_changed","payload":$devicePayload}',
        ChannelResponseShape.deviceKeySocket,
      ),
    ) as Map;
    expect((online['payload'] as Map)['uid'], actor);
    final offline = jsonDecode(
      rewriteChannelIds(
        '{"payload":{"s2c":{"list":[{"action":"e2ee_device_key_changed","payload":$devicePayload}]}}}',
        ChannelResponseShape.offline,
      ),
    ) as Map;
    final payload =
        (((offline['payload'] as Map)['s2c'] as Map)['list'] as List)
                .single['payload']
            as Map;
    expect(payload['uid'], actor);
    final message = IMBoyMessage(
      id: 'key-change',
      type: MsgDirection.S2C,
      action: 'e2ee_device_key_changed',
      from: Int64.parseInt(actor),
      to: Int64.parseInt(target),
      payload: utf8.encode(devicePayload),
    );
    final frame = ImboyFrame.encode(
      type: FrameType.msgS2C,
      flags: 0,
      payload: Uint8List.fromList(message.writeToBuffer()),
    );
    final (frames, _) = ImboyFrame.decodeStream(frame);
    final decoded = ImboyPbCodec.tryDecode(frames.single.payload)!;
    expect((decoded['payload'] as Map)['uid'], actor);
    expect(decoded['from'], actor);
    expect(decoded['to'], target);
  });

  test('raw device change dispatches the exact UID', () async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
    await StorageService.to.setString(Keys.currentUid, '2');
    const storage = MethodChannel(
      'plugins.it_nomads.com/flutter_secure_storage',
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(storage, (call) async => null);
    final events = <E2EEPeerKeyChangedEvent>[];
    final subscription = AppEventBus.on<E2EEPeerKeyChangedEvent>().listen(
      events.add,
    );
    try {
      final raw =
          '{"id":"","type":"S2C","action":"e2ee_device_key_changed","from":1,"to":2,"payload":{"uid":9007199254740993,"device_id":"","device_type":"ios","key_id":"key"}}';
      final parsed = jsonDecode(
        rewriteChannelIds(raw, ChannelResponseShape.deviceKeySocket),
      ) as Map<String, dynamic>;
      await MessageS2CService.switchS2C(parsed);
      await Future<void>.delayed(Duration.zero);
      expect(events.map((event) => event.uid), [actor]);
    } finally {
      await subscription.cancel();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(storage, null);
    }
  });
}
