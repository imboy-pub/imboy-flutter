import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/modules/enterprise_oa/data/oa_workbench_api.dart';
import 'package:imboy/modules/enterprise_oa/enterprise_oa_runtime_config.dart';
import 'package:imboy/modules/enterprise_oa/oa_workbench_provider.dart';
import 'package:imboy/store/model/user_model.dart';
import 'package:imboy/store/repository/user_repo_provider.dart';

/// 定位修订（2026-10-12）：发现键只有 accountKey（organization 不参与）。
class _DelayedApi extends OaWorkbenchApi {
  final calls = <String>[];
  final pending = <String, Completer<List<EnterpriseOaRuntimeConfig>>>{};
  @override
  Future<List<EnterpriseOaRuntimeConfig>> entries() {
    calls.add('entries');
    return pending.putIfAbsent('entries', Completer.new).future;
  }
}

List<EnterpriseOaRuntimeConfig> result(String redirect) =>
    parseOaWorkbenchEntries({
      'entries': [
        {
          'kind': 'oa',
          'organization_id': 10,
          'application_key': 'shared-oa-key',
          'redirect_uri': redirect,
        },
      ],
    });

void main() {
  testWidgets('账号切换后旧账号的配置结果不能回填', (tester) async {
    final api = _DelayedApi();
    Widget host(UserModel? user) => ProviderScope(
      overrides: [
        currentUserProvider.overrideWithValue(user),
        oaWorkbenchApiProvider.overrideWithValue(api),
      ],
      child: MaterialApp(
        home: Consumer(
          builder: (_, ref, _) {
            final state = ref.watch(oaWorkbenchEntriesProvider('account-a'));
            return Text(state.value?.firstOrNull?.redirectUri ?? 'loading');
          },
        ),
      ),
    );
    final userA = UserModel(uid: 'account-a', account: 'synthetic-account');
    final userB = UserModel(uid: 'account-b', account: 'synthetic-account');
    await tester.pumpWidget(host(userA));
    await tester.pump();
    // 在途请求完成前账号切换：旧账号结果不得回填新账号的观察。
    await tester.pumpWidget(host(userB));
    await tester.pump();
    api.pending['entries']!.complete(result('https://oa.example.com/a'));
    await tester.pumpAndSettle();
    expect(find.text('https://oa.example.com/a'), findsNothing);
    expect(api.calls, ['entries']);
  });

  test('未登录或账号不匹配不读取配置', () async {
    final api = _DelayedApi();
    final container = ProviderContainer.test(
      overrides: [
        currentUserProvider.overrideWithValue(null),
        oaWorkbenchApiProvider.overrideWithValue(api),
      ],
    );
    final provider = oaWorkbenchEntriesProvider('account-a');
    final sub = container.listen(provider, (_, _) {});
    addTearDown(sub.close);
    expect(await container.read(provider.future), isEmpty);
    expect(api.calls, isEmpty);
  });
}
