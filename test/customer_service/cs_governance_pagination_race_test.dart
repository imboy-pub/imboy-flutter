import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/component/http/http_client.dart';

import '../ux_matrix/ux_harness.dart';
import 'cs_governance_test_fixtures.dart';

void main() {
  setUp(initUxHarness);
  tearDown(teardownUxHarness);

  for (final switchOrganization in [false, true]) {
    testWidgets(switchOrganization ? '旧组织分页晚到不能混入新组织列表' : '分页请求在途时重复点击只发一个请求', (
      tester,
    ) async {
      final blocked = Completer<void>();
      final started = Completer<void>();
      var aSeatRequests = 0;
      final adapter = GovRouterAdapter(
        {
          'GET /cs/organizations/$orgA/seat-limit': [(200, limitPayload(orgA))],
          'GET /cs/organizations/$orgA/seats': [
            (
              200,
              seatsPayload(
                seats: [seatRow(orgA, identityA)],
                nextAfterId: identityA,
              ),
            ),
            (200, seatsPayload(seats: [seatRow(orgA, identityB)])),
          ],
          'GET /cs/organizations/$orgB/seat-limit': [
            (200, limitPayload(orgB, seatLimit: 'unlimited')),
          ],
          'GET /cs/organizations/$orgB/seats': [(200, seatsPayload())],
        },
        orgs: const <String>[orgA, orgB],
        beforeResponse: (key) async {
          if (key.endsWith('$orgA/seats') && ++aSeatRequests == 2) {
            started.complete();
            await blocked.future;
          }
        },
      );
      HttpClient.adapterForTest = adapter;
      addTearDown(() => HttpClient.adapterForTest = null);
      addTearDown(() {
        if (!blocked.isCompleted) blocked.complete();
      });
      await tester.pumpWidget(governanceHost(orgA));
      final more = find.byKey(const ValueKey('cs-governance-seats-more'));
      await pumpUntilUxFound(tester, more);
      // Await the wired async handler after releasing the old response.
      final pagination =
          (tester.widget<ListTile>(more).onTap! as dynamic)() as Future<void>;
      var paginationFinished = false;
      pagination.then((_) => paginationFinished = true);
      await tester.pump();
      for (var i = 0; i < 30 && !started.isCompleted; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(started.isCompleted, isTrue, reason: '必须确认旧分页请求实际在途');
      if (switchOrganization) {
        await tester.pumpWidget(governanceHost(orgB));
        await pumpUntilUxFound(tester, find.text('不限'));
      } else {
        expect(tester.widget<ListTile>(more).onTap, isNull);
        await tester.tap(more);
        await tester.pump();
        expect(aSeatRequests, 2);
      }
      blocked.complete();
      for (var i = 0; i < 200 && !paginationFinished; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(paginationFinished, isTrue, reason: '必须消费完旧分页回调后再检查隔离');
      await pagination;
      await settleUx(tester);
      expect(aSeatRequests, 2);
      if (switchOrganization) {
        expect(
          find.byKey(const ValueKey('cs-governance-seat-$identityA')),
          findsNothing,
        );
        expect(
          find.byKey(const ValueKey('cs-governance-seat-$identityB')),
          findsNothing,
        );
        expect(find.text('不限'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('cs-governance-seats-empty')),
          findsOneWidget,
        );
      } else {
        expect(
          find.byKey(const ValueKey('cs-governance-seat-$identityA')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('cs-governance-seat-$identityB')),
          findsOneWidget,
        );
        expect(more, findsNothing);
      }
    });
  }
}
