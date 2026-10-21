/// T16 详情域共享测试工具（fixture 服务注入、Fake 播放后端、统一 pump）。
///
/// 纪律：零网络、零平台通道——数据走 FixtureTalkRecordDetailService，
/// 回放走 FixtureTalkRecordPlaybackGateway + FakePlayerBackend（手动推
/// 进度，不启动真实计时器）。本文件仅服务 widget fixture 测试，不是与
/// 真实 API/播放器的联调验收（T13/T15/T22）。
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:imboy/config/router/routes/talk_record_routes.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/modules/talk_record/presentation/detail/talk_record_detail_page.dart';
import 'package:imboy/modules/talk_record/presentation/detail/talk_record_detail_providers.dart';
import 'package:imboy/modules/talk_record/presentation/detail/talk_record_fixture_service.dart';
import 'package:imboy/modules/talk_record/presentation/detail/talk_record_playback_service.dart';
import 'package:imboy/modules/talk_record/presentation/talk_record_providers.dart';
import 'package:imboy/modules/talk_record/presentation/talk_record_services.dart';

/// 手动驱动的播放后端 Fake：记录调用、手动 emit 进度（无真实计时器）。
class FakePlayerBackend implements TalkRecordPlayerBackend {
  final List<(String url, int initialPositionMs)> loads = [];
  final List<int> plays = [];
  final List<int> pauses = [];
  final List<int> seeks = [];
  int stopCount = 0;

  final _controller =
      StreamController<TalkRecordPlayerBackendState>.broadcast();

  @override
  Stream<TalkRecordPlayerBackendState> get states => _controller.stream;

  @override
  Future<void> load(String url, {int initialPositionMs = 0}) async {
    loads.add((url, initialPositionMs));
  }

  @override
  Future<void> play() async {
    plays.add(0);
  }

  @override
  Future<void> pause() async {
    pauses.add(0);
  }

  @override
  Future<void> seek(int positionMs) async {
    seeks.add(positionMs);
  }

  @override
  Future<void> stop() async {
    stopCount++;
  }

  @override
  void dispose() {}

  /// 测试推进度（同时驱动续签触发点）。
  void emit(int positionMs, {bool playing = true, int durationMs = 0}) {
    _controller.add(
      TalkRecordPlayerBackendState(
        playing: playing,
        positionMs: positionMs,
        durationMs: durationMs,
      ),
    );
  }

  void emitCompleted(int durationMs) {
    _controller.add(
      TalkRecordPlayerBackendState(
        playing: false,
        positionMs: durationMs,
        durationMs: durationMs,
        completed: true,
      ),
    );
  }
}

/// 注入式参与者目录（标记同事用；默认不可用场景用 EmptyParticipantDirectory）。
class FakeDirectory implements TalkRecordParticipantDirectory {
  FakeDirectory([this.options = const []]);

  final List<TalkRecordParticipantOption> options;

  @override
  bool get isAvailable => true;

  @override
  Future<List<TalkRecordParticipantOption>> search(
    String organizationId,
    String q,
  ) async {
    return options;
  }
}

/// 角色能力 fixture（对齐 UI-SPEC §3 capabilities_for_actor 投影）。
const Map<String, dynamic> kOwnerCaps = {
  'edit': true,
  'share': true,
  'export': true,
  'can_delete': true,
  'playback': true,
};
const Map<String, dynamic> kEditorCaps = {
  'edit': true,
  'share': false,
  'export': false,
  'can_delete': false,
  'playback': true,
};
const Map<String, dynamic> kEditorExportCaps = {
  'edit': true,
  'share': false,
  'export': true,
  'can_delete': false,
  'playback': true,
};
const Map<String, dynamic> kViewerCaps = {
  'edit': false,
  'share': false,
  'export': false,
  'can_delete': false,
  'playback': true,
};

class T16Harness {
  T16Harness({
    FixtureTalkRecordDetailService? service,
    FixtureTalkRecordPlaybackGateway? gateway,
    FakePlayerBackend? backend,
    TalkRecordParticipantDirectory? directory,
  }) : service = service ?? TalkRecordFixtureScenarios.transcribedWithSummary(),
       gateway = gateway ?? FixtureTalkRecordPlaybackGateway(),
       backend = backend ?? FakePlayerBackend(),
       directory = directory ?? const EmptyParticipantDirectory();

  final FixtureTalkRecordDetailService service;
  final FixtureTalkRecordPlaybackGateway gateway;
  final FakePlayerBackend backend;
  final TalkRecordParticipantDirectory directory;
}

/// harness → ProviderScope（override 字面量在 use-site 推断，
/// flutter_riverpod 3.x 不导出 Override 类型，对齐 T10 写法）。
ProviderScope harnessScope(T16Harness harness, {required Widget child}) {
  return ProviderScope(
    overrides: [
      talkRecordDetailServiceProvider.overrideWithValue(harness.service),
      talkRecordPlaybackGatewayProvider.overrideWithValue(harness.gateway),
      talkRecordPlayerBackendProvider.overrideWithValue(harness.backend),
      talkRecordParticipantDirectoryProvider.overrideWithValue(
        harness.directory,
      ),
    ],
    child: child,
  );
}

/// 直接 pump 详情页（无路由导航的场景）。
Future<void> pumpDetailPage(WidgetTester tester, T16Harness harness) {
  return tester.pumpWidget(
    harnessScope(
      harness,
      child: MaterialApp(home: TalkRecordDetailPage(recordId: '1001')),
    ),
  );
}

/// 经真实 GoRouter pump（需要 push 片段校对/发言人页的导航场景）。
Future<GoRouter> pumpDetailRouter(
  WidgetTester tester,
  T16Harness harness, {
  String initialLocation = '/talk_record/detail/1001',
}) async {
  final router = GoRouter(
    initialLocation: initialLocation,
    routes: talkRecordRoutes(),
  );
  await tester.pumpWidget(
    harnessScope(harness, child: MaterialApp.router(routerConfig: router)),
  );
  return router;
}

/// 统一 zh-CN 文案断言前置。
Future<void> useZhCn() async {
  await LocaleSettings.setLocale(AppLocale.zhCn);
}
