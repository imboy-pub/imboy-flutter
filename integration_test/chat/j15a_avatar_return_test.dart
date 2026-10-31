// J15.a：既有 C2C/C2G 会话头像 → 真实资料页 → 原列表原位置。
// 复用 J16.a 的 flows 登录/非生产前置；不发删消息、不修改偏好、不 stub。
// 必填：TEST_EXPECTED_UID、TEST_PEER_ID、TEST_GROUP_ID，以及 flows 登录参数。
// 启动前必须使用 local_office 和本机 API/WS override；账号及待发队列隔离
// 目前无法在启动前验证，本测试故意阻断启动，不能用于真机验收。
// 可复用合成 peer=120619900000000811、group=120619900000000004。
// 个人卡 id 来自路由，故另以真实 userShow 的 peerId/account/nickname 交叉核验；
// 资料页可读本地缓存，本测试不能宣称个人页每次打开必然发起网络请求。

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:imboy/component/http/http_client.dart' as http;
import 'package:imboy/component/http/channel_id_response_decoder.dart';
import 'package:imboy/component/http/http_response.dart';
import 'package:imboy/component/ui/avatar.dart';
import 'package:imboy/component/ui/contact_card.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/config/env.dart';
import 'package:imboy/page/contact/people_info/people_info_page.dart';
import 'package:imboy/page/conversation/conversation_page.dart';
import 'package:imboy/page/conversation/widget/conversation_item.dart';
import 'package:imboy/page/group/group_detail/group_detail_page.dart';
import 'package:imboy/page/group/group_detail/widgets/group_info_card.dart';
import 'package:imboy/store/model/contact_model.dart';
import 'package:imboy/store/model/group_model.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:integration_test/integration_test.dart';

import '../flows/app_launcher.dart';
import '../flows/test_utils.dart';
import 'support/c2c_journey_support.dart';

const _expectedUid = String.fromEnvironment('TEST_EXPECTED_UID');
const _peerId = String.fromEnvironment('TEST_PEER_ID');
const _groupId = String.fromEnvironment('TEST_GROUP_ID');
const _appEnv = String.fromEnvironment('APP_ENV');
const _apiOverride = String.fromEnvironment('API_BASE_URL_OVERRIDE');
const _wsOverride = String.fromEnvironment('WS_URL_OVERRIDE');
const _localApi = 'http://127.0.0.1:9800';
const _localWs = 'ws://127.0.0.1:9800/api/v1/ws';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('J15.a 真实个人/群资料返回原会话列表位置', (tester) async {
    _validateConfig();
    await ensureAppLaunched(tester, maxSeconds: 3);
    if (!await checkPreconditions(tester)) fail('J15.a 登录/环境前置失败');
    final generation = UserRepoLocal.to.sessionGeneration;
    _assertOwner(generation);
    await dismissRecoveryGuide(tester);
    await dismissUpgradeDialog(tester);
    await dismissE2eeBackupSetupPage(tester);
    expect(await openConversationTab(tester), isTrue);
    await settle(tester, maxSeconds: 2);
    await _visit(tester, generation, 'C2C', _peerId);
    await _visit(tester, generation, 'C2G', _groupId);
    _assertOwner(generation);
    fail('J15.a 未闭合：无法证明群详情页本次实际请求成功，卡片可能来自缓存或兜底');
  }, timeout: const Timeout(Duration(minutes: 4)));
}

void _validateConfig() {
  final id = RegExp(r'^[1-9][0-9]*$');
  expect(id.hasMatch(_expectedUid), isTrue, reason: '显式 TEST_EXPECTED_UID');
  expect(id.hasMatch(_peerId), isTrue, reason: '显式 TEST_PEER_ID');
  expect(id.hasMatch(_groupId), isTrue, reason: '显式 TEST_GROUP_ID');
  expect(_peerId, isNot(_expectedUid), reason: '必须是对端而非自己');
  expect(_appEnv, 'local_office', reason: '必须显式指定 APP_ENV');
  expect(_apiOverride, _localApi, reason: '必须显式指定本机 API override');
  expect(_wsOverride, _localWs, reason: '必须显式指定本机 WebSocket override');
  final config = envMap[_appEnv];
  expect(config, isNotNull, reason: '启动前必须核对实际环境配置对象');
  expect(config!.apiBaseUrl, _localApi);
  expect(config.wsUrl, _localWs);
  // flows 探活可单独指定 API_BASE_URL，它不是 App 的 API 配置。
  expect(FlowConfig.apiBaseUrl, anyOf('', _localApi));
  // 进程启动会恢复账号并自动重发队列；当前无法无侵入地在启动前验证隔离。
  // 不用人工布尔开关冒充验证；在有可靠隔离方案前始终拒绝启动。
  fail('J15.a 启动阻断：无法预先验证设备账号和待发队列隔离');
}

