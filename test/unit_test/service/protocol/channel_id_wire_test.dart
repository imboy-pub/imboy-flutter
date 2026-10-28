import 'dart:convert';
import 'dart:typed_data';

import 'package:fixnum/fixnum.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/service/protocol/imboy.pb.dart';
import 'package:imboy/service/protocol/imboy_frame.dart';
import 'package:imboy/service/protocol/imboy_pb_codec.dart';

void main() {
  test('v2 direct message retains adjacent sender and recipient IDs', () {
    final message = IMBoyMessage(
      id: 'direct-message',
      type: MsgDirection.C2C,
      from: Int64.parseInt('9007199254740993'),
      to: Int64.parseInt('9007199254740995'),
    );
    final encoded = ImboyFrame.encode(
      type: FrameType.msgC2C,
      flags: 0,
      payload: Uint8List.fromList(message.writeToBuffer()),
    );
    final (frames, _) = ImboyFrame.decodeStream(encoded);
    final decoded = ImboyPbCodec.tryDecode(frames.single.payload)!;
    expect(decoded['from'], '9007199254740993');
    expect(decoded['to'], '9007199254740995');
  });
  test('v2 group message keeps from and to exact', () {
    final message = IMBoyMessage(
      id: 'group-message',
      type: MsgDirection.C2G,
      from: Int64.parseInt('9007199254740993'),
      to: Int64.parseInt('9007199254740995'),
    );
    final encoded = ImboyFrame.encode(
      type: FrameType.msgC2G,
      flags: 0,
      payload: Uint8List.fromList(message.writeToBuffer()),
    );
    final (frames, _) = ImboyFrame.decodeStream(encoded);
    final decoded = ImboyPbCodec.tryDecode(frames.single.payload)!;
    expect(decoded['from'], '9007199254740993');
    expect(decoded['to'], '9007199254740995');
  });
  test('v2 protobuf group event keeps raw identities exact', () {
    final message = IMBoyMessage(
      id: 'synthetic-group',
      type: MsgDirection.S2C,
      action: 'group_member_leave',
      from: Int64.parseInt('9007199254740993'),
      to: Int64.parseInt('9007199254740995'),
      payload: utf8.encode(
        '{"gid":9007199254740995,"leave_uid":9007199254740993,"role":3}',
      ),
    );
    final encoded = ImboyFrame.encode(
      type: FrameType.msgS2C,
      flags: 0,
      payload: Uint8List.fromList(message.writeToBuffer()),
    );
    final (frames, _) = ImboyFrame.decodeStream(encoded);
    final decoded = ImboyPbCodec.tryDecode(frames.single.payload)!;
    expect(decoded['from'], '9007199254740993');
    expect(decoded['to'], '9007199254740995');
    expect(decoded['payload']['gid'], '9007199254740995');
    expect(decoded['payload']['leave_uid'], '9007199254740993');
    expect(decoded['payload']['role'], 3);
  });
  test('v2 protobuf channel message keeps raw payload IDs exact', () {
    final message = IMBoyMessage(
      id: 'synthetic',
      type: MsgDirection.S2C,
      action: 'channel_message',
      from: Int64.parseInt('9007199254740993'),
      to: Int64.parseInt('9007199254740995'),
      payload: utf8.encode(
        '{"id":9007199254740993,"channel_id":9007199254740995,"author_id":9007199254740997,"content":"ok"}',
      ),
    );
    final encoded = ImboyFrame.encode(
      type: FrameType.msgS2C,
      flags: 0,
      payload: Uint8List.fromList(message.writeToBuffer()),
    );
    final (frames, remaining) = ImboyFrame.decodeStream(encoded);
    expect(remaining, isEmpty);
    expect(frames, hasLength(1));
    final decoded = ImboyPbCodec.tryDecode(frames.single.payload)!;
    expect(decoded['from'], '9007199254740993');
    expect(decoded['to'], '9007199254740995');
    final payload = decoded['payload'] as Map;
    expect(payload['id'], '9007199254740993');
    expect(payload['channel_id'], '9007199254740995');
    expect(payload['author_id'], '9007199254740997');
    expect(payload['content'], 'ok');
  });
}
