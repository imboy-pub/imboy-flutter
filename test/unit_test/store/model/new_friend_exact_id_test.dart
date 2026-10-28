import 'dart:convert';

import 'package:fixnum/fixnum.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/component/http/channel_id_response_decoder.dart';
import 'package:imboy/service/protocol/imboy.pb.dart';
import 'package:imboy/service/protocol/imboy_pb_codec.dart';
import 'package:imboy/store/model/new_friend_model.dart';

void main() {
  test(
    'friend events preserve sender and recipient in raw JSON and protobuf',
    () {
      for (final action in ['apply_friend', 'apply_friend_confirm']) {
        final raw =
            '{"action":"$action","from":9007199254740993,'
            '"to":9007199254740995,"payload":{}}';
        final event = jsonDecode(
          rewriteChannelIds(raw, ChannelResponseShape.groupSocket),
        ) as Map;
        final model = NewFriendModel.fromJson(Map<String, dynamic>.from(event));
        expect(model.from, '9007199254740993');
        expect(model.to, '9007199254740995');
        final frame = IMBoyMessage(
          id: 'af_test',
          type: MsgDirection.S2C,
          action: action,
          from: Int64.parseInt('9007199254740993'),
          to: Int64.parseInt('9007199254740995'),
        );
        final decoded = ImboyPbCodec.tryDecode(frame.writeToBuffer())!;
        expect(decoded['from'], model.from);
        expect(decoded['to'], model.to);
      }
    },
  );

  test(
    'offline friend events preserve IDs without changing unrelated events',
    () {
      const raw =
          '{"payload":{"s2c":{"list":['
          '{"action":"apply_friend","from":9007199254740993,"to":9007199254740995},'
          '{"action":"other","from":10,"to":11}]}}}';
      final decoded = jsonDecode(
        rewriteChannelIds(raw, ChannelResponseShape.offline),
      ) as Map;
      final rows = ((decoded['payload'] as Map)['s2c'] as Map)['list'] as List;
      expect(rows[0]['from'], '9007199254740993');
      expect(rows[0]['to'], '9007199254740995');
      expect(rows[1]['from'], 10);
    },
  );

  test('confirmation response retains current and legacy peer IDs', () {
    for (final key in ['id', 'peerId']) {
      final decoded = jsonDecode(
        rewriteChannelIds(
          '{"payload":{"$key":9007199254740993,"is_friend":1}}',
          ChannelResponseShape.contact,
        ),
      ) as Map;
      expect(decoded['payload'][key], '9007199254740993');
      expect(decoded['payload']['is_friend'], 1);
    }
  });
}
