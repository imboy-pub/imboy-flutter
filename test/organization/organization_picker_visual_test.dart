import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:imboy/component/http/http_client.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/modules/organization/domain/organization_models.dart';
import 'package:imboy/modules/organization/infrastructure/current_organization_store.dart';
import 'package:imboy/modules/organization/infrastructure/organization_cache.dart';
import 'package:imboy/modules/organization/presentation/organization_picker_page.dart';
import 'package:imboy/page/chat_shell/experience_provider.dart';
import 'package:imboy/page/workspace/workspace_data_providers.dart';
import 'package:imboy/page/workspace_shell/workspace_shell_provider.dart';
import 'package:imboy/store/api/workspace_api.dart';
import 'package:imboy/store/model/user_model.dart';
import 'package:imboy/store/model/workspace_model.dart';
import 'package:imboy/store/repository/user_repo_provider.dart';

import '../ux_matrix/ux_harness.dart';
import 'organization_picker_page_widget_test.dart' as fixture;

const _account = '91001';
const _historical = bool.fromEnvironment('UX_T07_HISTORICAL');

class _Experience extends ProductExperienceNotifier {
  _Experience(this.initial, this.fail);
  final ProductExperience initial;
  final bool fail;
  final selections = <ProductExperience>[];

  @override
  ProductExperience build() => initial;

  @override
  Future<void> select(ProductExperience experience) async {
    selections.add(experience);
    if (fail) {
      throw StateError('synthetic preference failure');
    }
    await super.select(experience);
  }
}

class _WorkspaceApi extends WorkspaceApi {
  int mineCalls = 0;
  int brandingCalls = 0;

  @override
  Future<WorkspacePageResult<WorkspaceModel>> mine({
    int page = 1,
    int size = 20,
  }) async {
    expect((page, size), (1, 100));
    mineCalls++;
    return const WorkspacePageResult(list: [], total: 0, totalPage: 1);
  }

  @override
  Future<WorkspaceBranding> readBranding(EntityId workspaceId) async {
    brandingCalls++;
    return const WorkspaceBranding();
  }
}

class _PickerAdapter implements HttpClientAdapter {
  _PickerAdapter(this.scenario);
  final String scenario;
  final detail = Completer<ResponseBody>();
  final requests = <String>[];
  final unexpected = <String>[];

