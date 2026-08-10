// P0 群成员角色变更：117 群主提升 118，再由 Android 回读，最后恢复普通成员。
//
// promote/restore 会写入生产测试群，必须显式设置
// TEST_ALLOW_DUAL_ACCOUNT_GROUP_ROLE_PROD_WRITES=true；readback 只读。
// 不增删成员、不转让群主、不解散群、不修改不可逆 E2EE 设置。

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:imboy/page/group/group_detail/group_detail_page.dart';
import 'package:imboy/store/api/group_member_api.dart';
import 'package:imboy/store/repository/user_repo_local.dart';

import '../flows/app_launcher.dart';
import '../flows/test_utils.dart';

const _groupId = String.fromEnvironment('TEST_GROUP_ID', defaultValue: '');
const _roleAction = String.fromEnvironment(
  'TEST_GROUP_ROLE_ACTION',
  defaultValue: 'readback',
);
const _ownerUid = '50';
const _memberUid = '4';
const _targetRole = 3;
const _restoredRole = 1;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    '群成员角色提升、跨设备回读和恢复',
    (tester) async {
      if (!_requireAuthorization()) return;

      await ensureAppLaunched(tester, maxSeconds: 10);
      if (!await checkPreconditions(tester)) return;
      await settle(tester, maxSeconds: 2);

      final actualUid = UserRepoLocal.to.currentUid;
      final expectedUid = _roleAction == 'readback' ? _memberUid : _ownerUid;
      if (actualUid != expectedUid) {
        markTestSkipped('当前 App UID=$actualUid，不是本步骤授权账号 $expectedUid');
        return;
      }

      if (_roleAction == 'promote') {
        final before = await _readRole();
        if (before != _restoredRole) {
          markTestSkipped('测试前 118 角色不是普通成员(role=1)，拒绝覆盖未知权限状态');
          return;
        }
        final changed = await GroupMemberApi().updateRole(
          gid: _groupId,
          userId: _memberUid,
          role: _targetRole,
        );
        expect(changed, isTrue, reason: '117 提升 118 为管理员必须收到服务端成功响应');
        await _waitForRole(_targetRole);
        flowLog('117 已将测试群成员 118 提升为管理员，服务端角色回读 role=3');
      } else if (_roleAction == 'readback') {
        await _waitForRole(_targetRole);
        flowLog('118 Android 已从服务端回读自身管理员角色 role=3');
      } else {
        final before = await _readRole();
        if (before != _targetRole) {
          markTestSkipped('恢复前 118 角色不是管理员(role=3)，拒绝覆盖未知权限状态');
          return;
        }
        final changed = await GroupMemberApi().updateRole(
          gid: _groupId,
          userId: _memberUid,
          role: _restoredRole,
        );
        expect(changed, isTrue, reason: '117 恢复 118 为普通成员必须收到服务端成功响应');
        await _waitForRole(_restoredRole);
        flowLog('117 已将测试群成员 118 恢复为普通成员，服务端角色回读 role=1');
      }

      await _mountGroupDetail(tester);
      drainKnownFrameworkExceptions(tester);
    },
    semanticsEnabled: false,
    timeout: const Timeout(Duration(minutes: 6)),
  );
}

bool _requireAuthorization() {
  if (_groupId.isEmpty) {
    markTestSkipped('缺少 TEST_GROUP_ID');
    return false;
  }
  if (!{'promote', 'readback', 'restore'}.contains(_roleAction)) {
    markTestSkipped('TEST_GROUP_ROLE_ACTION 只能是 promote/readback/restore');
    return false;
  }
  if (!FlowConfig.hasCredentials || !FlowConfig.hasExplicitTestEnvironment) {
    markTestSkipped('缺少角色变更测试凭证或显式环境');
    return false;
  }
  if (_roleAction == 'readback') return true;

  const allowed = String.fromEnvironment(
    'TEST_ALLOW_DUAL_ACCOUNT_GROUP_ROLE_PROD_WRITES',
    defaultValue: 'false',
  );
  if (allowed.toLowerCase() != 'true') {
    markTestSkipped(
      '群成员角色生产写入需要显式设置 TEST_ALLOW_DUAL_ACCOUNT_GROUP_ROLE_PROD_WRITES=true',
    );
    return false;
  }
  if (!FlowConfig.targetsProduction) {
    markTestSkipped('角色 flow 当前只接受已明确授权的生产测试群验证');
    return false;
  }
  return true;
}

Future<int> _readRole() async {
  final payload = await GroupMemberApi().page(gid: _groupId, page: 1, size: 50);
  for (final row in _asList(payload)) {
    if (row is! Map) continue;
    final uid = (row['uid'] ?? row['user_id'] ?? row['id'])?.toString();
    if (uid != _memberUid) continue;
    final raw = row['role'];
    return raw is num ? raw.toInt() : int.tryParse('$raw') ?? 0;
  }
  return 0;
}

Future<void> _waitForRole(int expected) async {
  for (var i = 0; i < 20; i++) {
    if (await _readRole() == expected) return;
    await Future<void>.delayed(const Duration(milliseconds: 500));
  }
  fail('服务端未在 10 秒内回读 118 的目标角色 role=$expected');
}

Future<void> _mountGroupDetail(WidgetTester tester) async {
  final navigatorFinder = find.byType(Navigator);
  if (!tester.any(navigatorFinder)) fail('App 未找到根 Navigator');
  final navigator = Navigator.of(
    tester.element(navigatorFinder.first),
    rootNavigator: true,
  );
  final routeResult = navigator.push<void>(
    CupertinoPageRoute<void>(
      builder: (_) => const GroupDetailPage(
        groupId: _groupId,
        title: 'P0 测试群',
        memberCount: 2,
      ),
    ),
  );
  for (var i = 0; i < 40; i++) {
    if (tester.any(find.byType(GroupDetailPage))) break;
    await tester.pump(const Duration(milliseconds: 500));
  }
  expect(find.byType(GroupDetailPage), findsOneWidget);
  await settle(tester, maxSeconds: 3);
  if (navigator.canPop()) navigator.pop();
  await settle(tester, maxSeconds: 1);
  await routeResult;
}

List<dynamic> _asList(dynamic value) {
  if (value is List) return value;
  if (value is Map) {
    final nested = value['list'] ?? value['items'] ?? value['data'];
    return nested is List ? nested : const [];
  }
  return const [];
}
