import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/page/moment/moment_interactions.dart';

/// Slice C: 在客户端做"这条 moment 当前用户能不能看到"判定。
///
/// 真正的可见性强制由后端做（不能信任客户端）。本函数用于：
/// - 本地缓存 / 推送过来的 moment 在渲染前的二次过滤
/// - 已发布动态的预览（让作者看到"对方视角"）
///
/// 规则（与后端约定 / parseMomentVisibility 对齐）：
/// - 作者本人 → 永远可见（自己看自己一定 OK）
/// - 0 公开 → 所有人可见
/// - 1 仅好友 → friendUids 中可见
/// - 2 仅自己 → 仅作者
/// - 3 部分可见（白名单）→ allow_uids 中可见
/// - 4 不给谁看（黑名单）→ 好友 且 不在 deny_uids 中
/// - 未登录 viewer（空 uid） → 作为陌生人处理（仅公开可见）
void main() {
  group('canUserSeeMoment', () {
    Map<String, dynamic> moment({
      required String authorUid,
      required int visibility,
      List<String> allowUids = const [],
      List<String> denyUids = const [],
    }) {
      return <String, dynamic>{
        'author_uid': authorUid,
        'visibility': visibility,
        'allow_uids': allowUids,
        'deny_uids': denyUids,
      };
    }

    test('作者本人 → 任何 visibility 都可见', () {
      for (final v in [0, 1, 2, 3, 4]) {
        final m = moment(authorUid: 'me', visibility: v);
        expect(
          canUserSeeMoment(viewerUid: 'me', moment: m, friendUids: const {}),
          isTrue,
          reason: 'author self should see visibility=$v',
        );
      }
    });

    test('public(0) → 陌生人也能看', () {
      final m = moment(authorUid: 'a', visibility: 0);
      expect(canUserSeeMoment(viewerUid: 'stranger', moment: m, friendUids: const {}), isTrue);
    });

    test('friends(1) → 是好友可见', () {
      final m = moment(authorUid: 'a', visibility: 1);
      expect(
        canUserSeeMoment(viewerUid: 'b', moment: m, friendUids: const {'b'}),
        isTrue,
      );
    });

    test('friends(1) → 非好友不可见', () {
      final m = moment(authorUid: 'a', visibility: 1);
      expect(
        canUserSeeMoment(viewerUid: 'b', moment: m, friendUids: const {'c'}),
        isFalse,
      );
    });

    test('private(2) → 仅作者，其他人即使是好友也不可见', () {
      final m = moment(authorUid: 'a', visibility: 2);
      expect(
        canUserSeeMoment(viewerUid: 'b', moment: m, friendUids: const {'b'}),
        isFalse,
      );
    });

    test('allowList(3) → 仅在 allow_uids 中可见', () {
      final m = moment(
        authorUid: 'a',
        visibility: 3,
        allowUids: const ['b'],
      );
      expect(canUserSeeMoment(viewerUid: 'b', moment: m, friendUids: const {'b'}), isTrue);
      expect(canUserSeeMoment(viewerUid: 'c', moment: m, friendUids: const {'c'}), isFalse);
    });

    test('denyList(4) → 是好友 且 不在 deny_uids 中可见', () {
      final m = moment(
        authorUid: 'a',
        visibility: 4,
        denyUids: const ['blocked'],
      );
      // 好友 b 不在黑名单 → 可见
      expect(
        canUserSeeMoment(viewerUid: 'b', moment: m, friendUids: const {'b'}),
        isTrue,
      );
      // 好友 blocked 在黑名单 → 不可见
      expect(
        canUserSeeMoment(
          viewerUid: 'blocked',
          moment: m,
          friendUids: const {'blocked'},
        ),
        isFalse,
      );
      // 非好友 → 不可见（仅黑名单仍要求是好友圈以内）
      expect(
        canUserSeeMoment(viewerUid: 'stranger', moment: m, friendUids: const {}),
        isFalse,
      );
    });

    test('未登录 viewer（空 uid）→ 仅 public 可见', () {
      final pub = moment(authorUid: 'a', visibility: 0);
      final friends = moment(authorUid: 'a', visibility: 1);
      expect(canUserSeeMoment(viewerUid: '', moment: pub, friendUids: const {}), isTrue);
      expect(canUserSeeMoment(viewerUid: '', moment: friends, friendUids: const {}), isFalse);
    });

    test('未知 visibility → 走 friends 安全默认（与 parseMomentVisibility 对齐）', () {
      final raw = <String, dynamic>{
        'author_uid': 'a',
        'visibility': 99, // 未知
      };
      // 走 friends 默认：好友可见、陌生人不可见
      expect(canUserSeeMoment(viewerUid: 'b', moment: raw, friendUids: const {'b'}), isTrue);
      expect(canUserSeeMoment(viewerUid: 'b', moment: raw, friendUids: const {'c'}), isFalse);
    });

    test('author_uid 缺失 → 一律不可见（脏数据保守拒绝）', () {
      final m = <String, dynamic>{'visibility': 0};
      expect(canUserSeeMoment(viewerUid: 'b', moment: m, friendUids: const {}), isFalse);
    });
  });
}
