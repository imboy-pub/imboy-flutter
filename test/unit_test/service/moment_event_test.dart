import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/service/events/common_events.dart';

void main() {
  group('MomentTimelineChangedEvent', () {
    test('事件属性应正确透传', () {
      const event = MomentTimelineChangedEvent(
        action: 'moment_new',
        momentId: 'm_abc123',
        payload: {'moment_id': 'm_abc123'},
      );

      expect(event.action, 'moment_new');
      expect(event.momentId, 'm_abc123');
      expect(event.payload['moment_id'], 'm_abc123');
      expect(event.toString(), contains('moment_new'));
    });
  });
}
