import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/modules/identity/domain/value/user_id.dart';
import 'package:imboy/modules/social_graph/domain/friendship.dart';

void main() {
  final from = UserId('100');
  final to = UserId('200');
  Friendship fresh() => Friendship(from: from, to: to);

  group('Friendship 状态机（镜像后端 friend_agg）', () {
    test('none -request-> pending', () {
      final f = fresh().request();
      expect(f.status, FriendshipStatus.pending);
      expect(f.canAccept, isTrue);
    });

    test('pending -accept-> friends', () {
      final f = fresh().request().accept();
      expect(f.status, FriendshipStatus.friends);
      expect(f.isFriend, isTrue);
    });

    test('pending -reject-> none', () {
      final f = fresh().request().reject();
      expect(f.status, FriendshipStatus.none);
    });

    test('任意态 -block-> blocked', () {
      expect(fresh().block().status, FriendshipStatus.blocked);
      expect(
        fresh().request().accept().block().status,
        FriendshipStatus.blocked,
      );
    });

    test('block 幂等返回自身', () {
      final b = fresh().block();
      expect(identical(b.block(), b), isTrue);
    });

    test('blocked -unblock-> none', () {
      expect(fresh().block().unblock().status, FriendshipStatus.none);
    });

    test('friends -remove-> none', () {
      expect(fresh().request().accept().remove().status, FriendshipStatus.none);
    });
  });

  group('Friendship 非法转换抛 StateError（对齐后端 reject）', () {
    test('重复 request', () {
      expect(() => fresh().request().request(), throwsStateError);
    });
    test('对好友 request', () {
      expect(() => fresh().request().accept().request(), throwsStateError);
    });
    test('无申请 accept', () {
      expect(() => fresh().accept(), throwsStateError);
    });
    test('无申请 reject', () {
      expect(() => fresh().reject(), throwsStateError);
    });
    test('非拉黑态 unblock', () {
      expect(() => fresh().unblock(), throwsStateError);
    });
    test('非好友 remove', () {
      expect(() => fresh().remove(), throwsStateError);
    });
  });
}
