import 'dart:convert';
import 'dart:io' as io;

import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/component/helper/jwt.dart';
import 'package:imboy/modules/talk_record/application/talk_record_part_transport.dart';
import 'package:imboy/store/model/talk_record/talk_record_audio_upload_session.dart';

import 'support/gateway_request_host.dart';

class _StreamOnlyFile implements io.File {
  _StreamOnlyFile(this.file, {this.afterChunk});
  final io.File file;
  final void Function()? afterChunk;
  @override
  Future<int> length() => file.length();
  @override
  Stream<List<int>> openRead([int? start, int? end]) async* {
    await for (final chunk in file.openRead(start, end)) {
      yield chunk;
      afterChunk?.call();
    }
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late io.HttpServer server;
  late io.Directory directory;
  late SignedHost host;
  late io.File audio;
  final requests = <Map<String, List<String>>>[];
  final bodies = <List<int>>[];
  late Future<void> serving;
  var status = 200;

  setUp(() async {
    io.HttpOverrides.global = null;
    server = await io.HttpServer.bind(io.InternetAddress.loopbackIPv4, 0);
    directory = await io.Directory.systemTemp.createTemp('c06-s3-io-');
    audio = await io.File('${directory.path}/audio')
        .writeAsBytes(List<int>.generate(160000, (index) => index % 251));
    String encode(Map<String, Object> value) =>
        base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
    final token =
        '${encode({'alg': 'HS256', 'typ': 'JWT'})}.'
        '${encode({'sub': '9898002', 'exp': DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600})}.'
        '${base64Url.encode(List<int>.filled(32, 0)).replaceAll('=', '')}';
    expect(tokenExpired(token), isFalse);
    final config = await io.File('${directory.path}/host.json').writeAsString(
      jsonEncode({
        'base_url': 'http://127.0.0.1:${server.port}',
        'sign_key': 'synthetic-key',
        'device_id': 'synthetic-device',
        'app_version': '1.0.0',
        'sign_key_version': '1',
        'package_name': 'synthetic.c06',
        'actors': {
          'owner': {'uid': '9898002', 'jwt': token},
        },
      }),
    );
    host = await SignedHost.load(config.path);
    host.api.dio.options.headers.addAll({
      'authorization': token,
      'Cookie': 'synthetic=session',
      'sign': 'synthetic-sign',
      'did': 'synthetic-device',
      'pkg': 'synthetic.c06',
    });
    requests.clear();
    bodies.clear();
    status = 200;
    serving = () async {
      await for (final request in server) {
        final headers = <String, List<String>>{};
        request.headers.forEach((name, values) {
          headers[name.toLowerCase()] = List.of(values);
        });
        requests.add(headers);
        final body = <int>[];
        bodies.add(body);
        try {
          await for (final chunk in request) {
            body.addAll(chunk);
          }
        } on io.IOException {
          continue;
        }
        request.response.statusCode = status;
        if (status == 307) {
          request.response.headers.set('location', '/redirected');
        }
        await request.response.close();
      }
    }();
  });

  tearDown(() async {
    host.api.dio.close(force: true);
    await server.close(force: true);
    await serving;
    await directory.delete(recursive: true);
  });

  TalkRecordUploadRef ticket() => TalkRecordUploadRef(
    transport: 's3_put',
    grantUrl:
        'http://127.0.0.1:${server.port}/object?X-Amz-Signature=synthetic',
    objectKey: 'synthetic/audio',
    requiredHeaders: const {
      'content-type': 'audio/aac',
      'x-amz-checksum-sha256': 'synthetic-checksum',
    },
  );

  test(
    'real S3 PUT excludes configured business credentials and streams file',
    () async {
      expect(host.api.dio.options.headers['authorization'], isNotEmpty);
      await host.api.get('/business');
      for (final name in ['authorization', 'cookie', 'sign', 'did', 'pkg']) {
        expect(
          requests.single[name],
          isNotEmpty,
          reason: 'business $name must actually be active',
        );
      }
      requests.clear();
      bodies.clear();
      await TalkRecordS3PutPartTransport().put(ticket(), audio, () {});
      expect(requests, hasLength(1));
      for (final name in ['authorization', 'cookie', 'sign', 'did', 'pkg']) {
        expect(
          requests.single.containsKey(name),
          isFalse,
          reason: '$name must never reach S3',
        );
      }
      expect(requests.single['content-type'], ['audio/aac']);
      expect(requests.single['x-amz-checksum-sha256'], ['synthetic-checksum']);
      expect(requests.single['content-length'], ['160000']);
      expect(bodies.single, await audio.readAsBytes());
    },
  );

  test('S3 redirect and rejection send once without retry', () async {
    for (final code in [307, 400, 503]) {
      status = code;
      await expectLater(
        TalkRecordS3PutPartTransport().put(ticket(), audio, () {}),
        throwsA(anything),
      );
      expect(requests, hasLength(1));
      requests.clear();
    }
  });

  test('guard rejection after file IO prevents network dispatch', () async {
    var checks = 0;
    await expectLater(
      TalkRecordS3PutPartTransport().put(ticket(), audio, () {
        if (++checks > 1) throw StateError('synthetic owner changed');
      }),
      throwsStateError,
    );
    expect(requests, isEmpty);
  });

  test('S3 uses reopenable file stream without whole-file reads', () async {
    await TalkRecordS3PutPartTransport().put(
      ticket(),
      _StreamOnlyFile(audio),
      () {},
    );
    expect(bodies.single, await audio.readAsBytes());
  });

  test('owner change during streaming aborts remaining file chunks', () async {
    var active = true;
    var checks = 0;
    await expectLater(
      TalkRecordS3PutPartTransport().put(
        ticket(),
        _StreamOnlyFile(audio, afterChunk: () => active = false),
        () {
          checks++;
          if (!active) throw StateError('synthetic owner changed');
        },
      ),
      throwsA(anything),
    );
    expect(active, isFalse, reason: 'the real file stream must have started');
    expect(checks, greaterThan(3));
    expect(bodies.expand((body) => body).length, lessThan(160000));
  });
}
