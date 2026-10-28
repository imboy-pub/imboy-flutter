import 'dart:async';

import 'package:dio/dio.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/component/http/http_response.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/channel/channel_di_provider.dart';
import 'package:imboy/page/channel/channel_provider.dart';
import 'package:imboy/page/workspace/widget/workspace_access_guard.dart';
import 'package:imboy/page/workspace/workspace_access_provider.dart';
import 'package:imboy/page/workspace/workspace_channel_detail_page.dart';
import 'package:imboy/page/workspace/workspace_conversations_page.dart';
import 'package:imboy/page/workspace/workspace_data_providers.dart';
import 'package:imboy/page/workspace_shell/workspace_shell_provider.dart';
import 'package:imboy/service/event_bus.dart';
import 'package:imboy/service/events/common_events.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/service/websocket_events.dart';
import 'package:imboy/store/api/channel_api.dart';
import 'package:imboy/store/api/workspace_api.dart';
import 'package:imboy/store/model/channel_model.dart';
import 'package:imboy/store/model/user_model.dart';
import 'package:imboy/store/model/workspace_conversation_model.dart';
import 'package:imboy/store/model/workspace_model.dart';
import 'package:imboy/store/repository/user_repo_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../store/api/workspace_conversations_api_test.dart' show messageRow;

const _target = (workspaceId: '100', resource: kWorkspaceAccessContentResource);
const _channelTarget = (workspaceId: '100', resource: 'channel:9002');
const _millisecond = Duration(milliseconds: 1);

WorkspaceAccessContext _identity({
  String uid = '1',
  String origin = 'https://one.invalid',
  int session = 1,
  String? featureScope = 'one:1',
  int featureEpoch = 1,
  int featureRevision = 1,
  bool channelEnabled = true,
}) => (
  origin: origin,
  uid: uid,
  session: session,
  featureScope: featureScope,
  featureEpoch: featureEpoch,
  featureRevision: featureRevision,
  channelEnabled: channelEnabled,
);

WorkspaceConversationModel _row({
  int generation = 10,
  String text = 'secret',
}) => WorkspaceConversationModel.fromJson({
  ...messageRow(text: text),
  'member_generation_id': generation,
  'unread_count': 7,
});

ChannelModel _channel({String scope = 'workspace', String workspace = '100'}) =>
    ChannelModel(
      id: 9002,
      scope: scope,
      workspaceId: workspace,
      name: 'protected channel',
      creatorId: 1,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
      visibility: 1,
      accessType: 0,
      joinPolicy: 1,
    );

class _Api extends WorkspaceApi {
  final calls = <String>[];
  final pending = <Completer<List<WorkspaceConversationModel>>>[];

  @override
  Future<List<WorkspaceConversationModel>> conversations(EntityId workspaceId) {
    calls.add(workspaceId);
    final response = Completer<List<WorkspaceConversationModel>>();
    pending.add(response);
    return response.future;
  }

  @override
  Future<WorkspaceOverview> overview(EntityId workspaceId) async =>
      const WorkspaceOverview();

  @override
  Future<List<ChannelModel>> channels(
    EntityId workspaceId, {
    String? status,
  }) async => [];

  void accept(int index, {int generation = 10}) =>
      pending[index].complete([_row(generation: generation)]);
}

class _ChannelApi extends ChannelApi {
  final details = <Completer<ChannelModel>>[];
  final contents = <Completer<IMBoyHttpResponse>>[];

  @override
  Future<ChannelModel> getChannelChecked(String channelId) {
    final response = Completer<ChannelModel>();
    details.add(response);
    return response.future;
  }

  @override
  Future<IMBoyHttpResponse> get(
    String uri, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onReceiveProgress,
    httpTransformer,
  }) {
    expect(uri, '/api/v1/channel/9002/messages');
    final response = Completer<IMBoyHttpResponse>();
    contents.add(response);
    return response.future;
  }
}

class _PersonalDetail extends ChannelDetailNotifier {
  @override
  ChannelDetailState build() =>
      ChannelDetailState(channel: _channel(scope: 'personal'));
}

class _Identity extends Notifier<WorkspaceAccessContext> {
  @override
  WorkspaceAccessContext build() => _identity();

  void select(WorkspaceAccessContext value) => state = value;
}

