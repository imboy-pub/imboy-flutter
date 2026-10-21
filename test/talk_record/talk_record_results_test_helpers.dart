/// T21 结果域共享测试工具（fixture 服务注入、统一 pump）。
///
/// 纪律：零网络、零平台通道——数据走 FixtureTalkRecordResultsService。
/// GoRouter 深链 export/transfer/cleanup 时 detail 父页在栈中会 bind
/// 详情域 → 一并 override 详情域四注入点（复用 T16 fixture 与
/// FakePlayerBackend，对齐 T18 helpers）。
library;

import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:imboy/modules/talk_record/presentation/results/talk_record_export_delivery.dart';
import 'package:imboy/modules/talk_record/application/talk_record_local_binding.dart';
import 'package:imboy/modules/talk_record/presentation/talk_record_pending_uploads.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:imboy/config/router/routes/talk_record_routes.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/modules/talk_record/presentation/detail/talk_record_detail_providers.dart';
import 'package:imboy/modules/talk_record/presentation/detail/talk_record_fixture_service.dart';
import 'package:imboy/modules/talk_record/presentation/detail/talk_record_playback_service.dart';
import 'package:imboy/modules/talk_record/presentation/results/talk_record_delete_page.dart';
import 'package:imboy/modules/talk_record/presentation/results/talk_record_export_page.dart';
import 'package:imboy/modules/talk_record/presentation/results/talk_record_results_fixture_service.dart';
import 'package:imboy/modules/talk_record/presentation/results/talk_record_results_providers.dart';
import 'package:imboy/modules/talk_record/presentation/results/talk_record_transfer_page.dart';
import 'package:imboy/modules/talk_record/presentation/talk_record_providers.dart'
    show talkRecordParticipantDirectoryProvider;
import 'package:imboy/modules/talk_record/presentation/talk_record_services.dart';

import 'talk_record_detail_test_helpers.dart' show FakePlayerBackend;

class T21Harness {
  T21Harness({FixtureTalkRecordResultsService? service})
    : service =
          service ?? TalkRecordResultsFixtureScenarios.ownerExportAllowed();

  final FixtureTalkRecordResultsService service;

  /// 服务内单条目快捷访问（场景构造器均单记录）。
  TalkRecordResultsFixtureEntry get entry => service.entries.single;
}

/// harness → ProviderScope（结果域 + 详情域全覆盖注入）。
ProviderScope harnessScope(T21Harness harness, {required Widget child}) {
  return ProviderScope(
    overrides: [
      talkRecordPendingAccountProvider.overrideWithValue(
        const TalkRecordAccount('http://127.0.0.1', ''),
      ),
      talkRecordResultsServiceProvider.overrideWithValue(harness.service),
      talkRecordExportDeliveryProvider.overrideWithValue(
        TalkRecordExportDelivery(
          account: () =>
              const TalkRecordAccount('https://fixture.invalid', 'owner'),
          fetch: (_) async => ResponseBody.fromString('synthetic export', 200),
          save: ({
            required fileName,
            required bytes,
            required mimeType,
          }) async => Uri.file('/synthetic/export.txt'),
        ),
      ),
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

/// 经真实 GoRouter pump（export/transfer/cleanup 导航与返回路径场景）。
Future<GoRouter> pumpResultsRouter(
  WidgetTester tester,
  T21Harness harness, {
  required String initialLocation,
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

/// 直接 pump 导出页（MaterialApp home，无路由）。
Future<void> pumpExportPage(
  WidgetTester tester,
  T21Harness harness, {
  String recordId = '1001',
}) async {
  await tester.pumpWidget(
    harnessScope(
      harness,
      child: MaterialApp(home: TalkRecordExportPage(recordId: recordId)),
    ),
  );
  await tester.pumpAndSettle();
}

/// 直接 pump 移交页。
Future<void> pumpTransferPage(
  WidgetTester tester,
  T21Harness harness, {
  String recordId = '1001',
}) async {
  await tester.pumpWidget(
    harnessScope(
      harness,
      child: MaterialApp(home: TalkRecordTransferPage(recordId: recordId)),
    ),
  );
  await tester.pumpAndSettle();
}

/// 直接 pump 删除状态页。
Future<void> pumpDeletePage(
  WidgetTester tester,
  T21Harness harness, {
  String recordId = '1001',
}) async {
  await tester.pumpWidget(
    harnessScope(
      harness,
      child: MaterialApp(home: TalkRecordDeletePage(recordId: recordId)),
    ),
  );
  await tester.pumpAndSettle();
}

/// 统一 zh-CN 文案断言前置。
Future<void> useZhCn() async {
  await LocaleSettings.setLocale(AppLocale.zhCn);
}
