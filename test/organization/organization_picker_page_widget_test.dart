/// GZAPP-04 G9/G11 — 企业选择器 focused widget 测试。
///
/// 覆盖（计划 §5.1 验收锚点）：
/// - 数据源必须是 Organization membership：mine 供料渲染组织行（而非
///   workspace 壳列表），底部『加入企业』入口常驻；
/// - 切换企业缓存隔离（G11）：切到乙企业后，上一企业（甲）的
///   members/departments 缓存被 OrganizationCache.invalidateOrg 丢弃、
///   CurrentOrganizationStore 指针指向新企业、workspace 壳重载
///   （loadMine）并按 default-workspace 指针落位；
/// - 企业邀请码错误态：981 → joinInvalidCode / 982 → joinExpiredCode
///   页内文案（GZAPP-J11 preview 阶段暴露，mock envelope 供料）；
/// - 单码 → preview「确认加入 XX 企业」confirm 态 → code-only join
///   （免 orgId；GZAPP-J11 收敛：不再输入企业 ID）；
/// - 企业邀请码加入成功（joined）：刷新列表并切入新企业（preview 提供
///   目标企业事实，不依赖 join 响应投影）。
library;

import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

import 'package:imboy/component/http/http_client.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/modules/organization/domain/organization_models.dart';
import 'package:imboy/modules/organization/infrastructure/current_organization_store.dart';
import 'package:imboy/modules/organization/infrastructure/organization_cache.dart';
import 'package:imboy/modules/organization/presentation/organization_picker_page.dart';
import 'package:imboy/page/workspace/workspace_data_providers.dart';
import 'package:imboy/page/chat_shell/experience_provider.dart';
import 'package:imboy/page/workspace_shell/workspace_shell_provider.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/store/api/workspace_api.dart';
import 'package:imboy/store/model/workspace_model.dart';

const String _accountKey = '91001';
const String _orgA = '7001';
const String _orgB = '7002';
const String _orgC = '7003';

class _FailedExperience extends ProductExperienceNotifier {
  @override
  ProductExperience build() => ProductExperience.workspace;
  @override
  Future<void> select(ProductExperience experience) async {
    throw StateError('synthetic preference failure');
  }
}

class _FailedPersonalExperience extends _FailedExperience {
  @override
  ProductExperience build() => ProductExperience.chat;
}

class _RecoverableExperience extends ProductExperienceNotifier {
  bool failed = false;
  @override
  ProductExperience build() => ProductExperience.chat;
  @override
  Future<void> select(ProductExperience experience) async {
    if (!failed) {
      failed = true;
      throw StateError('synthetic first preference failure');
    }
    await super.select(experience);
  }
}

class _RestoreFailureStore extends SharedPreferencesStorePlatform {
  _RestoreFailureStore(this.failure);
  final String failure;
  final values = <String, Object>{};
  int restores = 0;

  @override
  Future<bool> setValue(String type, String key, Object value) async {
    if (key.endsWith('$kCurrentOrgStoragePrefix$_accountKey') &&
        value is String &&
        values[key] is String) {
      final old = jsonDecode(values[key] as String) as Map<String, dynamic>;
      final next = jsonDecode(value) as Map<String, dynamic>;
      if (old['id'] == _orgB && next['id'] == _orgA) {
        restores++;
        if (failure == 'throw') throw StateError('synthetic restore failure');
        return false;
      }
    }
    values[key] = value;
    return true;
  }

  @override
  Future<Map<String, Object>> getAll() async => Map.of(values);
  @override
  Future<bool> remove(String key) async {
    values.remove(key);
    return true;
  }

  @override
  Future<bool> clear() async {
    values.clear();
    return true;
  }
}

/// 按 URI path 分发的静态 adapter（org mine / default-workspace /
/// invite_code/join 共用一个 HttpClient.adapterForTest 注入点）。
class _RoutingAdapter implements HttpClientAdapter {
  _RoutingAdapter(this.routes);

