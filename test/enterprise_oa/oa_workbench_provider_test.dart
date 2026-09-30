import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/modules/enterprise_oa/data/oa_workbench_api.dart';
import 'package:imboy/modules/enterprise_oa/enterprise_oa_runtime_config.dart';
import 'package:imboy/modules/enterprise_oa/oa_workbench_provider.dart';
import 'package:imboy/store/model/user_model.dart';
import 'package:imboy/store/repository/user_repo_provider.dart';

class _DelayedApi extends OaWorkbenchApi {
  final calls = <String>[];
  final pending = <String, Completer<List<EnterpriseOaRuntimeConfig>>>{};
  @override
  Future<List<EnterpriseOaRuntimeConfig>> entries(String organizationId) {
    calls.add(organizationId);
    return pending.putIfAbsent(organizationId, Completer.new).future;
  }
}

void main() {
  testWidgets('企业切换后旧配置结果不能替换当前企业', (tester) async {
    final api = _DelayedApi();
    final user = UserModel(uid: 'account-a', account: 'synthetic-account');
    Widget host(String orgId) => ProviderScope(
      overrides: [
        currentUserProvider.overrideWithValue(user),
        oaWorkbenchApiProvider.overrideWithValue(api),
      ],
      child: MaterialApp(
        home: Consumer(
          builder: (_, ref, _) {
            final state = ref.watch(
              oaWorkbenchEntriesProvider((
                accountKey: 'account-a',
                organizationId: orgId,
              )),
            );
            return Text(state.value?.firstOrNull?.redirectUri ?? 'loading');
          },
        ),
      ),
    );
    await tester.pumpWidget(host('10'));
    await tester.pump();
    await tester.pumpWidget(host('20'));
    await tester.pump();
    List<EnterpriseOaRuntimeConfig> result(int org) => parseOaWorkbenchEntries({
      'entries': [
        {
          'kind': 'oa',
          'organization_id': org,
          'application_key': 'shared-oa-key',
          'redirect_uri': 'https://oa.example.com/$org',
        },
      ],
    }, '$org');
    api.pending['20']!.complete(result(20));
    await tester.pumpAndSettle();
    expect(find.text('https://oa.example.com/20'), findsOneWidget);
    api.pending['10']!.complete(result(10));
    await tester.pumpAndSettle();
    expect(find.text('https://oa.example.com/20'), findsOneWidget);
    expect(find.text('https://oa.example.com/10'), findsNothing);
    expect(api.calls, ['10', '20']);
  });

  test('未登录或账号不匹配不读取企业配置', () async {
    final api = _DelayedApi();
    final container = ProviderContainer.test(
      overrides: [
        currentUserProvider.overrideWithValue(null),
        oaWorkbenchApiProvider.overrideWithValue(api),
      ],
    );
    final provider = oaWorkbenchEntriesProvider((
      accountKey: 'account-a',
      organizationId: '10',
    ));
    final sub = container.listen(provider, (_, _) {});
    addTearDown(sub.close);
    expect(await container.read(provider.future), isEmpty);
    expect(api.calls, isEmpty);
  });
}
