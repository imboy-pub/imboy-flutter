import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/store/model/talk_record/talk_record_model.dart';
import 'package:imboy/store/model/talk_record/talk_record_enums.dart';

void main() {
  test('authorized DS detail owner/client identity is preserved for upload reconciliation', () {
    // Wire keys are asserted against real SQL-backed talk_record_ds:detail/2
    // in talk_record_ds_split_tests, not invented by a presentation fixture.
    final record = TalkRecordModel.fromJson({
      'id': 9223372036854775801,
      'owner_user_id': 9223372036854775802,
      'client_recording_id': 'cb6ed1f7-6bf0-4459-a3ea-83d953ab7b11',
      'scope': 'personal',
      'organization_id': null,
      'workspace_id': null,
      'capture_status': 'ended',
      'media_status': 'assembling',
      'duration_ms': 1200,
      'capabilities_for_actor': {'edit': true, 'share': true, 'delete': true},
    });
    expect(record.id, '9223372036854775801');
    expect(record.ownerUserId, '9223372036854775802');
    expect(record.clientRecordingId, 'cb6ed1f7-6bf0-4459-a3ea-83d953ab7b11');
    expect(record.scope, TalkRecordScope.personal);
    expect(record.organizationId, isEmpty);
    expect(record.workspaceId, isEmpty);
    expect(record.captureStatus, TalkRecordCaptureStatus.ended);
    expect(record.mediaStatus, TalkRecordMediaStatus.assembling);
  });
  test('missing owner/client remain unknown instead of assuming current account ownership', () {
    final record = TalkRecordModel.fromJson({'id': 1, 'scope': 'personal'});
    expect(record.ownerUserId, isEmpty);
    expect(record.clientRecordingId, isEmpty);
  });
}
