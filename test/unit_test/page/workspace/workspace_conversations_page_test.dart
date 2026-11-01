import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/component/ui/button.dart' show RoundedCupertinoButton;
import 'package:imboy/page/conversation/conversation_provider.dart';
import 'package:imboy/page/workspace/workspace_conversations_page.dart';
import 'package:imboy/page/workspace/workspace_data_providers.dart';
import 'package:imboy/page/workspace/widget/workspace_access_guard.dart';
import 'package:imboy/page/workspace/workspace_access_provider.dart';
import 'package:imboy/page/workspace/workspace_groups_page.dart'
    show WorkspaceGroupsStandalonePage;
import 'package:imboy/page/workspace_shell/workspace_shell_provider.dart';
import 'package:imboy/service/event_bus.dart';
import 'package:imboy/service/websocket_events.dart';
import 'package:imboy/store/api/workspace_api.dart';
import 'package:imboy/store/model/group_model.dart';
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

  @override
  Future<List<GroupModel>> memberGroups(EntityId workspaceId) async => [];
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
    workspaceAccessContextReaderProvider.overrideWith((ref) {
      final uid = ref.watch(currentUserProvider)?.uid ?? '';
      return () => (
        origin: 'https://workspace.invalid',
        uid: uid,
        session: 1,
        featureScope: 'workspace:$uid',
        featureEpoch: 1,
        featureRevision: 1,
        channelEnabled: true,
      );
    }),
    workspaceAccessNetworkProvider.overrideWith((ref) => Stream.value(true)),
    workspaceGroupAvatarLoaderProvider.overrideWithValue((_) async => []),
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
  await tester.pump();
  return router;
}

WorkspaceAccessNotifier _access(
  ProviderContainer container,
  String workspaceId,
) => container.read(
  workspaceAccessProvider((
    workspaceId: workspaceId,
    resource: kWorkspaceAccessContentResource,
  )).notifier,
);

/// J10.b：可变 session generation（重入新世代 = 上下文变化）。
class _SessionGen extends Notifier<int> {
  @override
  int build() => 1;
  void bump() => state++;
}

final _sessionGen = NotifierProvider<_SessionGen, int>(_SessionGen.new);

ProviderContainer _genContainer(_Api api) => ProviderContainer(
  overrides: [
    workspaceApiProvider.overrideWithValue(api),
    currentUserProvider.overrideWith((ref) => ref.watch(_account)),
    workspaceAccessContextReaderProvider.overrideWith((ref) {
      final uid = ref.watch(currentUserProvider)?.uid ?? '';
      final session = ref.watch(_sessionGen);
      return () => (
        origin: 'https://workspace.invalid',
        uid: uid,
        session: session,
        featureScope: 'workspace:$uid',
        featureEpoch: 1,
        featureRevision: 1,
        channelEnabled: true,
      );
    }),
    workspaceAccessNetworkProvider.overrideWith((ref) => Stream.value(true)),
    workspaceGroupAvatarLoaderProvider.overrideWithValue((_) async => []),
    conversationProvider.overrideWith(_NeverReadGlobal.new),
  ],
);