final _identityProvider = NotifierProvider<_Identity, WorkspaceAccessContext>(
  _Identity.new,
);

class _Harness {
  _Harness(Duration Function() clock) {
    container = ProviderContainer(
      overrides: [
        workspaceApiProvider.overrideWithValue(api),
        channelApiProvider.overrideWithValue(channelApi),
        workspaceAccessClockProvider.overrideWithValue(clock),
        workspaceAccessContextReaderProvider.overrideWith((ref) {
          final identity = ref.watch(_identityProvider);
          return () => identity;
        }),
        workspaceAccessNetworkProvider.overrideWith((ref) => network.stream),
        workspaceMessageClockProvider.overrideWithValue(() => wallTime),
        workspaceGroupAvatarLoaderProvider.overrideWithValue((_) async => []),
        currentUserProvider.overrideWithValue(UserModel.fromJson({'uid': '1'})),
        currentWorkspaceProvider.overrideWithValue(
          WorkspaceModel(id: '100', name: 'Workspace', ownerId: '1'),
        ),
        channelDetailProvider.overrideWith(_PersonalDetail.new),
      ],
    );
    keep(_target);
  }

  final api = _Api();
  final channelApi = _ChannelApi();
  final network = StreamController<bool>.broadcast();
  int wallTime = DateTime.now().millisecondsSinceEpoch;
  late final ProviderContainer container;
  WorkspaceAccessState get state =>
      container.read(workspaceAccessProvider(_target));
  WorkspaceAccessNotifier get access => notifier(_target);
  WorkspaceAccessNotifier notifier(WorkspaceAccessTarget target) =>
      container.read(workspaceAccessProvider(target).notifier);

  void keep(WorkspaceAccessTarget target) =>
      container.listen(workspaceAccessProvider(target), (_, _) {});

  void change(WorkspaceAccessContext next) {
    container.read(_identityProvider.notifier).select(next);
    container.read(workspaceAccessProvider(_target));
  }

  void dispose() {
    container.dispose();
    unawaited(network.close());
  }
}

void _empty(WorkspaceAccessState state) {
  expect(state.canRenderProtectedContent, isFalse);
  expect(state.rows, isEmpty);
  expect(state.channel, isNull);
  expect(state.deadline, isNull);
}

Future<void> _pump(
  WidgetTester tester,
  _Harness harness, {
  Widget? page,
  GlobalKey<NavigatorState>? navigatorKey,
}) async {
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: harness.container,
      child: TranslationProvider(
        child: MaterialApp(
          navigatorKey: navigatorKey,
          home: Scaffold(
            body:
                page ??
                WorkspaceAccessGuard(
                  target: _target,
                  builder: (_, state) => Semantics(
                    label: 'protected semantics',
                    child: TextButton(
                      onPressed: () {},
                      child: const Text('protected body'),
                    ),
                  ),
                ),
          ),
        ),
      ),
    ),
  );
  await _flush(tester);
}

Future<void> _online(WidgetTester tester, _Harness harness) async {
  harness.network.add(true);
  await _flush(tester);
}

Future<void> _unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await _flush(tester);
}

