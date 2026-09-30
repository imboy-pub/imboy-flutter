import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:imboy/modules/organization/domain/organization_models.dart';
import 'package:imboy/modules/organization/infrastructure/current_organization_store.dart';
import 'package:imboy/modules/organization/infrastructure/organization_cache.dart';
import 'package:imboy/modules/organization/presentation/organization_detail_page.dart';
import 'package:imboy/page/workspace_shell/workspace_shell_provider.dart';
import 'package:imboy/store/model/workspace_model.dart';
import 'package:imboy/store/repository/user_repo_provider.dart';

import '../ux_matrix/ux_harness.dart';

const _org = Organization(id: '7001', name: '企业甲', memberRole: 'member');
const _account = '1001';

class _LeaveAdapter extends RouteStubAdapter {
  _LeaveAdapter({String role = 'member', int code = 0})
    : super([
        (
          '/offboard',
          [
            (
              200,
              {
                'code': code,
                'msg': code == 0 ? 'ok' : '请先移交频道',
                'payload': {
                  'organization_id': 7001,
                  'user_id': 1001,
                  'status': 'removed',
                },
              },
            ),
          ],
        ),
        (
          '/default-workspace',
          [(200, uxEnvelope(payload: <String, dynamic>{}))],
        ),
        (
          '/organizations/7001',
          [
            (
              200,
              uxEnvelope(
                payload: {
                  'id': 7001,
                  'name': '企业甲',
                  'member_role': role,
                  'status': 'active',
                },
              ),
            ),
          ],
        ),
      ]);
  final List<RequestOptions> writes = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? stream,
    Future<void>? cancel,
  ) {
    if (options.uri.path.endsWith('/offboard')) writes.add(options);
    return super.fetch(options, stream, cancel);
  }
}

void main() {
  late ProviderContainer container;
  setUp(() async {
    await initUxHarness();
    container = ProviderContainer(
      overrides: [currentUserProvider.overrideWithValue(null)],
    );
    await CurrentOrganizationStore.forAccount(_account).set(_org);
    OrganizationCache.forAccount(_account).saveOrgs([_org]);
    container
        .read(workspaceShellProvider.notifier)
        .applyJoined(
          const WorkspaceModel(
            id: '20',
            name: '总部',
            ownerId: '1',
            organizationId: '7001',
          ),
        );
  });
  tearDown(() {
    container.dispose();
    CurrentOrganizationStore.disposeAccount(_account);
    OrganizationCache.disposeAccount(_account);
    teardownUxHarness();
  });

  Future<void> mount(WidgetTester tester, _LeaveAdapter adapter) async {
    tester.view.physicalSize = const Size(800, 6000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    uxInstallStub(adapter);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          routerConfig: GoRouter(
            initialLocation: '/organization/7001',
            routes: [
              GoRoute(
                path: '/organization',
                builder: (_, _) => const Scaffold(body: Text('企业列表')),
                routes: [
                  GoRoute(
                    path: ':id',
                    builder: (_, _) => const OrganizationDetailPage(
                      orgId: '7001',
                      accountKey: _account,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    await pumpUntilUxFound(
      tester,
      find.byKey(const ValueKey('organization-detail-leave')),
    );
    await settleUx(tester);
  }

  Future<void> confirm(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('organization-detail-leave')));
    await settleUx(tester);
    await tester.tap(find.widgetWithText(TextButton, '退出企业'));
    await settleUx(tester);
  }

  testWidgets('取消不请求接口、不清理空间', (tester) async {
    final adapter = _LeaveAdapter();
    await mount(tester, adapter);
    await tester.tap(find.byKey(const ValueKey('organization-detail-leave')));
    await settleUx(tester);
    await tester.tap(find.text('取消'));
    await settleUx(tester);
    expect(adapter.writes, isEmpty);
    expect(CurrentOrganizationStore.forAccount(_account).value?.id, '7001');
  });

  testWidgets('交接拒绝保留指针、工作区和页面', (tester) async {
    final adapter = _LeaveAdapter(code: 409);
    await mount(tester, adapter);
    await confirm(tester);
    expect(adapter.writes.single.method, 'POST');
    expect(
      adapter.writes.single.uri.path,
      '/api/v1/organizations/7001/members/1001/offboard',
    );
    expect(find.textContaining('请先移交频道'), findsOneWidget);
    expect(CurrentOrganizationStore.forAccount(_account).value?.id, '7001');
    expect(container.read(workspaceShellProvider).workspaces.single.id, '20');
  });

  testWidgets('成功退出清理本企业后返回企业列表', (tester) async {
    final adapter = _LeaveAdapter();
    await mount(tester, adapter);
    await confirm(tester);
    expect(adapter.writes, hasLength(1));
    expect(find.text('企业列表'), findsOneWidget);
    expect(CurrentOrganizationStore.forAccount(_account).value, isNull);
    expect(OrganizationCache.forAccount(_account).org('7001'), isNull);
    expect(container.read(workspaceShellProvider).workspaces, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('负责人显示交接提示、不调用退出接口', (tester) async {
    final adapter = _LeaveAdapter(role: 'owner');
    await mount(tester, adapter);
    expect(find.text('请先移交企业负责人，再退出企业'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('organization-detail-leave')));
    await settleUx(tester);
    expect(adapter.writes, isEmpty);
    expect(find.byType(AlertDialog), findsNothing);
  });
}
