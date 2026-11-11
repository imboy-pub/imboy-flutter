import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart'
    show
        ChatTheme,
        Message,
        MessageStatus,
        ResolveUserCallback,
        TextMessage,
        User,
        UserCache;
import 'package:flutter_chat_ui/flutter_chat_ui.dart'
    show
        OnMessageDoubleTapCallback,
        OnMessageLongPressCallback,
        OnMessageSecondaryTapCallback,
        OnMessageTapCallback;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart' as legacy_provider;

import 'package:imboy/component/chat/performance_monitor.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/modules/messaging/domain/message_status.dart'
    as domain_msg;
import 'package:imboy/modules/messaging/domain/selection/message_selection.dart';
import 'package:imboy/modules/messaging/domain/selection/message_selectability.dart';
import 'package:imboy/page/chat/chat/chat_message_item.dart';
import 'package:imboy/service/storage.dart';

/// ChatMessageItem 多选勾选态契约测试（chat_multi_select_v1 / W2-E）：
/// - 未激活/未传 conversationUk3：零 UI 变化（无勾选框）
/// - enter 激活后：每行渲染 44×44pt 勾选框；首条选中
/// - 点击勾选框 toggle 增删选中；不可选消息置灰且点击无效
/// - 已选消息变为不可选状态后仍可取消勾选
/// - 暗色 / 大字号渲染
/// - 列表滚动复用：状态按 message.id 从 provider 读取，不串选
const String _uk3 = 'conv_uk3_test';

TextMessage _text(
  String id, {
  String authorId = 'peer',
  Map<String, dynamic>? metadata,
  MessageStatus? status,
  DateTime? createdAt,
}) => TextMessage(
  id: id,
  authorId: authorId,
  text: 'body $id',
  metadata: metadata,
  status: status,
  createdAt:
      createdAt ??
      DateTime.fromMillisecondsSinceEpoch(
        1770000000000 + id.hashCode.abs() % 1000,
      ),
);

class _Harness extends StatelessWidget {
  const _Harness({required this.message, this.conversationUk3 = _uk3});

  final Message message;
  final String conversationUk3;

  @override
  Widget build(BuildContext context) {
    return ChatMessageItem(
      message: message,
      index: 0,
      animation: kAlwaysCompleteAnimation,
      currentUser: const User(id: 'me'),
      conversationUk3: conversationUk3,
      targetMsgId: '',
      targetMessageKey: GlobalKey(),
      burnTicker: const Stream<int>.empty(),
      performanceMonitor: ChatPerformanceMonitor(),
      readDelayTimers: {},
      readCommitted: {},
      onMessageStatusTap: (_, _) {},
      onVisibleRead: (_) async {},
      child: const SizedBox(width: 60, height: 20),
    );
  }
}

/// flutter_chat_ui 的 ChatMessage/Username 从 package:provider 作用域读取
/// 回调、用户缓存与 ChatTheme（真实 Chat widget 注入）；测试里补空实现。
Widget _withChatProviders(
  Widget child, {
  Brightness brightness = Brightness.light,
}) {
  return legacy_provider.MultiProvider(
    providers: [
      legacy_provider.Provider<String>.value(value: 'me'), // UserID
      legacy_provider.Provider<OnMessageTapCallback?>.value(value: null),
      legacy_provider.Provider<OnMessageDoubleTapCallback?>.value(value: null),
      legacy_provider.Provider<OnMessageLongPressCallback?>.value(value: null),
      legacy_provider.Provider<OnMessageSecondaryTapCallback?>.value(
        value: null,
      ),
      legacy_provider.Provider<ResolveUserCallback>.value(
        value: (id) async => id == 'me' ? const User(id: 'me') : null,
      ),
      legacy_provider.ChangeNotifierProvider<UserCache>.value(
        value: UserCache(),
      ),
      legacy_provider.Provider<ChatTheme>.value(
        value: brightness == Brightness.dark
            ? ChatTheme.dark()
            : ChatTheme.light(),
      ),
    ],
    child: child,
  );
}

