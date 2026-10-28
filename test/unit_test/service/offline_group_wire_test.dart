import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/component/http/channel_id_response_decoder.dart';

void main() {
  test('offline decoding targets each action only and retains cursors and counts', () {
    const raw =
        '{"code":0,"payload":{"s2c":{"next_last_msg_at":12345,"list":[{"payload":{"gid":9007199254740993,"user_id":9007199254740995,"role":3},"action":"group_member_role","msg_id":9007199254740997},{"action":"unrelated","payload":{"gid":123,"user_id":456}},{"action":"channel_message","payload":{"channel_id":9007199254740993,"id":9007199254740995,"channel":{"id":9007199254740997},"count":5}}]},"c2c":{"list":[{"payload":{"gid":123}}]}}}';
    final result =
        jsonDecode(rewriteChannelIds(raw, ChannelResponseShape.offline)) as Map;
    final payload = result['payload'] as Map;
    final s2c = payload['s2c'] as Map;
    final rows = s2c['list'] as List;
    expect(s2c['next_last_msg_at'], 12345);
    expect(rows[0]['msg_id'], '9007199254740997');
    expect(rows[0]['payload']['gid'], '9007199254740993');
    expect(rows[0]['payload']['user_id'], '9007199254740995');
    expect(rows[0]['payload']['role'], 3);
    expect(rows[1]['payload']['gid'], 123);
    expect(rows[2]['payload']['channel_id'], '9007199254740993');
    expect(rows[2]['payload']['id'], '9007199254740995');
    expect(rows[2]['payload']['channel']['id'], '9007199254740997');
    expect(rows[2]['payload']['count'], 5);
    expect(payload['c2c']['list'][0]['payload']['gid'], 123);
  });
}
