import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/conversation/conversation_provider.dart';
import 'package:imboy/page/workspace/workspace_conversations_page.dart';
import 'package:imboy/page/workspace/workspace_data_providers.dart';
import 'package:imboy/page/workspace_shell/workspace_shell_provider.dart';
import 'package:imboy/store/api/workspace_api.dart';
import 'package:imboy/store/model/user_model.dart';
import 'package:imboy/store/model/workspace_conversation_model.dart';
import 'package:imboy/store/model/workspace_model.dart';
import 'package:imboy/store/repository/user_repo_provider.dart';

import '../../store/api/workspace_conversations_api_test.dart' show messageRow;

class _Account extends Notifier<UserModel?> {
  @override
  UserModel? build() => UserModel.fromJson({'uid': '1'});
  void select(String uid) =>
      state = uid.isEmpty ? null : UserModel.fromJson({'uid': uid});
}

final _account = NotifierProvider<_Account, UserModel?>(_Account.new);

class _NeverReadGlobal extends ConversationNotifier {
  @override
  ConversationState build() =>
      throw StateError('Workspace read global conversation cache');
}

class _Api extends WorkspaceApi {
  final calls = <String>[];
  final pending = <Completer<List<WorkspaceConversationModel>>>[];
  @override
  Future<List<WorkspaceConversationModel>> conversations(EntityId workspaceId) {
    calls.add(workspaceId);
    final reply = Completer<List<WorkspaceConversationModel>>();
    pending.add(reply);
    return reply.future;
  }
}

void _select(ProviderContainer container, String id) => container
    .read(workspaceShellProvider.notifier)
    .applyCreated(
      WorkspaceCreateResult(
        workspace: WorkspaceModel(id: id, name: 'Workspace $id', ownerId: '1'),
        channelId: '',
        groupId: '',
        status: 'created',
      ),
    );

ProviderContainer _container(_Api api) => ProviderContainer(
  overrides: [
    workspaceApiProvider.overrideWithValue(api),
    currentUserProvider.overrideWith((ref) => ref.watch(_account)),
    conversationProvider.overrideWith(_NeverReadGlobal.new),
  ],
);

WorkspaceConversationModel _row(int id, String text, {int unread = 0}) =>
    WorkspaceConversationModel.fromJson({
      ...messageRow(id: id, text: text),
      'unread_count': unread,
    });

Future<GoRouter> _pump(WidgetTester tester, ProviderContainer container) async {
  final router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (_, _) => const WorkspaceConversationsPage()),
      GoRoute(
        path: '/chat/:id',
        builder: (_, state) => Scaffold(
          body: Text('chat ${state.pathParameters['id']} ${state.extra}'),
        ),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    TranslationProvider(
      child: UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ),
    ),
  );
  await tester.pump();
  return router;
}

Future<void> _disposePage(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump();
}

void main() {
  testWidgets(
    'authorized unread badges clear per target and disappear on workspace or account changes',
    (tester) async {
      final api = _Api();
      final container = _container(api);
      addTearDown(container.dispose);
      _select(container, '100');
      await _pump(tester, container);
      api.pending.single.complete([
        _row(1, 'A', unread: 5),
        _row(2, 'B', unread: 7),
      ]);
      await tester.pump();
      await tester.pump();
      expect(find.text('5'), findsOneWidget);
      expect(find.text('7'), findsOneWidget);
      container.invalidate(workspaceConversationsProvider('100'));
      await tester.pump();
      expect(find.text('5'), findsNothing);
      api.pending.last.complete([_row(1, 'A'), _row(2, 'B', unread: 7)]);
      await tester.pump();
      await tester.pump();
      expect(find.text('5'), findsNothing);
      expect(find.text('7'), findsOneWidget);
      _select(container, '200');
      await tester.pump();
      expect(find.text('7'), findsNothing);
      api.pending.last.complete([_row(3, 'C', unread: 9)]);
      await tester.pump();
      await tester.pump();
      expect(find.text('9'), findsOneWidget);
      container.read(_account.notifier).select('2');
      await tester.pump();
      expect(find.text('9'), findsNothing);
      api.pending.last.completeError(
        const WorkspaceApiException(403, 'removed'),
      );
      await tester.pump();
      await tester.pump();
      expect(find.text('5'), findsNothing);
      expect(find.text('7'), findsNothing);
      expect(find.text('9'), findsNothing);
      expect(tester.takeException(), isNull);
      await _disposePage(tester);
    },
  );

  testWidgets(
    'trusted rows render, search is scoped, chat route is reused without global cache',
    (tester) async {
      final api = _Api();
      final container = _container(api);
      addTearDown(container.dispose);
      _select(container, '100');
      await _pump(tester, container);
      api.pending.single.complete([
        _row(1, 'first safe preview'),
        _row(2, 'second safe preview'),
      ]);
      await tester.pump();
      await tester.pump();
      expect(find.text('first safe preview'), findsOneWidget);
      expect(find.text('second safe preview'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.enterText(find.byType(CupertinoSearchTextField), 'Group 2');
      await tester.pump();
      expect(find.text('first safe preview'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('workspace-message-2')));
      await tester.pumpAndSettle();
      expect(find.textContaining('chat 2'), findsOneWidget);
      expect(find.textContaining('C2G'), findsOneWidget);
      await _disposePage(tester);
    },
  );

  testWidgets(
    'workspace switch removes prior preview immediately and ignores late old response',
    (tester) async {
      final api = _Api();
      final container = _container(api);
      addTearDown(container.dispose);
      _select(container, '100');
      await _pump(tester, container);
      _select(container, '200');
      await tester.pump();
      expect(api.calls, ['100', '200']);
      api.pending[1].complete([_row(2, 'workspace B')]);
      await tester.pump();
      await tester.pump();
      api.pending[0].complete([_row(1, 'late workspace A')]);
      await tester.pump();
      await tester.pump();
      expect(find.text('workspace B'), findsOneWidget);
      expect(find.text('late workspace A'), findsNothing);
      container.invalidate(workspaceConversationsProvider('200'));
      await tester.pump();
      expect(find.text('workspace B'), findsNothing);
      api.pending[2].completeError(
        const WorkspaceApiException(403, 'access revoked'),
      );
      await tester.pump();
      await tester.pump();
      expect(find.text('access revoked'), findsOneWidget);
      expect(find.text('workspace B'), findsNothing);
      await _disposePage(tester);
    },
  );

  test('account switch invalidates same-workspace response and logout stops requests', () async {
    final api = _Api();
    final container = _container(api);
    addTearDown(container.dispose);
    final provider = workspaceConversationsProvider('100');
    final subscription = container.listen(provider, (_, _) {});
    addTearDown(subscription.close);
    container.read(_account.notifier).select('2');
    await container.pump();
    api.pending[1].complete([_row(2, 'new account')]);
    expect(
      (await container.read(provider.future)).single.previewText,
      'new account',
    );
    api.pending[0].complete([_row(1, 'old account')]);
    await container.pump();
    expect(
      container.read(provider).requireValue.single.previewText,
      'new account',
    );
    container.read(_account.notifier).select('');
    await container.pump();
    expect(await container.read(provider.future), isEmpty);
    expect(api.calls.length, 2);
  });
}