Future<void> _flush(WidgetTester tester) async {
  await tester.pump();
  await tester.pump();
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
  });

  test(
    'J29.a/b: 19.999/20/29.999/30s are exact for pending and failed rechecks',
    () {
      for (final fail in [false, true]) {
        fakeAsync((time) {
          final harness = _Harness(() => time.elapsed);
          harness.access.resume();
          harness.api.accept(0);
          time.flushMicrotasks();
          final rows = harness.state.rows;
          time.elapse(const Duration(milliseconds: 19999));
          expect(harness.api.calls, ['100']);
          expect(harness.state.rows, same(rows));
          time.elapse(_millisecond);
          expect(harness.api.calls, ['100', '100']);
          expect(harness.state.rechecking, isTrue);
          expect(harness.state.rows, same(rows));
          if (fail) {
            harness.api.pending[1].completeError(
              WorkspaceApiException(503, 'offline'),
            );
            time.flushMicrotasks();
          }
          time.elapse(const Duration(milliseconds: 9999));
          expect(harness.state.canRenderProtectedContent, isTrue);
          expect(harness.state.deadline, const Duration(seconds: 30));
          time.elapse(_millisecond);
          _empty(harness.state);
          expect(harness.state.phase, WorkspaceAccessPhase.unknown);
          if (!fail) harness.api.accept(1);
          time.flushMicrotasks();
          _empty(harness.state);
          harness.dispose();
        });
      }
    },
  );

  test(
    'J29.c: arrival defines t0; renewal keeps rows and defeats old deadline',
    () {
      fakeAsync((time) {
        final harness = _Harness(() => time.elapsed);
        harness.access.resume();
        time.elapse(const Duration(seconds: 7));
        harness.api.accept(0);
        time.flushMicrotasks();
        expect(harness.state.deadline, const Duration(seconds: 37));
        time.elapse(const Duration(seconds: 20));
        expect(harness.state.rows.single.previewText, 'secret');
        harness.api.accept(1);
        time.flushMicrotasks();
        expect(harness.state.deadline, const Duration(seconds: 57));
        time.elapse(const Duration(seconds: 10));
        expect(harness.state.canRenderProtectedContent, isTrue);
        harness.dispose();
      });
    },
  );

  test(
    'J29.b: initial and retry requests cannot remain pending indefinitely',
    () {
      fakeAsync((time) {
        final harness = _Harness(() => time.elapsed);
        harness.access.resume();
        time.elapse(const Duration(seconds: 30));
        _empty(harness.state);
        expect(harness.state.rechecking, isFalse);
        unawaited(harness.access.resetForRetry());
        expect(harness.api.calls.length, 2);
        harness.api.accept(0);
        time.flushMicrotasks();
        _empty(harness.state);
        expect(harness.state.rechecking, isTrue);
        time.elapse(const Duration(seconds: 30));
        _empty(harness.state);
        expect(harness.state.rechecking, isFalse);
        harness.dispose();
      });
    },
  );

  test('J29.e: old widget disposal cannot suspend the replacement page', () {
    fakeAsync((time) {
      final harness = _Harness(() => time.elapsed);
      final oldOwner = Object();
      final newOwner = Object();
      harness.access.resume(owner: oldOwner);
      harness.api.accept(0);
      time.flushMicrotasks();
      harness.access.resume(owner: newOwner);
      _empty(harness.state);
      harness.access.markEnvironmentSuspended(owner: oldOwner);
      harness.api.accept(1);
      time.flushMicrotasks();
      expect(harness.state.canRenderProtectedContent, isTrue);
      harness.access.markEnvironmentSuspended(owner: newOwner);
      _empty(harness.state);
      harness.dispose();
    });
  });

  test('J29.c/f: stale success and stale 403 cannot alter a new membership generation', () {
    for (final deny in [false, true]) {
      fakeAsync((time) {
        final harness = _Harness(() => time.elapsed);
        harness.access.resume();
        harness.api.accept(0);
        time.flushMicrotasks();
        time.elapse(const Duration(seconds: 20));
        harness.access.markRevoked();
        _empty(harness.state);
        unawaited(harness.access.resetForRetry());
        harness.api.accept(2, generation: 11);
        time.flushMicrotasks();
        final renewed = harness.state;
        if (deny) {
          harness.api.pending[1].completeError(
            WorkspaceApiException(403, 'old member'),
          );
        } else {
          harness.api.accept(1, generation: 10);
        }
        time.flushMicrotasks();
        expect(harness.state, same(renewed));
        expect(harness.state.rows.single.memberGenerationId, 11);
        harness.dispose();
      });
    }
  });

  final contexts = <String, WorkspaceAccessContext>{
    'account': _identity(uid: '2'),
    'origin': _identity(origin: 'https://two.invalid'),
    'same uid new session': _identity(session: 2),
    'feature scope': _identity(featureScope: 'two:1'),
    'feature epoch': _identity(featureEpoch: 2),
    'feature revision': _identity(featureRevision: 2),
  };
  for (final entry in contexts.entries) {
    test('J29.d: ${entry.key} fences previous content and responses', () {
      fakeAsync((time) {
        final harness = _Harness(() => time.elapsed);
        harness.access.resume();
        harness.api.accept(0);
        time.flushMicrotasks();
        time.elapse(const Duration(seconds: 20));
        harness.change(entry.value);
        _empty(harness.state);
        time.flushMicrotasks();
        expect(harness.api.calls.length, 3);
        harness.api.accept(1);
        time.flushMicrotasks();
        _empty(harness.state);
        harness.api.accept(2);
        time.flushMicrotasks();
        expect(harness.state.canRenderProtectedContent, isTrue);
        harness.dispose();
      });
    });
  }

  test('J29.d: workspace/resource, directory, statistics and cache cannot renew each other', () {
    fakeAsync((time) {
      final harness = _Harness(() => time.elapsed);
      const other = (
        workspaceId: '200',
        resource: kWorkspaceAccessContentResource,
      );
      const metadata = (workspaceId: '100', resource: 'statistics');
      harness.keep(other);
      harness.keep(metadata);
      harness.access.resume();
      harness.notifier(other).resume();
      harness.notifier(metadata).resume();
      harness.api.accept(0);
      time.flushMicrotasks();
      _empty(harness.container.read(workspaceAccessProvider(other)));
      _empty(harness.container.read(workspaceAccessProvider(metadata)));
      harness.container.listen(
        workspaceConversationsProvider('100'),
        (_, _) {},
      );
      expect(
        harness.container
            .read(workspaceConversationsProvider('100'))
            .asData
            ?.value,
        isNotEmpty,
      );
      time.elapse(const Duration(seconds: 20));
      unawaited(harness.api.overview('100'));
      unawaited(harness.api.channels('100'));
      harness.container.invalidate(workspaceConversationsProvider('100'));
      time.flushMicrotasks();
      expect(harness.api.calls, ['100', '200', '100']);
      expect(harness.state.deadline, const Duration(seconds: 30));
      time.elapse(const Duration(seconds: 10));
      _empty(harness.state);
      final projection = harness.container.read(
        workspaceConversationsProvider('100'),
      );
      expect(
        projection.asData?.value,
        isEmpty,
        reason: 'expired rows contribute no unread count',
      );
      expect(
        projection.value,
        isEmpty,
        reason: 'AsyncError must not retain protected rows in previous value',
      );
      harness.dispose();
    });
  });

  test('J29.c: monotonic cutoff wins even before its timer callback runs', () {
    fakeAsync((time) {
      var clock = Duration.zero;
      final harness = _Harness(() => clock);
      harness.access.resume();
      harness.api.accept(0);
      time.flushMicrotasks();
      clock = const Duration(seconds: 20);
      time.elapse(clock);
      clock = const Duration(seconds: 30);
      harness.api.accept(1);
      time.flushMicrotasks();
      _empty(harness.state);
      harness.dispose();
    });
  });

  test(
    'J29.f: current authority denial clears state and stops recheck timers',
    () {
      for (final code in [401, 403, 404, 410, 980]) {
        fakeAsync((time) {
          final harness = _Harness(() => time.elapsed);
          harness.access.resume();
          harness.api.accept(0);
          time.flushMicrotasks();
          time.elapse(const Duration(seconds: 20));
          harness.api.pending[1].completeError(
            WorkspaceApiException(code, 'denied'),
          );
          time.flushMicrotasks();
          _empty(harness.state);
          expect(harness.state.phase, WorkspaceAccessPhase.revoked);
          time.elapse(const Duration(minutes: 2));
          expect(harness.api.calls.length, 2);
          harness.dispose();
        });
      }
    },
  );

  test(
    'J29.d: channel details alone and disabled features never grant content',
    () {
      fakeAsync((time) {
        final harness = _Harness(() => time.elapsed);
        harness.keep(_channelTarget);
        harness.notifier(_channelTarget).resume();
        harness.channelApi.details[0].complete(_channel());
        time.flushMicrotasks();
        _empty(harness.container.read(workspaceAccessProvider(_channelTarget)));
        harness.channelApi.contents[0].complete(
          IMBoyHttpResponse.failure(errCode: 403),
        );
        time.flushMicrotasks();
        expect(
          harness.container.read(workspaceAccessProvider(_channelTarget)).phase,
          WorkspaceAccessPhase.revoked,
        );
        harness.change(_identity(channelEnabled: false));
        harness.container.read(workspaceAccessProvider(_channelTarget));
        time.flushMicrotasks();
        expect(harness.channelApi.details.length, 1);
        _empty(harness.container.read(workspaceAccessProvider(_channelTarget)));
        harness.dispose();
      });
    },
  );

  test(
    'J29.d: channel workspace mismatch and malformed content fail closed',
    () {
      for (final mismatch in [false, true]) {
        fakeAsync((time) {
          final harness = _Harness(() => time.elapsed);
          harness.keep(_channelTarget);
          harness.notifier(_channelTarget).resume();
          harness.channelApi.details[0].complete(
            _channel(workspace: mismatch ? '200' : '100'),
          );
          time.flushMicrotasks();
          if (!mismatch) {
            harness.channelApi.contents[0].complete(
              IMBoyHttpResponse.success({'items': <Map<String, dynamic>>[]}),
            );
            time.flushMicrotasks();
          }
          _empty(
            harness.container.read(workspaceAccessProvider(_channelTarget)),
          );
          expect(harness.channelApi.contents.length, mismatch ? 0 : 1);
          harness.dispose();
        });
      }
    },
  );

  test('J29.d: origin change between channel stages cannot issue an old content read', () {
    fakeAsync((time) {
      final harness = _Harness(() => time.elapsed);
      harness.keep(_channelTarget);
      harness.notifier(_channelTarget).resume();
      harness.change(_identity(origin: 'https://two.invalid'));
      harness.channelApi.details[0].complete(_channel());
      time.flushMicrotasks();
      expect(harness.channelApi.contents, isEmpty);
      _empty(harness.container.read(workspaceAccessProvider(_channelTarget)));
      unawaited(harness.notifier(_channelTarget).refresh());
      harness.channelApi.details[1].complete(_channel());
      time.flushMicrotasks();
      harness.channelApi.contents[0].complete(
        IMBoyHttpResponse.success({'list': <Map<String, dynamic>>[]}),
      );
      time.flushMicrotasks();
      expect(
        harness.container
            .read(workspaceAccessProvider(_channelTarget))
            .canRenderProtectedContent,
        isTrue,
      );
      harness.dispose();
    });
  });

  testWidgets(
    'J29.e: unknown/offline/error hide rows immediately; online must reauthorize',
    (tester) async {
      final harness = _Harness(
        () => tester.binding.clock.now().difference(DateTime(2026)),
      );
      await _pump(tester, harness);
      expect(harness.api.calls, isEmpty);
      AppEventBus.fire(
        const NetworkConnectionEvent(isConnected: true, networkType: 'wifi'),
      );
      await _flush(tester);
      expect(harness.api.calls, isEmpty);
      harness.network.add(false);
      await _flush(tester);
      expect(harness.api.calls, isEmpty);
      await _online(tester, harness);
      harness.api.accept(0);
      await _flush(tester);
      expect(find.text('protected body'), findsOneWidget);
      final semantics = tester.ensureSemantics();
      expect(
        find.bySemanticsLabel(RegExp('protected semantics')),
        findsOneWidget,
      );
      harness.network.addError(StateError('network stream failed'));
      await _flush(tester);
      _empty(harness.state);
      expect(find.text('protected body'), findsNothing);
      expect(
        find.bySemanticsLabel(RegExp('protected semantics')),
        findsNothing,
      );
      await _online(tester, harness);
      expect(find.text('protected body'), findsNothing);
      harness.api.accept(1);
      await _flush(tester);
      harness.network.add(false);
      await _flush(tester);
      _empty(harness.state);
      semantics.dispose();
      await _unmount(tester);
      harness.dispose();
    },
  );

  testWidgets(
    'J29.e: background and WS reconnect fence old replies before restoring',
    (tester) async {
      final harness = _Harness(
        () => tester.binding.clock.now().difference(DateTime(2026)),
      );
      await _pump(tester, harness);
      await _online(tester, harness);
      harness.api.accept(0);
      await _flush(tester);
      unawaited(harness.access.refresh());
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      _empty(harness.state);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await _flush(tester);
      harness.api.accept(1);
      await _flush(tester);
      _empty(harness.state);
      harness.api.accept(2);
      await _flush(tester);
      expect(find.text('protected body'), findsOneWidget);
      AppEventBus.fire(const WebSocketStatusChangedEvent(status: 'connected'));
      await _flush(tester);
      _empty(harness.state);
      harness.api.accept(3);
      await _flush(tester);
      expect(find.text('protected body'), findsOneWidget);
      await _unmount(tester);
      harness.dispose();
    },
  );

  testWidgets(
    'J29.a/b: guard keeps actions at 20s and removes text and semantics at 30s',
    (tester) async {
      final harness = _Harness(
        () => tester.binding.clock.now().difference(DateTime(2026)),
      );
      await _pump(tester, harness);
      await _online(tester, harness);
      harness.api.accept(0);
      await _flush(tester);
      final semantics = tester.ensureSemantics();
      await tester.pump(const Duration(milliseconds: 19999));
      expect(harness.api.calls.length, 1);
      expect(find.text('protected body'), findsOneWidget);
      await tester.pump(_millisecond);
      expect(harness.api.calls.length, 2);
      expect(find.byType(TextButton), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 9999));
      expect(
        find.bySemanticsLabel(RegExp('protected semantics')),
        findsOneWidget,
      );
      await tester.pump(_millisecond);
      _empty(harness.state);
      expect(find.text('protected body'), findsNothing);
      expect(find.byType(TextButton), findsNothing);
      expect(
        find.bySemanticsLabel(RegExp('protected semantics')),
        findsNothing,
      );
      semantics.dispose();
      await _unmount(tester);
      harness.dispose();
    },
  );

  testWidgets(
    'J29.e: inactive tab and covered route clear content before returning',
    (tester) async {
      final harness = _Harness(
        () => tester.binding.clock.now().difference(DateTime(2026)),
      );
      var active = true;
      late StateSetter update;
      final navigator = GlobalKey<NavigatorState>();
      await _pump(
        tester,
        harness,
        navigatorKey: navigator,
        page: StatefulBuilder(
          builder: (_, setState) {
            update = setState;
            return WorkspaceAccessGuard(
              target: _target,
              active: active,
              builder: (_, state) => const Text('route content'),
            );
          },
        ),
      );
      await _online(tester, harness);
      harness.api.accept(0);
      await _flush(tester);
      update(() => active = false);
      await _flush(tester);
      await _flush(tester);
      _empty(harness.state);
      update(() => active = true);
      await _flush(tester);
      await _flush(tester);
      expect(find.text('route content'), findsNothing);
      harness.api.accept(1);
      await _flush(tester);
      unawaited(
        navigator.currentState!.push<void>(
          MaterialPageRoute(
            builder: (_) => const Scaffold(body: Text('cover')),
          ),
        ),
      );
      await _flush(tester);
      await tester.pump(const Duration(milliseconds: 400));
      _empty(harness.state);
      navigator.currentState!.pop();
      await _flush(tester);
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('route content'), findsNothing);
      harness.api.accept(2);
      await _flush(tester);
      expect(find.text('route content'), findsOneWidget);
      await _unmount(tester);
      harness.dispose();
    },
  );

  testWidgets('J29.f: only this member and group revoke conversation content', (
    tester,
  ) async {
    final harness = _Harness(
      () => tester.binding.clock.now().difference(DateTime(2026)),
    );
    await _pump(tester, harness);
    await _online(tester, harness);
    harness.api.accept(0);
    await _flush(tester);
    for (final payload in [
      {'userId': '2', 'groupId': '1'},
      {'userId': '1', 'groupId': '2'},
    ]) {
      AppEventBus.fire(ChatExtendEvent(type: 'leave_group', payload: payload));
      await _flush(tester);
      expect(harness.state.canRenderProtectedContent, isTrue);
    }
    AppEventBus.fire(
      const ChatExtendEvent(
        type: 'leave_group',
        payload: {'userId': '1', 'groupId': '1'},
      ),
    );
    await _flush(tester);
    _empty(harness.state);
    expect(harness.state.phase, WorkspaceAccessPhase.revoked);
    expect(find.text('protected body'), findsNothing);
    await _unmount(tester);
    harness.dispose();
  });

  testWidgets(
    'J29.g: actual page hides expired preview without renewing qualification',
    (tester) async {
      final harness = _Harness(
        () => tester.binding.clock.now().difference(DateTime(2026)),
      );
      harness.wallTime = DateTime.utc(2099).millisecondsSinceEpoch;
      await _pump(
        tester,
        harness,
        page: const WorkspaceConversationsPage(embedded: true),
      );
      await _online(tester, harness);
      harness.api.pending[0].complete([
        WorkspaceConversationModel.fromJson({
          ...messageRow(text: 'ttl preview'),
          'unread_count': 7,
          'member_generation_id': 10,
          'latest_message': {
            ...(messageRow()['latest_message'] as Map<String, dynamic>),
            'payload': {
              'payload': {'text': 'ttl preview'},
            },
            'expire_at': DateTime.fromMillisecondsSinceEpoch(
              harness.wallTime + 2000,
            ).toUtc().toIso8601String(),
          },
        }),
      ]);
      await _flush(tester);
      expect(find.text('ttl preview'), findsOneWidget);
      final deadline = harness.state.deadline;
      harness.wallTime += 1999;
      await tester.pump(const Duration(milliseconds: 1999));
      expect(find.text('ttl preview'), findsOneWidget);
      harness.wallTime++;
      await tester.pump(_millisecond);
      expect(find.text('ttl preview'), findsNothing);
      expect(harness.state.canRenderProtectedContent, isTrue);
      expect(harness.state.rows.single.memberGenerationId, 10);
      expect(harness.state.rows.single.unreadCount, 7);
      expect(harness.state.deadline, deadline);
      expect(harness.api.calls.length, 1);
      harness.access.markRevoked();
      await _flush(tester);
      expect(find.byKey(const ValueKey('workspace-unread-1')), findsNothing);
      await _unmount(tester);
      harness.dispose();
    },
  );

  testWidgets(
    'J29.f: channel page gates cold entry, removes actions and preserves personal scope',
    (tester) async {
      final harness = _Harness(
        () => tester.binding.clock.now().difference(DateTime(2026)),
      );
      harness.container.listen(channelDetailProvider, (_, _) {});
      final personal = harness.container.read(channelDetailProvider.notifier);
      await _pump(
        tester,
        harness,
        page: WorkspaceChannelDetailPage(
          channelId: '9002',
          workspaceId: '100',
          detailEntry: Consumer(
            builder: (_, ref, _) {
              expect(
                ref.read(channelDetailProvider.notifier),
                isNot(same(personal)),
              );
              return TextButton(
                onPressed: () {},
                child: const Text('publish content'),
              );
            },
          ),
        ),
      );
      expect(find.text('publish content'), findsNothing);
      await _online(tester, harness);
      harness.channelApi.details[0].complete(_channel());
      await _flush(tester);
      expect(find.text('publish content'), findsNothing);
      harness.channelApi.contents[0].complete(
        IMBoyHttpResponse.success({'list': <Map<String, dynamic>>[]}),
      );
      await _flush(tester);
      expect(find.text('publish content'), findsOneWidget);
      AppEventBus.fire(
        const ChatExtendEvent(
          type: 'leave_group',
          payload: {'userId': '1', 'groupId': '1'},
        ),
      );
      await _flush(tester);
      expect(find.text('publish content'), findsOneWidget);
      AppEventBus.fire(
        const ChannelStateChangedEvent(
          channelId: '9002',
          action: 'channel_deleted',
          payload: {},
        ),
      );
      await _flush(tester);
      expect(find.text('publish content'), findsNothing);
      _empty(harness.container.read(workspaceAccessProvider(_channelTarget)));
      expect(
        harness.container.read(channelDetailProvider).channel?.scope,
        'personal',
      );
      await _unmount(tester);
      harness.dispose();
    },
  );

  testWidgets(
    'J29.f: disposal microtask tolerates an already disposed autoDispose notifier',
    (tester) async {
      final harness = _Harness(
        () => tester.binding.clock.now().difference(DateTime(2026)),
      );
      await _pump(tester, harness);
      final access = harness.access;
      await _unmount(tester);
      harness.dispose();
      await Future<void>.microtask(access.markEnvironmentSuspended);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'J29.e: initial offline clears an existing in-memory display budget',
    (tester) async {
      final harness = _Harness(
        () => tester.binding.clock.now().difference(DateTime(2026)),
      );
      harness.access.resume();
      harness.api.accept(0);
      await _flush(tester);
      expect(harness.state.canRenderProtectedContent, isTrue);
      await _pump(tester, harness);
      harness.network.add(false);
      await _flush(tester);
      _empty(harness.state);
      expect(harness.api.calls.length, 1);
      expect(find.text('protected body'), findsNothing);
      await _unmount(tester);
      harness.dispose();
    },
  );
}
