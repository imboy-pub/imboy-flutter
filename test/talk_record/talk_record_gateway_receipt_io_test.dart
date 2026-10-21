import 'dart:convert';
import 'dart:io' as io;

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/store/model/talk_record/talk_record_audio_upload_session.dart';
import 'package:imboy/modules/talk_record/application/talk_record_part_transport.dart';

import 'support/gateway_receipt_host.dart';

void main() {
  test(
    'real IO gateway validates exact byte receipt and retains signed headers',
    () async {
      final server = await io.HttpServer.bind(
        io.InternetAddress.loopbackIPv4,
        0,
      );
      final dir = await io.Directory.systemTemp.createTemp('receipt-owned-');
      final bytes = [1, 2, 3, 7, 9];
      final hash = sha256.convert(bytes).toString();
      final file = await io.File('${dir.path}/audio.aac').writeAsBytes(bytes);
      final cfg = await io.File('${dir.path}/host.json').writeAsString(
        jsonEncode({
          'base_url': 'http://127.0.0.1:${server.port}',
          'sign_key': 'owned-synthetic-key',
          'device_id': 'receipt-device',
          'app_version': '1.0.0',
          'sign_key_version': '1',
          'package_name': 'synthetic.receipt',
          'actors': {
            'owner': {'uid': '9898002', 'jwt': 'synthetic-host-token'},
          },
        }),
      );
      final host = await SignedHost.load(cfg.path);
      final cases = <(int, dynamic)>[
        (200, {'pinned': true, 'sha256': hash, 'size': bytes.length}),
        (200, {'pinned': false, 'sha256': hash, 'size': bytes.length}),
        (200, {'pinned': true, 'sha256': 'wrong', 'size': bytes.length}),
        (200, {'pinned': true, 'sha256': hash, 'size': bytes.length + 1}),
        (200, {'pinned': true, 'sha256': hash, 'size': '${bytes.length}'}),
        (200, {'pinned': true, 'size': bytes.length}),
        (200, {'code': 0, 'payload': <String, dynamic>{}}),
        (201, {'pinned': true, 'sha256': hash, 'size': bytes.length}),
        (403, {'pinned': true, 'sha256': hash, 'size': bytes.length}),
      ];
      var received = 0;
      final handling = () async {
        await for (final request in server) {
          final input = await request.fold<List<int>>(
            [],
            (a, b) => a..addAll(b),
          );
          expect(input, bytes);
          expect(request.method, 'PUT');
          expect(request.headers.value('sign'), isNotEmpty);
          expect(request.headers.value('did'), 'receipt-device');
          // Upload capability routes intentionally omit account JWT.
          expect(request.headers.value('authorization'), isNull);
          final response = cases[received++];
          request.response.statusCode = response.$1;
          request.response.headers.contentType = io.ContentType.json;
          request.response.write(jsonEncode(response.$2));
          await request.response.close();
        }
      }();
      final ticket = TalkRecordUploadRef(
        putUrl: '/api/v1/attachment/gateway/receipt?capability=owned',
        objectKey: 'synthetic/audio',
        clientUploadId: 'receipt',
        uploadCapability: 'owned',
        expiresAt: DateTime.now().add(const Duration(minutes: 1)),
        gateway: true,
        integrationPending: false,
      );
      try {
        final transport = TalkRecordGatewayPartTransport();
        await transport.put(ticket, file, () {});
        for (var i = 1; i < cases.length; i++) {
          await expectLater(
            transport.put(ticket, file, () {}),
            throwsStateError,
          );
        }
        expect(received, cases.length);
      } finally {
        host.api.dio.close(force: true);
        await server.close(force: true);
        await handling;
        await dir.delete(recursive: true);
      }
    },
  );
}
