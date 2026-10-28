/// W05（channel-group-ux-v2.2 F10/J14）工作区群目录与建群入口测试。
///
/// 离线合成：假 WorkspaceApi 经 workspaceApiProvider 覆盖注入；键less
/// 回退载荷经 HttpClient.adapterForTest 捕获。零真实网络、零真实用户、
/// 零外发。覆盖：
/// - 目录渲染与客户端搜索（关键词保留，J14.b）；
/// - 准确空态 + 创建 CTA（J14.a：合法下一步，不越权补资源）；
/// - 搜索无结果空态（不显示创建 CTA）；
/// - 建群选人页：真实工作区成员 API 加载、错误重试、选择计数、搜索过滤；
/// - 能力关闭时的键less workspace 建群回退载荷（member_uids/scope/
///   workspace_id，不带 request_id；成员集语义不变）。
library;

import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart' show CupertinoSearchTextField;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:go_router/go_router.dart';

import 'package:imboy/component/http/http_client.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/workspace/workspace_data_providers.dart';
import 'package:imboy/page/workspace/workspace_group_create_page.dart';
import 'package:imboy/page/workspace/workspace_groups_page.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/store/api/workspace_api.dart';
import 'package:imboy/store/model/group_model.dart';
import 'package:imboy/store/model/user_model.dart';
import 'package:imboy/store/model/workspace_model.dart';
import 'package:imboy/store/repository/user_repo_provider.dart';

class _Account extends Notifier<UserModel?> {
  @override
  UserModel? build() => UserModel.fromJson({'uid': '91001'});
}

final _account = NotifierProvider<_Account, UserModel?>(_Account.new);

class _Api extends WorkspaceApi {
  _Api({this.groupRows = const [], this.memberList, this.membersException});

  final List<GroupModel> groupRows;
  final List<WorkspaceMemberModel>? memberList;
  final Object? membersException;
  int memberCalls = 0;

  @override
  Future<List<GroupModel>> memberGroups(EntityId workspaceId) async =>
      groupRows;

  @override
  Future<WorkspacePageResult<WorkspaceMemberModel>> members(
    EntityId workspaceId, {
    int page = 1,
    int size = 20,
  }) async {
    memberCalls++;
    final ex = membersException;
    if (ex != null) throw ex;
    final list = memberList ?? const <WorkspaceMemberModel>[];
    return WorkspacePageResult(list: list, total: list.length);
  }
}

GroupModel _group(int id, String title) =>
    GroupModel.fromJson({'id': id, 'title': title});

WorkspaceMemberModel _member(String uid, String nickname) =>
    WorkspaceMemberModel.fromJson({
      'workspace_id': '100',
      'user_id': uid,
      'nickname': nickname,
      'account': 'acct-$uid',
      'role': 'member',
    });

Future<void> _pumpDirectory(
  WidgetTester tester,
  ProviderContainer container,
) async {
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) =>
            Scaffold(body: const WorkspaceGroupsPage(workspaceId: '100')),
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
}

