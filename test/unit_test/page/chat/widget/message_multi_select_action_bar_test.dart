import 'package:flutter/material.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart'
    show Message, TextMessage;
import 'package:flutter_test/flutter_test.dart';

import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/chat/chat/chat_multi_select_wiring.dart'
    show forwardEachActionAllowedFor;
import 'package:imboy/page/chat/chat/services/message_selection_traits.dart';
import 'package:imboy/page/chat/send_to/batch_forward_coordinator.dart'
    show kBatchForwardMaxMessages;
import 'package:imboy/page/chat/widget/message_multi_select_action_bar.dart';

/// MessageMultiSelectActionBar 契约测试（chat_multi_select_v1 / W2-E）：
/// - 已选计数展示（multiSelectCount）
/// - 动作按钮可用性：选中数>0 且 callback 非空才可点；禁用态不触发
/// - typed callback 收到传入的 selectedMessages（顺序保持）
/// - 取消 / 全不选回调；onClearSelection null 时隐藏全不选
/// - 暗色 / 大字号 / 窄屏渲染无溢出
List<Message> _messages(int n) => List.generate(
  n,
  (i) => TextMessage(
    id: 'm$i',
    authorId: 'peer',
    text: 'msg $i',
    createdAt: DateTime.fromMillisecondsSinceEpoch(1000 + i),
  ),
);

Widget _wrap(
  Widget child, {
  Brightness brightness = Brightness.light,
  TextScaler textScaler = TextScaler.noScaling,
}) {
  return TranslationProvider(
    child: MaterialApp(
      theme: ThemeData(brightness: brightness, useMaterial3: true),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: textScaler),
        child: child!,
      ),
      home: Scaffold(
        body: Align(alignment: Alignment.bottomCenter, child: child),
      ),
    ),
  );
}

