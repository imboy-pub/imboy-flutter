import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/store/model/talk_record/talk_record_participant_model.dart';

void main() {
  test('person payload contains only authoritative user id', () {
    expect(
      const TalkRecordParticipantInput(
        userId: '9001',
        displayName: 'untrusted name',
      ).toJson(),
      {'user_id': 9001},
    );
  });
  test('guest label normalizes and invalid input fails closed', () {
    expect(
      const TalkRecordParticipantInput(displayName: '  Guest  ').toJson(),
      {'display_name': 'Guest'},
    );
    expect(
      () => const TalkRecordParticipantInput().toJson(),
      throwsFormatException,
    );
    expect(
      () => const TalkRecordParticipantInput(userId: '0').toJson(),
      throwsFormatException,
    );
  });
  test('server reconciliation compares whole participant set not local success flag', () {
    final projection = TalkRecordParticipants.fromJson({
      'record_id': 10,
      'revision': 2,
      'list': [
        {
          'id': 1,
          'user_id': 9001,
          'display_name': 'Actual name',
          'attendance_source': 'selected',
        },
        {
          'id': 2,
          'user_id': null,
          'display_name': 'Guest',
          'attendance_source': 'manual',
        },
      ],
    });
    expect(
      projection.matches(const [
        TalkRecordParticipantInput(displayName: 'Guest'),
        TalkRecordParticipantInput(userId: '9001'),
      ]),
      isTrue,
    );
    expect(
      projection.matches(const [TalkRecordParticipantInput(userId: '9001')]),
      isFalse,
    );
    expect(
      projection.matches(const [
        TalkRecordParticipantInput(userId: '9001'),
        TalkRecordParticipantInput(userId: '9001'),
      ]),
      isFalse,
    );
  });
}