  final Map<String, dynamic> Function(String path) routes;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final body = routes(options.uri.path);
    return ResponseBody.fromString(
      jsonEncode(body),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Map<String, dynamic> _ok(dynamic payload) => {
  'code': 0,
  'msg': 'success',
  'payload': payload,
};

Map<String, dynamic> _orgPage(List<Map<String, dynamic>> list) => _ok({
  'list': list,
  'page': 1,
  'size': 10,
  'total': list.length,
  'total_page': 1,
});

Map<String, dynamic> _mineOf(List<String> ids) => _orgPage([
  for (final id in ids)
    {'id': int.parse(id), 'name': '组织$id', 'member_role': 'member'},
]);

/// WS API Fake：join/邀请链不触网；mine 可控 + 计数（断言壳重载）。
class _WsFakeApi extends WorkspaceApi {
  _WsFakeApi(this.workspaces);

  final List<WorkspaceModel> workspaces;
  int mineCalls = 0;

  @override
  Future<WorkspaceBranding> readBranding(EntityId workspaceId) async =>
      const WorkspaceBranding();

  @override
  Future<WorkspacePageResult<WorkspaceModel>> mine({
    int page = 1,
    int size = 20,
  }) async {
    mineCalls++;
    return WorkspacePageResult<WorkspaceModel>(
      list: workspaces,
      total: workspaces.length,
      totalPage: 1,
    );
  }
}

GoRouter _router({bool autoJoin = false}) => GoRouter(
  initialLocation: '/organization/picker',
  routes: [
    GoRoute(
      path: '/organization/picker',
      builder: (c, s) => autoJoin
          ? const OrganizationPickerPage(
              accountKey: _accountKey,
              autoJoin: true,
            )
          : const OrganizationPickerPage(accountKey: _accountKey),
    ),
    GoRoute(
      path: '/organization',
      builder: (c, s) => const Scaffold(body: Text('create-enterprise-page')),
    ),
    // _leave() 在无栈可弹时 go 到壳挂载点（真实行为同 join 页）。
    GoRoute(
      path: '/bottom_navigation',
      builder: (c, s) => const Scaffold(body: Center(child: Text('probe'))),
    ),
  ],
);

Future<void> _pump(
  WidgetTester tester,
  ProviderContainer container, {
  bool autoJoin = false,
}) async {
  tester.view.physicalSize = const Size(430, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    TranslationProvider(
      child: UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: _router(autoJoin: autoJoin)),
      ),
    ),
  );
}

/// 有界 pump 循环（dio 异步链 + setState 多轮 microtask 才收敛）。
Future<void> pumpUntilFound(WidgetTester tester, Finder finder) async {
  for (var i = 0; i < 30; i++) {
    await tester.pump(const Duration(milliseconds: 100));
    if (finder.evaluate().isNotEmpty) {
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));
      return;
    }
  }
}