void main() {
  testWidgets('渲染已选计数（已选 N 条）', (tester) async {
    await tester.pumpWidget(
      _wrap(
        MessageMultiSelectActionBar(
          selectedMessages: _messages(3),
          onCancel: () {},
        ),
      ),
    );
    expect(find.text(t.chat.multiSelectCount(count: 3)), findsOneWidget);
    expect(find.byKey(const ValueKey('multi_select_count')), findsOneWidget);
  });

  testWidgets('选中数为 0：三个动作按钮禁用且不触发回调', (tester) async {
    var fired = 0;
    await tester.pumpWidget(
      _wrap(
        MessageMultiSelectActionBar(
          selectedMessages: const [],
          onCancel: () {},
          onForwardEach: (_) => fired++,
          onForwardBundle: (_) => fired++,
          onExport: (_) => fired++,
        ),
      ),
    );
    for (final key in const [
      ValueKey('multi_select_forward_each'),
      ValueKey('multi_select_forward_bundle'),
      ValueKey('multi_select_export'),
    ]) {
      final gesture = tester.widget<GestureDetector>(find.byKey(key));
      expect(gesture.onTap, isNull, reason: '$key 应禁用');
    }
    await tester.tap(find.byKey(const ValueKey('multi_select_forward_each')));
    await tester.pump();
    expect(fired, 0);
  });

  testWidgets('typed callback 未接线（null）：按钮禁用占位', (tester) async {
    await tester.pumpWidget(
      _wrap(
        MessageMultiSelectActionBar(
          selectedMessages: _messages(1),
          onCancel: () {},
          // Central Wiring 接线前的默认形态：无任何动作 callback。
        ),
      ),
    );
    final gesture = tester.widget<GestureDetector>(
      find.byKey(const ValueKey('multi_select_forward_each')),
    );
    expect(gesture.onTap, isNull);
  });

  testWidgets('选中>0：动作按钮触发并携带原顺序 selectedMessages', (tester) async {
    final msgs = _messages(3);
    List<Message>? received;
    await tester.pumpWidget(
      _wrap(
        MessageMultiSelectActionBar(
          selectedMessages: msgs,
          onCancel: () {},
          onForwardEach: (list) => received = list,
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('multi_select_forward_each')));
    await tester.pump();
    expect(received, same(msgs));
    expect(received?.map((m) => m.id).toList(), ['m0', 'm1', 'm2']);
  });

  testWidgets('取消与全不选回调；onClearSelection=null 时隐藏全不选', (tester) async {
    var canceled = 0;
    var cleared = 0;
    await tester.pumpWidget(
      _wrap(
        MessageMultiSelectActionBar(
          selectedMessages: _messages(2),
          onCancel: () => canceled++,
          onClearSelection: () => cleared++,
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('multi_select_cancel')));
    await tester.pump();
    expect(canceled, 1);
    await tester.tap(find.byKey(const ValueKey('multi_select_clear')));
    await tester.pump();
    expect(cleared, 1);

    await tester.pumpWidget(
      _wrap(
        MessageMultiSelectActionBar(
          selectedMessages: _messages(2),
          onCancel: () {},
        ),
      ),
    );
    expect(find.byKey(const ValueKey('multi_select_clear')), findsNothing);
  });

  testWidgets('暗色主题渲染正常', (tester) async {
    await tester.pumpWidget(
      _wrap(
        MessageMultiSelectActionBar(
          selectedMessages: _messages(1),
          onCancel: () {},
        ),
        brightness: Brightness.dark,
      ),
    );
    expect(find.byType(MessageMultiSelectActionBar), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('大字号（1.4x）渲染无溢出', (tester) async {
    await tester.pumpWidget(
      _wrap(
        MessageMultiSelectActionBar(
          selectedMessages: _messages(9),
          onCancel: () {},
          onClearSelection: () {},
        ),
        textScaler: const TextScaler.linear(1.4),
      ),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('窄屏（320pt）渲染无溢出', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      _wrap(
        MessageMultiSelectActionBar(
          selectedMessages: _messages(12),
          onCancel: () {},
          onClearSelection: () {},
          onForwardEach: (_) {},
          onForwardBundle: (_) {},
          onExport: (_) {},
        ),
      ),
    );
    expect(tester.takeException(), isNull);
  });

  group('W5-G1 | 逐条转发 50 条上限入口拦截（G1-1）', () {
    /// 与 ChatMultiSelectPanel 同一接线口径：策略 → null callback → 禁用。
    MessageMultiSelectActionBar barPerPolicy(
      List<Message> msgs, {
      void Function(List<Message>)? onAllowed,
    }) => MessageMultiSelectActionBar(
      selectedMessages: msgs,
      onCancel: () {},
      onForwardEach:
          forwardEachActionAllowedFor(msgs.map(messageSelectionTraitsOf))
          ? (onAllowed ?? (_) {})
          : null,
    );

    test('策略：0 条禁用；1..50 可用；>50（51）禁用', () {
      final max = kBatchForwardMaxMessages;
      expect(max, 50, reason: 'SendToPage.batch 协调器硬上限');
      expect(
        forwardEachActionAllowedFor(_messages(0).map(messageSelectionTraitsOf)),
        isFalse,
        reason: '未勾选（0 条）不可逐条转发',
      );
      expect(
        forwardEachActionAllowedFor(_messages(1).map(messageSelectionTraitsOf)),
        isTrue,
      );
      expect(
        forwardEachActionAllowedFor(
          _messages(max).map(messageSelectionTraitsOf),
        ),
        isTrue,
        reason: '恰好 50 条应可用（上限含边界）',
      );
      expect(
        forwardEachActionAllowedFor(
          _messages(max + 1).map(messageSelectionTraitsOf),
        ),
        isFalse,
        reason: '第 51 条起入口禁用（协调器超限前置拦截）',
      );
    });

    testWidgets('>50 条：逐条转发按钮禁用且点击不触发（null callback）', (tester) async {
      var fired = 0;
      await tester.pumpWidget(
        _wrap(
          barPerPolicy(
            _messages(kBatchForwardMaxMessages + 1),
            onAllowed: (_) => fired++,
          ),
        ),
      );
      final gesture = tester.widget<GestureDetector>(
        find.byKey(const ValueKey('multi_select_forward_each')),
      );
      expect(gesture.onTap, isNull, reason: '超限时应传 null（禁用占位）');
      await tester.tap(find.byKey(const ValueKey('multi_select_forward_each')));
      await tester.pump();
      expect(fired, 0, reason: '禁用态不可触发任何行为');
    });

    testWidgets('<=50 条（50 整）：逐条转发可用并携带全部已选', (tester) async {
      var fired = 0;
      var received = 0;
      await tester.pumpWidget(
        _wrap(
          barPerPolicy(
            _messages(kBatchForwardMaxMessages),
            onAllowed: (list) {
              fired++;
              received = list.length;
            },
          ),
        ),
      );
      final gesture = tester.widget<GestureDetector>(
        find.byKey(const ValueKey('multi_select_forward_each')),
      );
      expect(gesture.onTap, isNotNull, reason: '50 条（含边界）应可用');
      await tester.tap(find.byKey(const ValueKey('multi_select_forward_each')));
      await tester.pump();
      expect(fired, 1);
      expect(received, kBatchForwardMaxMessages);
    });
  });
}
