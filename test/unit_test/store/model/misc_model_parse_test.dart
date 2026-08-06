import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/store/model/denylist_model.dart';
import 'package:imboy/store/model/feedback_model.dart';
import 'package:imboy/store/model/feedback_reply_model.dart';
import 'package:imboy/store/model/group_member_model.dart';
import 'package:imboy/store/model/group_model.dart';
import 'package:imboy/store/model/new_friend_model.dart';
import 'package:imboy/store/model/people_model.dart';
import 'package:imboy/store/model/user_device_model.dart';
import 'package:imboy/store/repository/group_member_repo_sqlite.dart';
import 'package:imboy/store/repository/new_friend_repo_sqlite.dart';
import 'package:imboy/store/repository/user_denylist_repo_sqlite.dart';

void main() {
  group('Misc model parsing', () {
    test('GroupModel.fromJson parses mixed primitive values safely', () {
      final model = GroupModel.fromJson({
        'group_id': 101,
        'type': true,
        'join_limit': '2',
        'content_limit': false,
        'user_id_sum': '7',
        'owner_uid': 9001,
        'creator_uid': 9002,
        'member_max': '500',
        'member_count': 12.0,
        'introduction': 123,
        'avatar': null,
        'title': false,
        'status': '1',
        'updated_at': '1767225600000',
        'created_at': 1767225600,
      });

      expect(model.groupId, 101);
      expect(model.type, 1);
      expect(model.joinLimit, 2);
      expect(model.contentLimit, 0);
      expect(model.userIdSum, 7);
      expect(model.ownerUid, 9001);
      expect(model.creatorUid, 9002);
      expect(model.memberMax, 500);
      expect(model.memberCount, 12);
      expect(model.introduction, '123');
      expect(model.avatar, '');
      expect(model.title, 'false');
      expect(model.status, 1);
    });

    test('GroupMemberModel.fromJson parses mixed primitive values safely', () {
      final model = GroupMemberModel.fromJson({
        GroupMemberRepo.id: '8',
        GroupMemberRepo.groupId: 201,
        GroupMemberRepo.userId: 3001,
        GroupMemberRepo.nickname: true,
        GroupMemberRepo.avatar: null,
        GroupMemberRepo.sign: false,
        GroupMemberRepo.account: 123456,
        GroupMemberRepo.inviteCode: 777,
        GroupMemberRepo.alias: false,
        GroupMemberRepo.description: 9,
        GroupMemberRepo.role: '3',
        GroupMemberRepo.isJoin: true,
        GroupMemberRepo.joinMode: 8,
        GroupMemberRepo.status: false,
        GroupMemberRepo.updatedAt: '1767225600000',
        GroupMemberRepo.createdAt: 1767225600,
      });

      expect(model.id, 8);
      expect(model.groupId, 201);
      expect(model.userId, 3001);
      expect(model.nickname, 'true');
      expect(model.avatar, '');
      expect(model.sign, 'false');
      expect(model.account, '123456');
      expect(model.inviteCode, '777');
      expect(model.alias, 'false');
      expect(model.description, '9');
      expect(model.role, 3);
      expect(model.isJoin, 1);
      expect(model.joinMode, '8');
      expect(model.status, 0);
    });

    test('NewFriendModel.fromJson parses mixed primitive values safely', () {
      final model = NewFriendModel.fromJson({
        NewFriendRepo.source: 11,
        NewFriendRepo.uid: 7001,
        NewFriendRepo.from: 7002,
        NewFriendRepo.to: 7003,
        NewFriendRepo.nickname: true,
        NewFriendRepo.avatar: null,
        NewFriendRepo.status: true,
        NewFriendRepo.msg: 123,
        NewFriendRepo.updatedAt: '1767225600000',
        NewFriendRepo.createdAt: 1767225600,
        NewFriendRepo.payload: {'k': 'v'},
      });

      expect(model.source, '11');
      expect(model.uid, 7001);
      expect(model.from, 7002);
      expect(model.to, 7003);
      expect(model.nickname, 'true');
      expect(model.avatar, isNull);
      expect(model.status, 1);
      expect(model.msg, '123');
      expect(model.payload, contains('"k":"v"'));
    });

    test('PeopleModel.fromJson parses mixed primitive values safely', () {
      final model = PeopleModel.fromJson({
        'id': 5001,
        'account': 6001,
        'nickname': null,
        'avatar': false,
        'gender': '2',
        'region': 88,
        'sign': 99,
        'distance': '12.5',
        'unit': 1,
        'is_friend': '1',
        'remark': 66,
        'friend_created_at': '1767225600000',
      });

      expect(model.id, 5001);
      expect(model.account, '6001');
      expect(model.nickname, '');
      expect(model.avatar, 'false');
      expect(model.gender, 2);
      expect(model.region, '88');
      expect(model.sign, '99');
      expect(model.distance, 12.5);
      expect(model.distanceUnit, '1');
      expect(model.isFriend, isTrue);
      expect(model.remark, '66');
    });

    test('DenylistModel.fromJson parses mixed primitive values safely', () {
      final model = DenylistModel.fromJson({
        'id': 8001,
        UserDenylistRepo.account: 8002,
        UserDenylistRepo.nickname: true,
        UserDenylistRepo.avatar: 123,
        UserDenylistRepo.remark: null,
        UserDenylistRepo.sign: false,
        UserDenylistRepo.createdAt: '1767225600000',
        UserDenylistRepo.gender: '2',
        UserDenylistRepo.region: 9,
        UserDenylistRepo.source: 4,
      });

      expect(model.deniedUid, 8001);
      expect(model.account, '8002');
      expect(model.nickname, 'true');
      expect(model.avatar, '123');
      expect(model.remark, '');
      expect(model.sign, 'false');
      expect(model.gender, 2);
      expect(model.region, '9');
      expect(model.source, '4');
    });

    test('FeedbackModel.fromJson parses mixed primitive values safely', () {
      final model = FeedbackModel.fromJson({
        'feedback_id': '9',
        'app_vsn': 71,
        'type': 100,
        'rating': true,
        'body': 123,
        'attach': '[1,"a"]',
        'reply_count': '5',
        'status': false,
        'updated_at': '1767225600000',
        'created_at': 1767225600,
      });

      expect(model.feedbackId, 9);
      expect(model.appVsn, '71');
      expect(model.type, '100');
      expect(model.rating, '1.0');
      expect(model.body, '123');
      expect(model.attach, [1, 'a']);
      expect(model.replyCount, 5);
      expect(model.status, 0);
    });

    test(
      'FeedbackReplyModel.fromJson parses mixed primitive values safely',
      () {
        final model = FeedbackReplyModel.fromJson({
          'feedback_reply_id': '10',
          'feedback_id': '9',
          'feedback_reply_pid': true,
          'replier_user_id': '88',
          'replier_name': 123,
          'body': false,
          'status': '1',
          'updated_at': '1767225600000',
          'created_at': 1767225600,
        });

        expect(model.feedbackReplyId, 10);
        expect(model.feedbackId, 9);
        expect(model.feedbackReplyPid, 1);
        expect(model.replierUserId, 88);
        expect(model.replierName, '123');
        expect(model.body, 'false');
        expect(model.status, 1);
      },
    );

    test('UserDeviceModel.fromJson parses mixed primitive values safely', () {
      final model = UserDeviceModel.fromJson({
        'device_id': 111,
        'device_name': true,
        'device_type': 22,
        'last_active_at': '1767225600000',
        'online': '1',
        'device_vsn': '{"systemVersion":"17.4"}',
      });

      expect(model.deviceId, '111');
      expect(model.deviceName, 'true');
      expect(model.deviceType, '22');
      expect(model.online, isTrue);
      expect(model.deviceVsn['systemVersion'], '17.4');
    });
  });
}