void main() {
  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
          (call) async => null,
        );
    // 每用例干净 scope：上一用例残留的指针/缓存会让隔离断言失真。
    OrganizationCache.disposeAccount(_accountKey);
    CurrentOrganizationStore.disposeAccount(_accountKey);
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
          null,
        );
    HttpClient.adapterForTest = null;
    OrganizationCache.disposeAccount(_accountKey);
    CurrentOrganizationStore.disposeAccount(_accountKey);
  });

  ProviderContainer makeContainer(_WsFakeApi api) {
    final container = ProviderContainer(
      overrides: [workspaceApiProvider.overrideWith((ref) => api)],
    );
    addTearDown(container.dispose);
    return container;
  }

  testWidgets('数据源=Organization membership：mine 供料渲染组织行 + 加入企业入口', (
    tester,
  ) async {
    HttpClient.adapterForTest = _RoutingAdapter(
      (path) => path.endsWith('/organizations/mine')
          ? _mineOf([_orgA, _orgB])
          : _ok(null),
    );
    final api = _WsFakeApi(const []);
    await _pump(tester, makeContainer(api));

    await pumpUntilFound(
      tester,
      find.byKey(const ValueKey('org-picker-tile-$_orgA')),
    );

    // 数据源断言：渲染的是 Organization 行（非 workspace 壳列表——
    // 壳播种为空，若误读 workspace 列表则两个组织名都不会出现）。
    expect(find.text('组织$_orgA'), findsOneWidget);
    expect(find.text('组织$_orgB'), findsOneWidget);
    expect(find.byKey(const ValueKey('org-picker-join-entry')), findsOneWidget);
    expect(find.text('加入企业'), findsOneWidget);
    expect(find.text('创建企业'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('org-picker-create-entry')));
    await tester.pumpAndSettle();
    expect(find.text('create-enterprise-page'), findsOneWidget);
  });

  testWidgets('企业列表为空时仍可从空间选择器返回个人', (tester) async {
    HttpClient.adapterForTest = _RoutingAdapter((path) => _mineOf([]));
    final container = makeContainer(_WsFakeApi(const []));
    final store = CurrentOrganizationStore.forAccount(_accountKey);
    await store.set(const Organization(id: _orgA, name: '合成企业'));
    await container
        .read(productExperienceProvider.notifier)
        .select(ProductExperience.workspace);
    await _pump(tester, container);
    await tester.pump(const Duration(milliseconds: 200));
    final personal = find.byKey(const ValueKey('org-picker-personal-entry'));
    expect(personal, findsOneWidget);
    expect(find.byKey(const ValueKey('org-picker-join-entry')), findsOneWidget);
    await tester.tap(personal);
    await pumpUntilFound(tester, find.text('probe'));
    expect(container.read(productExperienceProvider), ProductExperience.chat);
    expect(find.text('probe'), findsOneWidget);
    expect(store.value?.id, _orgA);
    expect(tester.takeException(), isNull);
  });

  testWidgets('企业列表读取和个人偏好写入失败时保留当前空间并显示错误', (tester) async {
    HttpClient.adapterForTest = _RoutingAdapter(
      (path) => {'code': 403, 'msg': 'synthetic denial', 'payload': null},
    );
    final container = ProviderContainer(
      overrides: [
        workspaceApiProvider.overrideWithValue(_WsFakeApi(const [])),
        productExperienceProvider.overrideWith(_FailedExperience.new),
      ],
    );
    addTearDown(container.dispose);
    await _pump(tester, container);
    await tester.pump(const Duration(milliseconds: 200));
    final personal = find.byKey(const ValueKey('org-picker-personal-entry'));
    expect(personal, findsOneWidget);
    await tester.tap(personal);
    await tester.pump(const Duration(milliseconds: 200));
    expect(
      container.read(productExperienceProvider),
      ProductExperience.workspace,
    );
    expect(
      find.textContaining(t.common.settingFailedPleaseTryAgain),
      findsOneWidget,
    );
    expect(find.text('probe'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('切换企业（G11）：上一企业缓存失效 + 指针切换 + 壳重载 + 默认 WS 落位', (tester) async {
    // 预置：当前企业=甲（指针+缓存：members/departments 有料）；乙为切换目标。
    final cache = OrganizationCache.forAccount(_accountKey);
    cache
      ..saveOrgs([const Organization(id: _orgA, name: '组织$_orgA')])
      ..saveMembers(_orgA, [
        const OrganizationMember(organizationId: _orgA, userId: '42'),
      ])
      ..saveDepartments(_orgA, [
        const OrganizationDepartment(
          id: '81',
          organizationId: _orgA,
          name: '研发部',
        ),
      ]);
    CurrentOrganizationStore.forAccount(_accountKey)
        .set(const Organization(id: _orgA, name: '组织$_orgA'));

    HttpClient.adapterForTest = _RoutingAdapter((path) {
      if (path.endsWith('/organizations/mine')) return _mineOf([_orgA, _orgB]);
      // ENT-APP-04 两阶段切换 Phase 1：detail 预载目标企业最新投影。
      if (path.endsWith('/organizations/$_orgB')) {
        return _ok({
          'id': int.parse(_orgB),
          'name': '组织$_orgB',
          'member_role': 'member',
        });
      }
      if (path.endsWith('/organizations/$_orgB/default-workspace')) {
        return _ok({
          'organization_id': int.parse(_orgB),
          'default_workspace_id': 9002,
        });
      }
      return _ok(null);
    });
    final api = _WsFakeApi([
      const WorkspaceModel(
        id: '9001',
        name: 'WS甲',
        ownerId: '1',
        organizationId: _orgA,
      ),
      const WorkspaceModel(
        id: '9002',
        name: 'WS乙',
        ownerId: '1',
        organizationId: _orgB,
      ),
    ]);
    final container = makeContainer(api);
    // 初始 currentWorkspaceId 由首次 loadMine 自动选 9001（列表第一项）。
    await _pump(tester, container);
    await pumpUntilFound(
      tester,
      find.byKey(const ValueKey('org-picker-tile-$_orgB')),
    );

    await tester.tap(find.byKey(const ValueKey('org-picker-tile-$_orgB')));
    await tester.pumpAndSettle();

    // G11 隔离断言：上一企业（甲）缓存条目被丢弃，乙不串见甲的成员/部门。
    expect(cache.members(_orgA), isEmpty);
    expect(cache.departments(_orgA), isEmpty);
    // 指针切换到乙（持久化语义由 store 单元保证）。
    expect(CurrentOrganizationStore.forAccount(_accountKey).value?.id, _orgB);
    // WS 壳重载（loadMine 至少一次）+ 按 default-workspace 落位 9002。
    expect(api.mineCalls, greaterThanOrEqualTo(1));
    expect(container.read(workspaceShellProvider).currentWorkspaceId, '9002');
    expect(
      container.read(productExperienceProvider),
      ProductExperience.workspace,
    );
  });

  for (final mode in [
    'same',
    'preference-failure',
    'default-failure',
    'restore-false',
    'restore-throw',
  ]) {
    testWidgets('个人选择企业 $mode：首页和企业工作区一致', (tester) async {
      final restoreFailure = mode.startsWith('restore-');
      final native = restoreFailure
          ? _RestoreFailureStore(mode.substring('restore-'.length))
          : null;
      if (native != null) {
        SharedPreferencesStorePlatform.instance = native;
        await StorageService.init();
      }
      final store = CurrentOrganizationStore.forAccount(_accountKey);
      await store.set(const Organization(id: _orgA, name: 'synthetic old'));
      final target = mode == 'same' ? _orgA : _orgB;
      final calls = <String>[];
      HttpClient.adapterForTest = _RoutingAdapter((path) {
        calls.add(path);
        if (path.endsWith('/organizations/mine')) {
          return _mineOf([_orgA, _orgB]);
        }
        if (path.endsWith('/default-workspace')) {
          if (mode == 'default-failure') {
            return {
              'code': 503,
              'msg': 'synthetic unavailable',
              'payload': null,
            };
          }
          return _ok({
            'organization_id': int.parse(target),
            'default_workspace_id': target == _orgA ? 9001 : 9002,
          });
        }
        if (path.endsWith('/organizations/$target')) {
          return _ok({'id': int.parse(target), 'name': 'synthetic target'});
        }
        return _ok(null);
      });
      final api = _WsFakeApi([
        const WorkspaceModel(
          id: '9001',
          name: 'old',
          ownerId: '1',
          organizationId: _orgA,
        ),
        const WorkspaceModel(
          id: '9002',
          name: 'new',
          ownerId: '1',
          organizationId: _orgB,
        ),
      ]);
      final container = ProviderContainer(
        overrides: [
          workspaceApiProvider.overrideWithValue(api),
          if (mode == 'preference-failure' || restoreFailure)
            productExperienceProvider.overrideWith(
              restoreFailure
                  ? _RecoverableExperience.new
                  : _FailedPersonalExperience.new,
            ),
        ],
      );
      addTearDown(container.dispose);
      final shell = container.read(workspaceShellProvider.notifier);
      await shell.loadMine();
      await shell.selectOrganization(_orgA, () async => '9001');
      await _pump(tester, container);
      final tile = find.byKey(ValueKey('org-picker-tile-$target'));
      await pumpUntilFound(tester, tile);
      await tester.tap(tile);
      await tester.pumpAndSettle();
      expect(
        calls.any((path) => path.endsWith('/organizations/$target')),
        isTrue,
      );
      final failed = mode == 'preference-failure' || restoreFailure;
      final restoredOld = failed && !restoreFailure;
      expect(store.value?.id, restoredOld ? _orgA : target);
      expect(
        container.read(workspaceShellProvider).organizationId,
        restoredOld ? _orgA : target,
      );
      expect(
        container.read(workspaceShellProvider).currentWorkspaceId,
        restoredOld || target == _orgA ? '9001' : '9002',
      );
      expect(
        container.read(productExperienceProvider),
        failed ? ProductExperience.chat : ProductExperience.workspace,
      );
      expect(
        find.byKey(const ValueKey('org-picker-switch-error')),
        failed ? findsOneWidget : findsNothing,
      );
      expect(tester.takeException(), isNull);
      if (native != null) {
        expect(native.restores, 1);
        expect(
          jsonDecode(
            StorageService.to.getString(
              '$kCurrentOrgStoragePrefix$_accountKey',
            ),
          )['id'],
          _orgB,
        );
        await tester.tap(tile);
        await tester.pumpAndSettle();
        expect(store.value?.id, _orgB);
        expect(container.read(workspaceShellProvider).organizationId, _orgB);
        expect(
          container.read(workspaceShellProvider).currentWorkspaceId,
          '9002',
        );
        expect(
          container.read(productExperienceProvider),
          ProductExperience.workspace,
        );
        expect(
          find.byKey(const ValueKey('org-picker-switch-error')),
          findsNothing,
        );
        expect(find.text('probe'), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
    });
  }

  testWidgets('两阶段切换 Phase 1 预载失败（detail 403）：指针/缓存不动 + 页内错误态可重试', (
    tester,
  ) async {
    // 预置：当前企业=甲（指针+缓存有料）。
    final cache = OrganizationCache.forAccount(_accountKey);
    cache
      ..saveOrgs([const Organization(id: _orgA, name: '组织$_orgA')])
      ..saveMembers(_orgA, [
        const OrganizationMember(organizationId: _orgA, userId: '42'),
      ]);
    CurrentOrganizationStore.forAccount(_accountKey)
        .set(const Organization(id: _orgA, name: '组织$_orgA'));

    HttpClient.adapterForTest = _RoutingAdapter((path) {
      if (path.endsWith('/organizations/mine')) return _mineOf([_orgA, _orgB]);
      // Phase 1 预载目标企业：membership 已失效（被移出）→ 403。
      if (path.endsWith('/organizations/$_orgB')) {
        return {'code': 403, 'msg': 'insufficient scope'};
      }
      return _ok(null);
    });
    await _pump(tester, makeContainer(_WsFakeApi(const [])));
    await pumpUntilFound(
      tester,
      find.byKey(const ValueKey('org-picker-tile-$_orgB')),
    );

    await tester.tap(find.byKey(const ValueKey('org-picker-tile-$_orgB')));
    await pumpUntilFound(
      tester,
      find.byKey(const ValueKey('org-picker-switch-error')),
    );

    // Phase 1 失败 = 完整 rollback：指针仍指甲、甲缓存原样（members 未被
    // 失效）、错误态页内可见（不弹走不假成功）、列表保留可再点重试。
    expect(
      CurrentOrganizationStore.forAccount(_accountKey).value?.id,
      _orgA,
      reason: '预载失败不得移动当前企业指针',
    );
    expect(cache.members(_orgA), isNotEmpty, reason: '甲缓存不被失效');
    expect(
      find.byKey(const ValueKey('org-picker-switch-error')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('org-picker-tile-$_orgA')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('org-picker-tile-$_orgB')),
      findsOneWidget,
    );
  });

  testWidgets('两阶段切换 Phase 1 失败后可重试：同一页面再次点击完成切换', (tester) async {
    final cache = OrganizationCache.forAccount(_accountKey);
    cache.saveOrgs([const Organization(id: _orgA, name: '组织$_orgA')]);
    CurrentOrganizationStore.forAccount(_accountKey)
        .set(const Organization(id: _orgA, name: '组织$_orgA'));

    // 第一次 detail 网络错误（500），重试时恢复 200。
    var detailOk = false;
    HttpClient.adapterForTest = _RoutingAdapter((path) {
      if (path.endsWith('/organizations/mine')) return _mineOf([_orgA, _orgB]);
      if (path.endsWith('/organizations/$_orgB')) {
        return detailOk
            ? _ok({
                'id': int.parse(_orgB),
                'name': '组织$_orgB',
                'member_role': 'member',
              })
            : {'code': 500, 'msg': 'boom'};
      }
      return _ok(null);
    });
    await _pump(tester, makeContainer(_WsFakeApi(const [])));
    await pumpUntilFound(
      tester,
      find.byKey(const ValueKey('org-picker-tile-$_orgB')),
    );

    await tester.tap(find.byKey(const ValueKey('org-picker-tile-$_orgB')));
    await pumpUntilFound(
      tester,
      find.byKey(const ValueKey('org-picker-switch-error')),
    );
    expect(CurrentOrganizationStore.forAccount(_accountKey).value?.id, _orgA);

    // 错误态可重试：服务端恢复后再点目标行 → 切换成功。
    detailOk = true;
    await tester.tap(find.byKey(const ValueKey('org-picker-tile-$_orgB')));
    await tester.pumpAndSettle();
    expect(
      CurrentOrganizationStore.forAccount(_accountKey).value?.id,
      _orgB,
      reason: '重试后完成两阶段切换',
    );
  });

  testWidgets('加入企业 981：preview 阶段码无效文案页内展示，不关对话框', (tester) async {
    HttpClient.adapterForTest = _RoutingAdapter((path) {
      if (path.endsWith('/organizations/mine')) return _mineOf([_orgA]);
      if (path.endsWith('/invite_code/preview')) {
        return {'code': 981, 'msg': 'invite_code invalid'};
      }
      return _ok(null);
    });
    await _pump(tester, makeContainer(_WsFakeApi(const [])));
    await pumpUntilFound(
      tester,
      find.byKey(const ValueKey('org-picker-join-entry')),
    );

    await tester.tap(find.byKey(const ValueKey('org-picker-join-entry')));
    await tester.pumpAndSettle();
    // GZAPP-J11：单码输入（无企业 ID 字段）。
    expect(find.byKey(const ValueKey('org-join-orgid-field')), findsNothing);
    await tester.enterText(
      find.byKey(const ValueKey('org-join-code-field')),
      'ABCD2345',
    );
    await tester.tap(find.byKey(const ValueKey('org-join-submit')));
    await pumpUntilFound(tester, find.byKey(const ValueKey('org-join-error')));

    expect(find.text('企业邀请码无效或已失效'), findsOneWidget);
    // 失败停留：输入框仍在（未提交成功关层）。
    expect(find.byKey(const ValueKey('org-join-code-field')), findsOneWidget);
  });

  testWidgets('加入企业 982：preview 阶段码过期文案页内展示', (tester) async {
    HttpClient.adapterForTest = _RoutingAdapter((path) {
      if (path.endsWith('/organizations/mine')) return _mineOf([_orgA]);
      if (path.endsWith('/invite_code/preview')) {
        return {'code': 982, 'msg': 'invite_code expired'};
      }
      return _ok(null);
    });
    await _pump(tester, makeContainer(_WsFakeApi(const [])));
    await pumpUntilFound(
      tester,
      find.byKey(const ValueKey('org-picker-join-entry')),
    );

    await tester.tap(find.byKey(const ValueKey('org-picker-join-entry')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('org-join-code-field')),
      'ABCD2345',
    );
    await tester.tap(find.byKey(const ValueKey('org-join-submit')));
    await pumpUntilFound(tester, find.byKey(const ValueKey('org-join-error')));

    expect(find.text('企业邀请码已过期'), findsOneWidget);
  });

  testWidgets('加入企业成功（joined）：preview 确认 → code-only join → 切入新企业', (
    tester,
  ) async {
    HttpClient.adapterForTest = _RoutingAdapter((path) {
      if (path.endsWith('/organizations/mine')) {
        return _mineOf([_orgA, _orgC]);
      }
      if (path.endsWith('/invite_code/preview')) {
        return _ok({'organization_id': int.parse(_orgC), 'name': '组织$_orgC'});
      }
      if (path.endsWith('/invite_code/join')) {
        return _ok({
          'status': 'joined',
          'join': {'organization_id': int.parse(_orgC)},
        });
      }
      // 两阶段切换 Phase 1：detail 预载丙企业投影。
      if (path.endsWith('/organizations/$_orgC')) {
        return _ok({
          'id': int.parse(_orgC),
          'name': '组织$_orgC',
          'member_role': 'member',
        });
      }
      if (path.endsWith('/organizations/$_orgC/default-workspace')) {
        return _ok({
          'organization_id': int.parse(_orgC),
          'default_workspace_id': 9001,
        });
      }
      return _ok(null);
    });
    await _pump(tester, makeContainer(_WsFakeApi(const [])));
    await pumpUntilFound(
      tester,
      find.byKey(const ValueKey('org-picker-join-entry')),
    );

    await tester.tap(find.byKey(const ValueKey('org-picker-join-entry')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('org-join-code-field')),
      'abcd2345',
    );
    await tester.tap(find.byKey(const ValueKey('org-join-submit')));
    // preview 成功 → confirm 态：显示目标企业名 + 加入身份（preview mock
    // 未带 role，模型兜底 member → 「普通成员」；小写输入自动大写归一）。
    await pumpUntilFound(
      tester,
      find.byKey(const ValueKey('org-join-org-name')),
    );
    expect(find.text('确认以 普通成员 身份加入「组织$_orgC」？'), findsOneWidget);

    // confirm 态再点提交 = code-only join（免 orgId）。
    await tester.tap(find.byKey(const ValueKey('org-join-submit')));
    await tester.pump(const Duration(milliseconds: 300));

    // 加入成功 → _refresh 后列表含丙 → 自动切入（指针指向丙）。
    expect(CurrentOrganizationStore.forAccount(_accountKey).value?.id, _orgC);
  });

  testWidgets('§5.1 加入企业入口：autoJoin=1 进入即打开邀请码对话框（一步到达）', (tester) async {
    HttpClient.adapterForTest = _RoutingAdapter(
      (path) =>
          path.endsWith('/organizations/mine') ? _mineOf([_orgA]) : _ok(null),
    );
    final container = makeContainer(_WsFakeApi(const []));

    await _pump(tester, container, autoJoin: true);
    // 首帧后 addPostFrameCallback 弹层 → 固定帧推进即可见
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byKey(const ValueKey('org-join-code-field')), findsOneWidget);
    expect(find.byKey(const ValueKey('org-join-submit')), findsOneWidget);
  });

  testWidgets('缺省（autoJoin 关闭）不自动弹层：仍落在选择器列表', (tester) async {
    HttpClient.adapterForTest = _RoutingAdapter(
      (path) =>
          path.endsWith('/organizations/mine') ? _mineOf([_orgA]) : _ok(null),
    );
    final container = makeContainer(_WsFakeApi(const []));

    await _pump(tester, container);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byKey(const ValueKey('org-join-code-field')), findsNothing);
    expect(find.byKey(const ValueKey('org-picker-join-entry')), findsOneWidget);
  });
}
