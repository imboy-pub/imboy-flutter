import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/store/model/talk_record/talk_record_audio_upload_session.dart';

void main() {
  Map<String, dynamic> granted() => {
    'part_id': 7366418340025468940,
    'attachment_id': 7366418340025468941,
    // attach_direct_logic:descriptor/5 s3_put grant projection.
    'upload_ref': <String, dynamic>{
      'state': 'GRANTED',
      'object_key': 'talk_record/synthetic.aac',
      'attempt_id': 1,
      'grant': <String, dynamic>{
        'transport': 's3_put',
        'url': 'https://garage.example.test/object?X-Amz-Signature=synthetic',
        'method': 'PUT',
        'required_headers': <String, String>{
          'Content-Type': 'audio/aac',
          'x-amz-checksum-sha256': 'synthetic-checksum',
        },
        'expires_in': 3600,
      },
    },
  };

  test('parses nested s3_put descriptor without losing TSID precision', () {
    final session = TalkRecordAudioUploadSession.fromJson(granted());
    expect(session.partId, '7366418340025468940');
    expect(session.attachmentId, '7366418340025468941');
    expect(session.uploadRef.transport, 's3_put');
    expect(session.uploadRef.isS3Put, isTrue);
    expect(
      session.uploadRef.grantUrl,
      'https://garage.example.test/object?X-Amz-Signature=synthetic',
    );
    expect(session.uploadRef.requiredHeaders['Content-Type'], 'audio/aac');
    expect(
      session.uploadRef.requiredHeaders['x-amz-checksum-sha256'],
      'synthetic-checksum',
    );
    expect(session.uploadRef.uploadable, isTrue);
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
      expect(session.uploadRef.uploadable, isFalse);
    }
  });

  test('retired gateway ticket form without grant fails closed', () {
    // 旧 gateway ticket 形态（backend V3-20 起零签发）：无 grant descriptor，
    // 永不可上传。
    final session = TalkRecordAudioUploadSession.fromJson({
      'upload_ref': <String, dynamic>{
        'put_url': '/api/v1/attachment/gateway/synthetic?capability=synthetic',
        'object_key': 'talk_record/synthetic.aac',
        'client_upload_id': 'synthetic-session',
        'upload_capability': 'synthetic',
        'gateway': true,
        'expires_at': 1792520300,
      },
    });
    expect(session.uploadRef.isS3Put, isFalse);
    expect(session.uploadRef.uploadable, isFalse);
  });

  test(
    'non-s3_put transport, invalid URL or incomplete descriptor cannot upload',
    () {
      final base = granted()['upload_ref'] as Map<String, dynamic>;
      Map<String, dynamic> grant() =>
          Map<String, dynamic>.from(base['grant'] as Map<String, dynamic>);
      final variants = <Map<String, dynamic>>[
        // grant 缺失或非 s3_put 传输型一律拒绝。
        {...base}..['grant'] = <String, dynamic>{},
        {...base, 'grant': grant()..['transport'] = 'http_put'},
        {...base, 'grant': grant()..['transport'] = ''},
        // URL 形态门禁。
        {...base, 'grant': grant()..['url'] = '{not a URL}'},
        {...base, 'grant': grant()..['url'] = 'file:///tmp/audio'},
        {
          ...base,
          'grant': grant()
            ..['url'] = 'https://user:secret@garage.example.test/object',
        },
        {
          ...base,
          'grant': grant()
            ..['url'] = 'https://garage.example.test/object#fragment',
        },
        // descriptor 完整性门禁。
        {...base}..['object_key'] = '',
        {...base, 'grant': grant()..['required_headers'] = <String, String>{}},
      ];
      for (final variant in variants) {
        final json = {...granted(), 'upload_ref': variant};
        expect(
          TalkRecordAudioUploadSession.fromJson(json).uploadRef.uploadable,
          isFalse,
          reason: '$variant must fail closed',
        );
      }
    },
  );
}
