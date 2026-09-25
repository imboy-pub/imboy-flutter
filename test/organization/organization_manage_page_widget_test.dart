/// GZAPP-05 — 企业管理页 focused widget 测试。
///
/// 覆盖（每条对应一个验收面）：
/// - 角色裁剪：非 owner/admin 只看到只读事实与无权限卡，治理区块不渲染；
///   owner 看到工作区/群/频道三块；
/// - 数据源边界：工作区列表只含 `organization_id` 等于本企业的项
///   （个人域工作区与其它企业的工作区都不出现）；
/// - 危险操作二次确认：取消 = 不产生请求；
/// - 失败引导：归档被后端拒绝时原样透出服务端文案（默认工作区需先设替代）；
/// - 归档可见性：`status=archived` 才有恢复按钮（否则归档后无路可回）；
/// - 四态：loading → 成功。
///
/// 适配器按路径路由：本页一次进入会打 detail / default-workspace /
/// workspaces-mine / groups / channels / channels?status=archived 六个口，
/// 单一静态应答无法表达，故用路径前缀表。
library;

import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:imboy/component/http/http_client.dart';
import 'package:imboy/modules/organization/presentation/organization_manage_page.dart';
import 'package:imboy/service/storage.dart';

const String kOrgId = '900';
const String kWsId = '801';
const String kOtherWsId = '802';

/// 路径命中表：按顺序取第一个命中的；未命中回 404。
class _Route {
  const _Route(
    this.fragment,
    this.status,
    this.body, {
    this.prefix = false,
    this.archivedOnly = false,
  });

  final String fragment;
  final int status;
  final dynamic body;

  /// true = 路径前缀命中（`/workspaces/:id/channels` 这类前缀）。
  final bool prefix;

  /// true = 只在请求带 `status=archived` 时命中；false = 只在未带时命中
  /// （同路径两条路由靠该位区分归档集合与活动集合）。
  final bool archivedOnly;
}

class _RoutingAdapter implements HttpClientAdapter {
  _RoutingAdapter(this.routes);

  final List<_Route> routes;

