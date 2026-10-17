import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/modules/customer_service/infrastructure/cs_api.dart';
import 'package:imboy/modules/customer_service/presentation/cs_queue_view.dart';

import '../ux_matrix/ux_harness.dart';

const _orgId = '7266418340025468901';
const _workspaceId = '7266418340025468921';
const _sessionId = '7266418340025468940';
const _captureKey = ValueKey('t16-queue');

Map<String, dynamic> _queuePage({bool empty = false, int total = 42}) =>
    uxEnvelope(
      payload: {
        'sessions': empty
            ? <Map<String, dynamic>>[]
            : [
                for (final (sessionId, name) in [
                  (_sessionId, '王**'),
                  ('7266418340025468941', ''),
                ])
                  {
                    'id': sessionId,
                    'organization_id': _orgId,
                    'conversation_id': '7266418340025468950',
                    'contact': {'masked_name': name},
                    'queued_at':
                        DateTime.now()
                            .subtract(
                              const Duration(days: 3, hours: 11, minutes: 30),
                            )
                            .millisecondsSinceEpoch ~/
                        1000,
                    'version': 3,
                    'status': 'queued',
                    'source': 'widget',
                    'last_message': {
                      'id': '7266418340025468961',
                      'preview': '请协助核对订单状态，合成摘要仅供离线测试。',
                    },
                  },
              ],
        'next_after_id': null,
        'total': empty ? 0 : total,
        'total_by_status': {'queued': empty ? 0 : total},
      },
    );

class _RecordingAdapter extends RouteStubAdapter {
  _RecordingAdapter(super.routes);

  final List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return super.fetch(options, requestStream, cancelFuture);
  }
}

void main() {
  setUp(initUxHarness);
  tearDown(teardownUxHarness);

  for (final (label, combo) in [
    ('390_1_light', UxCombo(const Size(390, 844))),
    ('360_1_light', UxCombo(const Size(360, 800))),
    (
      '360_2_dark',
      UxCombo(const Size(360, 800), textScale: 2, brightness: Brightness.dark),
    ),
    (
      '1280_1_dark',
      UxCombo(const Size(1280, 900), brightness: Brightness.dark),
    ),
    ('1280_2_light', UxCombo(const Size(1280, 900), textScale: 2)),
  ]) {
    for (final empty in [false, true]) {
      final kind = empty ? 'empty' : 'queue';
      testWidgets('golden: T16 $kind $label', (tester) async {
        uxInstallStub(
          RouteStubAdapter([
            ('/sessions/queue', [(200, _queuePage(empty: empty))]),
          ]),
        );
        await pumpUxCombo(
          tester,
          const RepaintBoundary(
            key: _captureKey,
            child: Scaffold(
              body: CsQueueView(orgId: _orgId, workspaceId: _workspaceId),
            ),
          ),
          combo,
        );
        final layoutError = tester.takeException();
        await expectLater(
          find.byKey(_captureKey),
          matchesGoldenFile('goldens/t16_${kind}_$label.png'),
        );
        expect(layoutError, isNull);
        if (!empty) {
          expect(find.text('**'), findsOneWidget);
          expect(find.text('3 天 11 小时'), findsNWidgets(2));
          expect(find.text('Web'), findsNWidgets(2));
          final name = tester.renderObject<RenderParagraph>(find.text('王**'));
          expect(name.didExceedMaxLines, isFalse);
          for (final button in find.byType(FilledButton).evaluate()) {
            final size = tester.getSize(find.byWidget(button.widget));
            expect(size.width, greaterThanOrEqualTo(48));
            expect(size.height, greaterThanOrEqualTo(48));
          }
        }
      });
    }
  }

  testWidgets('接单保留 CAS 与组织工作区；409 刷新后保留服务端计数', (tester) async {
    final adapter = _RecordingAdapter([
      (
        '/claim',
        [
          (
            409,
            {'code': 409, 'msg': 'conflict', 'payload': <String, dynamic>{}},
          ),
        ],
      ),
      ('/sessions/queue', [(200, _queuePage()), (200, _queuePage(total: 73))]),
    ]);
    uxInstallStub(adapter);
    CsQueuePage? metadata;
    await pumpUxCombo(
      tester,
      Scaffold(
        body: CsQueueView(
          orgId: _orgId,
          workspaceId: _workspaceId,
          onPageMeta: (page) => metadata = page,
        ),
      ),
      UxCombo(const Size(360, 800)),
    );
    expect(adapter.requests, hasLength(1));
    expect(metadata?.countOf('queued'), 42);
    await tester.tap(find.widgetWithText(FilledButton, '接单').first);
    await settleUx(tester);
    final claim = adapter.requests.singleWhere(
      (request) => request.path.endsWith('/claim'),
    );
    expect(claim.method, 'POST');
    expect(
      claim.path,
      contains('/organizations/$_orgId/sessions/$_sessionId/'),
    );
    expect(claim.data, {'workspace_id': _workspaceId, 'expected_version': 3});
    expect(
      adapter.requests.where((request) => request.path.endsWith('/queue')),
      hasLength(2),
    );
    expect(metadata?.countOf('queued'), 73);
    expect(find.widgetWithText(FilledButton, '接单'), findsNWidgets(2));
    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(seconds: 4));
  });

  testWidgets('队列事件只重拉原组织队列，保持服务端顺序和计数', (tester) async {
    final signal = StreamController<void>.broadcast();
    addTearDown(signal.close);
    final adapter = _RecordingAdapter([
      ('/sessions/queue', [(200, _queuePage()), (200, _queuePage(total: 73))]),
    ]);
    uxInstallStub(adapter);
    CsQueuePage? metadata;
    await pumpUxCombo(
      tester,
      Scaffold(
        body: CsQueueView(
          orgId: _orgId,
          refreshSignal: signal.stream,
          onPageMeta: (page) => metadata = page,
        ),
      ),
      UxCombo(const Size(360, 800)),
    );
    expect(metadata?.countOf('queued'), 42);
    signal.add(null);
    await settleUx(tester);
    expect(adapter.requests, hasLength(2));
    expect(metadata?.countOf('queued'), 73);
    expect(
      adapter.requests.every(
        (request) =>
            request.method == 'GET' &&
            request.path.endsWith('/organizations/$_orgId/sessions/queue'),
      ),
      isTrue,
    );
    expect(
      tester.getTopLeft(find.text('王**')).dy,
      lessThan(tester.getTopLeft(find.text('**')).dy),
    );
    expect(tester.takeException(), isNull);
  });
}
