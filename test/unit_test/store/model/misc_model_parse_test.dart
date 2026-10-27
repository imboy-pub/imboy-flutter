import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/store/model/denylist_model.dart';
import 'package:imboy/store/model/feedback_model.dart';
import 'package:imboy/store/model/feedback_reply_model.dart';
import 'package:imboy/store/model/group_member_model.dart';
import 'package:imboy/store/model/user_tag_model.dart';
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
      // 时间值断言：纯数字字符串不是 zoned ISO（后端 rfc3339 codec 合同），
      // 按未知处理为 0，绝不猜单位、绝不回填 now。
      expect(model.friendCreatedAt, 0);
      expect(model.registeredAt, 0);
    });

    group('PeopleModel 注册时间与好友关系时间分离 (R10)', () {
      test('R10-1 只有 created_at 时 registeredAt 为真实注册时间', () {
        final model = PeopleModel.fromJson({
          'uid': 5001,
          'account': '6001',
          'created_at': '2026-09-16T23:06:40.000Z',
        });
        expect(
          model.registeredAt,
          DateTime.utc(2026, 9, 16, 23, 6, 40).millisecondsSinceEpoch,
        );
        expect(model.registeredAt, 1789600000000);
        expect(model.friendCreatedAt, 0, reason: '无好友关系字段 → 未知');
      });

      test('R10-2 两个时间不同不串用（注册 vs 好友关系）', () {
        final model = PeopleModel.fromJson({
          'uid': 5001,
          'account': '6001',
          'created_at': '2026-09-16T23:06:40.000Z',
          'friend_created_at': '2026-09-20T02:00:00+08:00',
        });
        expect(
          model.registeredAt,
          DateTime.utc(2026, 9, 16, 23, 6, 40).millisecondsSinceEpoch,
        );
        expect(
          model.friendCreatedAt,
          DateTime.utc(2026, 9, 19, 18, 0, 0).millisecondsSinceEpoch,
        );
        expect(model.registeredAt, isNot(model.friendCreatedAt));
      });

      test('R10-3 缺失/非法不回填 now，UI 以 0 隐藏不显示"刚刚"', () {
        // 后端合同：注册时间缺失给空 binary（''）；非好友 friend_created_at
        // 给整数 0；无 zone 形态与纯数字字符串均按未知处理。
        final cases = <Map<String, dynamic>>[
          {'uid': 5001},
          {'uid': 5001, 'created_at': ''},
          {'uid': 5001, 'created_at': '2026-09-16T23:06:40'},
          {'uid': 5001, 'created_at': '1767225600000'},
          {'uid': 5001, 'friend_created_at': 0},
          {'uid': 5001, 'friend_created_at': 'garbage'},
        ];
        final nowMs = DateTime.now().millisecondsSinceEpoch;
        for (final json in cases) {
          final model = PeopleModel.fromJson(json);
          expect(model.registeredAt, 0, reason: '$json 注册时间缺失/非法 → 0');
          expect(model.friendCreatedAt, 0, reason: '$json 好友时间缺失/非法 → 0');
          // 0 即证明未回填 now（now 恒 > 0）；页面显示条件 >0 不成立 → 隐藏
          expect(model.registeredAt > 0, isFalse);
          expect(model.registeredAt, isNot(nowMs));
        }
      });
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

  group('UserTagModel referer_time 是计数不是时间 (R21-B)', () {
    test('计数按普通整数解析：null→0、数字字符串→int，绝不回填 now', () {
      // 旧实现 parseTimestamp：null → millisecond()（now 污染）。
      final fromNull = UserTagModel.fromJson(const {
        'user_id': 1,
        'tag_id': 2,
        'scene': 3,
        'name': '同事',
        'subtitle': '',
      });
      expect(fromNull.refererTime, 0, reason: '缺失计数为 0，不是当前时间戳');

      final fromStr = UserTagModel.fromJson(const {
        'user_id': 1,
        'tag_id': 2,
        'scene': 3,
        'name': '同事',
        'referer_time': '42',
      });
      expect(fromStr.refererTime, 42, reason: '数字字符串按整数直取');
    });

    test('计数值不被时间语义处理：不 ×1000、不做相对格式化输入', () {
      final model = UserTagModel.fromJson(const {
        'user_id': 1,
        'tag_id': 2,
        'scene': 3,
        'name': '同事',
        'referer_time': 1789600000, // 恰似秒值，但语义是"1789600000 个引用"（测试值）
      });
      // 原样保留：若被当秒 ×1000 或当毫秒格式化即语义污染。
      expect(model.refererTime, 1789600000);
      // toMap 往返稳定（本地 DB 读写同一计数语义）。
      expect(model.toMap()['referer_time'], 1789600000);
    });
  });
}
