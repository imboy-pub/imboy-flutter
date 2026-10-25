import 'dart:convert';
import 'dart:async';

import 'human_directory_controller_test.dart' show FakeSource;

import 'package:imboy/modules/organization/domain/human_directory_models.dart';

import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/modules/organization/presentation/human_directory_page.dart';

import 'organization_chart_widget_test.dart' as chart;
import '../../integration_test/enterprise/a04_native_inputs.dart';

import '../../integration_test/enterprise/a04_directory_fault_adapter.dart';

class _Backend implements HttpClientAdapter {
  final calls = <String>[];
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? body,
    Future<void>? cancel,
  ) async {
    calls.add(options.path);
    return ResponseBody.fromString(
      jsonEncode({
        'code': 0,
        'payload': {
          'list': [
            {'id': '42'},
          ],
        },
      }),
      200,
    );
  }

  @override
  void close({bool force = false}) {}
}

RequestOptions _request(String path) => RequestOptions(
  path: path,
  baseUrl: 'http://127.0.0.1:52190',
  method: 'GET',
);
Future<Map<String, dynamic>> _body(ResponseBody body) async => jsonDecode(
  utf8.decode(await body.stream.fold<List<int>>([], (a, b) => a..addAll(b))),
) as Map<String, dynamic>;

void main() {
  for (final entry in {
    'pub.imboy.app.v32qa': true,
    'pub.imboy.app.v32a04.current': true,
    'pub.imboy.app': false,
    '': false,
  }.entries) {
    test('owned bundle guard ${entry.key}', () {
      expect(isA04OwnedBundle(entry.key), entry.value);
    });
  }

  test('failure selects one root endpoint after real IO; other orgs and next call pass through', () async {
    final backend = _Backend();
    final adapter = A04DirectoryFaultAdapter(delegate: backend)..failOnce('41');
    expect(
      (await _body(
        await adapter.fetch(
          _request('/api/v1/organizations/42/directory/departments'),
          null,
          null,
        ),
      ))['code'],
      0,
    );
    final target = _request('/api/v1/organizations/41/directory/departments');
    expect((await _body(await adapter.fetch(target, null, null)))['code'], 503);
    expect((await _body(await adapter.fetch(target, null, null)))['code'], 0);
    expect(backend.calls, hasLength(3));
    expect(adapter.injectedFailures, 1);
  });
  test(
    'hold retains the actual body until release and cannot be armed twice',
    () async {
      final adapter = A04DirectoryFaultAdapter(delegate: _Backend())
        ..holdOnce('41');
      var completed = false;
      final response = adapter
          .fetch(
            _request('/api/v1/organizations/41/directory/departments'),
            null,
            null,
          )
          .then((value) {
            completed = true;
            return value;
          });
      await adapter.observed;
      expect(completed, isFalse);
      expect(() => adapter.holdOnce('42'), throwsStateError);
      adapter.release();
      expect((await _body(await response))['payload'], {
        'list': [
          {'id': '42'},
        ],
      });
      expect(adapter.heldResponses, 1);
    },
  );
  test(
    'real API Future consumer runs before the observed completion signal',
    () async {
      final source = FakeSource();
      final observed = A04ObservedDirectorySource(source)..observeNextRoot();
      final events = <String>[];
      final call = observed.directoryDepartments(organizationId: '41');
      call.then((_) => events.add('chart-consumer'));
      var signalled = false;
      final done = observed.consumed.then((_) {
        signalled = true;
        events.add('observer');
      });
      await Future<void>.delayed(Duration.zero);
      expect(signalled, isFalse);
      source.pendingDepartments.single.complete(
        const HumanDirectoryPage(
          list: <HumanDirectoryDepartment>[],
          cursor: null,
          hasMore: false,
        ),
      );
      await done;
      expect(events, ['chart-consumer', 'observer']);
    },
  );
  testWidgets(
    'source observer keeps the actual chart route and observes a disposed consumer',
    (tester) async {
      final source = chart.ChartSource();
      await tester.pumpWidget(
        TranslationProvider(
          child: MaterialApp(
            home: OrganizationChartPage(
              key: const ValueKey('a04-existing-route'),
              accountKey: 'synthetic',
              organizationId: '41',
              organizationName: 'Synthetic owned org',
              source: source,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final observed = await observeA04ChartSource(tester);
      expect(find.byKey(const ValueKey('a04-existing-route')), findsOneWidget);
      source.pending =
          Completer<HumanDirectoryPage<HumanDirectoryDepartment>>();
      observed.observeNextRoot();
      await tester.tap(find.byIcon(CupertinoIcons.refresh).last);
      await tester.pump();
      await tester.pumpWidget(const SizedBox.shrink());
      source.pending!.complete(
        const HumanDirectoryPage(
          list: <HumanDirectoryDepartment>[],
          cursor: null,
          hasMore: false,
        ),
      );
      await observed.consumed;
      await tester.pumpAndSettle();
      expect(find.byType(OrganizationChartPage), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
