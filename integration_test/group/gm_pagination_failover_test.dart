// integration_test/group/gm_pagination_failover_test.dart
//
// AT-GM4 分页失败回滚页码避免漏页（批次113）。
//
// 背景：服务端 group_member_logic:page_with_user_info 数据层故障时，
// 修复前 handler 把错误吞成「total=0 空列表 success」，客户端停在
// 不完整的第一页且 _hasMore=false，第二页成员静默永久丢失。
// 双侧修复：
//   - imboy handler：ds error 返回 elib_response:error（不吞错），
//     由 test/api/group_member_handler_tests.erl 失败路径用例验证；
//   - imboyapp _loadData：业务失败（ok=false）回滚 _currentPage，
//     由本测试验证。
//
// 注入方式：页面每轮 _loadData 都 new GroupMemberApi()（独立 Dio），
// 实例级拦截器够不着；用 HttpClient.adapterForTest（官方测试钩子，
// 对之后构造的实例生效）换上包装 adapter，命中 gid 的 page 请求
// 返回「HTTP 200 + code!=0」（与服务端 elib_response:error 同形态）。
// flutter_tester 沙箱禁止 spawn 子进程（ProcessException: Operation
// not permitted），故不做跨进程 erlang 注入。
//
// 判定核心：注入态触底加载失败 → 解除注入 → 再触底请求的是回滚后的
// 第 2 页 → 22 条到手；若未回滚（缺陷行为）则请求第 3 页得 0 条，
// 标题恒停在 20。
//
// 前置：群 100000000000000120 共 22 人（同 group_member_acceptance_test）。
// 运行配方同 group_member_acceptance_test.dart。

import 'dart:convert';
import 'dart:typed_data';
import 'dart:io' as io show HttpClient;

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:imboy/component/http/http_client.dart';
import 'package:imboy/main.dart' as app;
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:integration_test/integration_test.dart';

import '../flows/test_utils.dart';

const _expectedUid = String.fromEnvironment('TEST_EXPECTED_UID');
const _allowFlag = String.fromEnvironment(
  'TEST_ALLOW_GROUP_MEMBER_ACCEPTANCE',
  defaultValue: 'false',
);
const _allow = _allowFlag == 'true' || _allowFlag == 'True';
const _gid = '100000000000000120';

Future<void> _pump(WidgetTester tester, {int seconds = 3}) async {
  for (var i = 0; i < seconds * 2; i++) {
    await tester.pump(const Duration(milliseconds: 500));
  }
}

Future<bool> _waitFor(
  WidgetTester tester,
  bool Function() cond, {
  int seconds = 10,
}) async {
  for (var i = 0; i < seconds * 2 && !cond(); i++) {
    await tester.pump(const Duration(milliseconds: 500));
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }
  return cond();
}

/// 包装 adapter：注入开关打开时把 gid 命中的 page 请求替换为
/// 业务失败响应（HTTP 200 + code!=0）；其余请求透传真实网络。
class _FailoverAdapter implements HttpClientAdapter {
  _FailoverAdapter()
    : _inner = IOHttpClientAdapter(createHttpClient: () => io.HttpClient());

  final HttpClientAdapter _inner;
  bool failPageRequest = false;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (failPageRequest &&
        options.uri.path.contains('/group_member/page') &&
        '${options.queryParameters['gid']}' == _gid) {
      flowLog('[GM4] 拦截 page 请求（注入业务失败）');
      return ResponseBody.fromString(
        jsonEncode(<String, dynamic>{
          'code': 1,
          'msg': 'simulated_ds_down',
          'payload': <String, dynamic>{},
        }),
        200,
        headers: <String, List<String>>{
          Headers.contentTypeHeader: <String>[Headers.jsonContentType],
        },
      );
    }
    return _inner.fetch(options, requestStream, cancelFuture);
  }

  @override
  void close({bool force = false}) {
    _inner.close(force: force);
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('AT-GM4 分页失败回滚页码（业务失败注入）', (tester) async {
    if (!_allow) {
      markTestSkipped('需显式 TEST_ALLOW_GROUP_MEMBER_ACCEPTANCE=true');
      return;
    }
    app.main();
    await _pump(tester, seconds: 12);
    if (!await checkPreconditions(tester)) return;
    final loggedIn = await autoLoginOrSkip(tester);
    if (!loggedIn) return;
    expect(
      UserRepoLocal.to.currentUid,
      _expectedUid,
      reason: '必须是 smoke_bob（群主）',
    );

    // 注入开关：首屏请求之后才打开
    final failover = _FailoverAdapter();
    HttpClient.adapterForTest = failover;
    addTearDown(() => HttpClient.adapterForTest = null);

    final router = GoRouter.of(tester.element(find.byType(Navigator).first));
    router.push('/group/member', extra: <String, dynamic>{'groupId': _gid});
    await _pump(tester, seconds: 5);

    // 首屏第一页 20 条
    final title20 = await _waitFor(
      tester,
      () => tester.any(find.text('群成员 (20)')),
      seconds: 15,
    );
    expect(title20, isTrue, reason: 'AT-GM4 前置：首屏应加载第一页 20 条');

    // ---- 打开注入，触底触发 onLoad → 第 2 页业务失败 ----
    failover.failPageRequest = true;
    final listFinder = find.byType(ListView);
    expect(listFinder, findsOneWidget);
    for (var i = 0; i < 6; i++) {
      await tester.drag(listFinder, const Offset(0, -800));
      await _pump(tester, seconds: 1);
    }
    // 失败后：列表保持第一页 20 条（业务失败不清列表，页码回滚待重试）
    final still20 = await _waitFor(
      tester,
      () => tester.any(find.text('群成员 (20)')),
      seconds: 15,
    );
    expect(still20, isTrue, reason: 'AT-GM4 第二页失败后列表应保持 20 条');
    flowLog('[AT-GM4] 注入故障下触底加载失败，列表保持 20 条');

    // ---- 解除注入，再次触底 ----
    // _currentPage 若已回滚到 1，本次 loadMore 请求第 2 页 → 22 条；
    // 若未回滚（缺陷行为）则请求第 3 页 → 空列表 → 标题恒停 20。
    failover.failPageRequest = false;
    // 列表已在底部，纯 overscroll 不再触发 onLoad；先拖回顶部
    //（末次 overscroll 顺带触发 onRefresh 重载第一页），再触底加载。
    for (var i = 0; i < 8; i++) {
      await tester.drag(listFinder, const Offset(0, 800));
      await _pump(tester, seconds: 1);
    }
    await _waitFor(
      tester,
      () => tester.any(find.text('群成员 (20)')),
      seconds: 15,
    );
    for (var i = 0; i < 6; i++) {
      await tester.drag(listFinder, const Offset(0, -800));
      await _pump(tester, seconds: 1);
    }
    final title22 = await _waitFor(
      tester,
      () => tester.any(find.text('群成员 (22)')),
      seconds: 15,
    );
    expect(
      title22,
      isTrue,
      reason:
          'AT-GM4 恢复后重试应取回第 2 页共 22 条'
          '（页码未回滚则会请求第 3 页得 0 条，恒停在 20）',
    );
    flowLog('[AT-GM4] 页码回滚实证：恢复后重试命中第 2 页，20→22 无漏页');
  });
}
