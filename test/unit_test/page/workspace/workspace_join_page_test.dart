/// T2.6 (WP 团队码) — 团队码加入页 widget 测试 + API envelope 解析测试
///
/// 覆盖（全部无网，API 经 FakeApi / post 覆盖注入）：
/// - 输满 8 位自动提交（小写自动转大写）成功 → applyJoined 置顶切当前 +
///   导航 /bottom_navigation（joined 与 unchanged 均成功）
/// - 981 → joinInvalidCode 页内文案；982 → joinExpiredCode 页内文案；
///   异常路径不离开页面
/// - unchanged → joinAlreadyMember 成功提示（否则 joinSuccess(name)）
/// - WorkspaceApi.createInviteCode / joinByCode 的 envelope 解析与异常映射
library;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:imboy/component/http/http_response.dart';
import 'package:imboy/component/http/http_transformer.dart';
import 'package:imboy/component/ui/app_loading.dart' as app_loading;
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/workspace/workspace_data_providers.dart';
import 'package:imboy/page/workspace/workspace_join_page.dart';
import 'package:imboy/page/workspace_shell/workspace_shell_nav_items.dart';
import 'package:imboy/page/workspace_shell/workspace_shell_provider.dart';
import 'package:imboy/store/api/workspace_api.dart';
import 'package:imboy/store/model/workspace_model.dart';

/// 可控 Fake：joinByCode 结果 / 异常可注入；记录收到的码。
class _JoinFakeApi extends WorkspaceApi {
  WorkspaceJoinResult joinResult = const WorkspaceJoinResult();
  WorkspaceApiException? joinError;
  final List<String> receivedCodes = [];

  @override
  Future<WorkspaceJoinResult> joinByCode(String code) async {
    receivedCodes.add(code);
    final err = joinError;
    if (err != null) throw err;
    return joinResult;
  }
}

/// envelope 级 Fake：直接注入 post 响应（测 API 层解包与异常映射）。
class _EnvelopeFakeApi extends WorkspaceApi {
  final IMBoyHttpResponse resp;
  _EnvelopeFakeApi(this.resp);

  @override
  Future<IMBoyHttpResponse> post(
    String uri, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
    HttpTransformer? httpTransformer,
  }) async => resp;
}

GoRouter _router() => GoRouter(
  initialLocation: '/workspace/join',
  routes: [
    GoRoute(
      path: '/workspace/join',
      builder: (c, s) => const WorkspaceJoinPage(),
    ),
    GoRoute(
      path: '/bottom_navigation',
      builder: (c, s) => const _ProbePage(label: 'probe-home'),
    ),
  ],
);

class _ProbePage extends StatelessWidget {
  final String label;
  const _ProbePage({required this.label});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(label)),
    body: const SizedBox.shrink(),
  );
}

Future<void> _pump(
  WidgetTester tester, {
  required ProviderContainer container,
}) async {
  tester.view.physicalSize = const Size(430, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    TranslationProvider(
      child: UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          routerConfig: _router(),
          // EasyLoading toast host（成功提示断言依赖）
          builder: app_loading.AppLoading.init(),
        ),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 100));
}

/// 播种壳状态：已有一个工作区 9001（验证 applyJoined 的置顶去重语义）。
ProviderContainer _seededContainer(_JoinFakeApi api) {
  final container = ProviderContainer(
    overrides: [workspaceApiProvider.overrideWith((ref) => api)],
  );
  container
      .read(workspaceShellProvider.notifier)
      .applyCreated(
        WorkspaceCreateResult(
          workspace: const WorkspaceModel(
            id: '9001',
            name: '既有工作区',
            ownerId: '1001',
          ),
          channelId: '',
          groupId: '',
          status: 'created',
        ),
      );
  return container;
}

Future<void> _enterCode(WidgetTester tester, String code) async {
  await tester.enterText(
    find.byKey(const ValueKey('workspace-join-code-field')),
    code,
  );
  await tester.pump(); // onChanged → 自动提交启动
  await tester.pump(const Duration(milliseconds: 100)); // joinByCode resolve
}

