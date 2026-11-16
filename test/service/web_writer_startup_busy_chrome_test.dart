@TestOn('chrome')
library;

import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';

import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/config/init.dart';
import 'package:imboy/service/web_writer_gate_types.dart';
import 'package:web/web.dart' as web;

@JS('startupBusySelfTest')
external JSPromise<JSString> _selfTest();
@JS('startupBusyReset')
external void _reset();
@JS('startupBusyCounts')
external JSString _counts();
@JS('startupBusyStorageSnapshot')
external JSString _storageSnapshot();

void main() {
  test('second document runs real AppInitializer and is rejected before writes', () async {
    const sri = String.fromEnvironment('BROWSER_SQLITE_PROBE_SRI');
    const preparation = String.fromEnvironment(
      'BROWSER_SQLITE_PREPARATION_SHA256',
    );
    const counterSri = String.fromEnvironment('STARTUP_BUSY_COUNTER_SRI');
    expect(RegExp(r'^sha256-[A-Za-z0-9+/]{43}=$').hasMatch(sri), isTrue);
    expect(RegExp(r'^[0-9a-f]{64}$').hasMatch(preparation), isTrue);
    expect(RegExp(r'^sha256-[A-Za-z0-9+/]{43}=$').hasMatch(counterSri), isTrue);
    final script = web.HTMLScriptElement()
      ..src = '/fixtures/startup_busy_counter.js'
      ..integrity = counterSri
      ..crossOrigin = 'anonymous';
    final loaded = Completer<void>();
    script.onload = ((web.Event _) => loaded.complete()).toJS;
    script.onerror = ((web.Event _) => loaded.completeError(
      StateError('counter failed'),
    )).toJS;
    web.document.head!.append(script);
    await loaded.future.timeout(const Duration(seconds: 10));

    final owner = web.HTMLIFrameElement()..name = 'startup-busy-owner';
    final ready = Completer<void>();
    final opened = Completer<Map<Object?, Object?>>();
    final listener = ((web.MessageEvent event) {
      if (event.origin != web.window.location.origin ||
          event.source != owner.contentWindow)
        return;
      final data = event.data.dartify();
      if (data is! Map || data['frame'] != owner.name) return;
      if (data['kind'] == 'bridge-ready' && !ready.isCompleted)
        ready.complete();
      if (data['kind'] == 'bridge-bootstrap-error' && !ready.isCompleted) {
        ready.completeError(StateError('owner probe failed'));
      }
      if (data['kind'] == 'bridge-result' &&
          data['id'] == 1 &&
          !opened.isCompleted) {
        opened.complete(Map<Object?, Object?>.from(data));
      }
    }).toJS;
    web.window.addEventListener('message', listener);
    try {
      owner.src = Uri(
        path: '/fixtures/browser_sqlite_bridge_probe.htm',
        queryParameters: {'sri': sri, 'preparation': preparation},
      ).toString();
      web.document.body!.append(owner);
      await ready.future.timeout(const Duration(seconds: 20));
      owner.contentWindow!.postMessage(
        {
          'kind': 'bridge-call',
          'id': 1,
          'op': 'open',
          'uid': 'busy-owner',
        }.jsify(),
        web.window.location.origin.toJS,
      );
      final result = await opened.future.timeout(const Duration(seconds: 20));
      expect(result['error'], isNull);
      expect((result['result'] as Map)['opened'], isTrue);
      final ownerEvents = result['idb_events'] as List;
      expect(ownerEvents.any((e) => e is Map && e['event'] == 'open'), isTrue);
      final before = _storageSnapshot().toDart;
      _reset();
      final positive = jsonDecode(
        (await _selfTest().toDart.timeout(const Duration(seconds: 15))).toDart,
      ) as Map<String, dynamic>;
      expect(positive['storage_write'], greaterThanOrEqualTo(4));
      expect(positive['idb_open_delete'], greaterThanOrEqualTo(2));
      for (final key in ['fetch', 'xhr_send', 'WebSocket', 'EventSource']) {
        expect(
          positive[key],
          greaterThanOrEqualTo(1),
          reason: '$key hook inactive',
        );
      }
      expect(_storageSnapshot().toDart, before);
      _reset();
      expect(jsonDecode(_counts().toDart), isEmpty);
      await expectLater(
        AppInitializer.initialize(env: 'dev', signKeyVsn: '1'),
        throwsA(
          isA<WebWriterGateFailure>().having(
            (e) => e.kind,
            'kind',
            WebWriterFailureKind.occupied,
          ),
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 250));
      final counts = jsonDecode(_counts().toDart) as Map<String, dynamic>;
      for (final key in [
        'storage_write',
        'idb_open_delete',
        'fetch',
        'xhr_send',
        'WebSocket',
        'EventSource',
      ]) {
        expect(
          counts[key] ?? 0,
          0,
          reason: '$key was reached after writer rejection',
        );
      }
      expect(_storageSnapshot().toDart, before);
      // ignore: avoid_print
      print(
        'STARTUP_BUSY_RECEIPT ${jsonEncode({'origin': web.window.location.origin, 'sri': sri, 'preparation': preparation, 'counter_sri': counterSri, 'owner_idb_open': true, 'positive_counts': positive, 'failure': 'occupied', 'counts': counts, 'storage_unchanged': true})}',
      );
    } finally {
      owner.remove();
      web.window.removeEventListener('message', listener);
      script.remove();
    }
  }, timeout: const Timeout(Duration(seconds: 90)));
}
