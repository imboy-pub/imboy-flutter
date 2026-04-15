import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/page/moment/moment_interactions.dart';

/// Feature point 11: authorization predicates.
///
/// Both feed and detail pages currently inline the same checks:
///   canDelete       = author_uid == currentUid
///   canDeleteComment = user_id   == currentUid || canDeletePost
/// If the copy drifts we silently grant or revoke deletion. Extract to pure
/// helpers that handle null / empty / missing fields defensively.
void main() {
  group('canDeleteMoment', () {
    test('author matches currentUid → true', () {
      final moment = {'author_uid': 'u_1'};
      expect(canDeleteMoment(moment, 'u_1'), isTrue);
    });

    test('author differs from currentUid → false', () {
      final moment = {'author_uid': 'u_1'};
      expect(canDeleteMoment(moment, 'u_2'), isFalse);
    });

    test('empty currentUid (not logged in) → false even with matching empty author', () {
      final moment = {'author_uid': ''};
      expect(canDeleteMoment(moment, ''), isFalse);
    });

    test('missing author_uid → false', () {
      expect(canDeleteMoment(const {}, 'u_1'), isFalse);
    });

    test('whitespace-only author or currentUid → false', () {
      final moment = {'author_uid': '   '};
      expect(canDeleteMoment(moment, 'u_1'), isFalse);
      expect(canDeleteMoment({'author_uid': 'u_1'}, '   '), isFalse);
    });
  });

  group('canDeleteComment', () {
    test('commenter deletes own comment → true', () {
      final comment = {'user_id': 'u_commenter'};
      final moment = {'author_uid': 'u_author'};
      expect(
        canDeleteComment(
          comment,
          moment,
          currentUid: 'u_commenter',
        ),
        isTrue,
      );
    });

    test('post author deletes someone else\'s comment → true', () {
      final comment = {'user_id': 'u_commenter'};
      final moment = {'author_uid': 'u_author'};
      expect(
        canDeleteComment(
          comment,
          moment,
          currentUid: 'u_author',
        ),
        isTrue,
      );
    });

    test('third-party user cannot delete → false', () {
      final comment = {'user_id': 'u_commenter'};
      final moment = {'author_uid': 'u_author'};
      expect(
        canDeleteComment(
          comment,
          moment,
          currentUid: 'u_stranger',
        ),
        isFalse,
      );
    });

    test('empty currentUid → false even if comment/author also empty', () {
      final comment = {'user_id': ''};
      final moment = {'author_uid': ''};
      expect(
        canDeleteComment(comment, moment, currentUid: ''),
        isFalse,
      );
    });

    test('missing user_id on comment falls through to author check', () {
      // Commenter id missing (defensive): permission only via post authorship
      final comment = <String, dynamic>{};
      final moment = {'author_uid': 'u_author'};
      expect(
        canDeleteComment(comment, moment, currentUid: 'u_author'),
        isTrue,
      );
      expect(
        canDeleteComment(comment, moment, currentUid: 'u_other'),
        isFalse,
      );
    });
  });
}
