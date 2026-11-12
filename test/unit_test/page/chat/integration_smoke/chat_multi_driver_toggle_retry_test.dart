// test/unit_test/page/chat/integration_smoke/chat_multi_driver_toggle_retry_test.dart
//
// DEV-01 修复锚（RUN_ID=chat-multi-20261111）——
// integration_test/helpers/chat_multi_driver.dart 的两条行为在本机 widget 级
// 验证：
// 1. enterMultiSelectViaMenu 后计数=1（W1-A enter 契约：进入即选中长按消息）
//    —— 计数 Text 键约定与生产 action bar 同源（multi_select_count）；
// 2. toggleMessageSelection 的「tap 未注册 → 校验计数 → 重试」：假页把
//    首个 tap 吞掉（模拟真机入场噪声），driver 必须重试并注册勾选。
//
// 勾选回调接真 production 函数 toggleMessageSelectionWithFeedback +
// 真 messageSelectionProvider + 真 TextMessage fixtures（与 W3-K 设备用例
// 同一 toggle 链路）。

import 'package:flutter/material.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart' as core;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:imboy/modules/messaging/domain/selection/message_selection.dart';
import 'package:imboy/page/chat/chat/chat_message_item.dart';

import '../../../../../integration_test/helpers/chat_multi_driver.dart';
import '../../../../../integration_test/helpers/chat_multi_fixtures.dart';

const _uk3 = 'C2C_w3k_toggle_retry';

/// 假聊天页：勾选框 + action bar 计数（键名与生产 W2-E 同约定）。
///
/// 状态机走真 provider：initState 模拟 W1-A enter 契约（m1 预选 → 计数=1）。
/// [swallowFirstTapOf] 指定的消息 id 第一次 tap 被吞（模拟真机 tap 丢失），
/// 后续 tap 正常走生产 toggle；其余 id 一次 tap 即 toggle。
class _FakeChatMultiPage extends ConsumerStatefulWidget {
  const _FakeChatMultiPage({required this.swallowFirstTapOf});

  final String swallowFirstTapOf;

  @override
  ConsumerState<_FakeChatMultiPage> createState() => _FakeChatMultiPageState();
}

class _FakeChatMultiPageState extends ConsumerState<_FakeChatMultiPage> {
  final Set<String> _firstTapSwallowed = <String>{};

  core.Message _msgOf(String id) => ChatMultiMessageFixtures.text(
    id: id,
    text: 'toggle-target-$id',
    authorId: 'w3k-self',
    createdAt: DateTime.fromMillisecondsSinceEpoch(1700000000000),
  );

  @override
  void initState() {
    super.initState();
    // W1-A enter 契约：进入多选即选中长按消息（m1 预选 → 计数=1）。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref
          .read(messageSelectionProvider(_uk3).notifier)
          .enter('m1', messageSelectionTraitsOf(_msgOf('m1')));
    });
  }

  @override
  Widget build(BuildContext context) {
    final selection = ref.watch(messageSelectionProvider(_uk3));
    final ids = <String>['m1', 'm2'];
    return Scaffold(
      body: Column(
        children: [
          for (final id in ids)
            GestureDetector(
              key: chatMultiCheckboxKey(id),
              behavior: HitTestBehavior.opaque,
              onTap: () {
                if (id == widget.swallowFirstTapOf &&
                    !_firstTapSwallowed.contains(id)) {
                  // 模拟真机入场噪声：首个 tap 不注册（无状态变化）。
                  _firstTapSwallowed.add(id);
                  return;
                }
                toggleMessageSelectionWithFeedback(ref, _uk3, _msgOf(id));
              },
              child: SizedBox(
                width: 44,
                height: 44,
                child: Icon(
                  selection.contains(id)
                      ? Icons.check_circle
                      : Icons.radio_button_unchecked,
                ),
              ),
            ),
          Text('已选 ${selection.count} 条', key: ChatMultiKeys.count),
        ],
      ),
    );
  }
}

void main() {
  Future<void> pumpPage(WidgetTester tester, String swallowId) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: _FakeChatMultiPage(swallowFirstTapOf: swallowId),
        ),
      ),
    );
    // 排帧：让 initState 的 enter 契约回调执行（计数=1）。
    await tester.pump();
    expect(
      find.text('已选 1 条'),
      findsOneWidget,
      reason: 'enter 契约：进入多选即选中 m1（计数=1）',
    );
  }

  ProviderContainer containerOf(WidgetTester tester) =>
      ProviderScope.containerOf(
        tester.element(find.byType(_FakeChatMultiPage)),
      );

  testWidgets('enter 契约：进入即计数=1；吞 tap 后 driver 重试注册 m2（计数=2）', (tester) async {
    await pumpPage(tester, 'm2');

    await toggleMessageSelection(
      tester,
      find.byType(Scaffold),
      messageId: 'm2',
    );

    final container = containerOf(tester);
    final state = container.read(messageSelectionProvider(_uk3));
    expect(state.contains('m2'), isTrue, reason: '吞 tap 场景重试后 m2 勾选应注册');
    expect(state.contains('m1'), isTrue, reason: 'm1 保持 enter 预选');
    expect(find.text('已选 2 条'), findsOneWidget);
  });

  testWidgets('正常路径：一次 tap 即注册（不触发重试分支）', (tester) async {
    await pumpPage(tester, '__none__');

    await toggleMessageSelection(
      tester,
      find.byType(Scaffold),
      messageId: 'm2',
    );

    final container = containerOf(tester);
    expect(
      container.read(messageSelectionProvider(_uk3)).contains('m2'),
      isTrue,
      reason: 'tap 应注册',
    );
    expect(find.text('已选 2 条'), findsOneWidget);
  });
}
