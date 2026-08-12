// 仅本地/私网使用的 E2EE 群测试夹具。
//
// 该 flow 会创建一个新群、邀请一个测试成员并单向开启群级 E2EE；开启后
// 后端契约不允许回退，因此每次运行都必须传入新的唯一标题。
// 默认跳过，且拒绝生产环境。它不会删除群，也不会修改已有群。
//
// 示例（仅在确认是隔离本地环境后运行）：
// flutter test integration_test/demo_flow/local_e2ee_group_fixture_flow_test.dart \
//   -d <device> \
//   --dart-define=APP_ENV=local \
//   --dart-define=API_BASE_URL=http://<private-host>:9800 \
//   --dart-define=TEST_PHONE=... \
//   --dart-define=TEST_PASSWORD=... \
//   --dart-define=TEST_LOCAL_E2EE_GROUP_FIXTURE=true \
//   --dart-define=TEST_LOCAL_E2EE_GROUP_TITLE=LOCAL-E2EE-GROUP-<unique-marker>

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:imboy/component/http/http_client.dart';
import 'package:imboy/store/api/group_api.dart';
import 'package:imboy/store/api/group_member_api.dart';
import 'package:imboy/store/repository/user_repo_local.dart';

import '../flows/app_launcher.dart';
import '../flows/test_utils.dart';

const _ownerUid = String.fromEnvironment(
  'TEST_LOCAL_E2EE_GROUP_OWNER_UID',
  defaultValue: '1000000051',
);
const _memberUid = String.fromEnvironment(
  'TEST_LOCAL_E2EE_GROUP_MEMBER_UID',
  defaultValue: '1000000056',
);
const _groupTitle = String.fromEnvironment(
  'TEST_LOCAL_E2EE_GROUP_TITLE',
  defaultValue: '',
);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    '本地创建双账号 E2EE 群夹具并回读 e2ee_mode',
    (tester) async {
      if (!_requireLocalFixtureAuthorization()) return;

      await ensureAppLaunched(tester, maxSeconds: 10);
      if (!await checkPreconditions(tester)) return;
      await settle(tester, maxSeconds: 2);

      final actualUid = UserRepoLocal.to.currentUid;
      if (actualUid != _ownerUid) {
        markTestSkipped('当前 App UID=$actualUid，不是本地夹具群主 $_ownerUid，拒绝写入');
        return;
      }

      final existing = await _findGroupByTitle();
      if (existing != null) {
        fail(
          '唯一标题已存在，拒绝复用或重复开启 E2EE：gid=${existing.id}；请改用新的 TEST_LOCAL_E2EE_GROUP_TITLE',
        );
      }

      final created = await GroupApi().groupAdd(memberUserIds: const []);
      final group = created?['group'];
      if (group is! Map) fail('本地 E2EE 群夹具创建接口未返回 group');
      final gid = _readId(group);
      if (gid.isEmpty) fail('本地 E2EE 群夹具创建接口未返回 gid');
      expect(
        await GroupApi().groupEdit(
          gid: gid,
          data: <String, dynamic>{'title': _groupTitle},
        ),
        isTrue,
        reason: '本地 E2EE 群夹具创建后必须写入唯一标题，避免误复用测试群',
      );
      final titled = await GroupApi().detail(gid: gid);
      expect(
        _readTitle(titled),
        _groupTitle,
        reason: '本地 E2EE 群夹具标题必须由服务端回读确认',
      );
      flowLog('本地 E2EE 夹具已创建并命名：gid=$gid，准备邀请成员 $_memberUid');

      final joinResponse = await HttpClient.client.post(
        '/api/v1/group_member/join',
        data: <String, dynamic>{
          'gid': gid,
          'member_uids': <String>[_memberUid],
        },
      );
      expect(
        joinResponse.ok,
        isTrue,
        reason: '本地 E2EE 群已创建，但邀请测试成员失败；不继续开启 E2EE',
      );

      final members = await GroupMemberApi().page(gid: gid, page: 1, size: 20);
      final memberIds = _asList(
        members,
      ).map(_readMemberId).whereType<String>().toSet();
      expect(
        memberIds,
        containsAll(<String>{_ownerUid, _memberUid}),
        reason: '开启群级 E2EE 前必须确认群主和成员都已服务端入群',
      );

      expect(
        await GroupApi().setE2eeMode(gid: gid),
        isTrue,
        reason: '群主开启群级 E2EE 必须成功',
      );

      final detail = await GroupApi().detail(gid: gid);
      expect(_readE2eeMode(detail), 1, reason: '群详情必须回读 e2ee_mode=1');
      flowLog('本地 E2EE 群夹具完成：gid=$gid，成员=$_ownerUid,$_memberUid，e2ee_mode=1');
    },
    semanticsEnabled: false,
    timeout: const Timeout(Duration(minutes: 8)),
  );
}

bool _requireLocalFixtureAuthorization() {
  const allow = String.fromEnvironment(
    'TEST_LOCAL_E2EE_GROUP_FIXTURE',
    defaultValue: 'false',
  );
  if (allow.toLowerCase() != 'true') {
    markTestSkipped(
      '本地 E2EE 群夹具会创建群并邀请成员；请显式设置 TEST_LOCAL_E2EE_GROUP_FIXTURE=true',
    );
    return false;
  }
  if (!FlowConfig.hasCredentials || !FlowConfig.hasExplicitTestEnvironment) {
    markTestSkipped('本地 E2EE 群夹具缺少测试凭证或显式环境');
    return false;
  }
  if (FlowConfig.targetsProduction) {
    markTestSkipped('本地 E2EE 群夹具拒绝生产或无法识别的目标地址');
    return false;
  }
  if (_ownerUid.isEmpty || _memberUid.isEmpty || _ownerUid == _memberUid) {
    markTestSkipped('本地 E2EE 群夹具要求两个不同的测试 UID');
    return false;
  }
  if (!_groupTitle.startsWith('LOCAL-E2EE-GROUP-') || _groupTitle.length < 24) {
    markTestSkipped('必须传入带 LOCAL-E2EE-GROUP- 前缀的唯一标题');
    return false;
  }
  return true;
}

class _GroupSeed {
  const _GroupSeed({required this.id});

  final String id;
}

Future<_GroupSeed?> _findGroupByTitle() async {
  final payload = await GroupApi().page(page: 1, size: 100, attr: 'owner');
  for (final row in _asList(payload)) {
    if (row is Map && row['title']?.toString() == _groupTitle) {
      final id = _readId(row);
      if (id.isNotEmpty) return _GroupSeed(id: id);
    }
  }
  return null;
}

List<dynamic> _asList(dynamic value) {
  if (value is List) return value;
  if (value is Map) {
    final nested = value['list'] ?? value['items'] ?? value['data'];
    return nested is List ? nested : const [];
  }
  return const [];
}

String _readId(dynamic value) {
  if (value is! Map) return '';
  return (value['group_id'] ?? value['gid'] ?? value['id'])?.toString() ?? '';
}

String _readTitle(dynamic value) {
  if (value is! Map) return '';
  return (value['title'] ?? value['name'] ?? '').toString();
}

String? _readMemberId(dynamic value) {
  if (value is! Map) return null;
  final id =
      (value['uid'] ?? value['user_id'] ?? value['id'])?.toString() ?? '';
  return id.isEmpty ? null : id;
}

int _readE2eeMode(dynamic value) {
  if (value is! Map) return 0;
  final raw =
      value['e2ee_mode'] ??
      (value['group'] is Map ? value['group']['e2ee_mode'] : null);
  return int.tryParse(raw?.toString() ?? '') ?? 0;
}