  ResponseBody response(Object body) => ResponseBody.fromString(
    jsonEncode(body),
    200,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final path = options.uri.path;
    requests.add('${options.method} $path');
    if (options.method == 'GET' && path == '/api/v1/organizations/mine') {
      expect(options.queryParameters, {'page': 1, 'size': 100});
      return response(
        uxPage([
          {'id': 7001, 'name': '组织7001', 'member_role': 'owner'},
          {'id': 7002, 'name': '组织7002', 'member_role': 'member'},
        ]),
      );
    }
    if (options.method == 'GET' && path == '/api/v1/organizations/7002') {
      if (scenario == 'busy') {
        return detail.future;
      }
      return response(
        scenario == 'forbidden'
            ? {'code': 403, 'msg': 'insufficient scope'}
            : uxEnvelope(payload: {'id': 7002, 'name': '组织7002'}),
      );
    }
    if (options.method == 'GET' &&
        path == '/api/v1/organizations/7002/default-workspace') {
      return response(
        uxEnvelope(
          payload: {'organization_id': 7002, 'default_workspace_id': 9002},
        ),
      );
    }
    unexpected.add('${options.method} $path');
    throw StateError('Unexpected offline fixture request: $path');
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  setUp(() async {
    await initUxHarness();
    LocaleSettings.setLocale(AppLocale.zhCn);
    OrganizationCache.disposeAccount(_account);
    CurrentOrganizationStore.disposeAccount(_account);
    await CurrentOrganizationStore.forAccount(_account)
        .set(const Organization(id: '7001', name: '组织7001'));
  });
  tearDown(() {
    teardownUxHarness();
    OrganizationCache.disposeAccount(_account);
    CurrentOrganizationStore.disposeAccount(_account);
  });

  for (final (label, combo) in [
    ('360_1_light', UxCombo(const Size(360, 800))),
    (
      '360_2_dark',
      UxCombo(const Size(360, 800), textScale: 2, brightness: Brightness.dark),
    ),
    (
      '1280_1_dark',
      UxCombo(const Size(1280, 900), brightness: Brightness.dark),
    ),
    ('1280_2_light', UxCombo(const Size(1280, 900), textScale: 2)),
  ]) {
    for (final scenario in [
      'personal',
      'workspace',
      'busy',
      'forbidden',
      'recovered',
    ]) {
      testWidgets('golden: T07 $scenario $label', (tester) async {
        final adapter = _PickerAdapter(scenario);
        HttpClient.adapterForTest = adapter;
        final workspaceApi = _WorkspaceApi();
        final experience = _Experience(
          scenario == 'workspace'
              ? ProductExperience.workspace
              : ProductExperience.personal,
          scenario == 'recovered',
        );
        final container = ProviderContainer(
          overrides: [
            currentUserProvider.overrideWithValue(
              UserModel(uid: _account, account: 'synthetic'),
            ),
            workspaceApiProvider.overrideWith((ref) => workspaceApi),
            productExperienceProvider.overrideWith(() => experience),
          ],
        );
        addTearDown(container.dispose);
        final router = GoRouter(
          initialLocation: '/picker',
          routes: [
            GoRoute(
              path: '/picker',
              builder: (context, state) =>
                  const OrganizationPickerPage(accountKey: _account),
            ),
          ],
        );
        addTearDown(router.dispose);
        tester.view.physicalSize = combo.viewport;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final beforeShell = container.read(workspaceShellProvider);
        try {
          await tester.pumpWidget(
            TranslationProvider(
              child: UncontrolledProviderScope(
                container: container,
                child: MaterialApp.router(
                  routerConfig: router,
                  theme: ThemeData(brightness: combo.brightness),
                  builder: (context, child) => MediaQuery(
                    data: MediaQuery.of(
                      context,
                    ).copyWith(textScaler: TextScaler.linear(combo.textScale)),
                    child: child!,
                  ),
                ),
              ),
            ),
          );
          final target = find.byKey(const ValueKey('org-picker-tile-7002'));
          final personal = find.byKey(
            const ValueKey('org-picker-personal-entry'),
          );
          await fixture.pumpUntilFound(tester, target);
          expect(target, findsOneWidget);
          if (['busy', 'forbidden', 'recovered'].contains(scenario)) {
            await tester.tap(target);
            if (scenario == 'busy') {
              for (
                var round = 0;
                round < 30 && adapter.requests.length < 2;
                round++
              ) {
                await tester.pump(const Duration(milliseconds: 100));
              }
              expect(
                adapter.requests,
                contains('GET /api/v1/organizations/7002'),
              );
              await tester.pump(const Duration(milliseconds: 200));
            } else {
              final error = find.byKey(
                const ValueKey('org-picker-switch-error'),
              );
              await fixture.pumpUntilFound(tester, error);
              expect(error, findsOneWidget);
            }
          }
          if (!_historical) {
            final check = find.byIcon(CupertinoIcons.check_mark);
            if (scenario == 'personal' || scenario == 'workspace') {
              expect(check, findsOneWidget);
              expect(
                find.descendant(
                  of: scenario == 'personal'
                      ? personal
                      : find.byKey(const ValueKey('org-picker-tile-7001')),
                  matching: check,
                ),
                findsOneWidget,
              );
            }
            if (scenario == 'busy') {
              expect(
                find.descendant(
                  of: target,
                  matching: find.byType(CircularProgressIndicator),
                ),
                findsOneWidget,
              );
              expect(
                find.descendant(of: target, matching: check),
                findsNothing,
              );
              expect(tester.widget<ListTile>(target).onTap, isNull);
              expect(tester.widget<ListTile>(personal).onTap, isNull);
            }
            if (scenario == 'forbidden') {
              expect(
                find.text(
                  '${t.organization.picker.switchFailed}：${t.common.noPermission}',
                ),
                findsOneWidget,
              );
              expect(find.textContaining('insufficient scope'), findsNothing);
            }
            if (scenario == 'recovered') {
              expect(find.text('切换失败，已恢复原选择'), findsOneWidget);
            }
            expect(find.textContaining('code='), findsNothing);
            expect(
              find.byKey(const ValueKey('org-picker-join-entry')),
              findsOneWidget,
            );
            expect(
              find.byKey(const ValueKey('org-picker-create-entry')),
              findsOneWidget,
            );
            final join = tester.widget<FilledButton>(
              find.byKey(const ValueKey('org-picker-join-entry')),
            );
            final create = tester.widget<OutlinedButton>(
              find.byKey(const ValueKey('org-picker-create-entry')),
            );
            expect(join.onPressed, isNotNull);
            expect(create.onPressed, isNotNull);
          }
          expect(
            CurrentOrganizationStore.forAccount(_account).value?.id,
            '7001',
          );
          final afterShell = container.read(workspaceShellProvider);
          expect(
            (afterShell.organizationId, afterShell.currentWorkspaceId),
            (beforeShell.organizationId, beforeShell.currentWorkspaceId),
          );
          expect(container.read(productExperienceProvider), experience.initial);
          expect(
            experience.selections,
            scenario == 'recovered' ? [ProductExperience.workspace] : isEmpty,
          );
          expect(workspaceApi.mineCalls, scenario == 'recovered' ? 1 : 0);
          expect(workspaceApi.brandingCalls, 0);
          expect(
            adapter.requests
                .where((path) => path == 'GET /api/v1/organizations/mine')
                .length,
            1,
          );
          expect(
            adapter.requests
                .where(
                  (path) =>
                      path ==
                      'GET /api/v1/organizations/7002/default-workspace',
                )
                .length,
            scenario == 'recovered' ? 1 : 0,
          );
          expect(adapter.unexpected, isEmpty);
          expect(
            adapter.requests
                .where((path) => path == 'GET /api/v1/organizations/7002')
                .length,
            ['busy', 'forbidden', 'recovered'].contains(scenario) ? 1 : 0,
          );
          final layoutError = tester.takeException();
          await expectLater(
            find.byType(Scaffold).first,
            matchesGoldenFile('goldens/t07_${scenario}_$label.png'),
          );
          expect(layoutError, isNull);
        } finally {
          await tester.pumpWidget(const SizedBox.shrink());
          if (scenario == 'busy') {
            adapter.detail.complete(
              adapter.response(
                uxEnvelope(payload: {'id': 7002, 'name': '组织7002'}),
              ),
            );
            await tester.pump(const Duration(milliseconds: 100));
            expect(adapter.unexpected, isEmpty);
          }
        }
      });
    }
  }
}
