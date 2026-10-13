import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/modules/customer_service/domain/cs_session_flow.dart';
import 'package:imboy/modules/customer_service/infrastructure/cs_api.dart';
import 'package:imboy/modules/customer_service/presentation/cs_session_action_confirmation.dart';

class ActionApi extends CsApi {
  int writes = 0;
  int targets = 0;
  int? version;
  CsApiException? writeError, refreshError, targetError;
  Completer<CsTransferTargetPage>? heldTargets;
  Completer<void>? heldWrite;
  @override
  Future<CsTransferTargetPage> transferTargets(
    String orgId, {
    String? afterId,
    int? limit,
  }) async {
    targets++;
    if (targetError != null) throw targetError!;
    return heldTargets?.future ??
        CsTransferTargetPage(
          items: [
            const CsTransferTarget(
              identityId: '9',
              displayName: 'Real target',
              available: true,
            ),
          ],
        );
  }

  @override
  Future<void> close(
    String orgId,
    String sessionId, {
    required int expectedVersion,
    String? reason,
    String workspaceId = '',
  }) async {
    writes++;
    if (writeError != null) throw writeError!;
    version = expectedVersion;
    await heldWrite?.future;
  }

  @override
  Future<CsSessionDetail> sessionDetail(
    String orgId,
    String sessionId, {
    String workspaceId = '',
  }) async {
    if (refreshError != null) throw refreshError!;
    return detail();
  }
}

CsSessionDetail detail({int version = 5, String status = 'active'}) =>
    CsSessionDetail(
      sessionId: '3',
      organizationId: '1',
      conversationId: '4',
      assigneeIdentityId: '6',
      version: version,
      status: status,
    );
CsSessionFlow flow(ActionApi api) => CsSessionFlow(
  orgId: '1',
  sessionId: '3',
  workspaceId: '2',
  conversationId: '4',
  identityId: '6',
  csApi: api,
)..detail = detail();
Future<BuildContext> mount(WidgetTester tester) async {
  late BuildContext context;
  await tester.pumpWidget(
    MaterialApp(
      builder: (_, child) => TranslationProvider(child: child!),
      initialRoute: '/page',
      routes: {
        '/': (_) => const SizedBox(),
        '/page': (_) => Builder(
          builder: (c) {
            context = c;
            return const SizedBox();
          },
        ),
      },
    ),
  );
  return context;
}

