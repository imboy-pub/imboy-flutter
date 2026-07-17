import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/page/moment/moment_interactions.dart';

/// Feature point 13: filter MomentTimelineChangedEvent with per-surface rules
/// instead of the current blanket `event.momentId == viewing || empty` check,
/// which causes detail page to waste network + flicker on every unrelated
/// feed change.
///
/// Predicates live as pure functions so we can lock the policy table down.
void main() {
  const viewing = 'm_viewing';

  group('shouldRefreshDetailOnEvent', () {
    test(
      'moment_deleted on the currently viewed post → false (page pops itself)',
      () {
        expect(
          shouldRefreshDetailOnEvent(
            action: 'moment_deleted',
            eventMomentId: viewing,
            viewingMomentId: viewing,
          ),
          isFalse,
        );
      },
    );

    test('moment_deleted on some other post → false', () {
      expect(
        shouldRefreshDetailOnEvent(
          action: 'moment_deleted',
          eventMomentId: 'm_other',
          viewingMomentId: viewing,
        ),
        isFalse,
      );
    });

    test('moment_new → false (new post elsewhere does not affect detail)', () {
      expect(
        shouldRefreshDetailOnEvent(
          action: 'moment_new',
          eventMomentId: 'm_new',
          viewingMomentId: viewing,
        ),
        isFalse,
      );
    });

    test('moment_updated on the viewed post → true', () {
      expect(
        shouldRefreshDetailOnEvent(
          action: 'moment_updated',
          eventMomentId: viewing,
          viewingMomentId: viewing,
        ),
        isTrue,
      );
    });

    test('moment_updated on a different post → false', () {
      expect(
        shouldRefreshDetailOnEvent(
          action: 'moment_updated',
          eventMomentId: 'm_other',
          viewingMomentId: viewing,
        ),
        isFalse,
      );
    });

    test(
      'broadcast event (empty eventMomentId) → true (global refresh signal)',
      () {
        expect(
          shouldRefreshDetailOnEvent(
            action: 'moment_updated',
            eventMomentId: '',
            viewingMomentId: viewing,
          ),
          isTrue,
        );
      },
    );

    test('empty viewing id is always false (defensive)', () {
      expect(
        shouldRefreshDetailOnEvent(
          action: 'moment_updated',
          eventMomentId: '',
          viewingMomentId: '',
        ),
        isFalse,
      );
    });

    test(
      'moment_comment_changed → false (detail already updated optimistically)',
      () {
        expect(
          shouldRefreshDetailOnEvent(
            action: momentActionCommentChanged,
            eventMomentId: viewing,
            viewingMomentId: viewing,
          ),
          isFalse,
        );
      },
    );

    test(
      'unknown action on the viewed post → true (fail-open for forward compat)',
      () {
        expect(
          shouldRefreshDetailOnEvent(
            action: 'some_future_action',
            eventMomentId: viewing,
            viewingMomentId: viewing,
          ),
          isTrue,
        );
      },
    );
  });

  group('shouldRefreshFeedOnEvent', () {
    test('moment_new → true', () {
      expect(shouldRefreshFeedOnEvent('moment_new'), isTrue);
    });

    test('moment_deleted → true', () {
      expect(shouldRefreshFeedOnEvent('moment_deleted'), isTrue);
    });

    test('moment_updated → true', () {
      expect(shouldRefreshFeedOnEvent('moment_updated'), isTrue);
    });

    test(
      'moment_comment_changed → true (feed pulls fresh comments_preview)',
      () {
        expect(shouldRefreshFeedOnEvent(momentActionCommentChanged), isTrue);
      },
    );

    test('empty action → false (defensive, no broadcast-all semantics)', () {
      expect(shouldRefreshFeedOnEvent(''), isFalse);
    });
  });
}
