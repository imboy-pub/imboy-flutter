@TestOn('vm')
library;

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

const _originInput = String.fromEnvironment('WEB_CONTROL_TEST_ORIGIN');
late Uri _origin;

// Flutter's default 400 client cannot observe this validated loopback fixture.
class _FixtureHttpOverrides extends HttpOverrides {}

Future<List<Object?>> _stats(String id) async {
  final client = _FixtureHttpOverrides().createHttpClient(null)
    ..findProxy = (_) => 'DIRECT';
  try {
    final request = await client.getUrl(_origin.resolve('/stats?case=$id'));
    request.followRedirects = false;
    final response = await request.close();
    expect(response.statusCode, 200);
    return jsonDecode(await utf8.decoder.bind(response).join())
        as List<Object?>;
  } finally {
    client.close(force: true);
  }
}

Future<Map<Object?, Object?>> _waitRow(
  String id,
  bool Function(Map<Object?, Object?>) ready,
) async {
  for (var attempt = 0; attempt < 100; attempt++) {
    final rows = await _stats(id);
    if (rows.length == 1 && ready(rows.single as Map)) {
      return rows.single as Map;
    }
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
  fail('fixture state did not settle for synthetic case $id');
}

Future<int> _post(String id, {String? origin}) async {
  final client = _FixtureHttpOverrides().createHttpClient(null)
    ..findProxy = (_) => 'DIRECT';
  try {
    final request = await client.postUrl(
      _origin.resolve('/api/v1/probe?case=$id'),
    );
    request.followRedirects = false;
    if (origin != null) request.headers.set('origin', origin);
    request.add([1, 2, 3]);
    final response = await request.close();
    await response.drain<void>();
    return response.statusCode;
  } finally {
    client.close(force: true);
  }
}

void main() {
  setUpAll(() {
    expect(
      _originInput,
      isNotEmpty,
      reason: 'controlled fixture preparation required',
    );
    _origin = Uri.parse(_originInput);
    expect(_origin.scheme, 'http');
    expect({'127.0.0.1', 'localhost'}, contains(_origin.host));
    expect(_origin.userInfo, isEmpty);
    expect(_origin.path, anyOf('', '/'));
    expect(_origin.hasQuery || _origin.hasFragment, isFalse);
  });

  test(
    'arrival remains visible when a partially delivered request is aborted',
    () async {
      final socket = await Socket.connect(_origin.host, _origin.port);
      try {
        socket.write(
          'POST /api/v1/probe?case=oracle-aborted HTTP/1.1\r\n'
          'Host: ${_origin.authority}\r\nContent-Length: 1024\r\n'
          'Connection: close\r\n\r\n{}',
        );
        await socket.flush();
        final arrival = await _waitRow(
          'oracle-aborted',
          (row) => row['size'] == 2,
        );
        expect(arrival['complete'], isFalse);
        expect(arrival['aborted'], isFalse);
        expect(arrival['sha256'], isNull);
        socket.destroy();
        final aborted = await _waitRow(
          'oracle-aborted',
          (row) => row['aborted'] == true,
        );
        expect(aborted['complete'], isFalse);
        expect(aborted['size'], 2);
        expect(await _stats('oracle-aborted'), hasLength(1));
        // The same fixture remains alive after the connection is aborted.
        expect(await _stats('oracle-not-sent'), isEmpty);
      } finally {
        socket.destroy();
      }
    },
  );

  test(
    'a completed body updates its existing arrival with exact bytes and hash',
    () async {
      expect(await _post('oracle-complete'), 200);
      final rows = await _stats('oracle-complete');
      expect(rows, hasLength(1));
      final row = rows.single as Map;
      expect(row['complete'], isTrue);
      expect(row['aborted'], isFalse);
      expect(row['size'], 3);
      expect(row['sha256'], sha256.convert([1, 2, 3]).toString());
    },
  );

  test(
    'opaque and malformed Origin are controlled 403 without process loss',
    () async {
      for (final entry in {
        'oracle-opaque': 'null',
        'oracle-malformed': 'http://[',
      }.entries) {
        expect(await _post(entry.key, origin: entry.value), 403);
        final rows = await _stats(entry.key);
        expect(rows, hasLength(1));
        expect((rows.single as Map)['rejected'], isTrue);
      }
      expect(await _stats('oracle-after-origin-rejection'), isEmpty);
    },
  );

  test(
    'malformed absolute request target is controlled 400 and fixture survives',
    () async {
      final socket = await Socket.connect(_origin.host, _origin.port);
      try {
        socket.write(
          'GET http://[ HTTP/1.1\r\nHost: ${_origin.authority}\r\n'
          'Connection: close\r\n\r\n',
        );
        await socket.flush();
        final response = await utf8.decoder
            .bind(socket)
            .join()
            .timeout(const Duration(seconds: 3));
        expect(response.split('\r\n').first, contains(' 400 '));
        expect(await _stats('oracle-after-target-rejection'), isEmpty);
      } finally {
        socket.destroy();
      }
    },
  );
}
