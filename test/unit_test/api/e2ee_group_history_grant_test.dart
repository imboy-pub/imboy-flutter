import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/store/api/e2ee_api.dart';

void main() {
  group('E2EEGroupHistoryGrant', () {
    test('解析服务端权威范围并绑定请求 gid', () {
      final grant = E2EEGroupHistoryGrant.fromPayload(
        {
          'gid': '100',
          'session_id': 'session-a',
          'epoch_id': 'session-a',
          'generation_no': 2,
          'start_seq': 481,
          'end_seq': 900,
        },
        expectedGid: '100',
        expectedSessionId: 'session-a',
      );

      expect(grant.gid, '100');
      expect(grant.sessionId, 'session-a');
      expect(grant.generationNo, 2);
      expect(grant.startSeq, 481);
      expect(grant.endSeq, 900);
    });

    test('gid 不一致、非正范围和倒置 end_seq 均拒绝', () {
      for (final payload in [
        {
          'gid': '999',
          'session_id': 'session-a',
          'epoch_id': 'session-a',
          'generation_no': 2,
          'start_seq': 481,
          'end_seq': 900,
        },
        {
          'gid': '100',
          'session_id': 'other',
          'epoch_id': 'other',
          'generation_no': 2,
          'start_seq': 481,
          'end_seq': 900,
        },
        {
          'gid': '100',
          'session_id': 'session-a',
          'epoch_id': 'session-a',
          'generation_no': 0,
          'start_seq': 481,
          'end_seq': 900,
        },
        {
          'gid': '100',
          'session_id': 'session-a',
          'epoch_id': 'session-a',
          'generation_no': 2,
          'start_seq': 481,
          'end_seq': 480,
        },
        {
          'gid': '100',
          'session_id': 'session-a',
          'epoch_id': 'session-a',
          'generation_no': 2,
          'start_seq': 481,
          'end_seq': null,
        },
      ]) {
        expect(
          () => E2EEGroupHistoryGrant.fromPayload(
            payload,
            expectedGid: '100',
            expectedSessionId: 'session-a',
          ),
          throwsA(isA<FormatException>()),
        );
      }
    });
  });
}
