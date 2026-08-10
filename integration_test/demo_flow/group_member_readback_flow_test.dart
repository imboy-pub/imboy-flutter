// P0 群管理跨设备回读：Android/118 只读核对 macOS/117 管理员写入的测试群。
// 不创建、不修改、不删除任何群数据。

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:imboy/component/http/http_client.dart';
import 'package:imboy/page/group/group_detail/group_detail_page.dart';
import 'package:imboy/store/api/group_api.dart';
import 'package:imboy/store/api/group_member_api.dart';
import 'package:imboy/store/repository/user_repo_local.dart';

import '../flows/app_launcher.dart';
import '../flows/test_utils.dart';

const _expectedUid = String.fromEnvironment(
  'TEST_EXPECTED_UID',
  defaultValue: '4',
);
const _groupTitle = String.fromEnvironment(
  'TEST_GROUP_TITLE',
  defaultValue: '',
);
const _announcementMarker = String.fromEnvironment(
  'TEST_GROUP_ANNOUNCEMENT',
  defaultValue: '',
);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    '成员账号可回读管理员写入的测试群、成员和公告',
    (tester) async {
      if (_groupTitle.isEmpty || !_announcementMarker.startsWith('P0-GROUP-')) {
        markTestSkipped('缺少目标测试群标题或公告标记');
        return;
      }

      await ensureAppLaunched(tester, maxSeconds: 10);
      if (!await checkPreconditions(tester)) return;
      await settle(tester, maxSeconds: 2);

      final actualUid = UserRepoLocal.to.currentUid;
      if (actualUid != _expectedUid) {
        markTestSkipped('当前 App UID=$actualUid，不是成员账号 $_expectedUid');
        return;
      }

      final group = await _findTestGroup();
      if (group == null) {
        markTestSkipped('成员账号未找到目标测试群，无法进行跨设备回读');
        return;
      }
      final members = _asList(
        await GroupMemberApi().page(gid: group.id, page: 1, size: 20),
      );
      final memberIds = members.map(_readMemberId).whereType<String>().toSet();
      expect(memberIds, containsAll(<String>{'50', '4'}));

      final detail = await GroupApi().detail(gid: group.id);
      expect(_readTitle(detail), _groupTitle);

      final notices = await _loadAnnouncements(group.id);
      expect(
        notices.any((item) => item.contains(_announcementMarker)),
        isTrue,
        reason: '成员账号应能从服务端回读管理员公告',
      );

      final navigatorFinder = find.byType(Navigator);
      if (!tester.any(navigatorFinder)) fail('App 未找到根 Navigator');
      final navigator = Navigator.of(
        tester.element(navigatorFinder.first),
        rootNavigator: true,
      );
      final routeResult = navigator.push<void>(
        CupertinoPageRoute<void>(
          builder: (_) => GroupDetailPage(
            groupId: group.id,
            title: _groupTitle,
            memberCount: memberIds.length,
          ),
        ),
      );
      final mounted = await _waitFor(
        tester,
        () => tester.any(find.byType(GroupDetailPage)),
        maxAttempts: 40,
      );
      expect(mounted, isTrue);
      await settle(tester, maxSeconds: 4);
      flowLog('成员账号已回读测试群、成员和公告，并挂载群详情页');

      if (navigator.canPop()) navigator.pop();
      await settle(tester, maxSeconds: 1);
      await routeResult;
      drainKnownFrameworkExceptions(tester);
    },
    semanticsEnabled: false,
    timeout: const Timeout(Duration(minutes: 6)),
  );
}

class _GroupSeed {
  const _GroupSeed({required this.id});

  final String id;
}

Future<_GroupSeed?> _findTestGroup() async {
  final payload = await GroupApi().page(page: 1, size: 100, attr: 'join');
  for (final row in _asList(payload)) {
    if (row is Map && row['title']?.toString() == _groupTitle) {
      final id = _readId(row);
      if (id.isNotEmpty) return _GroupSeed(id: id);
    }
  }
  return null;
}

Future<List<String>> _loadAnnouncements(String gid) async {
  final response = await HttpClient.client.dio.get<dynamic>(
    '/api/v1/group_notice/page',
    queryParameters: {'gid': gid, 'page': 1, 'size': 50},
  );
  final body = response.data;
  if (body is! Map) return const [];
  return _asList(
    body['payload'],
  ).map((item) => item is Map ? item.values.join('|') : '$item').toList();
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
  return (value['title'] ?? value['name'])?.toString() ?? '';
}

String? _readMemberId(dynamic value) {
  if (value is! Map) return null;
  final id =
      (value['uid'] ?? value['user_id'] ?? value['id'])?.toString() ?? '';
  return id.isEmpty ? null : id;
}

Future<bool> _waitFor(
  WidgetTester tester,
  bool Function() predicate, {
  required int maxAttempts,
}) async {
  for (var i = 0; i < maxAttempts; i++) {
    if (predicate()) return true;
    await tester.pump(const Duration(milliseconds: 500));
  }
  return predicate();
}