Future<void> _pumpItem(
  WidgetTester tester,
  ProviderContainer container,
  Message message, {
  String conversationUk3 = _uk3,
  Brightness brightness = Brightness.light,
  TextScaler textScaler = TextScaler.noScaling,
}) async {
  await tester.pumpWidget(
    TranslationProvider(
      child: UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: ThemeData(brightness: brightness, useMaterial3: true),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: textScaler),
            child: child!,
          ),
          home: Scaffold(
            body: _withChatProviders(
              ListView(
                children: [
                  _Harness(message: message, conversationUk3: conversationUk3),
                ],
              ),
              brightness: brightness,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  // themeProvider 首次初始化会异步跑 applySystemTheme → toggleTheme 的
  // 300ms 动画延迟；推进假时钟，避免测试结束时遗留 pending Timer。
  await tester.pump(const Duration(milliseconds: 400));
}

MessageSelectionNotifier _selection(ProviderContainer container) =>
    container.read(messageSelectionProvider(_uk3).notifier);

void main() {
  setUp(() async {
    // enable_visibility_read 默认 true 会给每行挂 VisibilityDetector（其
    // paint 会调度 500ms 组合回调 Timer，与多选断言无关且会遗留 pending
    // Timer）——本文件聚焦多选勾选态，显式关闭已读推进路径。
    await StorageService.setMap(Keys.currentUser, {
      'setting': {'enable_visibility_read': false},
    });
  });

  testWidgets('未激活多选：不渲染勾选框（零 UI 变化）', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await _pumpItem(tester, container, _text('m1'));
    expect(find.byKey(const ValueKey('multi_select_check_m1')), findsNothing);
  });

  testWidgets('conversationUk3 为空（旧调用方）：不渲染勾选框', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await _pumpItem(tester, container, _text('m1'), conversationUk3: '');
    expect(find.byKey(const ValueKey('multi_select_check_m1')), findsNothing);
  });

  testWidgets('enter 激活：勾选框渲染、首条选中、触达区 ≥44×44pt', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await _pumpItem(tester, container, _text('m1'));
    _selection(container).enter(
      'm1',
      const MessageSelectionTraits(
        msgType: 'text',
        status: domain_msg.MessageStatus.sent,
      ),
    );
    await tester.pump();

    final checkFinder = find.byKey(const ValueKey('multi_select_check_m1'));
    expect(checkFinder, findsOneWidget);
    // 44×44pt 触达区（DESIGN.md §13.2 Hard Rule 1）。
    final rect = tester.getRect(checkFinder);
    expect(rect.width, greaterThanOrEqualTo(44.0));
    expect(rect.height, greaterThanOrEqualTo(44.0));
    // 选中态用实心图标。
    final icon = tester.widget<Icon>(
      find.descendant(of: checkFinder, matching: find.byType(Icon)),
    );
    expect(icon.icon, CupertinoIcons.checkmark_circle_fill);
  });

  testWidgets('点击勾选框 toggle：加入 → 取消', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await _pumpItem(tester, container, _text('m1'));
    _selection(container).enter(
      'm1',
      const MessageSelectionTraits(
        msgType: 'text',
        status: domain_msg.MessageStatus.sent,
      ),
    );
    await tester.pump();

    // m1 已选 → 点击取消。
    await tester.tap(find.byKey(const ValueKey('multi_select_check_m1')));
    await tester.pump();
    expect(
      container.read(messageSelectionProvider(_uk3)).contains('m1'),
      isFalse,
    );
    // 再点 → 重新选中。
    await tester.tap(find.byKey(const ValueKey('multi_select_check_m1')));
    await tester.pump();
    expect(
      container.read(messageSelectionProvider(_uk3)).contains('m1'),
      isTrue,
    );
  });

  testWidgets('不可选消息（发送中）：置灰 + 点击无效', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final sending = _text(
      'm_send',
      metadata: const {'msg_type': 'text'},
      status: MessageStatus.sending,
    );
    await _pumpItem(tester, container, sending);
    _selection(container).enter(
      'm_seed',
      const MessageSelectionTraits(
        msgType: 'text',
        status: domain_msg.MessageStatus.sent,
      ),
    );
    await tester.pump();

    final checkFinder = find.byKey(const ValueKey('multi_select_check_m_send'));
    expect(checkFinder, findsOneWidget);
    // 整行置灰。
    expect(
      tester
          .widget<Opacity>(
            find.ancestor(of: checkFinder, matching: find.byType(Opacity)),
          )
          .opacity,
      0.45,
    );
    await tester.tap(checkFinder, warnIfMissed: false);
    await tester.pump();
    expect(
      container.read(messageSelectionProvider(_uk3)).contains('m_send'),
      isFalse,
    );
  });

  testWidgets('E2EE 解密失败占位行：不可选', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final failed = _text(
      'm_e2ee',
      metadata: const {'msg_type': 'text', '_e2ee_failed': true},
    );
    await _pumpItem(tester, container, failed);
    _selection(container).enter(
      'm_seed',
      const MessageSelectionTraits(
        msgType: 'text',
        status: domain_msg.MessageStatus.sent,
      ),
    );
    await tester.pump();

    expect(
      find.byKey(const ValueKey('multi_select_check_m_e2ee')),
      findsOneWidget,
    );
    await tester.tap(
      find.byKey(const ValueKey('multi_select_check_m_e2ee')),
      warnIfMissed: false,
    );
    await tester.pump();
    expect(
      container.read(messageSelectionProvider(_uk3)).contains('m_e2ee'),
      isFalse,
    );
  });

  testWidgets('已选消息变为发送中：仍可取消勾选（W1-A 契约）', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final sending = _text(
      'm_sel',
      metadata: const {'msg_type': 'text'},
      status: MessageStatus.sending,
    );
    await _pumpItem(tester, container, sending);
    final notifier = _selection(container);
    // 先以可选状态选中（模拟消息尚未进入发送中时勾选）。
    notifier.enter(
      'm_sel',
      const MessageSelectionTraits(
        msgType: 'text',
        status: domain_msg.MessageStatus.sent,
      ),
    );
    await tester.pump();

    // 消息行现为发送中（不可选）但已勾选：勾选框保持可用，
    // 点击取消成功（toggle 已选分支不查可选性）。
    await tester.tap(find.byKey(const ValueKey('multi_select_check_m_sel')));
    await tester.pump();
    expect(
      container.read(messageSelectionProvider(_uk3)).contains('m_sel'),
      isFalse,
    );
  });

  testWidgets('暗色 / 大字号渲染无溢出', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await _pumpItem(tester, container, _text('m_dark'));
    _selection(container).enter(
      'm_dark',
      const MessageSelectionTraits(
        msgType: 'text',
        status: domain_msg.MessageStatus.sent,
      ),
    );
    await tester.pump();
    expect(
      find.byKey(const ValueKey('multi_select_check_m_dark')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);

    await _pumpItem(
      tester,
      container,
      _text('m_dark'),
      brightness: Brightness.dark,
      textScaler: const TextScaler.linear(1.4),
    );
    expect(
      find.byKey(const ValueKey('multi_select_check_m_dark')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('滚动复用：勾选态按 message.id 取自 provider，不串选', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    // 无 key 的复用列表（与 ChatAnimatedList 的 itemBuilder 复用同构）。
    final messages = List.generate(12, (i) => _text('m$i'));
    await tester.pumpWidget(
      TranslationProvider(
        child: UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: _withChatProviders(
                ListView.builder(
                  itemExtent: 72,
                  itemCount: messages.length,
                  itemBuilder: (context, index) =>
                      _Harness(message: messages[index]),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    // 激活并选中 m0 / m2。
    final notifier = _selection(container);
    notifier.enter(
      'm0',
      const MessageSelectionTraits(
        msgType: 'text',
        status: domain_msg.MessageStatus.sent,
      ),
    );
    notifier.toggle(
      'm2',
      const MessageSelectionTraits(
        msgType: 'text',
        status: domain_msg.MessageStatus.sent,
      ),
    );
    await tester.pump();

    // 初始视口内 m0/m2 勾选、m1 未选。
    expect(_isChecked(tester, 'm0'), isTrue);
    expect(_isChecked(tester, 'm1'), isFalse);
    expect(_isChecked(tester, 'm2'), isTrue);

    // 滚出再滚回（触发 item 复用重建）：勾选态不串。
    await tester.drag(find.byType(ListView), const Offset(0, -600));
    await tester.pumpAndSettle();
    expect(_isChecked(tester, 'm0'), isFalse); // 已滚出视口
    await tester.drag(find.byType(ListView), const Offset(0, 600));
    await tester.pumpAndSettle();
    expect(_isChecked(tester, 'm0'), isTrue); // 复用重建后按 id 取回选中态
    expect(_isChecked(tester, 'm2'), isTrue);

    final state = container.read(messageSelectionProvider(_uk3));
    expect(state.contains('m0'), isTrue);
    expect(state.contains('m2'), isTrue);
    expect(state.contains('m1'), isFalse);
    // 冲刷 themeProvider 初始化遗留的动画 Timer。
    await tester.pump(const Duration(milliseconds: 400));
  });
}

/// 勾选框当前是否为选中态（实心图标）。
bool _isChecked(WidgetTester tester, String messageId) {
  final finder = find.byKey(ValueKey('multi_select_check_$messageId'));
  if (finder.evaluate().isEmpty) return false;
  final icon = tester.widget<Icon>(
    find.descendant(of: finder, matching: find.byType(Icon)),
  );
  return icon.icon == CupertinoIcons.checkmark_circle_fill;
}
