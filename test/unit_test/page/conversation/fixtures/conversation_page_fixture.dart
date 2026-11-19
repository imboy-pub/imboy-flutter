part of '../conversation_page_test.dart';

// Called after unmount, inside runAsync: earlier title queries still need the
// fake microtask queue pumped while their real browser I/O finishes.
Future<void> _closeOwnedConversationDatabase(
  WidgetTester tester,
  sqlite.Database? database,
  String databaseName,
) async {
  var finished = false;
  Object? failure;
  StackTrace? failureStack;
  final cleanup =
      (() async {
        if (database != null && database.isOpen) {
          // This query shares the title reads' FIFO lock; drain them before close.
          await database.rawQuery('SELECT 1');
        }
        await database?.close();
        await sqlite.databaseFactory.deleteDatabase(databaseName);
      })().then<void>(
        (_) {
          finished = true;
        },
        onError: (Object error, StackTrace stack) {
          failure = error;
          failureStack = stack;
          finished = true;
        },
      );
  const timeout = Duration(seconds: 5);
  final elapsed = Stopwatch()..start();
  while (!finished && elapsed.elapsed < timeout) {
    await tester.pump();
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  if (!finished) {
    throw TestFailure(
      'Owned conversation database cleanup did not finish within $timeout',
    );
  }
  await cleanup;
  if (failure != null) Error.throwWithStackTrace(failure!, failureStack!);
  await tester.pump();
}

class _StateOverrideNotifier extends ConversationNotifier {
  _StateOverrideNotifier(this._initial);
  final ConversationState _initial;

  @override
  ConversationState build() => _initial;
}

/// LAY-04：捕获重试派发（不触网络）的 notifier。
///
/// 错误视图的重试按钮必须重新发起权威拉取（syncAuthoritativeConversationList），
/// 这里只计数不执行，保证断言独立于真实网络实现。
class _RetryCapturingNotifier extends _StateOverrideNotifier {
  _RetryCapturingNotifier(super.initial);

  int syncCalls = 0;

  @override
  Future<void> syncAuthoritativeConversationList({
    String trigger = 'manual',
  }) async {
    syncCalls++;
  }
}

/// J15.b 桌面壳向量：捕获右栏派发的 ChatSelection（宿主目的地判据）。
class _CapturingWebShellNotifier extends WebShellNotifier {
  final selections = <ChatSelection>[];

  @override
  WebShellState build() => const WebShellState();

  @override
  void selectItem(WebSelection selection) {
    if (selection is ChatSelection) selections.add(selection);
  }
}

// 只验证生产页面的导航分派，不替代真实资料页或真机验收。
GoRouter _stubRouter({
  List<String>? visitedRoutes,
  List<Object?>? visitedExtras,
  bool webShellHost = false,
}) {
  Widget stub(String label, GoRouterState state) {
    visitedRoutes?.add(state.uri.path);
    return Scaffold(body: Center(child: Text(label)));
  }

  return GoRouter(
    initialLocation: webShellHost ? '/web_shell' : '/conversation',
    routes: [
      GoRoute(
        path: webShellHost ? '/web_shell' : '/conversation',
        builder: (_, _) => const ConversationPage(),
      ),
      GoRoute(
        path: '/contact/new_friend',
        builder: (_, state) => stub('new_friend stub', state),
      ),
      GoRoute(
        path: '/contact/people/:id',
        builder: (_, state) =>
            stub('person ${state.pathParameters['id']}', state),
      ),
      GoRoute(
        path: '/group/detail/:id',
        builder: (_, state) =>
            stub('group ${state.pathParameters['id']}', state),
      ),
      GoRoute(
        path: '/chat/:id',
        builder: (_, state) {
          visitedExtras?.add(state.extra);
          return stub('chat ${state.pathParameters['id']}', state);
        },
      ),
    ],
  );
}
