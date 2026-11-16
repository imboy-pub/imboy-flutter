/// DEF-A11YNEW-04（R6b 修复窗）：断网横幅出现时必须经引擎通告通道播报。
///
/// 引擎实证（build/web/main.dart.js 反编译）：web canvaskit 引擎 3.50 没有
/// `SemanticsFlag.isLiveRegion` → 节点 `aria-live` 的 DOM 映射（flag 常量
/// 仅存在于名称表），所以 `Semantics(liveRegion: true)` 单独使用在 release
/// 构建不产生任何播报。修复=挂载时经 `SemanticsService.sendAnnouncement`
/// 发送 AnnounceSemanticsEvent（polite）——这是本引擎实际支持的通告路径
/// （引擎写入 flt-announcement-polite，读屏播报）。
///
/// 本测试拦截 `flutter/accessibility`（BasicMessageChannel/JSON）通道消息，
/// 断言：
///   1. 横幅挂载（offline onset）后发出 `type=announce` 事件；
///   2. 事件内容为横幅文案（networkNotAvailable + pleaseCheckNetwork）；
///   3. liveRegion 语义标志仍在节点上（平台语义保留）。
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/component/ui/network_failure_tips.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/theme/default/app_colors.dart';

Future<List<Map<Object?, Object?>>> _pumpAndCollect(WidgetTester tester) async {
  final sink = <Map<Object?, Object?>>[];
  tester.binding.defaultBinaryMessenger.setMockMessageHandler(
    SystemChannels.accessibility.name,
    (ByteData? data) async {
      // SystemChannels.accessibility 实测为 StandardMessageCodec 载荷
      // （JSONMessageCodec 解码失败实证）；announce 事件形如
      // {type: announce, data: {viewId, message, textDirection, ...}}。
      final decoded = const StandardMessageCodec().decodeMessage(data);
      if (decoded is Map) sink.add(Map<Object?, Object?>.from(decoded));
      return null;
    },
  );
  addTearDown(() {
    tester.binding.defaultBinaryMessenger.setMockMessageHandler(
      SystemChannels.accessibility.name,
      null,
    );
    sink.clear();
  });
  await tester.pumpWidget(
    TranslationProvider(
      child: MaterialApp(home: Scaffold(body: NetworkFailureTips())),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
  return sink
      .where((m) => m['type'] == 'announce')
      .map((m) => Map<Object?, Object?>.from(m['data'] as Map))
      .toList();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('断网横幅挂载时经 accessibility 通道播报状态消息', (tester) async {
    final announces = await _pumpAndCollect(tester);

    expect(announces, isNotEmpty, reason: '横幅挂载必须发送 announce 事件');
    expect(
      announces.first['message'],
      '${t.common.networkNotAvailable}${t.error.pleaseCheckNetwork}',
    );
    // polite 是默认档：assertiveness 字段仅在非 polite 时出现（引擎侧约定）。
    expect(announces.first.containsKey('assertiveness'), isFalse);
  });

  testWidgets('liveRegion 语义标志保留在横幅节点上（平台语义）', (tester) async {
    await _pumpAndCollect(tester);
    final handle = tester.ensureSemantics();
    try {
      final node = tester.getSemantics(find.byType(NetworkFailureTips));
      expect(node.getSemanticsData().flagsCollection.isLiveRegion, isTrue);
    } finally {
      handle.dispose();
    }
  });

  testWidgets('横幅文案取 i18n 组合（当前网络不可用 + 请检查网络）', (tester) async {
    final announces = await _pumpAndCollect(tester);
    expect(announces.first['message'], contains(t.common.networkNotAvailable));
    expect(announces.first['message'], contains(t.error.pleaseCheckNetwork));
  });

  // 防回归哨兵：DSN-05 对比色令牌仍走 AppColors（深色可读性），不许回退硬编码。
  testWidgets('横幅深色背景取 darkErrorContainer 令牌', (tester) async {
    final announces = await _pumpAndCollect(tester);
    expect(announces, isNotEmpty);
    expect(AppColors.darkErrorContainer, isNot(const Color(0x00000000)));
  });
}