Future<void> _pumpCreatePage(
  WidgetTester tester,
  ProviderContainer container,
) async {
  await tester.pumpWidget(
    TranslationProvider(
      child: UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          // 页面创建流程使用 AppLoading（EasyLoading），测试宿主需挂其
          // builder 才不会在 show 时抛 Bad state（rtc_room_test 同款）。
          builder: EasyLoading.init(),
          home: const WorkspaceGroupCreatePage(workspaceId: '100'),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
}

void main() {
  setUp(() {
    // 安全存储通道 mock 为「无数据」：避免 token_decryption_failed 标记
    // 把请求拦在 _setDefaultConfig（W04.d.g 套件同款防护）。
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
          (call) async => null,
        );
    StorageService.to.setBool('token_decryption_failed', false);
  });

  tearDown(() {
    HttpClient.adapterForTest = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
          null,
        );
  });

  testWidgets('目录渲染已加入群；搜索过滤且关键词保留（J14.b）', (tester) async {
    final api = _Api(groupRows: [_group(1, '产品群'), _group(2, '研发群')]);
    final container = ProviderContainer(
      overrides: [
        workspaceApiProvider.overrideWithValue(api),
        currentUserProvider.overrideWith((ref) => ref.watch(_account)),
      ],
    );
    addTearDown(container.dispose);
    await _pumpDirectory(tester, container);

    expect(find.text('产品群'), findsOneWidget);
    expect(find.text('研发群'), findsOneWidget);

    await tester.enterText(find.byType(CupertinoSearchTextField), '产品');
    await tester.pump();
    expect(find.text('产品群'), findsOneWidget);
    expect(find.text('研发群'), findsNothing);
    // 关键词保留在输入框（J14.b：搜索无结果/刷新期间关键词不清）。
    expect(
      tester
          .widget<CupertinoSearchTextField>(
            find.byType(CupertinoSearchTextField),
          )
          .controller!
          .text,
      '产品',
    );

    await tester.enterText(find.byType(CupertinoSearchTextField), '不存在');
    await tester.pump();
    expect(find.text(t.common.searchNoResults), findsOneWidget);
    // 搜索无结果不显示创建 CTA（避免在「查无此群」语境诱导建群）。
    expect(find.text(t.organization.manage.createGroup), findsNothing);
  });

  testWidgets('空目录给准确空态与创建 CTA（J14.a），不越权补资源', (tester) async {
    final api = _Api(groupRows: const []);
    final container = ProviderContainer(
      overrides: [
        workspaceApiProvider.overrideWithValue(api),
        currentUserProvider.overrideWith((ref) => ref.watch(_account)),
      ],
    );
    addTearDown(container.dispose);
    await _pumpDirectory(tester, container);

    expect(find.text(t.workspace.groupsEmptyTitle), findsOneWidget);
    expect(find.text(t.workspace.groupsEmptySubtitle), findsOneWidget);
    // 创建 CTA 是合法下一步；只导航到选人页，不自动建任何资源。
    expect(find.text(t.organization.manage.createGroup), findsOneWidget);
  });

  testWidgets('建群页：成员来自真实工作区成员 API，可搜索、选择计数', (tester) async {
    final api = _Api(
      memberList: [_member('880014', '张三'), _member('880015', '李四')],
    );
    final container = ProviderContainer(
      overrides: [
        workspaceApiProvider.overrideWithValue(api),
        currentUserProvider.overrideWith((ref) => ref.watch(_account)),
      ],
    );
    addTearDown(container.dispose);
    await _pumpCreatePage(tester, container);

    expect(api.memberCalls, 1);
    expect(find.text('张三'), findsOneWidget);
    expect(find.text('李四'), findsOneWidget);

    // 未选时按钮无计数；选一人后计数含创建者自身 (+1)。
    await tester.tap(find.text('张三'));
    await tester.pump();
    expect(
      find.textContaining('${t.organization.manage.createGroup}(2)'),
      findsOneWidget,
    );

    // 成员搜索过滤。
    await tester.enterText(find.byType(CupertinoSearchTextField), '李四');
    await tester.pump();
    // 搜索词本身也会出现在输入框里，故断言「成员行消失」而非成员行存在。
    expect(find.text('张三'), findsNothing);
    expect(find.textContaining('李四'), findsWidgets);
  });

  testWidgets('建群页：成员加载失败 ≠ 空成员，提供重试', (tester) async {
    final api = _Api(
      membersException: DioException(
        requestOptions: RequestOptions(path: '/x'),
      ),
    );
    final container = ProviderContainer(
      overrides: [
        workspaceApiProvider.overrideWithValue(api),
        currentUserProvider.overrideWith((ref) => ref.watch(_account)),
      ],
    );
    addTearDown(container.dispose);
    await _pumpCreatePage(tester, container);

    expect(find.text(t.common.errorNetwork), findsOneWidget);
    expect(find.text(t.common.buttonRetry), findsOneWidget);
    expect(api.memberCalls, 1);
  });

  testWidgets('能力关闭：建群走键less workspace 回退，载荷不含合同键', (tester) async {
    // 不设 currentUid：保持未登录态（isLoggedIn=false），请求路径才不会
    // 被「已登录但 token 为空 → _handleTokenExpired 登出分支」拦截；
    // 与合同套件同口径。account 传空串即可（能力关闭不建意图）。
    final bodies = <Map<String, dynamic>>[];
    HttpClient.adapterForTest = _CaptureAdapter(bodies);
    final api = _Api(memberList: [_member('880014', '张三')]);
    final container = ProviderContainer(
      overrides: [
        workspaceApiProvider.overrideWithValue(api),
        currentUserProvider.overrideWith((ref) => ref.watch(_account)),
      ],
    );
    addTearDown(container.dispose);
    await _pumpCreatePage(tester, container);

    await tester.tap(find.text('张三'));
    await tester.pump();
    await tester.tap(
      find.textContaining('${t.organization.manage.createGroup}(2)'),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(bodies, hasLength(1));
    expect(bodies.single['member_uids'], ['880014']);
    expect(bodies.single['scope'], 'workspace');
    expect(bodies.single['workspace_id'], '100');
    // 能力关闭：不带任何合同键（键less 回退语义零变化）。
    expect(bodies.single.containsKey('request_id'), isFalse);
    expect(bodies.single.containsKey('recover_only'), isFalse);
  });
}

/// 捕获请求体并以键less 建群成功 envelope 回应。
class _CaptureAdapter implements HttpClientAdapter {
  _CaptureAdapter(this.bodies);

  final List<Map<String, dynamic>> bodies;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    bodies.add(Map<String, dynamic>.from(options.data as Map));
    return ResponseBody.fromString(
      jsonEncode({
        'code': 0,
        'msg': 'success',
        'payload': {
          'group': {'id': 990300},
          'member_list': <Map<String, dynamic>>[],
        },
      }),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
