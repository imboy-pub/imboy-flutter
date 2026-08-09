/// 转账失败契约（2026-08-09 真机验证 Task #89 补充）：
///
/// transfer_send_page._handleSend 的失败分支是 `transferId == null` →
/// AppLoading.showError(operationFailedAgainLater)。所以 sendTransfer 的
/// 契约是：失败返回 null（页面弹"操作失败，请稍后再试"），成功返回
/// transfer_id（页面 pop 回聊天页触发 WS 投递）。绝不能把失败伪装成
/// 空字符串——那会让转账页当成"成功但无 id"卡死。
///
/// 真机实测路径：金额 0.5 元通过前端校验（≥0.1），服务端 `Amount >= 100`
/// 拒绝（前后端最低金额不一致：0.1 vs 1.0）→ 400 + msg"转账参数不合法"
/// → sendTransfer 应返回 null。
///
/// ⚠️ 环境说明：sendTransfer 失败分支内部 `await AppLoading.showError`
/// （wallet_api.dart:235，store 层耦合 UI toast），其 future 要等 overlay
/// 动画 complete 才返回。因此：
/// 1. 必须用 testWidgets + AppLoading.init() 搭 UI 环境，否则 EasyLoading
///    断言 `overlayEntry != null` 直接崩；
/// 2. 不能直接 `await sendTransfer(...)`——showError 的 future 依赖
///    AnimationController，testWidgets 里 await 会死锁，须不 await 并显式
///    pump 推进动画帧；
/// 3. 调用后须 pump 过 toast 的 2s 展示 Timer 并等 dismiss 动画完成，
///    否则测试结束报 pending timer / 活跃 ticker。
///
/// 测试原理同 fail_open_contract_test：注入恒返指定响应的 HttpClientAdapter，
/// 必须自己注入出口（Http2Adapter 绕过 HttpOverrides，不注入会真打生产）。
library;

import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:imboy/component/http/http_client.dart';
import 'package:imboy/component/ui/app_loading.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/store/api/wallet_api.dart';

/// 恒定返回给定 statusCode + JSON body 的出口
class _FixedResponseAdapter implements HttpClientAdapter {
  _FixedResponseAdapter(this.statusCode, this.body);
  final int statusCode;
  final String body;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromString(
      body,
      statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  late WalletApi api;

  setUp(() async {
    // ⚠️ 必须 mock platform channel：testWidgets 建了 binding 后，未 mock 的
    // MethodChannel 调用返回**永不完成**的 future（而 test() 无 binding 时
    // 是直接抛异常）。HttpClient._setDefaultConfig 走 accessToken →
    // flutter_secure_storage channel（user_repo_local.dart:42），不 mock 就
    // 挂死在 `await done.future`，10min 超时（曾实测两次）。
    // 对比：fail_open_contract_test 用 test() 能过，正是因为无 binding 时
    // channel 调用抛 Error 被断言成"请求失败"——那组测试实际没走到 dio。
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
          (MethodCall call) async => null,
        );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
          null,
        );
  });

  Future<void> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        builder: AppLoading.init(),
        home: const Scaffold(body: SizedBox()),
      ),
    );
  }

  /// 驱动一次 sendTransfer 并完整走完 toast 生命周期。
  ///
  /// 挂起链：sendTransfer → post（dio 异步链，时长不定）→ 失败分支
  /// `await AppLoading.showError`（future 依赖 overlay 动画 complete，
  /// container.dart:87-92，动画在 postFrame 才启动、isPersistentCallbacks
  /// 分支）。testWidgets 里固定帧 pump 无法预知 dio 链到达 showError 的
  /// 时机（曾实测 3 帧序列全超时 10min），所以有界循环 pump：每帧 100ms
  /// 推进 fake clock（覆盖任何 Future.delayed / 退避 / 动画），直到
  /// sendTransfer 的 future 完成（最多 6s）。
  Future<String?> driveSendTransfer(
    WidgetTester tester, {
    required String receiverUid,
    required int amount,
  }) async {
    final done = Completer<String?>();
    api
        .sendTransfer(receiverUid: receiverUid, amount: amount)
        .then(done.complete, onError: done.completeError);
    for (var i = 0; i < 60 && !done.isCompleted; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    final transferId = await done.future;
    // toast 展示 Timer(2s) 触发 → dismiss 动画 → _reset → overlay 移除
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    return transferId;
  }

  testWidgets('sendTransfer 服务端拒绝（400 转账参数不合法）返回 null', (tester) async {
    await pumpApp(tester);
    HttpClient.adapterForTest = _FixedResponseAdapter(
      400,
      '{"code":400,"msg":"转账参数不合法","payload":null}',
    );
    addTearDown(() => HttpClient.adapterForTest = null);
    // ⚠️ 必须在注入 adapter 之后构造：adapterForTest 只对之后构造的
    // dio 实例生效（http_client.dart:187），早构造会带真实 IO 适配器
    // 真打生产（曾实测 10min 超时）。
    api = WalletApi();

    final transferId = await driveSendTransfer(
      tester,
      receiverUid: '118',
      amount: 50, // 0.5 元 < 服务端下限 100 分
    );
    expect(transferId, isNull);
  });

  testWidgets('sendTransfer 成功返回 transfer_id 字符串', (tester) async {
    await pumpApp(tester);
    HttpClient.adapterForTest = _FixedResponseAdapter(
      200,
      // ⚠️ 业务成功码是 code:0（http_transformer.dart:22 `code == 0` 才 success），
      // 不是 HTTP 200——mock body 用 code:200 会被判定 failure 返回 null
      '{"code":0,"msg":"success.","payload":{"transfer_id":"105970867502319616"}}',
    );
    addTearDown(() => HttpClient.adapterForTest = null);
    api = WalletApi();

    final transferId = await driveSendTransfer(
      tester,
      receiverUid: '118',
      amount: 100,
    );
    expect(transferId, '105970867502319616');
  });

  testWidgets('sendTransfer 成功但缺 payload（异常响应）返回 null，不返回空串', (tester) async {
    await pumpApp(tester);
    HttpClient.adapterForTest = _FixedResponseAdapter(
      200,
      '{"code":0,"msg":"success.","payload":null}',
    );
    addTearDown(() => HttpClient.adapterForTest = null);
    api = WalletApi();

    final transferId = await driveSendTransfer(
      tester,
      receiverUid: '118',
      amount: 100,
    );
    expect(transferId, isNull);
  });
}
