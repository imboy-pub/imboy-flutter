/// T12 合同自测 — imboy-enterprise-uiux-v1
///
/// 必需清单（manifest）：
///  1. p1_action_enabled_contrast_at_least_3
///  2. p1_action_targets_at_least_48
///  3. p1_missing_callback_is_disabled_not_noop
///  4. p1_muted_is_toggleable_not_disabled
///  5. pending 不重复回调
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mocktail/mocktail.dart';
import 'package:imboy/service/channel_service.dart';
import 'package:imboy/page/channel/channel_di_provider.dart';
import 'package:imboy/store/model/channel_subscription_model.dart';

import 'dart:async' show Stream;
import 'dart:math' show pow;
import 'dart:convert' show jsonEncode;
import 'dart:typed_data' show Uint8List;

import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:imboy/component/http/http_client.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/channel/widgets/channel_header_bar.dart';
import 'package:imboy/store/model/channel_model.dart';
import 'package:imboy/service/storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:imboy/theme/default/theme.dart';
import 'package:imboy/theme/default/font_types.dart';

class _NotificationService extends Mock implements ChannelService {}

/// 其余 HTTP 路径的空成功出口；通知状态由独立依赖夹具提供。
class _T12NoopAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
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

ChannelModel _channel({
  bool managed = true,
  bool subscribed = false,
  bool verified = false,
}) {
  return ChannelModel(
    id: 1001,
    name: '工程效率频道',
    description: '说明',
    tags: const ['效率'],
    subscriberCount: 12,
    visibility: 0,
    accessType: 0,
    joinPolicy: 0,
    isVerified: verified,
    userRole: managed ? ChannelUserRole.admin : ChannelUserRole.none,
    creatorId: 1,
    isSubscribed: subscribed,
    createdAt: DateTime(2024, 1, 1),
    updatedAt: DateTime(2024, 1, 1),
  );
}

Future<void> pumpT12Header(
  WidgetTester tester, {
  required ChannelModel channel,
  VoidCallback? onManageTap,
  VoidCallback? onShareTap,
  VoidCallback? onForwardTap,
  VoidCallback? onActionTap,
  bool isActionPending = false,
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  await StorageService.init();
  HttpClient.adapterForTest = _T12NoopAdapter();
  addTearDown(() => HttpClient.adapterForTest = null);
  final service = _NotificationService();
  when(() => service.getSubscription(any())).thenAnswer(
    (_) async => ChannelSubscriptionModel(
      channelId: channel.id,
      subscribedAt: DateTime(2024),
      isMuted: false,
    ),
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [channelServiceProvider.overrideWithValue(service)],
      child: TranslationProvider(
        child: MaterialApp(
          theme: AppTheme.getLightThemeFromOption(FontSizeOption.normal),
          home: Scaffold(
            body: ChannelHeaderBar(
              channel: channel,
              onManageTap: onManageTap,
              onShareTap: onShareTap,
              onForwardTap: onForwardTap,
              onActionTap: onActionTap,
              isActionPending: isActionPending,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

CupertinoButton _buttonOfSemantics(WidgetTester tester, String label) {
  final Finder f = find.ancestor(
    of: find.bySemanticsLabel(label),
    matching: find.byType(CupertinoButton),
  );
  return tester.widget<CupertinoButton>(f.first);
}

/// WCAG 相对亮度对比度。
double contrastRatio(Color a, Color b) {
  double lum(Color c) {
    double ch(double v) {
      final double x = v / 255;
      return x <= 0.03928
          ? x / 12.92
          : pow((x + 0.055) / 1.055, 2.4).toDouble();
    }

    return 0.2126 * ch(c.r * 255.0) +
        0.7152 * ch(c.g * 255.0) +
        0.0722 * ch(c.b * 255.0);
  }

  final double l1 = lum(a);
  final double l2 = lum(b);
  final double lighter = l1 > l2 ? l1 : l2;
  final double darker = l1 > l2 ? l2 : l1;
  return (lighter + 0.05) / (darker + 0.05);
}

void main() {
  testWidgets('p1_action_enabled_contrast_at_least_3：可用动作图标对比度≥3:1', (
    tester,
  ) async {
    await pumpT12Header(
      tester,
      channel: _channel(managed: true, subscribed: true),
      onManageTap: () {},
      onShareTap: () {},
      onForwardTap: () {},
    );
    // 可用且非激活态动作（分享，次级文本色图标）对 HeaderBar 背景的对比度
    final Color surface = Theme.of(
      tester.element(find.byType(ChannelHeaderBar)),
    ).colorScheme.surface;
    final Icon shareIcon = tester.widget<Icon>(
      find.descendant(
        of: find.bySemanticsLabel('分享'),
        matching: find.byIcon(CupertinoIcons.share),
      ),
    );
    expect(
      contrastRatio(shareIcon.color!, surface),
      greaterThanOrEqualTo(3.0),
      reason: '可用动作图标与背景对比度必须 ≥3:1（D02）',
    );
  });

  testWidgets('p1_action_targets_at_least_48：动作点击目标≥48×48', (tester) async {
    await pumpT12Header(
      tester,
      channel: _channel(managed: true, subscribed: true),
      onManageTap: () {},
      onShareTap: () {},
      onForwardTap: () {},
    );
    for (final String label in <String>['分享', '发送给好友', '消息免打扰']) {
      final Size size = tester.getSize(find.bySemanticsLabel(label).first);
      expect(size.width, greaterThanOrEqualTo(48), reason: '$label 点击目标宽 ≥48');
      expect(size.height, greaterThanOrEqualTo(48), reason: '$label 点击目标高 ≥48');
    }
  });

  testWidgets('p1_missing_callback_is_disabled_not_noop：回调缺失即禁用', (
    tester,
  ) async {
    await pumpT12Header(
      tester,
      channel: _channel(managed: true, subscribed: true),
      // 只给管理回调：分享/转发缺失
      onManageTap: () {},
    );
    expect(_buttonOfSemantics(tester, '管理').onPressed, isNotNull);
    expect(
      _buttonOfSemantics(tester, '分享').onPressed,
      isNull,
      reason: '缺失回调必须禁用（onPressed=null），不得空函数假可用',
    );
    expect(_buttonOfSemantics(tester, '发送给好友').onPressed, isNull);
  });

  testWidgets('p1_muted_is_toggleable_not_disabled：静音动作始终可切换', (tester) async {
    await pumpT12Header(
      tester,
      channel: _channel(managed: true, subscribed: true),
      onManageTap: () {},
    );
    // 静音按钮（默认未静音：主色激活态）必须可点击切换
    final CupertinoButton mute = _buttonOfSemantics(tester, '消息免打扰');
    expect(mute.onPressed, isNotNull, reason: '静音是切换动作，任何视觉态都不得被禁用');
  });

  testWidgets('pending 不重复回调：进行中点击不触发', (tester) async {
    int calls = 0;
    await pumpT12Header(
      tester,
      channel: _channel(managed: false, subscribed: false),
      onActionTap: () => calls++,
      isActionPending: true,
    );
    // 未订阅的显著 CTA 是 FilledButton（非圆环动作），pending 即禁用
    final FilledButton subscribe = tester.widget<FilledButton>(
      find.byType(FilledButton),
    );
    expect(subscribe.onPressed, isNull, reason: '进行中必须禁用');
    await tester.tap(find.byType(FilledButton), warnIfMissed: false);
    await tester.pump();
    expect(calls, 0, reason: '进行中点击不得重复触发回调');
  });
}
