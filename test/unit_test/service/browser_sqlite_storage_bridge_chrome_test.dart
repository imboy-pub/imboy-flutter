@TestOn('chrome')
library;

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:web/web.dart' as web;

void main() {
  test('actual two-context SQLite durability counterexamples', () async {
    const sri = String.fromEnvironment('BROWSER_SQLITE_PROBE_SRI');
    const preparation = String.fromEnvironment(
      'BROWSER_SQLITE_PREPARATION_SHA256',
    );
    expect(
      RegExp(r'^sha256-[A-Za-z0-9+/]{43}=$').hasMatch(sri),
      isTrue,
      reason: 'A controlled compilation with pinned JS bytes is required',
    );
    expect(
      RegExp(r'^[0-9a-f]{64}$').hasMatch(preparation),
      isTrue,
      reason: 'The immutable compilation receipt must be bound to the plan',
    );
    final frame = web.HTMLIFrameElement()
      ..src = Uri(
        path: '/fixtures/browser_sqlite_bridge_host.htm',
        queryParameters: {'sri': sri, 'preparation': preparation},
      ).toString();
    web.document.body!.append(frame);
    try {
      final report = await _waitForReport(frame);
      // Receipt includes actual IDB event order and each context's RPC results.
      // ignore: avoid_print
      print('BROWSER_SQLITE_BRIDGE_RECEIPT ${jsonEncode(report)}');
      expect(report['probe_sri'], sri);
      expect(report['preparation_sha256'], preparation);
      expect(report['origin'], web.window.location.origin);
      expect(report['status'], 'PASS', reason: jsonEncode(report));
      final cases = report['cases'] as List;
      expect(cases, hasLength(7));
      expect(cases.every((row) => (row as Map)['status'] == 'PASS'), isTrue);
    } finally {
      frame.remove();
    }
  }, timeout: const Timeout(Duration(seconds: 90)));
}

Future<Map<Object?, Object?>> _waitForReport(
  web.HTMLIFrameElement frame,
) async {
  final deadline = DateTime.now().add(const Duration(seconds: 75));
  while (DateTime.now().isBefore(deadline)) {
    final text = frame.contentDocument?.querySelector('#report')?.textContent;
    if (text != null && text != 'RUNNING') {
      final report = jsonDecode(text);
      if (report is Map<String, dynamic> && report['status'] != 'RUNNING') {
        return report;
      }
    }
    await Future<void>.delayed(const Duration(milliseconds: 50));
  }
  throw StateError('Browser bridge report timed out; inspect fixture setup');
}
