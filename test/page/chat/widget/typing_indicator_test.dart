import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:imboy/component/extension/imboy_cache_manager.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/config/env.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/chat/widget/typing_indicator.dart';
import 'package:imboy/service/event_bus.dart';
import 'package:imboy/service/events/message_events.dart';
import 'package:imboy/service/storage.dart';

/// TypingIndicatorWidget 输入指示器 widget 契约测试
///
/// 关键挑战：
///   - ConsumerStatefulWidget 监听 [AppEventBus] 上 [MessageTypingEvent]
///   - ref.watch(themeProvider.notifier) 调 getThemeColor()（state.isDarkMode 即可）
///   - UserRepoLocal.to.currentUid 用于过滤自己的 typing 事件
///   - 5 秒超时自动隐藏 → 测试用 tester.pump(Duration) 推进 timer
///
/// 覆盖：
///   - 初始隐藏（_isTyping=false）→ SizedBox.shrink
///   - 收到非自己 + 同会话 typing.start → 显示气泡 + peerTitle
///   - 收到 typing.stop → 隐藏
///   - 自己的 typing 事件被过滤
///   - 非当前会话事件被过滤
///   - 5 秒超时自动隐藏
const String _convUk3 = 'c2c:1838294017982464:1838294017982465';
const String _peerId = '1838294017982465';
const String _peerTitle = '张三';
const String _currentUid = 'tsid_uid_001';
const String _otherUid = 'tsid_uid_002';

Future<void> _pump(WidgetTester tester) async {
  await tester.pumpWidget(
    ProviderScope(
      child: TranslationProvider(
        child: const MaterialApp(
          home: Scaffold(
            body: TypingIndicatorWidget(
              conversationUk3: _convUk3,
              peerId: _peerId,
              peerTitle: _peerTitle,
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
    // 注入 currentUid 让 UserRepoLocal.to.currentUid 工作（typing 过滤逻辑用）
    await StorageService.to.setString(Keys.currentUid, _currentUid);
  });

  tearDownAll(() async {
    IMBoyCacheManager.debugLogEnabled = true;
    await StorageService.to.remove(Keys.currentUid);
  });

  group('TypingIndicatorWidget visibility', () {
    testWidgets('default state → hidden (SizedBox.shrink, 不渲染气泡)',
        (tester) async {
      await _pump(tester);

      // 初始 _isTyping=false → 整个 widget 树是 SizedBox.shrink
      // 应找不到 peerIsTyping 文案
      expect(find.textContaining(_peerTitle), findsNothing);
      // SizedBox.shrink 是 default
      expect(find.byType(TypingIndicatorWidget), findsOneWidget);

      await _unmount(tester);
    });

    testWidgets('收到 typing.start (非自己 + 同会话) → 显示气泡 + peerTitle',
        (tester) async {
      await _pump(tester);

      AppEventBus.fire(
        const MessageTypingEvent(
          conversationUk3: _convUk3,
          typierId: _otherUid,
          status: TypingStatus.start,
        ),
      );
      // EventBus 是 stream-based async；需要让 microtask + setState 完成
      await tester.pump(Duration.zero);
      await tester.pump();

      // 显示态：peerTitle "张三 正在输入..." 类似文案
      expect(find.textContaining(_peerTitle), findsOneWidget);

      await _unmount(tester);
    });

    testWidgets('收到 typing.stop → 立即隐藏', (tester) async {
      await _pump(tester);

      // 先 start
      AppEventBus.fire(
        const MessageTypingEvent(
          conversationUk3: _convUk3,
          typierId: _otherUid,
          status: TypingStatus.start,
        ),
      );
      await tester.pump(Duration.zero);
      await tester.pump();
      expect(find.textContaining(_peerTitle), findsOneWidget);

      // 再 stop
      AppEventBus.fire(
        const MessageTypingEvent(
          conversationUk3: _convUk3,
          typierId: _otherUid,
          status: TypingStatus.stop,
        ),
      );
      await tester.pump(Duration.zero);
      await tester.pump();
      expect(find.textContaining(_peerTitle), findsNothing);

      await _unmount(tester);
    });
  });

  group('TypingIndicatorWidget filters', () {
    testWidgets('自己的 typing.start → 不显示（被过滤）', (tester) async {
      await _pump(tester);

      AppEventBus.fire(
        const MessageTypingEvent(
          conversationUk3: _convUk3,
          typierId: _currentUid, // 自己
          status: TypingStatus.start,
        ),
      );
      await tester.pump();

      expect(find.textContaining(_peerTitle), findsNothing);
      await _unmount(tester);
    });

    testWidgets('非当前会话的 typing.start → 不显示（被过滤）', (tester) async {
      await _pump(tester);

      AppEventBus.fire(
        const MessageTypingEvent(
          conversationUk3: 'c2c:9999999999999:8888888888888', // 不同会话
          typierId: _otherUid,
          status: TypingStatus.start,
        ),
      );
      await tester.pump();

      expect(find.textContaining(_peerTitle), findsNothing);
      await _unmount(tester);
    });
  });

  group('TypingIndicatorWidget timeout', () {
    testWidgets('5 秒后自动隐藏（无新 start 事件维持）', (tester) async {
      await _pump(tester);

      AppEventBus.fire(
        const MessageTypingEvent(
          conversationUk3: _convUk3,
          typierId: _otherUid,
          status: TypingStatus.start,
        ),
      );
      await tester.pump(Duration.zero);
      await tester.pump();
      expect(find.textContaining(_peerTitle), findsOneWidget);

      // 推进 5 秒 + 100ms 缓冲触发 _hideTimer
      await tester.pump(const Duration(seconds: 5, milliseconds: 100));

      expect(
        find.textContaining(_peerTitle),
        findsNothing,
        reason: '5 秒后 _hideTimer 触发自动 _hideTyping',
      );

      await _unmount(tester);
    });
  });
}
