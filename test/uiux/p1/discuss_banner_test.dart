/// T13 合同自测 — imboy-enterprise-uiux-v1
///
/// 必需清单（manifest）：
///  1. p1_discuss_has_exactly_one_direction_indicator
///  2. p1_discuss_tap_opens_original_group_target_once
///  3. scale2 中英文均可读
///  4. 文案无箭头（T06 冻结文案联动）
library;

import 'dart:async' show Stream;
import 'dart:convert' show jsonEncode;
import 'dart:typed_data' show Uint8List;

import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:imboy/component/http/http_client.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/channel/channel_provider.dart';
import 'package:imboy/page/workspace/workspace_channel_detail_page.dart';
import 'package:imboy/page/workspace/workspace_data_providers.dart';
import 'package:imboy/page/workspace/workspace_groups_page.dart';
import 'package:imboy/page/workspace_shell/workspace_shell_provider.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/service/voice_playback_service.dart';
import 'package:imboy/store/model/group_model.dart';
import 'package:imboy/store/model/workspace_model.dart';
import 'package:imboy/theme/default/theme.dart';
import 'package:imboy/theme/default/font_types.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'p1_fixtures.dart';

/// 空成功出口（host 页与群列表页的兜底出站）。
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

/// 挂载 workspace 宿主（真实 _DiscussInGroupBanner），群组 provider 注入
/// 合成数据（原讨论目标 WorkspaceGroupsPage 可达）。
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
          currentWorkspaceProvider.overrideWithValue(
            const WorkspaceModel(
              id: '100',
              name: 'synthetic-workspace',
              ownerId: '1',
              organizationId: '10',
            ),
          ),
          workspaceGroupsProvider('100').overrideWith(
            (ref) async => <GroupModel>[
              GroupModel.fromJson(<String, dynamic>{
                'id': 301,
                'title': 'General',
              }),
            ],
          ),
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
  testWidgets(
    'p1_discuss_has_exactly_one_direction_indicator：横幅恰一个方向指示且文案无箭头',
    (tester) async {
      await pumpT13Host(tester);
      expect(_banner, findsOneWidget);
      // 唯一方向指示：尾部 chevron
      expect(
        find.descendant(
          of: _banner,
          matching: find.byIcon(CupertinoIcons.chevron_forward),
        ),
        findsOneWidget,
      );
      // 文案无箭头字符（T06 冻结文案）
      final Text guide = tester.widget<Text>(
        find.descendant(of: _banner, matching: find.byType(Text)).first,
      );
      expect(
        RegExp(r'[→←⟶⟵➜➤]|->|<-').hasMatch(guide.data ?? ''),
        isFalse,
        reason: '文案不得再含箭头字符（与 chevron 双重指示）',
      );
    },
  );

  testWidgets('p1_discuss_tap_opens_original_group_target_once：点击进原群目标', (
    tester,
  ) async {
    await pumpT13Host(tester);
    await tester.tap(_banner);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(
      find.byType(WorkspaceGroupsPage),
      findsOneWidget,
      reason: '点击横幅打开原群列表入口（General 目标不变）',
    );
  });

  testWidgets('scale2 中文可读：无渲染异常', (tester) async {
    await pumpT13Host(tester, scale: 2.0);
    expect(tester.takeException(), isNull);
    expect(
      find.descendant(
        of: _banner,
        matching: find.byIcon(CupertinoIcons.chevron_forward),
      ),
      findsOneWidget,
    );
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
    expect(find.textContaining('Channels are for publishing'), findsOneWidget);
    expect(
      find.descendant(
        of: _banner,
        matching: find.byIcon(CupertinoIcons.chevron_forward),
      ),
      findsOneWidget,
    );
  });
}