void main() {
  testWidgets('输满 8 位自动提交（小写转大写）：applyJoined 置顶切当前 + 导航', (tester) async {
    final api = _JoinFakeApi()
      ..joinResult = const WorkspaceJoinResult(
        status: 'joined',
        workspace: WorkspaceModel(id: '9005', name: '官网改版', ownerId: '1002'),
      );
    final container = _seededContainer(api);
    addTearDown(container.dispose);

    await _pump(tester, container: container);
    expect(find.byKey(const ValueKey('workspace-join-submit')), findsOneWidget);

    // 小写输入：formatter 规范为大写后自动提交
    await _enterCode(tester, 'ab12cd34');

    // joined → 成功提示 joinSuccess(name)
    expect(find.textContaining('官网改版'), findsOneWidget);
    // 离开页面：回到壳挂载点
    expect(find.text('probe-home'), findsOneWidget);
    // applyJoined：新工作区置顶 + 切当前
    final state = container.read(workspaceShellProvider);
    expect(state.workspaces.length, 2);
    expect(state.workspaces.first.id, '9005');
    expect(state.currentWorkspaceId, '9005');
    expect(state.destination, WorkspaceShellDestination.overview);
    // API 收到的码已大写化
    expect(api.receivedCodes, ['AB12CD34']);
    // 清理 EasyLoading 自动消失 Timer，避免 pending timers
    await tester.pump(const Duration(seconds: 2));
    await tester.pump(const Duration(seconds: 4));
  });

  testWidgets('unchanged（已是成员）同样成功：joinAlreadyMember 提示 + 导航', (tester) async {
    final api = _JoinFakeApi()
      ..joinResult = const WorkspaceJoinResult(
        status: 'unchanged',
        workspace: WorkspaceModel(id: '9005', name: '官网改版', ownerId: '1002'),
      );
    final container = _seededContainer(api);
    addTearDown(container.dispose);

    await _pump(tester, container: container);
    await _enterCode(tester, 'AB12CD34');

    // unchanged → joinAlreadyMember 文案 + 同样导航并回填
    expect(find.text('你已在该工作区中'), findsOneWidget);
    expect(find.text('probe-home'), findsOneWidget);
    final state = container.read(workspaceShellProvider);
    expect(state.currentWorkspaceId, '9005');
    // 清理 EasyLoading 自动消失 Timer，避免 pending timers
    await tester.pump(const Duration(seconds: 2));
    await tester.pump(const Duration(seconds: 4));
  });

  testWidgets('981 码无效：joinInvalidCode 页内文案，不离开页面', (tester) async {
    final api = _JoinFakeApi()
      ..joinError = const WorkspaceApiException(981, 'invite_code invalid');
    final container = _seededContainer(api);
    addTearDown(container.dispose);

    await _pump(tester, container: container);
    await _enterCode(tester, 'AB12CD34');

    expect(find.text('团队码无效或已失效'), findsOneWidget);
    // 异常路径留在本页（未导航）
    expect(find.text('probe-home'), findsNothing);
    expect(
      find.byKey(const ValueKey('workspace-join-code-field')),
      findsOneWidget,
    );
    // 壳状态未被回填
    expect(container.read(workspaceShellProvider).currentWorkspaceId, '9001');
  });

  testWidgets('982 码过期：joinExpiredCode 页内文案，不离开页面', (tester) async {
    final api = _JoinFakeApi()
      ..joinError = const WorkspaceApiException(982, 'invite_code expired');
    final container = _seededContainer(api);
    addTearDown(container.dispose);

    await _pump(tester, container: container);
    await _enterCode(tester, 'AB12CD34');

    expect(find.text('团队码已过期'), findsOneWidget);
    expect(find.text('probe-home'), findsNothing);
  });

  testWidgets('重新输入清除错误态（页内错误随输入消失）', (tester) async {
    final api = _JoinFakeApi()
      ..joinError = const WorkspaceApiException(981, 'invite_code invalid');
    final container = _seededContainer(api);
    addTearDown(container.dispose);

    await _pump(tester, container: container);
    await _enterCode(tester, 'AB12CD34');
    expect(find.text('团队码无效或已失效'), findsOneWidget);

    // 退格一位（触发 onChanged，非输满）→ 错误文案消失
    await tester.enterText(
      find.byKey(const ValueKey('workspace-join-code-field')),
      'AB12CD3',
    );
    await tester.pump();
    expect(find.text('团队码无效或已失效'), findsNothing);
  });

  group('WorkspaceApi invite_code / join envelope 解析（post 注入）', () {
    test('createInviteCode：{code, expires_at} 解析', () async {
      final api = _EnvelopeFakeApi(
        IMBoyHttpResponse.success(const {
          'code': 'AB12CD34',
          'expires_at': '2026-09-30 12:00:00',
        }),
      );
      final result = await api.createInviteCode('9001');
      expect(result.code, 'AB12CD34');
      expect(result.expiresAt, '2026-09-30 12:00:00');
      expect(result.isValid, isTrue);
    });

    test('joinByCode：{status, workspace} 解析（joined + workspace 字段）', () async {
      final api = _EnvelopeFakeApi(
        IMBoyHttpResponse.success(const {
          'status': 'joined',
          'workspace': {
            'id': 9005,
            'name': '官网改版',
            'logo': '',
            'owner_id': 1002,
            'status': 'active',
          },
        }),
      );
      final result = await api.joinByCode('AB12CD34');
      expect(result.status, 'joined');
      expect(result.isAlreadyMember, isFalse);
      // TSID integer → EntityId string
      expect(result.workspace.id, '9005');
      expect(result.workspace.name, '官网改版');
      expect(result.workspace.ownerId, '1002');
    });

    test('joinByCode：981 → isInviteInvalid / 982 → isInviteExpired', () async {
      final invalid = _EnvelopeFakeApi(
        IMBoyHttpResponse.failure(errMsg: '码无效', errCode: 981),
      );
      await expectLater(
        invalid.joinByCode('AAAAAAAA'),
        throwsA(
          isA<WorkspaceApiException>()
              .having((e) => e.isInviteInvalid, 'isInviteInvalid', isTrue)
              .having((e) => e.isInviteExpired, 'isInviteExpired', isFalse),
        ),
      );

      final expired = _EnvelopeFakeApi(
        IMBoyHttpResponse.failure(errMsg: '码过期', errCode: 982),
      );
      await expectLater(
        expired.joinByCode('AAAAAAAA'),
        throwsA(
          isA<WorkspaceApiException>()
              .having((e) => e.isInviteExpired, 'isInviteExpired', isTrue)
              .having((e) => e.isInviteInvalid, 'isInviteInvalid', isFalse),
        ),
      );
    });
  });
}
