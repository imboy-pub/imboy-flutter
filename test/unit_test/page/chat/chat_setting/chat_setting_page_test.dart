import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:imboy/component/extension/imboy_cache_manager.dart';
import 'package:imboy/component/ui/cell_pressable.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/config/env.dart';
import 'package:imboy/app_core/feature_flags/app_feature_registry.dart';
import 'package:imboy/app_core/feature_flags/generated_product_features.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/chat/chat_setting/chat_setting_page.dart';
import 'package:imboy/service/storage.dart';

/// ChatSettingPage widget test
///
/// 关键挑战：initState 调 _loadBurnSetting → ConversationRepo.findByPeerId
/// 异步链路（SqliteService）。测试中 sqlite mock 缺失会让 _loadBurnSetting
/// catch 异常静默失败，但不阻塞 build（_burnEnabled / _muteEnabled 保持默认 false）。
///
/// 覆盖：
///   - AppBar title "聊天设置"
///   - 渲染消息免打扰开关 / 加密提示
///   - 设置项使用 CellPressable
///   - 类型契约：type / peerId / options
Future<void> _pump(
  WidgetTester tester, {
  String type = 'C2C',
  String peerId = 'peer_1',
  Map<String, dynamic>? options,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      child: TranslationProvider(
        child: MaterialApp(
          home: ChatSettingPage(peerId, type: type, options: options),
        ),
      ),
    ),
  );
  await tester.pump();
}

Future<void> _unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    Env.uploadKey = 'test_dummy_upload_key';
    Env.uploadScene = 'test_scene';
    IMBoyCacheManager.debugLogEnabled = false;
    await StorageService.to.setString(Keys.currentUid, 'tsid_uid_001');
    // ccc47b60 起 AppFeatureRegistry.snapshot 按账号 scope 隔离：scope 未
    // 绑定时 snapshot 为空，e2ee 等编译特性缺省判 false（仅 core 例外）。
    // 「完整编译集合下入口可见」的既有断言需要显式给出远程 snapshot。
    AppFeatureRegistry.replaceSnapshotForTest({'e2ee': true});
  });

  tearDownAll(() async {
    IMBoyCacheManager.debugLogEnabled = true;
    await StorageService.to.remove(Keys.currentUid);
  });

  group('ChatSettingPage construction contract', () {
    test('default options is null', () {
      const page = ChatSettingPage('peer_1', type: 'C2C');
      expect(page.peerId, 'peer_1');
      expect(page.type, 'C2C');
      expect(page.options, isNull);
    });

    test('accepts options map', () {
      const page = ChatSettingPage(
        'peer_1',
        type: 'C2C',
        options: {'encryption_mode': 'e2ee'},
      );
      expect(page.options?['encryption_mode'], 'e2ee');
    });

    test('ChatSettingPage is a ConsumerStatefulWidget', () {
      const page = ChatSettingPage('peer_1', type: 'C2G');
      expect(page, isA<StatefulWidget>());
      expect(page, isA<ChatSettingPage>());
    });
  });

  group('ChatSettingPage layout', () {
    testWidgets('AppBar title 渲染 "聊天设置"', (tester) async {
      await _pump(tester);
      // i18n: chatSettings = "聊天设置"
      expect(find.text('聊天设置'), findsAtLeastNWidgets(1));
      await _unmount(tester);
    });

    testWidgets('renders 消息免打扰 setting item', (tester) async {
      await _pump(tester);
      // i18n: muteNotifications = "消息免打扰"
      expect(find.text('消息免打扰'), findsOneWidget);
      await _unmount(tester);
    });

    testWidgets('renders 默认未知加密态占位', (tester) async {
      await _pump(tester);
      // B2: options=null 且 EncryptionModeService 未初始化（widget 测试无
      // policy 拉取链路）→ 加密模式未知，显示中性占位 '-'，
      // 不得把实际可能已加密的会话谎报成"消息未加密传输"或具体模式名。
      expect(
        find.text('-'),
        compiledProductFeatures.contains('e2ee')
            ? findsOneWidget
            : findsNothing,
      );
      expect(find.text('消息未加密传输'), findsNothing);
      await _unmount(tester);
    });

    testWidgets('设置项使用 CellPressable', (tester) async {
      await _pump(tester);
      // chat_setting_page._buildSettingTile 使用 CellPressable
      expect(
        find.byType(CellPressable).evaluate().length,
        greaterThanOrEqualTo(1),
      );
      await _unmount(tester);
    });
  });

  group('ChatSettingPage E2EE 功能位隐藏', () {
    tearDown(() {
      // 恢复 setUpAll 基线 snapshot（scope 隔离语义下「缺省」即空表 →
      // 编译特性全部 false；本组用例验证的是远程缺省不扩大入口，故恢复
      // 到显式开启基线，由各用例自行覆盖关闭态）。
      AppFeatureRegistry.replaceSnapshotForTest({'e2ee': true});
    });

    testWidgets('features.e2ee=false：加密模式项与安全码项均不渲染', (tester) async {
      // 服务端硬闸档位（关闭/明文交付）会把 features.e2ee 置 false 下发
      AppFeatureRegistry.replaceSnapshotForTest(const {'e2ee': false});
      await _pump(tester, type: 'C2C');
      expect(find.text('-'), findsNothing);
      expect(find.text('标准模式'), findsNothing);
      expect(find.text('消息未加密传输'), findsNothing);
      expect(find.text('安全码验证'), findsNothing);
      // 其余设置项不受影响
      expect(find.text('消息免打扰'), findsOneWidget);
      await _unmount(tester);
    });

    testWidgets('features.e2ee 缺省：入口遵循编译功能集合', (tester) async {
      await _pump(tester, type: 'C2C');
      // 完整配置保留 B2 未知加密态占位；第一期不能因远程缺省开启入口。
      final expected = compiledProductFeatures.contains('e2ee')
          ? findsOneWidget
          : findsNothing;
      expect(find.text('-'), expected);
      expect(find.text('安全码验证'), expected);
      expect(find.text('消息免打扰'), findsOneWidget);
      await _unmount(tester);
    });
  });
}
