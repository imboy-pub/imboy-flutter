import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/store/model/talk_record/talk_record_audio_upload_session.dart';

void main() {
  final now = DateTime.fromMillisecondsSinceEpoch(1792520000000, isUtc: true);
  Map<String, dynamic> registered() => {
    'part_id': 7366418340025468940,
    'attachment_id': 7366418340025468941,
    // attach_logic:presign_registered/6 response, expires_at is Unix seconds.
    'upload_ref': <String, dynamic>{
      'put_url':
          '/api/v1/attachment/gateway/synthetic-session?capability=synthetic',
      'object_key': 'talk_record/synthetic.aac',
      'expires_at': 1792520300,
      'upload_capability': 'synthetic',
      'gateway': true,
      'client_upload_id': 'synthetic-session',
      'session_state': 'registered',
    },
  };

  test('parses nested attachment ticket without losing TSID precision', () {
    final session = TalkRecordAudioUploadSession.fromJson(registered());
    expect(session.partId, '7366418340025468940');
    expect(session.attachmentId, '7366418340025468941');
    expect(session.uploadRef.putUrl, startsWith('/api/v1/attachment/gateway/'));
    expect(session.uploadRef.clientUploadId, 'synthetic-session');
    expect(session.uploadRef.gateway, isTrue);
    expect(session.expiresAt, now.add(const Duration(minutes: 5)));
    expect(session.uploadRef.canUploadAt(now), isTrue);
    expect(session.uploadRef.canUploadAt(session.expiresAt!), isFalse);
  });

  test('server integration_pending branch cannot upload', () {
    final session = TalkRecordAudioUploadSession.fromJson({
      'part_id': 1,
      'upload_ref': <String, dynamic>{
        'attachment_id': 2,
        'object_key': 'talk_record/synthetic.aac',
        'upload_url': null,
        'expiry': '2026-10-21T04:58:20Z',
        'integration_pending': true,
      },
    });
    expect(session.uploadRef.integrationPending, isTrue);
    expect(session.uploadRef.putUrl, isEmpty);
    expect(session.uploadRef.canUploadAt(now), isFalse);
  });

  test('legacy strings, missing and malformed nested refs fail closed', () {
    for (final ref in [
      null,
      'https://uploads.example.test',
      42,
      <String, dynamic>{},
    ]) {
      final session = TalkRecordAudioUploadSession.fromJson({
        'upload_ref': ref,
      });
      expect(session.uploadRef.canUploadAt(now), isFalse);
    }
  });

  test('missing expiry, invalid URL and pending ticket cannot upload', () {
    for (final change in <Map<String, dynamic>>[
      {'expires_at': null},
      {'expires_at': 999999999999999999},
      {'put_url': '{not a URL}'},
      {'put_url': 'file:///tmp/audio'},
      {'integration_pending': true},
      {'client_upload_id': ''},
      {
        'put_url':
            '//evil.example.test/api/v1/attachment/gateway/synthetic-session',
      },
      {'put_url': '/api/v1/attachment/gateway/other?capability=synthetic'},
      {'put_url': '/other?capability=synthetic'},
      {'upload_capability': 'mismatched'},
    ]) {
      final json = registered();
      (json['upload_ref'] as Map<String, dynamic>).addAll(change);
      expect(
        TalkRecordAudioUploadSession.fromJson(json).uploadRef.canUploadAt(now),
        isFalse,
      );
    }
  });
}
