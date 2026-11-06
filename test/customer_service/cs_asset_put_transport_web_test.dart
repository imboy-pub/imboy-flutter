@TestOn('browser')
library;

import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:web/web.dart' as web;
import 'package:imboy/modules/customer_service/infrastructure/cs_asset_put_transport.dart';

void main() {
  test('browser rejects 307/308 and omits cookies', () async {
    final base = 'http://${web.window.location.hostname}:19972';
    await web.window.fetch('$base/reset'.toJS).toDart;
    await web.window
        .fetch('$base/set'.toJS, web.RequestInit(credentials: 'include'))
        .toDart;
    final cookieCheck = await web.window
        .fetch(
          '$base/cookiecheck'.toJS,
          web.RequestInit(credentials: 'include'),
        )
        .toDart;
    expect((await cookieCheck.text().toDart).toDart, 'present');
    final bytes = Uint8List.fromList([1, 2]);
    final headers = {
      'Content-Type': 'image/png',
      'x-amz-checksum-sha256': base64.encode(sha256.convert(bytes).bytes),
    };
    final transport = CsAssetPutTransport();
    try {
      for (final code in [307, 308]) {
        await expectLater(
          transport.putDirect(
            url: '$base/redirect$code',
            permittedOrigin: Uri.parse(base),
            bytes: bytes,
            requiredHeaders: headers,
          ),
          throwsA(isA<CsAssetPutException>()),
        );
      }
      final progress = <int>[];
      await transport.putDirect(
        url: '$base/ok',
        permittedOrigin: Uri.parse(base),
        bytes: bytes,
        requiredHeaders: headers,
        onSendProgress: (sent, total) => progress.add(sent),
      );
      expect(progress, [bytes.length]);
      final response = await web.window
          .fetch('$base/stats'.toJS, web.RequestInit(credentials: 'omit'))
          .toDart;
      final stats = jsonDecode((await response.text().toDart).toDart) as Map;
      expect(stats['redirect307'], 1);
      expect(stats['redirect308'], 1);
      expect(stats['dest'], 0);
      expect(stats['ok'], 1);
      expect(stats['cookies'], 0);
    } finally {
      transport.close();
    }
  }, skip: !const bool.fromEnvironment('CS_DIRECT_WEB_FIXTURE'));

  test('browser aborts slow PUT on timeout, cancellation and close', () async {
    final base = 'http://${web.window.location.hostname}:19972';
    final bytes = Uint8List.fromList([1, 2]);
    final headers = {
      'Content-Type': 'image/png',
      'x-amz-checksum-sha256': base64.encode(sha256.convert(bytes).bytes),
    };
    for (final mode in ['timeout', 'cancel', 'close']) {
      final transport = CsAssetPutTransport(
        webTimeout: const Duration(milliseconds: 300),
      );
      final cancel = CancelToken();
      final result = transport.putDirect(
        url: '$base/slow',
        permittedOrigin: Uri.parse(base),
        bytes: bytes,
        requiredHeaders: headers,
        cancelToken: cancel,
      );
      final expected = expectLater(
        result,
        throwsA(
          isA<CsAssetPutException>().having(
            (e) => e.requestStarted,
            'requestStarted',
            true,
          ),
        ),
      );
      if (mode != 'timeout') {
        await Future<void>.delayed(const Duration(milliseconds: 100));
        if (mode == 'cancel') cancel.cancel();
        if (mode == 'close') transport.close();
      }
      await expected.timeout(const Duration(seconds: 3));
      transport.close();
    }
    final response = await web.window
        .fetch('$base/stats'.toJS, web.RequestInit(credentials: 'omit'))
        .toDart;
    final stats = jsonDecode((await response.text().toDart).toDart) as Map;
    expect(stats['slow'], 3);
  }, skip: !const bool.fromEnvironment('CS_DIRECT_WEB_FIXTURE'));
}
