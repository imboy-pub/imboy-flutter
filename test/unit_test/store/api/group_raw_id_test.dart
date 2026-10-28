import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:imboy/component/http/channel_id_response_decoder.dart';
import 'package:imboy/store/model/group_model.dart';
import 'package:imboy/store/model/contact_model.dart';
import 'package:imboy/store/model/channel_decimal_id.dart';

void main() {
  test('offline C2C and C2G retain raw sender and recipient IDs', () {
    const raw =
        '{"payload":{"c2c":{"list":[{"from":9007199254740993,"to":9007199254740995,"created_at":10}]},"c2g":{"list":[{"from":9007199254740995,"to":9007199254740997}]}}}';
    final decoded = jsonDecode(
      rewriteChannelIds(raw, ChannelResponseShape.offline),
    );
    expect(decoded['payload']['c2c']['list'][0]['from'], '9007199254740993');
    expect(decoded['payload']['c2c']['list'][0]['to'], '9007199254740995');
    expect(decoded['payload']['c2c']['list'][0]['created_at'], 10);
    expect(decoded['payload']['c2g']['list'][0]['to'], '9007199254740997');
  });
  test('wire IDs preserve old numbers and avoid web rounding', () {
    expect(decimalIdForWire('42'), 42);
    final large = decimalIdForWire('9007199254740993');
    if (kIsWeb) {
      expect(large, '9007199254740993');
    } else {
      expect(large, int.parse('9007199254740993'));
    }
  });
  test('adjacent contact identities remain distinct after raw decoding', () {
    const raw =
        '{"payload":{"friend":[{"id":9007199254740992,"nickname":"A"},{"id":9007199254740993,"nickname":"B"}]}}';
    final decoded = jsonDecode(
      rewriteChannelIds(raw, ChannelResponseShape.contact),
    );
    final friends = (decoded['payload']['friend'] as List)
        .map((e) => ContactModel.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();
    expect(friends.map((e) => e.peerId), [
      '9007199254740992',
      '9007199254740993',
    ]);
    expect(friends[0].peerId == friends[1].peerId, isFalse);
  });
  test('group list preserves raw identities without converting counts', () {
    const raw =
        '{"payload":{"list":[{"id":9007199254740993,"owner_uid":9007199254740995,"creator_uid":9007199254740997,"member_count":10}],"next_cursor":"signed-token"}}';
    final decoded = jsonDecode(
      rewriteChannelIds(raw, ChannelResponseShape.groupList),
    );
    final row = Map<String, dynamic>.from(decoded['payload']['list'][0] as Map);
    final group = GroupModel.fromJson(row);
    expect(group.groupId, '9007199254740993');
    expect(group.ownerUid, '9007199254740995');
    expect(group.creatorUid, '9007199254740997');
    expect(group.memberCount, 10);
    expect(decoded['payload']['next_cursor'], 'signed-token');
  });

  test('group creation and workspace cursor preserve raw identities', () {
    final created = jsonDecode(
      rewriteChannelIds(
        '{"payload":{"group":{"id":9007199254740993},"gid":9007199254740993}}',
        ChannelResponseShape.groupCreate,
      ),
    );
    final workspace = jsonDecode(
      rewriteChannelIds(
        '{"payload":{"workspace_id":9007199254740993,"next_cursor":9007199254740995,"list":[{"id":9007199254740995}]}}',
        ChannelResponseShape.groupWorkspace,
      ),
    );
    expect(created['payload']['group']['id'], '9007199254740993');
    expect(created['payload']['gid'], '9007199254740993');
    expect(workspace['payload']['workspace_id'], '9007199254740993');
    expect(workspace['payload']['next_cursor'], '9007199254740995');
  });
}