  /// 命中记录（断言「有没有真的发请求」）。
  final List<String> hits = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final path = options.path;
    final query = options.queryParameters;
    final full = query.isEmpty
        ? path
        : '$path?${query.entries.map((e) => '${e.key}=${e.value}').join('&')}';
    hits.add('${options.method} $full');
    final wantsArchived = query['status'] == 'archived';
    for (final r in routes) {
      // options.path 是完整 URL，用子串包含匹配。
      final matched = path.contains(r.fragment);
      if (!matched) continue;
      if (r.archivedOnly != wantsArchived) continue;
      return ResponseBody.fromString(
        jsonEncode(r.body),
        r.status,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
    }
    return ResponseBody.fromString(
      jsonEncode({'code': 404, 'msg': 'not found'}),
      404,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Map<String, dynamic> _ok(dynamic payload) => {
  'code': 0,
  'msg': 'success',
  'payload': ?payload,
};

Map<String, dynamic> _orgPayload({
  required String role,
  String status = 'active',
}) => {
  'id': kOrgId,
  'name': '广州企业',
  'owner_id': '1001',
  'status': status,
  'member_role': role,
};

/// 企业下两个工作区应为可见（其中一个是默认），另加两个不该出现的干扰项：
/// 个人域工作区（organization_id 空）与其它企业的工作区。
Map<String, dynamic> _wsPage({String ownWsOwner = '1001'}) => {
  'list': [
    {
      'id': kWsId,
      'name': '广州研发区',
      'owner_id': ownWsOwner,
      'status': 'active',
      'organization_id': kOrgId,
    },
    {
      'id': kOtherWsId,
      'name': '广州市场区',
      'owner_id': '1002',
      'status': 'active',
      'organization_id': kOrgId,
    },
    {
      'id': '900',
      'name': '我的个人区',
      'owner_id': '1001',
      'status': 'active',
      'organization_id': null,
    },
    {
      'id': '901',
      'name': '别家企业区',
      'owner_id': '1001',
      'status': 'active',
      'organization_id': '999',
    },
  ],
  'page': 1,
  'size': 100,
  'total': 4,
  'total_page': 1,
};

_RoutingAdapter _happyAdapter({
  String role = 'owner',
  int archiveStatus = 200,
  String archiveBody = 'success',
  String ownWsOwner = '1001',
}) => _RoutingAdapter([
  _Route(
    '/api/v1/organizations/$kOrgId/default-workspace',
    200,
    _ok({'organization_id': kOrgId, 'default_workspace_id': kWsId}),
  ),
  _Route('/api/v1/organizations/$kOrgId', 200, _ok(_orgPayload(role: role))),
  _Route('/api/v1/workspaces/mine', 200, _ok(_wsPage(ownWsOwner: ownWsOwner))),
  _Route(
    '/api/v1/workspaces/$kWsId/groups',
    200,
    _ok({
      'list': [
        {'id': '7001', 'title': '企业全员群', 'member_count': 12, 'status': 1},
      ],
    }),
  ),
  _Route(
    '/api/v1/workspaces/$kWsId/channels',
    200,
    _ok({
      'list': [
        {'id': '6001', 'name': '公告', 'subscriber_count': 3, 'status': 1},
      ],
    }),
    prefix: true,
  ),
  // 归档集合（同路径，靠 query 区分）。
  _Route(
    '/api/v1/workspaces/$kWsId/channels',
    200,
    _ok({
      'list': [
        {'id': '6002', 'name': '旧公告', 'subscriber_count': 0, 'status': 0},
      ],
    }),
    prefix: true,
    archivedOnly: true,
  ),
  // 工作区归档：默认 200；测试可注入失败以断言错误引导。
  _Route(
    '/api/v1/workspaces/$kWsId/archive',
    archiveStatus,
    archiveStatus == 200
        ? _ok(null)
        : {'code': archiveStatus, 'msg': archiveBody},
  ),
]);

Future<void> _pumpUntilFound(WidgetTester tester, Finder finder) async {
  for (var i = 0; i < 40; i++) {
    await tester.pump(const Duration(milliseconds: 100));
    if (finder.evaluate().isNotEmpty) {
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));
      return;
    }
  }
}

void main() {
  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
    // 请求链会走到 secure_storage 平台通道；不 mock 则该调用在
    // FakeAsync 里永不完成（表现为页面永停 loading）。
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
          (call) async => null,
        );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
          null,
        );
    HttpClient.adapterForTest = null;
  });

  Widget buildHost() => const MaterialApp(
    home: OrganizationManagePage(orgId: kOrgId, accountKey: '1001'),
  );

  testWidgets('角色裁剪：既非管理者也不拥有工作区时全只读', (tester) async {
    HttpClient.adapterForTest = _happyAdapter(
      role: 'member',
      ownWsOwner: '1002',
    );
    await tester.pumpWidget(buildHost());
    await _pumpUntilFound(
      tester,
      find.byKey(const ValueKey('org-manage-forbidden')),
    );

    expect(find.byKey(const ValueKey('org-manage-forbidden')), findsOneWidget);
    expect(find.textContaining('只读'), findsWidgets);
    // 治理区块整体不渲染
    expect(
      find.byKey(const ValueKey('org-manage-create-workspace')),
      findsNothing,
    );
    expect(find.byKey(const ValueKey('org-manage-create-group')), findsNothing);
    expect(
      find.byKey(const ValueKey('org-manage-create-channel')),
      findsNothing,
    );
  });

  testWidgets('WS Owner（非组织管理者）：只看到自己拥有的工作区，且无组织级动作', (tester) async {
    // 计划 §5.2：企业管理对 Organization Owner/Admin **和 Workspace Owner**
    // 可见，并按权限裁剪管理项——组织级动作（新建工作区）不给 WS Owner。
    HttpClient.adapterForTest = _happyAdapter(role: 'member');
    await tester.pumpWidget(buildHost());
    await _pumpUntilFound(
      tester,
      find.byKey(const ValueKey('org-manage-ws-$kWsId')),
    );

    expect(find.byKey(const ValueKey('org-manage-ws-$kWsId')), findsOneWidget);
    // 只列自己拥有的：另一个工作区（owner=1002）不出现
    expect(
      find.byKey(const ValueKey('org-manage-ws-$kOtherWsId')),
      findsNothing,
    );
    // 组织级动作不出现
    expect(
      find.byKey(const ValueKey('org-manage-create-workspace')),
      findsNothing,
    );
    // 没有落到无权限态
    expect(find.byKey(const ValueKey('org-manage-forbidden')), findsNothing);
  });

  testWidgets('owner：工作区只列本企业项，个人域/别家企业都不出现', (tester) async {
    HttpClient.adapterForTest = _happyAdapter();
    await tester.pumpWidget(buildHost());
    await _pumpUntilFound(tester, find.text('广州研发区'));

    // 行与 ChoiceChip 都会渲染名字，故按 key 断言存在性。
    expect(find.byKey(const ValueKey('org-manage-ws-$kWsId')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('org-manage-ws-$kOtherWsId')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('org-manage-ws-chip-$kWsId')),
      findsOneWidget,
    );
    expect(find.text('我的个人区'), findsNothing);
    expect(find.text('别家企业区'), findsNothing);
    expect(find.textContaining('默认工作区'), findsWidgets);
  });

  testWidgets('群与频道区块渲染，且有可点击的解散/归档动作', (tester) async {
    HttpClient.adapterForTest = _happyAdapter();
    HttpClient.adapterForTest = _happyAdapter();
    await tester.pumpWidget(buildHost());
    await _pumpUntilFound(tester, find.text('企业全员群'));

    expect(find.text('企业全员群'), findsOneWidget);
    // 频道区块在首屏之下：ListView 懒构建，未滚动时它根本不在 widget 树里，
    // 因此必须先滚到可见再断言（这也顺带覆盖真实滚动行为）。
    await tester.scrollUntilVisible(
      find.text('公告'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.text('公告'), findsOneWidget);
    // 企业频道策略文案（免费 + 非公开）
    expect(find.textContaining('非公开'), findsWidgets);
  });

  testWidgets('归档可见性：archived 集合才有恢复入口', (tester) async {
    HttpClient.adapterForTest = _happyAdapter();
    await tester.pumpWidget(buildHost());
    // 先等资源区拿到事实（loading 期间没有 ListView，滚动会找不到 Scrollable）。
    await _pumpUntilFound(tester, find.text('企业全员群'));
    await tester.scrollUntilVisible(
      find.text('旧公告'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(find.text('旧公告'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('org-manage-restore-6002')),
      findsOneWidget,
    );
    // 活动频道的归档动作收进行内菜单（ENT-APP-06）：打开菜单后可见
    // 归档项，且没有恢复项（恢复只属于归档集合）。
    await tester.tap(
      find.byKey(const ValueKey('org-manage-channel-menu-6001')),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('org-manage-archive-6001')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('org-manage-restore-6001')), findsNothing);
    // 关闭菜单，恢复归档频道行的断言语境。
    await tester.tapAt(const Offset(10, 100));
    await tester.pumpAndSettle();
  });

  testWidgets('危险操作：二次确认弹窗取消则不产生任何请求', (tester) async {
    final adapter = _happyAdapter();
    HttpClient.adapterForTest = adapter;
    await tester.pumpWidget(buildHost());
    await _pumpUntilFound(tester, find.text('广州研发区'));

    final before = adapter.hits.where((h) => h.contains('/archive')).length;
    await tester.tap(find.byKey(const ValueKey('org-manage-ws-menu-$kWsId')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('归档工作区').last);
    await tester.pumpAndSettle();

    // 确认弹窗出现，文案写明不可逆后果与替代工作区前置条件
    expect(find.textContaining('归档「广州研发区」'), findsOneWidget);
    expect(find.textContaining('替代工作区'), findsOneWidget);
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();

    expect(adapter.hits.where((h) => h.contains('/archive')).length, before);
  });

  testWidgets('归档失败：透出服务端文案（引导先设替代工作区）', (tester) async {
    HttpClient.adapterForTest = _happyAdapter(
      archiveStatus: 403,
      archiveBody: '默认工作区未指定替代，禁止归档',
    );
    await tester.pumpWidget(buildHost());
    await _pumpUntilFound(tester, find.text('广州研发区'));

    await tester.tap(find.byKey(const ValueKey('org-manage-ws-menu-$kWsId')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('归档工作区').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('确认执行'));
    await _pumpUntilFound(tester, find.textContaining('归档工作区：'));

    expect(find.textContaining('默认工作区未指定替代，禁止归档'), findsOneWidget);
  });

  testWidgets('loading 态先于成功态出现', (tester) async {
    HttpClient.adapterForTest = _happyAdapter();
    await tester.pumpWidget(buildHost());
    await tester.pump();
    // 首帧在 loading（未拿到服务端事实）
    expect(find.byType(CircularProgressIndicator), findsWidgets);
    await _pumpUntilFound(tester, find.text('广州研发区'));
    expect(find.byKey(const ValueKey('org-manage-ws-$kWsId')), findsOneWidget);
  });
}
