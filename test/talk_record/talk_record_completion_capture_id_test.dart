import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/store/model/talk_record/talk_record_capture_model.dart';

void main() {
  test(
    'completion capture EntityId serializes exact signed64 JSON integer',
    () {
      for (final id in ['1', '119258348645517312', '9223372036854775807']) {
        final body = TalkRecordCompleteCaptureInput(
          captureId: id,
          lastSeq: 0,
          manifestHash: 'synthetic',
        ).toJson();
        expect(body['capture_id'], isA<int>());
        expect(jsonDecode(jsonEncode(body))['capture_id'].toString(), id);
      }
    },
  );
  test(
    'completion rejects noncanonical and overflowing IDs before request',
    () {
      for (final id in [
        '',
        '0',
        '-1',
        '+1',
        '01',
        '1.5',
        ' 1',
        '9223372036854775808',
        '999999999999999999999999999999999',
      ]) {
        expect(
          () => TalkRecordCompleteCaptureInput(
            captureId: id,
            lastSeq: 0,
            manifestHash: 'synthetic',
          ).toJson(),
          throwsFormatException,
        );
      }
    },
  );
}