void main() {
  testWidgets('lock covers target fetch and rejects close until cancellation', (
    tester,
  ) async {
    final context = await mount(tester), api = ActionApi();
    api.heldTargets = Completer();
    final f = flow(api), actions = CsSessionActionConfirmation(api: api);
    final pending = actions.transfer(
      context: context,
      flow: f,
      isCurrent: () => true,
      risks: () => const CsActionRisks(),
    );
    expect(actions.busy, isTrue);
    await actions.close(
      context: context,
      flow: f,
      isCurrent: () => true,
      risks: () => const CsActionRisks(),
    );
    expect(api.targets, 1);
    expect(api.writes, 0);
    actions.invalidate();
    api.heldTargets!.complete(CsTransferTargetPage(items: []));
    await pending;
    await tester.pumpAndSettle();
    expect(find.byType(SimpleDialog), findsNothing);
    actions.dispose();
    f.dispose();
  });
  testWidgets('cancel is zero write; double confirmation dispatches once', (
    tester,
  ) async {
    final context = await mount(tester), api = ActionApi();
    final f = flow(api), actions = CsSessionActionConfirmation(api: api);
    final cancelled = actions.close(
      context: context,
      flow: f,
      isCurrent: () => true,
      risks: () => const CsActionRisks(draft: true),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('未发送'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, '取消'));
    await tester.pumpAndSettle();
    await cancelled;
    expect(api.writes, 0);
    api.heldWrite = Completer();
    final pending = actions.close(
      context: context,
      flow: f,
      isCurrent: () => true,
      risks: () => const CsActionRisks(),
    );
    await tester.pumpAndSettle();
    final confirm = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, '关闭会话'),
    );
    confirm.onPressed!();
    confirm.onPressed!();
    await tester.pumpAndSettle();
    expect(api.writes, 1);
    expect(api.version, 5);
    api.heldWrite!.complete();
    await pending;
    actions.dispose();
    f.dispose();
  });
  testWidgets('changed authoritative version refuses old confirmation', (
    tester,
  ) async {
    final context = await mount(tester), api = ActionApi();
    final f = flow(api), actions = CsSessionActionConfirmation(api: api);
    final pending = actions.close(
      context: context,
      flow: f,
      isCurrent: () => true,
      risks: () => const CsActionRisks(),
    );
    await tester.pumpAndSettle();
    final confirm = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, '关闭会话'),
    );
    f.detail = detail(version: 6);
    confirm.onPressed!();
    await tester.pumpAndSettle();
    await pending;
    expect(api.writes, 0);
    actions.dispose();
    f.dispose();
  });
  testWidgets('inflight or unconfirmed writes block confirmation', (
    tester,
  ) async {
    final context = await mount(tester), api = ActionApi();
    final f = flow(api), actions = CsSessionActionConfirmation(api: api);
    var risks = const CsActionRisks(
      sending: true,
      uploading: true,
      unconfirmed: true,
    );
    final pending = actions.close(
      context: context,
      flow: f,
      isCurrent: () => true,
      risks: () => risks,
    );
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, '关闭会话'))
          .onPressed,
      isNull,
    );
    risks = const CsActionRisks();
    actions.refresh();
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '关闭会话'));
    await tester.pumpAndSettle();
    await pending;
    expect(api.writes, 1);
    actions.dispose();
    f.dispose();
  });
  testWidgets(
    'scope invalidation removes own dialog but preserves external dialog',
    (tester) async {
      final context = await mount(tester), api = ActionApi();
      final f = flow(api), actions = CsSessionActionConfirmation(api: api);
      final pending = actions.close(
        context: context,
        flow: f,
        isCurrent: () => true,
        risks: () => const CsActionRisks(),
      );
      await tester.pumpAndSettle();
      final staleCancel = tester
          .widget<TextButton>(find.widgetWithText(TextButton, '取消'))
          .onPressed!;
      unawaited(
        showDialog<void>(
          context: context,
          builder: (_) => const AlertDialog(content: Text('external')),
        ),
      );
      await tester.pumpAndSettle();
      actions.invalidate();
      staleCancel();
      await tester.pumpAndSettle();
      await pending;
      expect(find.text('external'), findsOneWidget);
      expect(find.text('关闭会话', skipOffstage: false), findsNothing);
      expect(api.writes, 0);
      actions.dispose();
      f.dispose();
    },
  );
  testWidgets(
    'transfer confirmation names real target and cancel writes nothing',
    (tester) async {
      final context = await mount(tester), api = ActionApi();
      final f = flow(api), actions = CsSessionActionConfirmation(api: api);
      final pending = actions.transfer(
        context: context,
        flow: f,
        isCurrent: () => true,
        risks: () => const CsActionRisks(),
      );
      await tester.pumpAndSettle();
      final option = tester.widget<SimpleDialogOption>(
        find.byType(SimpleDialogOption),
      );
      option.onPressed!();
      option.onPressed!();
      await tester.pumpAndSettle();
      expect(find.textContaining('Real target'), findsOneWidget);
      expect(find.textContaining('不再经办'), findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, '取消'));
      await tester.pumpAndSettle();
      await pending;
      expect(api.writes, 0);
      actions.dispose();
      f.dispose();
    },
  );
  testWidgets(
    'late old completion cannot unlock or remove new-scope confirmation',
    (tester) async {
      final context = await mount(tester), api = ActionApi();
      api.heldWrite = Completer();
      final f = flow(api), actions = CsSessionActionConfirmation(api: api);
      final old = actions.close(
        context: context,
        flow: f,
        isCurrent: () => true,
        risks: () => const CsActionRisks(),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, '关闭会话'));
      await tester.pumpAndSettle();
      actions.invalidate();
      final newer = actions.close(
        context: context,
        flow: flow(ActionApi()),
        isCurrent: () => true,
        risks: () => const CsActionRisks(),
      );
      await tester.pumpAndSettle();
      api.heldWrite!.complete();
      await old;
      expect(actions.busy, isTrue);
      expect(find.widgetWithText(FilledButton, '关闭会话'), findsOneWidget);
      actions.invalidate();
      await tester.pumpAndSettle();
      await newer;
      actions.dispose();
      f.dispose();
    },
  );
  testWidgets('409 with failed refresh remains conflict and never replays', (
    tester,
  ) async {
    final context = await mount(tester), api = ActionApi();
    api.writeError = const CsApiException(409, 'cas_mismatch');
    api.refreshError = const CsApiException(503, 'synthetic unavailable');
    final f = flow(api), actions = CsSessionActionConfirmation(api: api);
    final pending = actions.close(
      context: context,
      flow: f,
      isCurrent: () => true,
      risks: () => const CsActionRisks(),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '关闭会话'));
    await tester.pumpAndSettle();
    expect((await pending)?.failure, CsSeatFailureKind.conflict);
    expect(api.writes, 1);
    expect(actions.busy, isFalse);
    expect(f.historyError, isNotNull);
    actions.dispose();
    f.dispose();
  });
  for (final code in [401, 403]) {
    testWidgets('current targets $code revokes read authority', (tester) async {
      final context = await mount(tester), api = ActionApi();
      api.targetError = CsApiException(code, 'synthetic refused');
      final f = flow(api), actions = CsSessionActionConfirmation(api: api);
      try {
        await actions.transfer(
          context: context,
          flow: f,
          isCurrent: () => true,
          risks: () => const CsActionRisks(),
        );
      } on CsApiException {
        /* legacy propagation must still revoke */
      }
      expect(f.readRevoked, isTrue);
      expect(f.machine.canSend, isFalse);
      expect(actions.busy, isFalse);
      expect(api.writes, 0);
      actions.dispose();
      f.dispose();
    });
  }
  for (final code in [401, 403]) {
    testWidgets('late targets $code cannot revoke rebound scope', (
      tester,
    ) async {
      final context = await mount(tester), api = ActionApi();
      api.heldTargets = Completer();
      var current = true;
      final f = flow(api), actions = CsSessionActionConfirmation(api: api);
      final old = actions.transfer(
        context: context,
        flow: f,
        isCurrent: () => current,
        risks: () => const CsActionRisks(),
      );
      current = false;
      actions.invalidate();
      final newerFlow = flow(ActionApi());
      final newer = actions.close(
        context: context,
        flow: newerFlow,
        isCurrent: () => true,
        risks: () => const CsActionRisks(),
      );
      await tester.pumpAndSettle();
      api.heldTargets!.completeError(CsApiException(code, 'synthetic refused'));
      await old;
      expect(newerFlow.readRevoked, isFalse);
      expect(newerFlow.machine.canSend, isTrue);
      expect(actions.busy, isTrue);
      actions.invalidate();
      await tester.pumpAndSettle();
      await newer;
      actions.dispose();
      f.dispose();
      newerFlow.dispose();
    });
  }
}