WorkspaceAccessState _accessState(ProviderContainer container) =>
    container.read(
      workspaceAccessProvider((
        workspaceId: '100',
        resource: kWorkspaceAccessContentResource,
      )),
    );

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
      unawaited(_access(container, '100').refresh());
      await tester.pump();
      expect(find.text('5'), findsOneWidget);
      api.pending.last.complete([_row(1, 'A'), _row(2, 'B', unread: 7)]);
      await tester.pump();
      await tester.pump();
      expect(find.text('5'), findsNothing);
      expect(find.text('7'), findsOneWidget);
      _select(container, '200');
      await tester.pump();
      await tester.pump();
      expect(find.text('7'), findsNothing);
      api.pending.last.complete([_row(3, 'C', unread: 9)]);
      await tester.pump();
      await tester.pump();
      expect(find.text('9'), findsOneWidget);
      container.read(_account.notifier).select('2');
      await tester.pump();
      await tester.pump();
      expect(find.text('9'), findsNothing);
      _select(container, '200');
      await tester.pump();
      await tester.pump();
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
      unawaited(_access(container, '200').refresh());
      await tester.pump();
      expect(find.text('workspace B'), findsOneWidget);
      api.pending[2].completeError(
        const WorkspaceApiException(403, 'access revoked'),
      );
      await tester.pump();
      await tester.pump();
      expect(find.text(t.workspace.contentRevoked), findsOneWidget);
      expect(find.text('workspace B'), findsNothing);
      await _disposePage(tester);
    },
  );

  testWidgets(
    'empty state CTA opens the scoped workspace groups page, not platform discovery',
    (tester) async {
      final api = _Api();
      final container = _container(api);
      addTearDown(container.dispose);
      _select(container, '100');
      await _pump(tester, container);
      api.pending.single.complete([]);
      await tester.pump();
      await tester.pump();
      final cta = find.byType(RoundedCupertinoButton);
      expect(cta, findsOneWidget);
      await tester.tap(cta);
      await tester.pumpAndSettle();
      expect(find.byType(WorkspaceGroupsStandalonePage), findsOneWidget);
      // 独立页承载（IosPageTemplate 标题）而非平台公开群发现页
      expect(find.text(t.workspace.navGroups), findsWidgets);
      await _disposePage(tester);
    },
  );

  testWidgets('J08.a: 两账号×两workspace切换不残留内容，迟到旧响应不写回', (tester) async {
    final api = _Api();
    final container = _container(api);
    addTearDown(container.dispose);
    // 账号 A + workspace 100。
    _select(container, '100');
    await _pump(tester, container);
    final ws100A = api.pending.single;

    // 切账号 B：同 workspace 的受保护内容必须失效并重新拉取。
    container.read(_account.notifier).select('2');
    await tester.pump();
    await tester.pump();
    // 再切 workspace 200：当前目标 = B 账号 × ws200。
    _select(container, '200');
    await tester.pump();
    await tester.pump();
    expect(api.calls, ['100', '100', '200']);

    // 当前目标先完成并渲染。
    api.pending[2].complete([_row(3, 'account-b-ws200')]);
    await tester.pump();
    await tester.pump();
    expect(find.text('account-b-ws200'), findsOneWidget);

    // 旧账号 A×ws100 响应迟到：不得残留渲染。
    ws100A.complete([_row(1, 'account-a-ws100')]);
    await tester.pump();
    await tester.pump();
    expect(find.text('account-a-ws100'), findsNothing);
    expect(find.text('account-b-ws200'), findsOneWidget);

    // 新账号 B×旧 ws100 响应迟到：同样不得写回当前页面。
    api.pending[1].complete([_row(2, 'account-b-ws100')]);
    await tester.pump();
    await tester.pump();
    expect(find.text('account-b-ws100'), findsNothing);
    expect(find.text('account-b-ws200'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _disposePage(tester);
  });

  test('account switch invalidates same-workspace response and logout stops requests', () async {
    final api = _Api();
    final container = _container(api);
    addTearDown(container.dispose);
    final provider = workspaceConversationsProvider('100');
    final accessProvider = workspaceAccessProvider((
      workspaceId: '100',
      resource: kWorkspaceAccessContentResource,
    ));
    final accessSubscription = container.listen(accessProvider, (_, _) {});
    addTearDown(accessSubscription.close);
    final subscription = container.listen(provider, (_, _) {});
    addTearDown(subscription.close);
    _access(container, '100').resume();
    // a12f1a6c7：resume 在 _active 已 true 时早退，请求由 build 排队的
    // microtask(refresh) 发出——先冲刷微任务队列再断言。
    await Future<void>.delayed(Duration.zero);
    expect(api.calls, ['100']);
    container.read(_account.notifier).select('2');
    await container.pump();
    await Future<void>.delayed(Duration.zero);
    expect(container.read(accessProvider).canRenderProtectedContent, isFalse);
    expect(api.calls, ['100', '100']);
    api.pending[1].complete([_row(2, 'new account')]);
    await container.pump();
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
    expect(container.read(accessProvider).canRenderProtectedContent, isFalse);
    expect(container.read(accessProvider).rows, isEmpty);
    expect(api.calls.length, 2);
  });

  testWidgets('J10.b 同资源重入新 generation：旧数据/偏好不继承，仅当前世代呈现', (tester) async {
    final api = _Api();
    final container = _genContainer(api);
    addTearDown(container.dispose);
    _select(container, '100');
    await _pump(tester, container);
    await tester.pump();
    expect(api.calls, ['100']);

    // 旧世代授权渲染。
    api.pending[0].complete([_row(1, 'old-era'), _row(2, 'old-pref')]);
    await tester.pump();
    await tester.pump();
    expect(find.text('old-era'), findsOneWidget);

    // 旧世代再校验在途（recheck 形态），响应尚未完成。
    unawaited(_access(container, '100').refresh());
    await tester.pump();
    expect(api.pending, hasLength(2));

    // 重入：membership 新世代（session 上下文变化）→ 在途旧请求作废。
    container.read(_sessionGen.notifier).bump();
    await tester.pump();
    await tester.pump();
    expect(api.calls, hasLength(3));
    expect(_accessState(container).canRenderProtectedContent, isFalse);

    // 旧世代迟到响应：数据与旧资格都不呈现。
    api.pending[1].complete([_row(1, 'old-era'), _row(2, 'old-pref')]);
    await tester.pump();
    await tester.pump();
    expect(find.text('old-era'), findsNothing);
    expect(find.text('old-pref'), findsNothing);
    expect(_accessState(container).canRenderProtectedContent, isFalse);

    // 新世代响应到达：仅当前世代可呈现。
    api.pending[2].complete([_row(9, 'new-era')]);
    await tester.pump();
    await tester.pump();
    expect(find.text('new-era'), findsOneWidget);
    expect(find.text('old-era'), findsNothing);
    expect(_accessState(container).canRenderProtectedContent, isTrue);
    expect(tester.takeException(), isNull);
    await _disposePage(tester);
  });

  testWidgets('J10.c 冷启动：资格未知时不渲染受保护内容', (tester) async {
    final api = _Api();
    final container = _genContainer(api);
    addTearDown(container.dispose);
    _select(container, '100');
    await _pump(tester, container);
    await tester.pump();
    // 请求在途、资格未知：不得出现任何受保护行。
    expect(api.pending, hasLength(1));
    expect(_accessState(container).phase, WorkspaceAccessPhase.unknown);
    expect(_accessState(container).canRenderProtectedContent, isFalse);
    expect(find.text('cold-era'), findsNothing);
    expect(find.text('another-era'), findsNothing);
    // 授权完成后才呈现。
    api.pending.single.complete([_row(1, 'cold-era')]);
    await tester.pump();
    await tester.pump();
    expect(find.text('cold-era'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _disposePage(tester);
  });

  testWidgets('J10.c 冷启动请求失败：未授权仍无受保护渲染且可重试', (tester) async {
    final api = _Api();
    final container = _genContainer(api);
    addTearDown(container.dispose);
    _select(container, '100');
    await _pump(tester, container);
    await tester.pump();
    // 非授权类失败（500）：phase 保持 unknown，无受保护渲染。
    api.pending.single.completeError(const WorkspaceApiException(500, 'boom'));
    await tester.pump();
    await tester.pump();
    expect(_accessState(container).phase, WorkspaceAccessPhase.unknown);
    expect(_accessState(container).canRenderProtectedContent, isFalse);
    expect(find.text('failed-era'), findsNothing);
    // 重试成功后才呈现。
    unawaited(_access(container, '100').resetForRetry());
    await tester.pump();
    await tester.pump();
    expect(api.pending, hasLength(2));
    api.pending[1].complete([_row(1, 'failed-era')]);
    await tester.pump();
    await tester.pump();
    expect(find.text('failed-era'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _disposePage(tester);
  });

  testWidgets('J10.c 返回：叠页返回后旧快照不直接呈现，须重新授权', (tester) async {
    final api = _Api();
    final container = _genContainer(api);
    addTearDown(container.dispose);
    _select(container, '100');
    final router = await _pump(tester, container);
    await tester.pump();
    api.pending.single.complete([_row(1, 'return-era')]);
    await tester.pump();
    await tester.pump();
    expect(find.text('return-era'), findsOneWidget);

    // 叠页（离开受保护页）：内容立即不可见，资格回到未知。
    unawaited(router.push('/chat/9'));
    await tester.pumpAndSettle();
    expect(find.text('return-era'), findsNothing);
    expect(_accessState(container).canRenderProtectedContent, isFalse);

    // 返回：重新授权完成前不得恢复受保护渲染。
    router.pop();
    await tester.pumpAndSettle();
    await tester.pump();
    await tester.pump();
    expect(api.pending, hasLength(2));
    expect(find.text('return-era'), findsNothing);
    api.pending[1].complete([_row(1, 'return-era')]);
    await tester.pump();
    await tester.pump();
    expect(find.text('return-era'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _disposePage(tester);
  });

  testWidgets('J10.c 重连：WS 重连先作废授权，重新拉取前无受保护渲染', (tester) async {
    final api = _Api();
    final container = _genContainer(api);
    addTearDown(container.dispose);
    _select(container, '100');
    await _pump(tester, container);
    await tester.pump();
    api.pending.single.complete([_row(1, 'reconnect-era')]);
    await tester.pump();
    await tester.pump();
    expect(find.text('reconnect-era'), findsOneWidget);

    // 重连事件：先作废当前授权（unknown），再排队重新拉取。
    AppEventBus.fire(const WebSocketStatusChangedEvent(status: 'connected'));
    await tester.pump();
    await tester.pump();
    expect(find.text('reconnect-era'), findsNothing);
    expect(_accessState(container).canRenderProtectedContent, isFalse);
    expect(api.pending, hasLength(2));

    // 重新授权完成前保持无渲染；完成后恢复。
    api.pending[1].complete([_row(1, 'reconnect-era')]);
    await tester.pump();
    await tester.pump();
    expect(find.text('reconnect-era'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _disposePage(tester);
  });
}
