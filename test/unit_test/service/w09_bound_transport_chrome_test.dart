@TestOn('chrome')
library;

import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/component/http/http_response.dart';
import 'package:imboy/component/upload/browser_direct_put_web.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/service/account_local_task_registry.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/service/web_writer_gate.dart';
import 'package:imboy/store/api/attachment_direct_api.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web/web.dart' as web;

import '../../env_test_pin.dart';

// Counts the production's actual Fetch call and delegates it unchanged to the
// browser. Only the isolated Flutter test origin is contacted; no fake response.
class _FetchObserver {
  final original = web.window.getProperty<JSFunction>('fetch'.toJS);
  final urls = <String>[];
  void install() {
    web.window.setProperty(
      'fetch'.toJS,
      ((JSAny? url, JSAny? options) {
        urls.add(url.dartify() as String);
        return original.callAsFunction(web.window, url, options);
      }).toJS,
    );
  }

  void restore() => web.window.setProperty('fetch'.toJS, original);
}

String get _url =>
    '${Uri.base.origin}/fixtures/w09-owned-put'
    '?signature=synthetic%2Bvalue%2F&part=%2F';
final _bytes = Uint8List.fromList([1, 2, 3, 4]);
const _uid = '900000000001';
const _headers = {'content-type': 'application/octet-stream'};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    pinLoopbackTestEnv();
    await prepareWebWriter(); // Actual namespace lease + fresh production VFS.
    expect(isWebWriterReady, isTrue);
    SharedPreferences.setMockInitialValues({Keys.currentUid: _uid});
    await StorageService.init();
  });

  test('invalid browser header releases abort registration and timeout before Fetch', () async {
    final observed = _FetchObserver()..install();
    const timeout = Duration(seconds: 17);
    final timers = <Timer>[];
    void Function()? registered;
    void Function()? unregistered;
    var reachedDispatch = false;
    try {
      await runZoned(
        () => expectLater(
          directWebPutUrl(
            _url,
            _bytes,
            // Headers.set requires ByteString, so this fails in real Chrome.
            const {'content-type': 'application/\u0100'},
            null,
            timeout,
            (abort) => registered = abort,
            (abort) => unregistered = abort,
            beforeDispatch: () => reachedDispatch = true,
          ),
          throwsA(anything),
        ),
        zoneSpecification: ZoneSpecification(
          createTimer: (self, parent, zone, duration, callback) {
            final timer = parent.createTimer(zone, duration, callback);
            if (duration == timeout) timers.add(timer);
            return timer;
          },
        ),
      );
      expect(registered, isNotNull);
      expect(unregistered, isNotNull);
      expect(identical(registered, unregistered), isTrue);
      expect(timers, hasLength(1));
      expect(timers.single.isActive, isFalse);
      expect(reachedDispatch, isFalse);
      expect(observed.urls, isEmpty);
    } finally {
      for (final timer in timers) {
        timer.cancel();
      }
      observed.restore();
    }
  });

  test(
    'Fetch final hook rejects after request preparation without dispatch',
    () async {
      final observed = _FetchObserver()..install();
      var registered = 0;
      var unregistered = 0;
      try {
        await expectLater(
          directWebPutUrl(
            _url,
            _bytes,
            _headers,
            null,
            const Duration(seconds: 5),
            (_) => registered++,
            (_) => unregistered++,
            beforeDispatch: () => throw StateError('synthetic denied owner'),
          ),
          throwsStateError,
        );
        expect(observed.urls, isEmpty);
        expect(registered, 1);
        expect(unregistered, 1);
      } finally {
        observed.restore();
      }
    },
  );

  test(
    'UID change while buffering denies Fetch and does not renew/finalize',
    () async {
      final observed = _FetchObserver()..install();
      final reachedBuffer = Completer<void>();
      final releaseBytes = Completer<void>();
      final owner = AccountLocalTaskOwner.capture();
      final generation = UserRepoLocal.to.sessionGeneration;
      final actions = <String>[];
      var reads = 0;
      final source = DirectUploadSource(
        length: _bytes.length,
        openRead: () async* {
          reads++;
          if (reads == 2) {
            reachedBuffer.complete();
            await releaseBytes.future;
          }
          yield _bytes;
        },
        beforeDispatch: () {
          requireWebWriter();
          final actor = UserRepoLocal.to;
          if (AccountLocalTaskOwner.capture() != owner ||
              !actor.isCurrentSession(generation) ||
              actor.isAuthTransitioning) {
            throw StateError('captured synthetic account changed');
          }
        },
      );
      final upload = DirectAttachmentApi.uploadSource(
        source,
        fileName: 'synthetic.bin',
        mime: 'application/octet-stream',
        clientUploadId: '30000000-0000-4000-8000-000000000001',
        sessionFn: (path, {body}) async {
          final action = path.split('/').last;
          actions.add(action);
          switch (action) {
            case 'register':
              return IMBoyHttpResponse.success({
                'state': 'DECLARED',
                'object_key': 'synthetic/owned-object',
              });
            case 'declare':
              return IMBoyHttpResponse.success({'state': 'DECLARED'});
            case 'grant':
              return IMBoyHttpResponse.success({
                'state': 'GRANTED',
                'attempt_id': 1,
                'grant': {
                  'transport': 's3_put',
                  'method': 'PUT',
                  'url': _url,
                  'required_headers': [
                    ['Content-Type', 'application/octet-stream'],
                    [
                      'x-amz-checksum-sha256',
                      base64Encode(sha256.convert(_bytes).bytes),
                    ],
                  ],
                },
              });
            default:
              fail('Rejected owner must not $action');
          }
        },
      );
      final outcome = expectLater(
        upload,
        throwsA(isA<DirectUploadDispatchRejected>()),
      );
      try {
        await reachedBuffer.future.timeout(const Duration(seconds: 5));
        await StorageService.to.setString(Keys.currentUid, '900000000002');
        releaseBytes.complete();
        await outcome;
        expect(reads, 2);
        expect(actions, ['register', 'declare', 'grant']);
        expect(observed.urls, isEmpty);
      } finally {
        if (!releaseBytes.isCompleted) releaseBytes.complete();
        await StorageService.to.setString(Keys.currentUid, _uid);
        observed.restore();
      }
    },
  );

  test('cancellation inside final hook cannot dispatch Fetch', () async {
    final observed = _FetchObserver()..install();
    final cancel = CancelToken();
    try {
      await expectLater(
        directWebPutUrl(
          _url,
          _bytes,
          _headers,
          cancel,
          const Duration(seconds: 5),
          (_) {},
          (_) {},
          beforeDispatch: () => cancel.cancel('synthetic cancel'),
        ),
        throwsA(isA<DioException>()),
      );
      expect(observed.urls, isEmpty);
    } finally {
      observed.restore();
    }
  });

  test('unbound CS/guest signatures retain actual Fetch and raw URL', () async {
    final observed = _FetchObserver()..install();
    try {
      // The response may be 404/405; the existing transport returns its status.
      expect(
        await directWebPutUrl(
          _url,
          _bytes,
          _headers,
          null,
          const Duration(seconds: 5),
          (_) {},
          (_) {},
        ),
        isA<int>(),
      );
      expect(
        await directWebPut(
          Uri.parse(_url),
          _bytes,
          _headers,
          null,
          const Duration(seconds: 5),
          (_) {},
          (_) {},
        ),
        isA<int>(),
      );
      expect(observed.urls, [_url, Uri.parse(_url).toString()]);
    } finally {
      observed.restore();
    }
  });
}
