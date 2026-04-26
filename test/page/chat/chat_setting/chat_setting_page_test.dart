import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:imboy/component/extension/imboy_cache_manager.dart';
import 'package:imboy/component/ui/cell_pressable.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/config/env.dart';
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

    testWidgets('renders 默认未加密提示', (tester) async {
      await _pump(tester);
      // 默认 options=null → 走"未加密"提示分支
      // i18n: msgNotEncrypted = "消息未加密传输"
      expect(find.text('消息未加密传输'), findsOneWidget);
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
}
