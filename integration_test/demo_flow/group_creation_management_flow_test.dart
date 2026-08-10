// P0 双账号建群与群管理写入：只允许授权的 117/118 测试账号。
//
// 该 flow 默认定位同标题测试群；设置 TEST_REQUIRE_FRESH_GROUP=true 时，
// 只用授权的群主 UID 50 创建一个仅含群主的新群，再邀请 UID 4，证明全新建群
// 和入群写入。之后修改群名并发布一条测试公告，再通过详情、成员和公告接口
// 及 GroupDetailPage 回读核对。不会解散群、退群、移除成员、开启群级 E2EE
// 或操作第三方成员。

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

const _ownerUid = String.fromEnvironment(
  'TEST_GROUP_OWNER_UID',
  defaultValue: '50',
);
const _memberUid = String.fromEnvironment(
  'TEST_GROUP_MEMBER_UID',
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
const _requireFreshGroup = String.fromEnvironment(
  'TEST_REQUIRE_FRESH_GROUP',
  defaultValue: 'false',
);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    '双账号建群、群名和公告写入后可服务端回读',
    (tester) async {
      if (!_requireGroupWriteAuthorization()) return;

      await ensureAppLaunched(tester, maxSeconds: 10);
      if (!await checkPreconditions(tester)) return;
      await settle(tester, maxSeconds: 2);

      final actualUid = UserRepoLocal.to.currentUid;
      if (actualUid != _ownerUid) {
        markTestSkipped('当前 App UID=$actualUid，不是授权的建群管理员 $_ownerUid，拒绝写入');
        return;
      }

      final group = await _findOrCreateTestGroup();
      if (group == null) {
        fail('建群接口未返回可核对的 group id');
      }
      flowLog(
        '${group.reused ? '复用' : '创建'}测试群：gid=${group.id}，title=${group.title}',
      );

      final edited = await GroupApi().groupEdit(
        gid: group.id,
        data: {'title': _groupTitle},
      );
      expect(edited, isTrue, reason: '群名修改必须收到服务端成功响应');
      flowLog('群名写入标记：$_groupTitle；公告标记：$_announcementMarker');

      var announcementPage = await _loadAnnouncements(group.id);
      if (!announcementPage.any((item) => item.contains(_announcementMarker))) {
        // 群编辑和公告发布共享用户级三秒节流；显式等待避免把正常
        // 的连续管理动作误判为公告功能失败。
        await Future<void>.delayed(const Duration(seconds: 4));
        final announcementAdded = await _publishAnnouncement(group.id);
        expect(announcementAdded, isTrue, reason: '公告发布必须收到服务端成功响应');
        announcementPage = await _loadAnnouncements(group.id);
      }

      final detail = await GroupApi().detail(gid: group.id);
      expect(_readId(detail), group.id, reason: '群详情应返回同一 gid');
      expect(_readTitle(detail), _groupTitle, reason: '群名应从服务端回读为测试标题');

      final memberPage = await GroupMemberApi().page(
        gid: group.id,
        page: 1,
        size: 20,
      );
      final members = _asList(memberPage);
      final memberIds = members.map(_readMemberId).whereType<String>().toSet();
      expect(
        memberIds,
        containsAll(<String>{_ownerUid, _memberUid}),
        reason: '成员服务端回读必须同时包含管理员和授权测试成员',
      );

      expect(
        announcementPage.any((item) => item.contains(_announcementMarker)),
        isTrue,
        reason: '公告服务端回读必须包含唯一测试标记',
      );

      final navigatorFinder = find.byType(Navigator);
      if (!tester.any(navigatorFinder)) {
        fail('App 未找到根 Navigator，无法执行群详情 UI 回读');
      }
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
      expect(mounted, isTrue, reason: '群详情页应成功挂载');
      await settle(tester, maxSeconds: 4);
      flowLog('测试群定位、群名、公告服务端回读和 GroupDetailPage 已通过');

      if (navigator.canPop()) navigator.pop();
      await settle(tester, maxSeconds: 1);
      await routeResult;
      drainKnownFrameworkExceptions(tester);
    },
    semanticsEnabled: false,
    timeout: const Timeout(Duration(minutes: 8)),
  );
}

bool _requireGroupWriteAuthorization() {
  const allow = String.fromEnvironment(
    'TEST_ALLOW_DUAL_ACCOUNT_GROUP_PROD_WRITES',
    defaultValue: 'false',
  );
  if (allow.toLowerCase() != 'true') {
    markTestSkipped(
      '建群/群管理生产写入必须显式设置 TEST_ALLOW_DUAL_ACCOUNT_GROUP_PROD_WRITES=true',
    );
    return false;
  }
  if (!FlowConfig.hasCredentials || !FlowConfig.hasExplicitTestEnvironment) {
    markTestSkipped('缺少建群测试凭证或显式环境');
    return false;
  }
  if (!FlowConfig.targetsProduction) {
    markTestSkipped('本 flow 只接受已明确授权的生产双账号验证，非目标环境跳过');
    return false;
  }
  if (_ownerUid != '50' || _memberUid != '4' || _ownerUid == _memberUid) {
    markTestSkipped('建群 flow 仅允许当前授权的 UID 50→4，拒绝其他账号组合');
    return false;
  }
  if (!_groupTitle.startsWith('P0-TEST-GROUP-') ||
      _groupTitle.length < 16 ||
      !_announcementMarker.startsWith('P0-GROUP-')) {
    markTestSkipped('必须传入带 P0 测试前缀的唯一群标题和公告标记');
    return false;
  }
  if (_requireFreshGroup.toLowerCase() == 'true' &&
      !_groupTitle.contains('-FRESH-')) {
    markTestSkipped('全新建群模式要求标题包含 -FRESH-，避免误用旧测试群');
    return false;
  }
  return true;
}