void _assertOwner(int generation) {
  final user = UserRepoLocal.to;
  expect(user.isLoggedIn, isTrue);
  expect(user.currentUid, _expectedUid, reason: '登录账号不得漂移');
  expect(user.isCurrentSession(generation), isTrue);
  expect(user.isAuthTransitioning, isFalse);
  expect(user.isClearingSession, isFalse);
}

Finder _item(String type, String id) => find.byWidgetPredicate(
  (w) => w is ConversationItem && w.model.type == type && w.model.peerId == id,
);

Future<void> _waitFor(
  WidgetTester tester,
  int generation,
  bool Function() predicate,
  String reason,
) async {
  final clock = Stopwatch()..start();
  while (clock.elapsed < const Duration(seconds: 20)) {
    _assertOwner(generation);
    if (predicate()) return;
    await Future<void>.delayed(const Duration(milliseconds: 200));
    await tester.pump(const Duration(milliseconds: 100));
  }
  fail('J15.a 超时：$reason（真实资料 API/页面失败不得放宽断言）');
}

// 只读真实接口，不用 syncByUid/save，避免测试预先写入目的页缓存。
Future<Map<String, dynamic>> _identity(String type, String id) async {
  final response = await http.HttpClient().get(
    type == 'C2C' ? API.userShow : API.groupDetail,
    queryParameters: {if (type == 'C2C') 'id': id else 'gid': id},
    options: Options(
      responseDecoder: channelIdResponseDecoder(
        type == 'C2C'
            ? ChannelResponseShape.contact
            : ChannelResponseShape.groupDetail,
      ),
    ),
  );
  expect(response.ok, isTrue, reason: '$type 真实资料 API 失败：${response.msg}');
  final payload = IMBoyHttpResponse.payloadAsMap(response.payload);
  expect(payload, isNotEmpty, reason: '$type 真实资料 API 不得返回空对象');
  return payload;
}

Future<void> _visit(
  WidgetTester tester,
  int generation,
  String type,
  String id,
) async {
  _assertOwner(generation);
  final expected = await _identity(type, id);
  _assertOwner(generation);
  final list = find.byType(ConversationPage);
  expect(list, findsOneWidget);
  final listElement = tester.element(list);
  final router = GoRouter.of(listElement);
  final listRoute = GoRouterState.of(listElement).uri;
  final scrollView = find.descendant(
    of: list,
    matching: find.byType(CustomScrollView),
  );
  expect(scrollView, findsOneWidget, reason: '定位会话页自身的 CustomScrollView');
  final owner = tester.widget<CustomScrollView>(scrollView);
  final scroll = find.descendant(
    of: scrollView,
    matching: find.byElementPredicate((element) {
      final widget = element.widget;
      if (widget is! Scrollable || widget.axis != Axis.vertical) return false;
      ScrollView? nearestScrollView;
      element.visitAncestorElements((ancestor) {
        if (ancestor.widget is ScrollView) {
          nearestScrollView = ancestor.widget as ScrollView;
          return false;
        }
        return true;
      });
      return identical(nearestScrollView, owner);
    }),
  );
  expect(scroll, findsOneWidget, reason: '排除群头像等嵌套 GridView');
  final row = _item(type, id);
  // 真列表惰性构建：从顶端查找，不筛选、不注入任何会话。
  tester.state<ScrollableState>(scroll).position.jumpTo(0);
  await tester.pump();
  await tester.scrollUntilVisible(
    row,
    180,
    scrollable: scroll,
    maxScrolls: 100,
  );
  await Scrollable.ensureVisible(tester.element(row), alignment: 0.5);
  await settle(tester, maxSeconds: 2);
  final position = tester.state<ScrollableState>(scroll).position;
  if (position.pixels == 0 && position.maxScrollExtent > 0) {
    position.jumpTo(24.0.clamp(0.0, position.maxScrollExtent));
    await settle(tester, maxSeconds: 1);
  }
  final original = tester.widget<ConversationItem>(row).model;
  expect(original.type, type);
  expect(original.peerId, id);
  expect(original.isShow, 1);
  final offset = position.pixels;
  final rect = tester.getRect(row);
  final avatar = find.descendant(
    of: row,
    matching: find.byType(type == 'C2G' ? SmartGroupAvatar : Avatar),
  );
  expect(avatar, findsOneWidget);
  expect(avatar.hitTestable(), findsOneWidget, reason: '必须真实命中头像热区');
  // Avatar 自带放大手势也必须真实参与竞争，不能直接调用 onTapAvatar。
  await tester.tap(avatar);
  await _assertProfile(tester, generation, type, id, expected);
  _assertOwner(generation);
  expect(router.canPop(), isTrue);
  router.pop();
  await settle(tester, maxSeconds: 2);
  expect(find.byType(PeopleInfoPage), findsNothing);
  expect(find.byType(GroupDetailPage), findsNothing);
  expect(tester.element(list), same(listElement), reason: '返回原列表而非重新建页');
  expect(GoRouterState.of(tester.element(list)).uri, listRoute);
  expect(tester.state<ScrollableState>(scroll).position, same(position));
  final returned = tester.widget<ConversationItem>(row).model;
  expect(returned.id, original.id);
  expect(returned.uk3, original.uk3);
  expect(returned.type, type);
  expect(returned.peerId, id);
  expect(position.pixels, closeTo(offset, 0.5), reason: 'pop 不得重置 offset');
  final after = tester.getRect(row);
  expect(after.left, closeTo(rect.left, 0.5));
  expect(after.top, closeTo(rect.top, 0.5), reason: '原身份行的屏幕坐标应保持');
  expect(after.size, rect.size);
  _assertOwner(generation);
  flowLog('J15A_RETURN type=$type id=$id offset=$offset y=${rect.top}');
}

