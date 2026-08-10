// P0 建群后邀请成员的受控探针。
// 只接受授权的 117 -> 118 测试账号和显式生产写入门禁；成功后用服务端成员页回读。

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:imboy/component/http/http_client.dart';
import 'package:imboy/store/api/group_member_api.dart';
import 'package:imboy/store/repository/user_repo_local.dart';

import '../flows/app_launcher.dart';
import '../flows/test_utils.dart';

const _groupId = String.fromEnvironment('TEST_GROUP_ID', defaultValue: '');
const _ownerUid = '50';
const _memberUid = '4';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    '群主邀请成员后服务端回读成员关系',
    (tester) async {
      if (!_authorized()) return;

      await ensureAppLaunched(tester, maxSeconds: 10);
      if (!await checkPreconditions(tester)) return;
      await settle(tester, maxSeconds: 2);

      final uid = UserRepoLocal.to.currentUid;
      if (uid != _ownerUid) {
        markTestSkipped('当前 App UID=$uid，不是授权群主 $_ownerUid');
        return;
      }

      final response = await HttpClient.client.post(
        '/api/v1/group_member/join',
        data: <String, dynamic>{
          'gid': _groupId,
          'member_uids': <String>[_memberUid],
        },
      );
      flowLog(
        '邀请 118 响应：ok=${response.ok} code=${response.code} msg=${response.msg}',
      );
      expect(response.ok, isTrue, reason: '邀请接口必须返回业务成功');

      final page = await GroupMemberApi().page(
        gid: _groupId,
        page: 1,
        size: 20,
      );
      final ids = _asList(page)
          .map((row) {
            if (row is! Map<Object?, Object?>) return '';
            return (row['uid'] ?? row['user_id'] ?? row['id']).toString();
          })
          .where((id) => id.isNotEmpty && id != 'null')
          .toSet();
      expect(ids, containsAll(<String>{_ownerUid, _memberUid}));
      flowLog('服务端成员回读包含 117/118，群成员邀请链路通过');
    },
    semanticsEnabled: false,
    timeout: const Timeout(Duration(minutes: 5)),
  );
}

bool _authorized() {
  if (_groupId.isEmpty) {
    markTestSkipped('缺少 TEST_GROUP_ID');
    return false;
  }
  if (!FlowConfig.hasCredentials || !FlowConfig.hasExplicitTestEnvironment) {
    markTestSkipped('缺少成员邀请测试凭证或显式环境');
    return false;
  }
  if (!FlowConfig.targetsProduction) {
    markTestSkipped('成员邀请探针只接受已明确授权的生产测试群验证');
    return false;
  }
  const allow = String.fromEnvironment(
    'TEST_ALLOW_DUAL_ACCOUNT_GROUP_PROD_WRITES',
    defaultValue: 'false',
  );
  if (allow.toLowerCase() != 'true') {
    markTestSkipped(
      '成员邀请生产写入必须显式设置 TEST_ALLOW_DUAL_ACCOUNT_GROUP_PROD_WRITES=true',
    );
    return false;
  }
  return true;
}

List<dynamic> _asList(dynamic value) {
  if (value is List) return value;
  if (value is Map) {
    final nested = value['list'] ?? value['items'] ?? value['data'];
    return nested is List ? nested : const [];
  }
  return const [];
}