class _GroupSeed {
  const _GroupSeed({
    required this.id,
    required this.title,
    required this.reused,
  });

  final String id;
  final String title;
  final bool reused;
}

Future<_GroupSeed?> _findOrCreateTestGroup() async {
  if (_requireFreshGroup.toLowerCase() == 'true') {
    final existing = await _findExistingTestGroup();
    if (existing != null) {
      fail('全新建群标题已存在，拒绝复用旧群：gid=${existing.id}');
    }

    final response = await GroupApi().groupAdd(memberUserIds: const []);
    final group = response?['group'];
    if (group is! Map) return null;
    final id = _readId(group);
    if (id.isEmpty) return null;
    flowLog('全新测试群已创建：gid=$id，准备邀请 118');

    // GroupMemberApi.join 的旧返回类型把“成功但无 payload”折成 null；
    // 这里直接核对 HTTP 成功和成员服务端回读，避免把成功邀请误判为失败。
    final joinResponse = await HttpClient.client.post(
      '/api/v1/group_member/join',
      data: <String, dynamic>{
        'gid': id,
        'member_uids': <String>[_memberUid],
      },
    );
    flowLog(
      '邀请 118 响应：ok=${joinResponse.ok} code=${joinResponse.code} msg=${joinResponse.msg}',
    );
    expect(
      joinResponse.ok,
      isTrue,
      reason: '全新测试群已创建但邀请 118 失败，拒绝把单成员群误报为双账号建群通过',
    );
    final members = _asList(
      await GroupMemberApi().page(gid: id, page: 1, size: 20),
    );
    final memberIds = members.map(_readMemberId).whereType<String>().toSet();
    expect(
      memberIds,
      containsAll(<String>{_ownerUid, _memberUid}),
      reason: '全新测试群邀请后服务端成员必须同时包含 117 和 118',
    );
    return _GroupSeed(
      id: id,
      title: group['title']?.toString() ?? '',
      reused: false,
    );
  }

  final existing = await _findExistingTestGroup();
  if (existing != null) return existing;

  // 后端可能按成员集合幂等复用已有群；先核对当前授权两人是否已有同群，
  // 避免把“复用旧群”误报成“新建群”。
  final pair = await _findExistingPairGroup();
  if (pair != null) return pair;

  final response = await GroupApi().groupAdd(memberUserIds: [_memberUid]);
  final group = response?['group'];
  if (group is! Map) return null;
  final id = _readId(group);
  if (id.isEmpty) return null;
  return _GroupSeed(
    id: id,
    title: group['title']?.toString() ?? '',
    reused: false,
  );
}

Future<_GroupSeed?> _findExistingTestGroup() async {
  final payload = await GroupApi().page(page: 1, size: 100, attr: 'owner');
  final rows = _asList(payload);
  for (final row in rows) {
    if (row is! Map || row['title']?.toString() != _groupTitle) continue;
    final id = _readId(row);
    if (id.isNotEmpty) {
      return _GroupSeed(id: id, title: _groupTitle, reused: true);
    }
  }
  return null;
}

Future<_GroupSeed?> _findExistingPairGroup() async {
  final payload = await GroupApi().page(page: 1, size: 100, attr: 'owner');
  final rows = _asList(payload);
  for (final row in rows) {
    if (row is! Map) continue;
    final id = _readId(row);
    if (id.isEmpty) continue;
    final memberPage = await GroupMemberApi().page(gid: id, page: 1, size: 20);
    final memberIds = _asList(
      memberPage,
    ).map(_readMemberId).whereType<String>().toSet();
    if (memberIds.length == 2 &&
        memberIds.contains(_ownerUid) &&
        memberIds.contains(_memberUid)) {
      return _GroupSeed(
        id: id,
        title: row['title']?.toString() ?? '',
        reused: true,
      );
    }
  }
  return null;
}

Future<bool> _publishAnnouncement(String gid) async {
  final response = await HttpClient.client.post(
    '/api/v1/group_notice/add',
    data: {
      'gid': gid,
      'title': 'P0 测试公告',
      'body': _announcementMarker,
      'status': 1,
      'expired_at': DateTime.now()
          .toUtc()
          .add(const Duration(days: 30))
          .toIso8601String(),
    },
  );
  flowLog('发布公告响应：ok=${response.ok} code=${response.code} msg=${response.msg}');
  return response.code == 0;
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
  final raw = value['group_id'] ?? value['gid'] ?? value['id'];
  return raw?.toString().trim() ?? '';
}

String _readTitle(dynamic value) {
  if (value is! Map) return '';
  final raw = value['title'] ?? value['name'];
  return raw?.toString() ?? '';
}

String? _readMemberId(dynamic value) {
  if (value is! Map) return null;
  final raw = value['uid'] ?? value['user_id'] ?? value['id'];
  final id = raw?.toString().trim() ?? '';
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
