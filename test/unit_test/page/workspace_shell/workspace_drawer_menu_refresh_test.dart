import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/modules/organization/domain/organization_models.dart';
import 'package:imboy/modules/organization/infrastructure/current_organization_store.dart';
import 'package:imboy/modules/organization/infrastructure/organization_api.dart';
import 'package:imboy/modules/organization/infrastructure/organization_cache.dart';
import 'package:imboy/modules/organization/presentation/organization_entry_provider.dart';
import 'package:imboy/page/chat_shell/experience_provider.dart';
import 'package:imboy/page/workspace_shell/workspace_drawer_menu.dart';
import 'package:imboy/store/model/user_model.dart';
import 'package:imboy/store/repository/user_repo_provider.dart';

const _account = 'synthetic-space-refresh';

class _PendingOrganizations extends OrganizationApi {
  final requests = <Completer<List<Organization>>>[];

  @override
  Future<List<Organization>> allMine() {
    final request = Completer<List<Organization>>();
    requests.add(request);
    return request.future;
  }
}

class _PersonalExperience extends ProductExperienceNotifier {
  @override
  ProductExperience build() => ProductExperience.personal;
}

void main() {
  setUp(() {
    OrganizationCache.disposeAccount(_account);
    CurrentOrganizationStore.disposeAccount(_account);
  });
  tearDown(() {
    OrganizationCache.disposeAccount(_account);
    CurrentOrganizationStore.disposeAccount(_account);
  });

  for (final withCache in [false, true]) {
    testWidgets('空间加载失败可原地重试，保留缓存并禁止重复请求 cache=$withCache', (
      tester,
    ) async {
      if (withCache) {
        OrganizationCache.forAccount(_account).replaceMineOrgs([
          const Organization(id: '101', name: '缓存企业'),
        ]);
      }
      final api = _PendingOrganizations();
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 400);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            organizationApiProvider.overrideWithValue(api),
            currentUserProvider.overrideWithValue(
              UserModel(uid: _account, account: 'synthetic', nickname: '合成用户'),
            ),
            productExperienceProvider.overrideWith(_PersonalExperience.new),
          ],
          child: TranslationProvider(
            child: MaterialApp(
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: const TextScaler.linear(2),
                ),
                child: child!,
              ),
              home: const Scaffold(
                body: Align(
                  alignment: Alignment.topCenter,
                  child: SizedBox(
                    height: 240,
                    child: WorkspaceDrawerMenu(compact: true),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      expect(api.requests, hasLength(1));
      api.requests.first.completeError(StateError('synthetic offline'));
      await tester.pumpAndSettle();
      expect(find.text(t.common.loadError), findsOneWidget);
      expect(find.text('缓存企业'), withCache ? findsOneWidget : findsNothing);
      expect(find.text(t.main.setting), findsOneWidget);

      final retry = find.byKey(const ValueKey('drawer-space-retry'));
      await tester.ensureVisible(retry);
      await tester.pumpAndSettle();
      await tester.tap(retry);
      await tester.pump();
      expect(api.requests, hasLength(2));
      expect(tester.widget<CupertinoButton>(retry).onPressed, isNull);
      expect(
        find.descendant(
          of: retry,
          matching: find.byType(CupertinoActivityIndicator),
        ),
        findsOneWidget,
      );
      expect(find.text('缓存企业'), withCache ? findsOneWidget : findsNothing);
      await tester.tap(retry);
      await tester.pump();
      expect(api.requests, hasLength(2));

      api.requests.last.complete([
        const Organization(id: '102', name: '服务端企业'),
      ]);
      await tester.pumpAndSettle();
      expect(find.text(t.common.loadError), findsNothing);
      expect(retry, findsNothing);
      expect(find.text('缓存企业'), findsNothing);
      expect(find.text('服务端企业'), findsOneWidget);
      expect(find.byType(WorkspaceDrawerMenu), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