Future<void> _assertProfile(
  WidgetTester tester,
  int generation,
  String type,
  String id,
  Map<String, dynamic> expected,
) async {
  final path = type == 'C2C' ? '/contact/people/$id' : '/group/detail/$id';
  final page = find.byType(type == 'C2C' ? PeopleInfoPage : GroupDetailPage);
  await _waitFor(tester, generation, () {
    if (page.evaluate().length != 1) return false;
    final element = tester.element(page);
    final widget = element.widget;
    final pageId = widget is PeopleInfoPage
        ? widget.id
        : (widget as GroupDetailPage).groupId;
    return pageId == id && GoRouterState.of(element).uri.path == path;
  }, '头像应进入 $path 的目标身份页面，而非聊天页/头像预览');
  if (type == 'C2C') {
    await _assertPerson(tester, generation, id, expected);
  } else {
    await _assertGroup(tester, generation, id, expected);
  }
  expect(page, findsOneWidget);
  expect(GoRouterState.of(tester.element(page)).uri.path, path);
  // 再探活一次只能证明独立请求成功，不能证明页面发起了请求。
  await _identity(type, id);
  _assertOwner(generation);
}

Future<void> _assertPerson(
  WidgetTester tester,
  int generation,
  String id,
  Map<String, dynamic> expected,
) async {
  final person = ContactModel.fromMap(expected);
  expect(person.peerId, id, reason: '真实 userShow 返回身份必须匹配目标');
  expect(person.account.trim(), isNotEmpty, reason: '不接受空资料壳');
  final page = find.byType(PeopleInfoPage);
  expect(page, findsOneWidget);
  expect(tester.widget<PeopleInfoPage>(page).id, id);
  final card = find.descendant(of: page, matching: find.byType(ContactCard));
  await _waitFor(tester, generation, () {
    if (!tester.any(card)) return false;
    final data = tester.widget<ContactCard>(card);
    return data.account == person.account && data.nickname == person.nickname;
  }, '个人资料卡应加载该 peer 的 account/nickname');
  expect(tester.widget<ContactCard>(card).id, id);
  expect(
    find.descendant(of: card, matching: find.text('ID: ${person.account}')),
    findsOneWidget,
    reason: '真实身份字段须渲染，不能只验路由参数',
  );
}

Future<void> _assertGroup(
  WidgetTester tester,
  int generation,
  String id,
  Map<String, dynamic> expected,
) async {
  final group = GroupModel.fromJson(expected);
  expect(group.groupId, id, reason: '真实群 API 返回身份必须匹配目标');
  expect(group.title.trim(), isNotEmpty, reason: '不接受路由 title/未命名兜底');
  final page = find.byType(GroupDetailPage);
  expect(page, findsOneWidget);
  expect(tester.widget<GroupDetailPage>(page).groupId, id);
  final card = find.descendant(of: page, matching: find.byType(GroupInfoCard));
  await _waitFor(tester, generation, () {
    if (!tester.any(card)) return false;
    final data = tester.widget<GroupInfoCard>(card).group;
    return data.groupId == id &&
        data.title == group.title &&
        data.memberCount == group.memberCount;
  }, '真实群资料卡应加载 groupId/title/memberCount');
  expect(
    find.descendant(of: card, matching: find.text(group.displayTitle)),
    findsOneWidget,
    reason: '群资料名称必须真实渲染',
  );
}
