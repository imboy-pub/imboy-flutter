/// T13 合同自测 — imboy-enterprise-uiux-v1（W06/F12 收敛后改写）
///
/// 必需清单（manifest）：
///  1. p1_discuss_banner_removed_no_general_copy（J12：不造 General，
///     跳群列表常驻引导已移除）
///  2. p1_discuss_no_dm_entry（个人会话列表不是频道讨论目的地）
///  3. scale2 中英文均可读
library;

import 'dart:async' show Stream;
import 'dart:convert' show jsonEncode;
import 'dart:typed_data' show Uint8List;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:imboy/component/http/http_client.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/channel/channel_provider.dart';
import 'package:imboy/page/workspace/workspace_channel_detail_page.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/service/voice_playback_service.dart';
import 'package:imboy/theme/default/theme.dart';
import 'package:imboy/theme/default/font_types.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'p1_fixtures.dart';

/// 空成功出口（host 页内容区的兜底出站）。
class _T13NoopAdapter implements HttpClientAdapter {
  final List<String> paths = <String>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    paths.add(options.uri.path);
    return ResponseBody.fromString(
      jsonEncode(<String, dynamic>{'code': 0, 'msg': 'success'}),
      200,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>[Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

/// 挂载 workspace 宿主（W06 收敛后：内容区 = embedded ChannelDetailPage，
/// 无讨论引导横幅、无「全部消息」按钮）。
Future<void> pumpT13Host(WidgetTester tester, {double scale = 1.0}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  await StorageService.init();
  HttpClient.adapterForTest = _T13NoopAdapter();
  addTearDown(() => HttpClient.adapterForTest = null);

  final P1FixtureTrace trace = P1FixtureTrace();
  await tester.pumpWidget(
    TranslationProvider(
      child: ProviderScope(
        overrides: [
          channelDetailProvider.overrideWith(
            () => P1ChannelDetailFixture(
              trace: trace,
              channel: p1SyntheticChannel(managed: true),
              messages: p1SyntheticMessages(),
            ),
          ),
          voicePlaybackServiceProvider.overrideWith(P1SilentPlayback.new),
        ],
        child: MaterialApp(
          theme: AppTheme.getLightThemeFromOption(FontSizeOption.normal),
          builder: (BuildContext context, Widget? child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: const WorkspaceChannelDetailPage(channelId: '1001'),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

Finder get _banner =>
    find.byKey(const ValueKey('workspace-channel-discuss-guide'));

void main() {
  testWidgets('p1_discuss_banner_removed_no_general_copy：横幅移除且无 General 文案', (
    tester,
  ) async {
    await pumpT13Host(tester);
    expect(_banner, findsNothing, reason: 'F12：常驻讨论引导跳群列表与真实绑定入口并存，W06 已移除');
    // J12：不造 General——页面任何位置不得出现 General 字样引导。
    expect(find.textContaining('General'), findsNothing);
  });

  testWidgets('p1_discuss_no_dm_entry：无「全部消息/私聊」入口按钮', (tester) async {
    await pumpT13Host(tester);
    expect(
      find.byKey(const ValueKey('workspace-channel-detail-dm-entry')),
      findsNothing,
    );
  });

  testWidgets('scale2 中文可读：无渲染异常', (tester) async {
    await pumpT13Host(tester, scale: 2.0);
    expect(tester.takeException(), isNull);
    expect(_banner, findsNothing);
  });

  testWidgets('scale2 英文可读：无渲染异常', (tester) async {
    // slang 为各 locale 配置了 deferred library（l_en_US.loadLibrary）：
    // 必须异步加载，且加载走真实事件循环 —— 需在 tester.runAsync（真实
    // zone）内执行，否则 FakeAsync 下永挂；setLocaleSync 会抛
    // _DeferredNotLoadedError。
    await tester.runAsync(() => LocaleSettings.setLocale(AppLocale.enUs));
    addTearDown(() => LocaleSettings.setLocale(AppLocale.zhCn));
    await pumpT13Host(tester, scale: 2.0);
    expect(tester.takeException(), isNull);
    expect(find.textContaining('General'), findsNothing);
  });
}
