import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:imboy/component/extension/imboy_cache_manager.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/config/env.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/chat/widget/chat_input.dart';
import 'package:imboy/service/storage.dart';

/// ChatInput widget 契约测试
///
/// ChatInput 是 1262 行 StatefulWidget + TickerProviderStateMixin，依赖：
///   - mention_provider Riverpod
///   - emoji_picker_flutter 资源
///   - 多个动画 controller / focus node
///   - SendButtonVisibilityMode / 文本状态
///
/// 完整交互测试超出 ROI 范围，本文件聚焦：
///   1. **构造参数契约**（type / peerId / 默认值）— 不 pump widget
///   2. **isMuted=true 禁言态简化分支**（绕开 mention/emoji 复杂渲染）
///   3. **类型断言**（StatefulWidget / 默认值不变）
Future<void> _pump(
  WidgetTester tester, {
  required bool isMuted,
  String? muteMessage,
}) async {
  final composerHeight = ValueNotifier<double>(52);
  addTearDown(composerHeight.dispose);

  await tester.pumpWidget(
    ProviderScope(
      child: TranslationProvider(
        child: MaterialApp(
          home: Scaffold(
            body: ChatInput(
              type: 'C2C',
              peerId: 'peer_1',
              onSendPressed: (text) async => true,
              composerHeight: composerHeight,
              isMuted: isMuted,
              muteMessage: muteMessage,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

/// 按聊天类型渲染非禁言态输入行（用于验证工具区按钮可见性）。
/// 默认 text 模式不构建 emoji 面板；C2G 的群成员加载错误被 provider 吞掉，
/// 因此单次 pump 即可安全断言同步渲染的工具按钮。
Future<void> _pumpType(WidgetTester tester, String type) async {
  final composerHeight = ValueNotifier<double>(52);
  addTearDown(composerHeight.dispose);

  await tester.pumpWidget(
    ProviderScope(
      child: TranslationProvider(
        child: MaterialApp(
          home: Scaffold(
            body: ChatInput(
              type: type,
              peerId: 'peer_1',
              onSendPressed: (text) async => true,
              composerHeight: composerHeight,
            ),
          ),
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

  group('ChatInput construction contract', () {
    test('default values', () {
      final composerHeight = ValueNotifier<double>(52);
      addTearDown(composerHeight.dispose);

      final widget = ChatInput(
        type: 'C2C',
        peerId: 'peer_1',
        onSendPressed: (text) async => true,
        composerHeight: composerHeight,
      );

      expect(widget.type, 'C2C');
      expect(widget.peerId, 'peer_1');
      expect(widget.isMuted, false);
      expect(widget.muteMessage, isNull);
      // hintText 构造默认 null，渲染期兜底 t.chat.messageInputHint（chat_input.dart:875）
      expect(widget.hintText, isNull);
      expect(widget.autocorrect, true);
      expect(widget.autofocus, false);
      expect(widget.maxLines, 6);
      expect(widget.minLines, 1);
      expect(widget.maxLength, 1000);
      expect(widget.handleSafeArea, true);
      // 默认 sendButtonVisibilityMode（editing）
      expect(widget.textCapitalization, TextCapitalization.sentences);
      expect(widget.keyboardType, TextInputType.multiline);
      expect(widget.textInputAction, TextInputAction.newline);
    });

    test('ChatInput is a StatefulWidget', () {
      final composerHeight = ValueNotifier<double>(52);
      addTearDown(composerHeight.dispose);

      final widget = ChatInput(
        type: 'C2G',
        peerId: 'group_1',
        onSendPressed: (text) async => true,
        composerHeight: composerHeight,
      );
      expect(widget, isA<StatefulWidget>());
      expect(widget, isA<ChatInput>());
    });

    test('accepts type=C2G group chat scenario', () {
      final composerHeight = ValueNotifier<double>(52);
      addTearDown(composerHeight.dispose);

      final widget = ChatInput(
        type: 'C2G',
        peerId: 'group_42',
        onSendPressed: (text) async => true,
        composerHeight: composerHeight,
        isMuted: true,
        muteMessage: '管理员将群禁言',
      );
      expect(widget.type, 'C2G');
      expect(widget.isMuted, isTrue);
      expect(widget.muteMessage, '管理员将群禁言');
    });
  });

  group('ChatInput isMuted=true (muted state)', () {
    testWidgets('isMuted=true → 渲染禁言提示条 + volume_off icon', (tester) async {
      await _pump(tester, isMuted: true);

      // i18n: mutedCannotSend = "禁言期间无法发送消息"
      expect(find.text('禁言期间无法发送消息'), findsOneWidget);
      expect(find.byIcon(CupertinoIcons.volume_off), findsOneWidget);

      await _unmount(tester);
    });

    testWidgets('isMuted=true + custom muteMessage → 显示自定义文案 '
        '（覆盖默认 i18n）', (tester) async {
      await _pump(tester, isMuted: true, muteMessage: '你已被禁言 5 分钟');

      expect(find.text('你已被禁言 5 分钟'), findsOneWidget);
      // 默认文案不应再出现
      expect(find.text('禁言期间无法发送消息'), findsNothing);

      await _unmount(tester);
    });

    testWidgets('isMuted=true → 不渲染输入框 / emoji 按钮 / 发送按钮', (tester) async {
      await _pump(tester, isMuted: true);

      // 禁言态应仅渲染禁言提示，无 TextField / 发送按钮
      expect(find.byType(TextField), findsNothing);
      // 不渲染 hintText "Type a message"
      expect(find.text('Type a message'), findsNothing);

      await _unmount(tester);
    });
  });

  group('ChatInput @提及按钮可见性（仅 C2G）', () {
    final mentionButton = find.byKey(const Key('chat_mention_button'));

    testWidgets('type=C2G → 显示 @提及按钮（at 图标）', (tester) async {
      await _pumpType(tester, 'C2G');

      expect(mentionButton, findsOneWidget);
      expect(find.byIcon(CupertinoIcons.at), findsOneWidget);

      await _unmount(tester);
    });

    testWidgets('type=C2C → 不显示 @提及按钮', (tester) async {
      await _pumpType(tester, 'C2C');

      expect(mentionButton, findsNothing);
      expect(find.byIcon(CupertinoIcons.at), findsNothing);

      await _unmount(tester);
    });

    testWidgets('type=C2G 点击 @提及按钮 → 输入框插入 @ 触发提及', (tester) async {
      await _pumpType(tester, 'C2G');

      await tester.tap(mentionButton);
      await tester.pump();

      // showMentionPicker 在光标处插入 '@'
      final field = tester.widget<TextField>(
        find.byKey(const Key('chat_message_input')),
      );
      expect(field.controller?.text, '@');

      await _unmount(tester);
    });
  });
}
