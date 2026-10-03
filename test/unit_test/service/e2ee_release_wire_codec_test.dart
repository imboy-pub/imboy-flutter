import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/service/protocol/imboy_frame.dart';
import 'package:imboy/service/protocol/imboy.pb.dart';

import '../../../integration_test/e2ee_release/harness/release_wire_codec.dart';

void main() {
  final message = {'id': 'xid', 'type': 'C2C', 'payload': 'encrypted'};
  Uint8List frame({int flags = 0, int type = FrameType.msgS2C}) =>
      ImboyFrame.encode(
        type: type,
        flags: flags,
        payload: Uint8List.fromList(
          utf8.encode(
            jsonEncode({
              'id': 'xid',
              'type': 'C2C_SERVER_ACK',
              'in_reply_to': 'xid',
            }),
          ),
        ),
      );
  for (final protocol in ['imboy.v2', 'imboy-json', 'text', 'sip', null]) {
    test('round trip $protocol uses production framing', () {
      final codec = ReleaseWireCodec(protocol);
      final encoded = codec.encode(message);
      expect(encoded is Uint8List, protocol == 'imboy.v2');
      expect(codec.decode(encoded).message, message);
    });
  }
  test('JSON ACK fallback retains correlation inside v2', () {
    final result = ReleaseWireCodec('imboy.v2').decode(frame());
    expect(result.message!['in_reply_to'], 'xid');
    expect(result.message!['type'], 'C2C_SERVER_ACK');
  });
  test('decodes production protobuf business payload inside v2', () {
    final payload = IMBoyMessage(id: 'xid', type: MsgDirection.C2C);
    final bytes = ImboyFrame.encode(
      type: FrameType.msgC2C,
      flags: 0,
      payload: Uint8List.fromList(payload.writeToBuffer()),
    );
    final result = ReleaseWireCodec('imboy.v2').decode(bytes);
    expect(result.message!['id'], 'xid');
    expect(result.message!['type'], 'C2C');
  });
  test('heartbeat sequence remains a control payload', () {
    final codec = ReleaseWireCodec('imboy.v2');
    final result = codec.decode(ImboyFrame.heartbeatPing(321));
    expect(result.message, isNull);
    expect(result.controlType, FrameType.heartbeatPing);
    expect(result.controlPayload, [1, 65]);
    expect(() => result.controlPayload.clear(), throwsUnsupportedError);
    expect(codec.decode(frame(type: FrameType.ack)).message, isNull);
  });
  test('rejects truncation trailing bytes and wrong version', () {
    final codec = ReleaseWireCodec('imboy.v2');
    final bytes = frame();
    expect(
      () => codec.decode(bytes.sublist(0, bytes.length - 1)),
      throwsFormatException,
    );
    expect(() => codec.decode([...bytes, 0]), throwsFormatException);
    bytes[2] = 3;
    expect(() => codec.decode(bytes), throwsFormatException);
  });
  test('rejects unsupported transformations and protocol', () {
    final codec = ReleaseWireCodec('imboy.v2');
    expect(
      () => codec.decode(frame(flags: FrameFlags.cmp)),
      throwsFormatException,
    );
    expect(
      () => codec.decode(frame(flags: FrameFlags.enc)),
      throwsFormatException,
    );
    expect(() => ReleaseWireCodec('unknown'), throwsFormatException);
  });
  test('rejects empty protobuf, malformed JSON and invalid bytes', () {
    final codec = ReleaseWireCodec('imboy.v2');
    expect(
      () => codec.decode(
        ImboyFrame.encode(
          type: FrameType.msgS2C,
          flags: 0,
          payload: Uint8List(0),
        ),
      ),
      throwsFormatException,
    );
    expect(() => codec.decode('[]'), throwsFormatException);
    expect(() => codec.decode('{'), throwsFormatException);
    expect(() => codec.decode([256]), throwsFormatException);
    expect(
      () => codec.encode({'id': '', 'type': 'C2C'}),
      throwsFormatException,
    );
  });
  test('legacy heartbeat and bounded payload', () {
    final codec = ReleaseWireCodec('text');
    expect(codec.decode('pong').controlType, FrameType.heartbeatPong);
    expect(
      () => codec.decode('x' * (ReleaseWireCodec.maxBytes + 1)),
      throwsFormatException,
    );
  });
}
