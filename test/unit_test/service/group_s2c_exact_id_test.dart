import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/component/http/channel_id_response_decoder.dart';
import 'package:imboy/service/group_edit_s2c.dart';
import 'package:imboy/service/group_member_mute_s2c.dart';
import 'package:imboy/service/group_member_role_s2c.dart';
import 'package:imboy/service/group_notice_s2c.dart';
import 'package:imboy/service/group_transfer_s2c.dart';
import 'package:imboy/service/protocol/imboy.pb.dart';
import 'package:imboy/service/protocol/imboy_frame.dart';
import 'package:imboy/service/protocol/imboy_pb_codec.dart';

void main() {
  const gid = '9007199254740993';
  const uid = '9007199254740995';
  const raw =
      '{"gid":9007199254740993,"user_id":9007199254740995,"role":3,"mute_until":1,"from_owner_uid":9007199254740995,"to_owner_uid":9007199254740997,"notice_id":9007199254740997,"publisher_id":9007199254740995}';

  void check(Map<String, dynamic> payload) {
    final role = parseGroupMemberRolePayload(payload) as GroupMemberRolePayload;
    expect((role.gid, role.userId, role.role), (gid, uid, 3));
    final mute = parseGroupMemberMutePayload(payload) as GroupMemberMutePayload;
    expect((mute.gid, mute.userId), (gid, uid));
    final transfer = parseGroupTransferPayload(payload) as GroupTransferPayload;
    expect(
      (transfer.gid, transfer.fromOwnerUid, transfer.toOwnerUid),
      (gid, uid, '9007199254740997'),
    );
    expect((parseGroupEditPayload(payload) as GroupEditPayload).gid, gid);
    final notice = parseGroupNoticePublishedPayload(
      payload,
    ) as GroupNoticePublishedPayload;
    expect(
      (notice.gid, notice.noticeId, notice.publisherId),
      (gid, '9007199254740997', uid),
    );
  }

  test('group raw JSON ids survive all event parsers', () {
    final decoded = jsonDecode(
      rewriteChannelIds('{"payload":$raw}', ChannelResponseShape.groupSocket),
    );
    check(Map<String, dynamic>.from(decoded['payload'] as Map));
  });

  test('v2 protobuf group payload ids survive event parsing', () {
    final message = IMBoyMessage(
      id: 'synthetic',
      type: MsgDirection.S2C,
      action: 'group_member_role',
      payload: utf8.encode(raw),
    );
    final frame = ImboyFrame.encode(
      type: FrameType.msgS2C,
      flags: 0,
      payload: Uint8List.fromList(message.writeToBuffer()),
    );
    final (frames, _) = ImboyFrame.decodeStream(frame);
    final decoded = ImboyPbCodec.tryDecode(frames.single.payload)!;
    check(Map<String, dynamic>.from(decoded['payload'] as Map));
  });
}
