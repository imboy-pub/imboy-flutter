/// T18 分享域共享测试工具（fixture 服务/发送通道注入、统一 pump）。
///
/// 纪律：零网络、零平台通道、零真实消息——数据走
/// FixtureTalkRecordShareService，卡片发送走 FixtureShareCardSender
///（结果标注示例）。本文件仅服务 widget fixture 测试，不是与真实
/// API/IM 的联调验收（T17/T22）。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:imboy/config/router/routes/talk_record_routes.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/modules/talk_record/presentation/detail/talk_record_detail_providers.dart';
import 'package:imboy/modules/talk_record/presentation/detail/talk_record_fixture_service.dart';
import 'package:imboy/modules/talk_record/presentation/detail/talk_record_playback_service.dart';
import 'package:imboy/modules/talk_record/presentation/share/talk_record_grant_edit_page.dart';
import 'package:imboy/modules/talk_record/presentation/share/talk_record_share_fixture_service.dart';
import 'package:imboy/modules/talk_record/presentation/share/talk_record_share_manage_page.dart';
import 'package:imboy/modules/talk_record/presentation/share/talk_record_share_providers.dart';
import 'package:imboy/modules/talk_record/presentation/talk_record_providers.dart'
    show talkRecordParticipantDirectoryProvider;
import 'package:imboy/modules/talk_record/presentation/talk_record_services.dart';

import 'talk_record_detail_test_helpers.dart' show FakePlayerBackend;

class T18Harness {
  T18Harness({
    FixtureTalkRecordShareService? service,
    FixtureShareCardSender? sender,
  }) : service = service ?? TalkRecordShareFixtureScenarios.ownerWithGrants(),
       sender = sender ?? FixtureShareCardSender();

  final FixtureTalkRecordShareService service;

  /// fixture 发送通道（默认成功；shouldSucceed=false 模拟失败）。
  final FixtureShareCardSender sender;
}

/// harness → ProviderScope。
///
/// 除分享域两个注入点外，一并 override 详情域（GoRouter 深链时 detail
/// 父页在栈中会 bind detail/segments/speakers/player——必须零网络零
/// 平台通道，复用 T16 fixture 与 Fake 播放后端）。
ProviderScope harnessScope(T18Harness harness, {required Widget child}) {
  return ProviderScope(
    overrides: [
      talkRecordShareServiceProvider.overrideWithValue(harness.service),
      talkRecordShareCardSenderProvider.overrideWithValue(harness.sender),
      talkRecordDetailServiceProvider.overrideWithValue(
        TalkRecordFixtureScenarios.transcribedWithSummary(),
      ),
      talkRecordPlaybackGatewayProvider.overrideWithValue(
        FixtureTalkRecordPlaybackGateway(),
      ),
      talkRecordPlayerBackendProvider.overrideWithValue(FakePlayerBackend()),
      talkRecordParticipantDirectoryProvider.overrideWithValue(
        const EmptyParticipantDirectory(),
      ),
    ],
    child: child,
  );
}

/// 直接 pump 分享管理页（无路由导航场景）。
Future<void> pumpShareManagePage(
  WidgetTester tester,
  T18Harness harness, {
  String recordId = '1001',
}) async {
  await tester.pumpWidget(
    harnessScope(
      harness,
      child: MaterialApp(home: TalkRecordShareManagePage(recordId: recordId)),
    ),
  );
  await tester.pumpAndSettle();
}

/// 经真实 GoRouter pump（分享管理/编辑权限/失效页导航场景）。
Future<GoRouter> pumpShareRouter(
  WidgetTester tester,
  T18Harness harness, {
  String initialLocation = '/talk_record/detail/1001/share',
}) async {
  final router = GoRouter(
    initialLocation: initialLocation,
    routes: talkRecordRoutes(),
  );
  await tester.pumpWidget(
    harnessScope(harness, child: MaterialApp.router(routerConfig: router)),
  );
  await tester.pumpAndSettle();
  return router;
}

/// 经真实 GoRouter pump 编辑权限页（query grant_id 为空=新建）。
Future<void> pumpGrantEditPage(
  WidgetTester tester,
  T18Harness harness, {
  String grantId = '',
  String recordId = '1001',
}) {
  final query = grantId.isEmpty ? '' : '?grant_id=$grantId';
  return pumpShareRouter(
    tester,
    harness,
    initialLocation: '/talk_record/detail/$recordId/share/grant_edit$query',
  );
}

/// 直接 pump 编辑权限页（MaterialApp home，无路由）。
Future<void> pumpGrantEditHome(
  WidgetTester tester,
  T18Harness harness, {
  String grantId = '',
  String recordId = '1001',
}) async {
  await tester.pumpWidget(
    harnessScope(
      harness,
      child: MaterialApp(
        home: TalkRecordGrantEditPage(recordId: recordId, grantId: grantId),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// 统一 zh-CN 文案断言前置。
Future<void> useZhCn() async {
  await LocaleSettings.setLocale(AppLocale.zhCn);
}
